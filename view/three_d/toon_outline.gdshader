// 卡通描边（反向外壳）：沿法线在裁剪空间外扩恒定像素宽度，背面渲染成深色；作为 toon 材质的 next_pass。
shader_type spatial;
render_mode unshaded, cull_front;

uniform float width_px = 2.0;
uniform vec4 color : source_color = vec4(0.13, 0.09, 0.08, 1.0);

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 dir = (PROJECTION_MATRIX * vec4(n, 0.0)).xy;
	float len = length(dir);
	if (len > 0.0001) {
		clip.xy += dir / len * width_px * 2.0 / VIEWPORT_SIZE * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = color.rgb;
}
