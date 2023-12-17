-- Copyright (c) NWNC HARFANG and contributors. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.

hg = require("harfang")
require("utils")

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
local tex_photo0 = hg.LoadTextureFromAssets('photos/In_this_ghost_world_Im_going_to_disappear_if_I_cant_run.png', hg.TF_UClamp)
local tex_photo1 = hg.LoadTextureFromAssets('photos/In_this_ghost_world_they_wont_let_me_in.png', hg.TF_UClamp)

local fade = 0.0
local noise_intensity = 0.0
local angle = 0
local clock, clock_s
local swapped = 0

while not hg.ReadKeyboard('default'):Key(hg.K_Escape) do
	clock = hg.GetClock()
	dt = hg.TickClock()
	angle = angle + hg.time_to_sec_f(dt)

	clock_s = hg.time_to_sec_f(clock) * 0.1
	local fade = (clock_s * 2.0)%2.0
	fade = clamp(map(fade, 0.995, 1.0, 0.0, 1.0), 0.0, 1.0)

	noise_intensity = make_triangle_wave(clock_s%1.0)

	noise_intensity = clamp(map(noise_intensity, 0.8, 1.0, 0.0, 1.0), 0.0, 1.0)

	noise_intensity = noise_intensity * 10.0

	val_uniforms = {hg.MakeUniformSetValue('control', hg.Vec4(noise_intensity, fade, 0.0, 0.0))}
	_, tex_video, size, fmt = hg.UpdateTexture(streamer, handle, tex_video, size, fmt)

	local uniform_photo0, uniform_photo1
	if swapped then
		uniform_photo0 = tex_photo0
		uniform_photo1 = tex_photo1
	else
		uniform_photo0 = tex_photo1
		uniform_photo1 = tex_photo0
	end
	tex_uniforms = {
		hg.MakeUniformSetTexture('u_video', tex_video, 0),
		hg.MakeUniformSetTexture('u_photo0', uniform_photo0, 1),
		hg.MakeUniformSetTexture('u_photo1', uniform_photo1, 2)
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