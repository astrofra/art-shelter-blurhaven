// HARFANG(R) Copyright (C) 2022 Emmanuel Julien, NWNC HARFANG. Released under GPL/LGPL/Commercial Licence, see licence.txt for details.
#include <bgfx_shader.sh>

//
float LightAttenuation(vec3 L, vec3 D, float dist, float attn, float inner_rim, float outer_rim) {
	float k = 1.0;
	if (attn > 0.0)
		k = max(1.0 - dist * attn, 0.0); // distance attenuation

	if (outer_rim > 0.0) {
		float c = dot(L, D);
		k *= clamp(1.0 - (c - inner_rim) / (outer_rim - inner_rim), 0.0, 1.0); // spot attenuation
	}
	return k;
}

float SampleHardShadow(sampler2DShadow map, vec4 coord, float bias) {
	vec3 uv = coord.xyz / coord.w;
	return shadow2D(map, vec3(uv.xy, uv.z - bias));
}

float SampleShadowPCF(sampler2DShadow map, vec4 coord, float inv_pixel_size, float bias, vec4 jitter) {
	float k_pixel_size = inv_pixel_size * coord.w;

	float k = 0.0;

#if FORWARD_PIPELINE_AAA
	#define PCF_SAMPLE_COUNT 2 // 3x3

//	ARRAY_BEGIN(float, weights, 9) 0.024879, 0.107973, 0.024879, 0.107973, 0.468592, 0.107973, 0.024879, 0.107973, 0.024879 ARRAY_END();
	ARRAY_BEGIN(float, weights, 9) 0.011147, 0.083286, 0.011147, 0.083286, 0.622269, 0.083286, 0.011147, 0.083286, 0.011147 ARRAY_END();

	for (int j = 0; j <= PCF_SAMPLE_COUNT; ++j) {
		float v = 6.0 * (float(j) + jitter.y) / float(PCF_SAMPLE_COUNT) - 1.0;
		for (int i = 0; i <= PCF_SAMPLE_COUNT; ++i) {
			float u = 6.0 * (float(i) + jitter.x) / float(PCF_SAMPLE_COUNT) - 1.0;
			k += SampleHardShadow(map, coord + vec4(vec2(u, v) * k_pixel_size, 0.0, 0.0), bias) * weights[j * 3 + i];
		}
	}
#else // FORWARD_PIPELINE_AAA
	// 2x2
	k += SampleHardShadow(map, coord + vec4(vec2(-0.5, -0.5) * k_pixel_size, 0.0, 0.0), bias);
	k += SampleHardShadow(map, coord + vec4(vec2( 0.5, -0.5) * k_pixel_size, 0.0, 0.0), bias);
	k += SampleHardShadow(map, coord + vec4(vec2(-0.5,  0.5) * k_pixel_size, 0.0, 0.0), bias);
	k += SampleHardShadow(map, coord + vec4(vec2( 0.5,  0.5) * k_pixel_size, 0.0, 0.0), bias);

	k /= 4.0;
#endif // FORWARD_PIPELINE_AAA

	return k;
}

// Forward PBR GGX
float DistributionGGX(float NdotH, float roughness) {
	float a = roughness * roughness;
	float a2 = a * a;

	float divisor = NdotH * NdotH * (a2 - 1.0) + 1.0;
	return a2 / max(PI * divisor * divisor, 1e-8); 
}

float GeometrySchlickGGX(float NdotW, float k) {
	float div = NdotW * (1.0 - k) + k;
	return NdotW / ((abs(div) > 1e-8) ? div : 1e-8);
}

float GeometrySmith(float NdotV, float NdotL, float roughness) {
	float r = roughness + 1.0;
	float k = (r * r) / 8.0;
	float ggx2 = GeometrySchlickGGX(NdotV, k);
	float ggx1 = GeometrySchlickGGX(NdotL, k);
	return ggx1 * ggx2;
}

vec3 FresnelSchlick(float cosTheta, vec3 F0) {
	return F0 + (1.0 - F0) * pow(max(1.0 - cosTheta, 0.0), 5.0);
}

vec3 FresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness) {
	return F0 + (max(vec3_splat(1.0 - roughness), F0) - F0) * pow(max(1.0 - cosTheta, 0.0), 5.0);
}

vec3 GGX(vec3 V, vec3 N, float NdotV, vec3 L, vec3 albedo, float roughness, float metalness, vec3 F0, vec3 diffuse_color, vec3 specular_color) {
	vec3 H = normalize(V - L);

	float NdotH = max(dot(N, H), 0.0);
	float NdotL = max(-dot(N, L), 0.0);
	float HdotV = max(dot(H, V), 0.0);

	float D = DistributionGGX(NdotH, roughness);
	float G = GeometrySmith(NdotV, NdotL, roughness);
	vec3 F = FresnelSchlick(HdotV, F0);

	vec3 specularBRDF = (F * D * G) / max(4.0 * NdotV * NdotL, 0.001);

	vec3 kD = (vec3_splat(1.0) - F) * (1.0 - metalness); // metallic materials have no diffuse (NOTE: mimics mental ray and 3DX Max ART renderers behavior)
	vec3 diffuseBRDF = kD * albedo;

	return (diffuse_color * diffuseBRDF + specular_color * specularBRDF) * NdotL;
}

//
vec3 DistanceFog(vec3 pos, vec3 color) {
	if (uFogState.y == 0.0)
		return color;

	float k = clamp((pos.z - uFogState.x) * uFogState.y, 0.0, 1.0);
	return mix(color, uFogColor.xyz, k);
}