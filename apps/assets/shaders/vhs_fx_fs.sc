// Copyright (c) NWNC HARFANG and contributors. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for details.

$input vTexCoord0

#include <bgfx_shader.sh>

SAMPLER2D(u_video, 0);
SAMPLER2D(u_photo0, 1);
SAMPLER2D(u_photo1, 2);

void main() {
	gl_FragColor = texture2D(u_video, vTexCoord0);
}