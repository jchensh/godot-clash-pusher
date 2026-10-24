// 草地：按世界坐标 1 米(=1 格) 棋盘格双色 + 与 toon.gdshader 同口径的色阶光。
shader_type spatial;
render_mode specular_disabled;

uniform vec4 color_a : source_color = vec4(0.55, 0.78, 0.38, 1.0);
uniform vec4 color_b : source_color = vec4(0.5, 0.73, 0.34, 1.0);
uniform float band_hi = 0.45;
uniform float band_lo = 0.05;
uniform float mid = 0.6;
uniform float dark = 0.32;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float checker = mod(floor(world_pos.x) + floor(world_pos.z), 2.0);
	ALBEDO = mix(color_a.rgb, color_b.rgb, checker);
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * ATTENUATION;
	float band = ndl > band_hi ? 1.0 : (ndl > band_lo ? mid : dark);
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
