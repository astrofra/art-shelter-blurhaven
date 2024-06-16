-- Copyright (c) Astrofra
-- Licensed under the MIT license. See LICENSE file in the project root for details.

function LoadPhotoFromTable(_photo_table, _photo_idx)
	return hg.LoadTextureFromAssets('photos/' .. _photo_table[_photo_idx] .. '.png', hg.TF_UClamp)
end

hg = require("harfang")
require("utils")
require("arguments")
require("coroutines")

hg.InputInit()
hg.WindowSystemInit()
hg.AudioInit()

-- local res_x, res_y = 768, 576
-- local res_x, res_y = 800, 600
local res_x, res_y = 960, 720
-- local res_x, res_y = math.floor(1080 * (4/3)), 1080
local default_window_mode = hg.WV_Windowed

local options = parseArgs(arg)
local screen_modes = {
	Windowed = hg.WV_Windowed,
    Undecorated = hg.WV_Undecorated,
    Fullscreen = hg.WV_Fullscreen,
    Hidden = hg.WV_Hidden,
    FullscreenMonitor1 = hg.WV_FullscreenMonitor1,
    FullscreenMonitor2 = hg.WV_FullscreenMonitor2,
    FullscreenMonitor3 = hg.WV_FullscreenMonitor3
}
if options.output then
	default_window_mode = screen_modes[options.output]
end
if options.width then
	res_x = options.width
end
if options.height then
	res_y = options.height
end

local win = hg.NewWindow('Blurhaven', res_x, res_y, 32, default_window_mode) --, hg.WV_Fullscreen)
hg.RenderInit(win)
hg.RenderReset(res_x, res_y, hg.RF_VSync | hg.RF_MSAA4X | hg.RF_MaxAnisotropy)

hg.AddAssetsFolder('assets_compiled')

pipeline = hg.CreateForwardPipeline()
res = hg.PipelineResources()

-- text rendering
-- load font and shader program
local max_font_index = 440
local font_size = math.floor(60 * (res_x / 960.0))
local font = {}

for font_idx = 1, max_font_index do
    local font_name = string.format("ai_font_%03d.otf", font_idx)
    table.insert(font, hg.LoadFontFromAssets("fonts/" .. font_name, font_size))

	-- progress feedback on screen
	local progress_value = font_idx / max_font_index
	hg.SetViewClear(0, hg.CF_Color | hg.CF_Depth, hg.Color(progress_value, progress_value, progress_value, 1.0), 1, 0)
	hg.SetViewRect(0, 0, 0, res_x, res_y)

	hg.Touch(0)  -- force the view to be processed as it would be ignored since nothing is drawn to it (a clear does not count)

	hg.Frame()
	hg.UpdateWindow(win)
end

local font_program = hg.LoadProgramFromAssets('core/shader/font')
local font_rand_0 = 1
local font_rand_1 = 0
local font_rand_2 = 0

-- text uniforms and render state
local text_uniform_values = {hg.MakeUniformSetValue('u_color', hg.Vec4(1, 1, 0, 1))}
local text_render_state = hg.ComputeRenderState(hg.BM_Alpha, hg.DT_Always, hg.FC_Disabled)

-- VHS fx shader
screen_prg = hg.LoadProgramFromAssets('shaders/vhs_fx.vsb', 'shaders/vhs_fx.fsb')

-- create a plane model for the final rendering stage
local vtx_layout = hg.VertexLayoutPosFloatNormUInt8TexCoord0UInt8()

local screen_zoom = 1
local screen_mdl = hg.CreatePlaneModel(vtx_layout, screen_zoom, screen_zoom * (res_y / res_x), 1, 1)
local screen_ref = res:AddModel('screen', screen_mdl)

-- video stream
local tex_video = hg.CreateTexture(res_x, res_y, "Video texture", 0)
local size = hg.iVec2(res_x, res_y)
local fmt = hg.TF_RGB8

local streamer = hg.MakeVideoStreamer('hg_ffmpeg.dll')
streamer:Startup()
local handle = streamer:Open('assets_compiled/videos/noise-512x512.mp4')
streamer:Play(handle)
local video_start_clock = hg.GetClock()

-- state context
local photo_state = {
    current_photo = nil,
    photo_table = nil,
    next_tex = nil,
    tex_photo0 = nil,
	index_photo0 = nil,
    noise_intensity = nil,
    coroutine = nil,
	sounds = {}
}

-- photo
photo_state.photo_table = {
	-- "a_pink_unicorn_released_me_from_this_ghost_world_just_for_a_while",
	"empty_ghost_world",
	"in_this_ghost_world_im_going_to_disappear_if_i_cant_run",
	"in_this_ghost_world_i_can_t_cross_the_bridge",
	"in_this_ghost_world_i_can_t_hide",
	"in_this_ghost_world_i_just_try_to_walk",
	"in_this_ghost_world_i_m_falling_apart",
	"in_this_ghost_world_nothing_happens",
	"in_this_ghost_world_they_wont_let_me_in",
	-- "in_this_ghost_world_they_won_t_let_me_in",
	"in_this_ghost_world_the_light_stays_outside",
	"in_this_ghost_world_we_are_still_waiting_for_closed_windows",
	"in_this_ghost_world_you_dont_see_me",
	"i_d_rather_go_away_from_this_ghost_world",
	"i_know_there_s_some_light_on_the_other_side_of_the_ghost_world",
	"marie_while_i_m_falling_into_this_ghost_world",
	"this_ghost_world_like_a_spider_s_web",
	"waiting_for_a_never_ending_rest_in_this_ghost_world",
	"we_all_are_ghosts",
	"what_will_i_become_in_this_ghost_world",
	"the_day_i_failed_to_escape_this_ghost_world",
	"there_s_no_way_to_escape_this_ghost_world"
}

