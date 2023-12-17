// Copyright (c) NWNC HARFANG and contributors. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for details.

#define SAMPLE_WIDTH 20

$input vTexCoord0

#include <bgfx_shader.sh>

uniform vec4 control; // VHS FX -> x : noise_intensity, y : fade (0 = photo0, 1 = photo1)

SAMPLER2D(u_video, 0);
SAMPLER2D(u_photo0, 1);
SAMPLER2D(u_photo1, 2);

void main() {
	vec4 vhs_noise = texture2D(u_video, vTexCoord0);
	vec2 vTexCoord0_mirror = vec2(1.0, 0.0) + vTexCoord0 * vec2(-1.0, 1.0);
	vec4 photo0, photo1;
	float intensity_accumulation = 0.0;
	float i;
	vec2 noise_offset = vec2(0.0, 0.0);

	for(i = 0.0; i < 1.0; i += 1.0/SAMPLE_WIDTH){
		noise_offset = vTexCoord0 + vec2(i * 0.01, 0.0);
		intensity_accumulation += texture2D(u_video, vTexCoord0 + noise_offset);
	}

	intensity_accumulation = intensity_accumulation * (10.0 / SAMPLE_WIDTH);
	intensity_accumulation = min(1.0, intensity_accumulation) * 0.1;
	intensity_accumulation = max(0.0, intensity_accumulation - 0.05);

	// photo0 = vec4(1.0, 0.0, 0.0, 1.0);
	// photo1 = vec4(0.0, 1.0, 0.0, 1.0);

	photo0 = texture2D(u_photo0, vTexCoord0_mirror + vec2(intensity_accumulation * control.x, 0.0));
	photo1 = texture2D(u_photo1, vTexCoord0_mirror + vec2(intensity_accumulation * control.x, 0.0));

	vec4 photo_mix = mix(photo0, photo1, control.y);

	gl_FragColor = photo_mix + vhs_noise * control.x;
}