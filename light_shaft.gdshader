shader_type spatial;
// 穀倉裡從木板縫透進來的夕陽光柱（2026-10-10 環境感，main.gd _barn_light）。
// 加亮、不吃光、不寫深度；寬度方向兩邊柔、頭尾淡進淡出，靠近牆地面也淡（不切出硬邊）
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.72, 0.4);
uniform float strength = 0.12;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

// 只繞著光柱的長軸轉向鏡頭：從哪個角度看都是一樣寬的一道光，不會側看變成一條細線
void vertex() {
	vec3 axis = normalize(MODEL_MATRIX[1].xyz);
	vec3 center = (MODEL_MATRIX * vec4(0.0, VERTEX.y, 0.0, 1.0)).xyz;
	vec3 side = normalize(cross(axis, CAMERA_POSITION_WORLD - center));
	VERTEX = (inverse(MODEL_MATRIX) * vec4(center + side * VERTEX.x, 1.0)).xyz;
}

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float along = smoothstep(0.0, 0.15, UV.y) * (1.0 - smoothstep(0.6, 1.0, UV.y));
	// 光柱跟後面的牆、地面靠得很近的地方淡掉
	float scene = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	float gap = -v.z / v.w + VERTEX.z;
	float soft = clamp(gap / 0.6, 0.0, 1.0);
	ALBEDO = color * strength * across * across * along * soft;
}
