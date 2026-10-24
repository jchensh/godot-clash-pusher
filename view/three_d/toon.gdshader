// 卡通色阶光：顶点色作底色（× tint，阵营部件用），直射光量化为 3 阶（亮 / 中 / 暗），环境光照常叠加。
shader_type spatial;
render_mode specular_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float band_hi = 0.45;     // N·L 高于此 = 亮面
uniform float band_lo = 0.05;     // N·L 高于此 = 中间调，否则暗面
uniform float mid = 0.6;
uniform float dark = 0.32;

void fragment() {
	ALBEDO = COLOR.rgb * tint.rgb;
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * ATTENUATION;
	float band = ndl > band_hi ? 1.0 : (ndl > band_lo ? mid : dark);
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
