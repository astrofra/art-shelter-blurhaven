-- Copyright (c) NWNC HARFANG and contributors. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.

function LoadPhotoFromTable(photo_table, photo_idx)
	return hg.LoadTextureFromAssets('photos/' .. photo_table[photo_idx] .. '.png', hg.TF_UClamp)
end

hg = require("harfang")
require("utils")
require("states")

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

local handle = streamer:Open('assets_compiled/videos/noise-512x512.mp4');

streamer:Play(handle)

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
local tex_photo0 = LoadPhotoFromTable(photo_table, current_photo)

local noise_intensity = 0.0
local start_clock, clock, clock_s

local keyboard = hg.Keyboard('raw')

local state = GET_COMMAND

-- function GetCommand(dt, keyboard, photo_table, noise_intensity)
-- 	if keyboard:Released(hg.K_Space) then
-- 		return NextPhoto, nil
-- 	end

-- 	return GetCommand, nil
-- end

-- function RampNoiseUp(dt, keyboard, photo_table, noise_intensity)
-- end

-- function NextPhoto(dt, keyboard, photo_table, noise_intensity)
-- 	current_photo = current_photo + 1
-- 	if current_photo > #photo_table then
-- 		current_photo = 1
-- 	end
-- 	return GetCommand, LoadPhotoFromTable(photo_table, current_photo)
-- end

state_func = GET_COMMAND

while not keyboard:Pressed(hg.K_Escape) do
	keyboard:Update()
	dt = hg.TickClock()

	if state == NOP then
		--
	elseif state == GET_COMMAND then
		--
		if keyboard:Released(hg.K_Space) then
			state = LOAD_NEXT_PHOTO
		end
		--
	elseif state == LOAD_NEXT_PHOTO then
		--
		current_photo = current_photo + 1
		if current_photo > #photo_table then
			current_photo = 1
		end
		next_tex = LoadPhotoFromTable(photo_table, current_photo)
		start_clock = hg.GetClock()
		state = RAMP_NOISE_UP
		--
	elseif state == RAMP_NOISE_UP then
		--
		clock = hg.GetClock() - start_clock
		clock_s = hg.time_to_sec_f(clock)
		noise_intensity = clock_s + 2.0 * clamp(map(clock_s, 0.8, 1.0, 0.0, 1.0), 0.0, 1.0)

		if clock_s >= 1.0 then
			noise_intensity = 1.0
			state = SET_NEXT_PHOTO
		end
		--
	elseif state == SET_NEXT_PHOTO then
		--
		tex_photo0 = next_tex
		next_tex = nil
		start_clock = hg.GetClock()
		state = RAMP_NOISE_DOWN
		--
	elseif state == RAMP_NOISE_DOWN then
		clock = hg.GetClock() - start_clock
		clock_s = hg.time_to_sec_f(clock)
		noise_intensity = clock_s + 2.0 * clamp(map(clock_s, 0.8, 1.0, 0.0, 1.0), 0.0, 1.0)
		noise_intensity = 1.0 - noise_intensity

		if clock_s >= 1.0 then
			noise_intensity = 0.0
			state = GET_COMMAND
		end
	end

	val_uniforms = {hg.MakeUniformSetValue('control', hg.Vec4(noise_intensity, 0.0, 0.0, 0.0))}
	_, tex_video, size, fmt = hg.UpdateTexture(streamer, handle, tex_video, size, fmt)

	local uniform_photo0

	tex_uniforms = {
		hg.MakeUniformSetTexture('u_video', tex_video, 0),
		hg.MakeUniformSetTexture('u_photo0', tex_photo0, 1)
	}

	view_id = 0

	hg.SetViewPerspective(view_id, 0, 0, res_x, res_y, hg.TranslationMat4(hg.Vec3(0, 0, -0.68)))

	hg.DrawModel(view_id, screen_mdl, screen_prg, val_uniforms, tex_uniforms, hg.TransformationMat4(hg.Vec3(0, 0, 0), hg.Vec3(math.pi / 2, math.pi, 0)))

	if streamer:GetTimeStamp(handle) > hg.time_from_sec_f(85.0) then
		print(streamer:GetTimeStamp(handle) .. " / " .. streamer:GetDuration(handle))
		streamer:Seek(handle, 0)
		streamer:Play(handle)
	end

	hg.Frame()
	hg.UpdateWindow(win)
end

hg.RenderShutdown()
hg.DestroyWindow(win)