local ghostWorldAssociations = {
	-- "Escape",
	"Void",
	"Peril",
	"Obstacle",
	"Exposure",
	"Endurance",
	"Dissolution",
	"Stagnation",
	-- "Exclusion",
	"Banishment",
	"Darkness",
	"Anticipation",
	"Invisibility",
	"Departure",
	"Hope",
	"Descent",
	"Entanglement",
	"Limbo",
	"Ethereality",
	"Transformation",
	"Failure",
	"Imprisonment"
  }
  

-- audio
-- background noise
local bg_snd_ref = hg.LoadWAVSoundAsset('sfx/static.wav')
local bg_src_ref = hg.PlayStereo(bg_snd_ref, hg.StereoSourceState(1, hg.SR_Loop))

-- photo change fx
for snd_idx = 0, 4 do
	photo_state.sounds[snd_idx + 1] = hg.LoadWAVSoundAsset('sfx/change' .. snd_idx .. '.wav') 
end

photo_state.current_photo = 1
photo_state.next_tex = nil
photo_state.tex_photo0 = LoadPhotoFromTable(photo_state.photo_table, photo_state.current_photo)
photo_state.index_photo0 = photo_state.current_photo

photo_state.noise_intensity = 0.0
chroma_distortion = 0.0

local zoom_level = 1.125
zoom_level = 1.0 / zoom_level

local keyboard = hg.Keyboard('raw')

local switch_clock = hg.GetClock()

local font_rand_idx = 1

while not keyboard:Pressed(hg.K_Escape) do
	keyboard:Update()
	dt = hg.TickClock()

	if photo_state.coroutine == nil and (keyboard:Released(hg.K_Space) or (hg.GetClock() - switch_clock > hg.time_from_sec_f(10.0))) then
		photo_state.coroutine = coroutine.create(PhotoChangeCoroutine)
		switch_clock = hg.GetClock()
	elseif photo_state.coroutine and coroutine.status(photo_state.coroutine) ~= 'dead' then
		coroutine.resume(photo_state.coroutine, photo_state)
	else
		photo_state.coroutine = nil
	end

	chroma_distortion = clamp(map(photo_state.noise_intensity, 0.1, 0.5, 0.0, 1.0), 0.0, 1.0)
	val_uniforms = {hg.MakeUniformSetValue('control', hg.Vec4(photo_state.noise_intensity, chroma_distortion, 0.0, 0.0))}
	-- val_uniforms = {hg.MakeUniformSetValue('control', hg.Vec4(1.0, 1.0, 0.0, 0.0))} -- test only
	_, tex_video, size, fmt = hg.UpdateTexture(streamer, handle, tex_video, size, fmt)

	tex_uniforms = {
		hg.MakeUniformSetTexture('u_video', tex_video, 0),
		hg.MakeUniformSetTexture('u_photo0', photo_state.tex_photo0, 1)
	}

	view_id = 0

	hg.SetViewPerspective(view_id, 0, 0, res_x, res_y, hg.TranslationMat4(hg.Vec3(0, 0, -0.68 * zoom_level)))

	hg.DrawModel(view_id, screen_mdl, screen_prg, val_uniforms, tex_uniforms, hg.TransformationMat4(hg.Vec3(0, 0, 0), hg.Vec3(math.pi / 2, math.pi, 0)))

	-- text OSD
	-- osd_text = "TV" .. photo_state.index_photo0
	osd_text = ghostWorldAssociations[photo_state.index_photo0]
	view_id = view_id + 1

	hg.SetView2D(view_id, 0, 0, res_x, res_y, -1, 1, hg.CF_None, hg.Color.Black, 1, 0)

	local text_pos = hg.Vec3(res_x * 0.05, res_y * 0.05, -0.5)
	local _osd_colors = {hg.Vec4(1.0, 0.0, 0.0, 0.8), hg.Vec4(0.0, 1.0, 0.0, 0.8), hg.Vec4(1.0, 1.0, 1.0, 1.0)}
	local _osd_offsets = {-2.0, 1.0, 0.0}
	-- if math.random(100) > 90 then 
	-- 	font_rand_0 = math.random(math.floor(max_font_index/3) - 1) + 1
	-- end
	-- if math.random(100) > 95 then 
	-- 	font_rand_1 = math.random(math.floor(max_font_index/3))
	-- end
	-- if math.random(100) > 98 then 
	-- 	font_rand_2 = math.random(math.floor(max_font_index/3))
	-- end
	-- local font_rand_idx = font_rand_0 + font_rand_1 + font_rand_2
	if photo_state.noise_intensity > 0.25 and photo_state.index_photo0 == photo_state.current_photo then
		font_rand_idx = font_rand_idx + 1
		if font_rand_idx > max_font_index then
			font_rand_idx = 1
		end
		for _text_loop = 1, 3 do
			local _text_offset = hg.Vec3(res_x * 0.001 * _osd_offsets[_text_loop] * photo_state.noise_intensity, 0.0, 0.0)
			hg.DrawText(view_id, font[font_rand_idx], osd_text, font_program, 'u_tex', 0, 
					hg.Mat4.Identity, text_pos + _text_offset, hg.DTHA_Left, hg.DTVA_Bottom, 
					{hg.MakeUniformSetValue('u_color', _osd_colors[_text_loop])}, 
					{}, text_render_state)
		end
	end

	-- loop noise video
	if hg.GetClock() - video_start_clock > hg.time_from_sec_f(85.0) then
		video_start_clock = hg.GetClock()
		print("Restart VHS tape!")
		streamer:Seek(handle, 0)
		streamer:Play(handle)
	end

	hg.Frame()
	hg.UpdateWindow(win)
end

hg.RenderShutdown()
hg.DestroyWindow(win)
