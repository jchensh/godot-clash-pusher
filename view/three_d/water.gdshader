// 河水：沿河向（世界 X）流动的浅色波纹条 + 两岸白色泡沫边；纯表现，随 TIME 动。
shader_type spatial;
render_mode specular_disabled, unshaded;

uniform vec4 deep : source_color = vec4(0.33, 0.68, 0.84, 1.0);
uniform vec4 light_tone : source_color = vec4(0.55, 0.85, 0.95, 1.0);
uniform vec4 foam : source_color = vec4(0.93, 0.98, 1.0, 1.0);
uniform float flow_speed = 0.35;

void fragment() {
	// UV.x 沿河长（世界 X），UV.y 跨河宽：中间深、两岸泡沫。
	float wave = sin((UV.x * 18.0 - TIME * flow_speed * 6.0) + sin(UV.y * 9.0 + TIME) * 1.5);
	float stripe = smoothstep(0.75, 0.95, wave);
	float edge = min(UV.y, 1.0 - UV.y);
	float foam_k = 1.0 - smoothstep(0.04, 0.12, edge + 0.02 * sin(UV.x * 40.0 + TIME * 2.0));
	vec3 col = mix(deep.rgb, light_tone.rgb, stripe * 0.6);
	ALBEDO = mix(col, foam.rgb, foam_k);
}
