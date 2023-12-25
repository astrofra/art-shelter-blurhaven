-- Copyright (c) NWNC HARFANG and contributors. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.

function LoadPhotoFromTable(photo_table, photo_idx)
	return hg.LoadTextureFromAssets('photos/' .. photo_table[photo_idx] .. '.png', hg.TF_UClamp)
end

hg = require("harfang")
require("utils")
require("coroutines")

hg.InputInit()
hg.WindowSystemInit()

res_x, res_y = 960, 720
win = hg.RenderInit('Blurhaven', res_x, res_y, hg.RF_VSync)

hg.AddAssetsFolder('assets_compiled')

pipeline = hg.CreateForwardPipeline()
res = hg.PipelineResources()

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

-- photo

local photo_table = {
	"Empty_ghost_world",
	"In_this_ghost_world_Im_going_to_disappear_if_I_cant_run",
	"In_this_ghost_world_they_wont_let_me_in",
	"In_this_ghost_world_we_are_still_waiting_for_closed_windows",
	"In_this_ghost_world_you_dont_see_me",
	"What_will_I_become_in_this_ghost_world"
}

local current_photo = 1
local next_tex = nil
local tex_photo0 = LoadPhotoFromTable(photo_table, current_photo)

local noise_intensity = 0.0
local chroma_distortion = 0.0

local keyboard = hg.Keyboard('raw')

local current_coroutine = nil

while not keyboard:Pressed(hg.K_Escape) do
	keyboard:Update()
	dt = hg.TickClock()

	if current_coroutine == nil and keyboard:Released(hg.K_Space) then
		current_coroutine = coroutine.create(PhotoChangeCoroutine)
	elseif current_coroutine and coroutine.status(current_coroutine) ~= 'dead' then
		local _success, _current_photo, _photo_table, _next_tex, _tex_photo0, _noise_intensity
		_success, _current_photo, _photo_table, _next_tex, _tex_photo0, _noise_intensity = coroutine.resume(current_coroutine, current_photo, photo_table, next_tex, tex_photo0)
		current_photo = _current_photo or current_photo
		photo_table = _photo_table or photo_table
		tex_photo0 = _tex_photo0 or tex_photo0
		noise_intensity = _noise_intensity or noise_intensity
	else
		current_coroutine = nil
	end

	chroma_distortion = clamp(map(noise_intensity, 0.1, 0.5, 0.0, 1.0), 0.0, 1.0)
	val_uniforms = {hg.MakeUniformSetValue('control', hg.Vec4(noise_intensity, chroma_distortion, 0.0, 0.0))}
	-- val_uniforms = {hg.MakeUniformSetValue('control', hg.Vec4(1.0, 1.0, 0.0, 0.0))} -- test only
	_, tex_video, size, fmt = hg.UpdateTexture(streamer, handle, tex_video, size, fmt)

	tex_uniforms = {
		hg.MakeUniformSetTexture('u_video', tex_video, 0),
		hg.MakeUniformSetTexture('u_photo0', tex_photo0, 1)
	}

	view_id = 0

	hg.SetViewPerspective(view_id, 0, 0, res_x, res_y, hg.TranslationMat4(hg.Vec3(0, 0, -0.68)))

	hg.DrawModel(view_id, screen_mdl, screen_prg, val_uniforms, tex_uniforms, hg.TransformationMat4(hg.Vec3(0, 0, 0), hg.Vec3(math.pi / 2, math.pi, 0)))

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