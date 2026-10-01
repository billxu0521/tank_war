shader_type spatial;
// 樹的葉片卡（blender/tree.py、grove.py 的 leafcard 材質）：透明底挖空、不接收影子，加上風吹。
// main.gd 的 _flatten_models 開場時把 leafcard 材質換成這個，貼圖沿用 glb 裡的。
// 風跟草地（grass.gdshader）同一個方向、同一波：整棵樹冠跟著陣風慢慢晃，每片葉子再各自細細抖；
// 越高晃越多（樹根附近不動），樹幹沒有晃，所以幅度要小，不然葉子會跟枝條脫開。
render_mode cull_back, specular_disabled, shadows_disabled, world_vertex_coords;

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap;
uniform float sway = 0.18;      // 整棵樹冠晃動的幅度（公尺，樹頂那邊）
uniform float flutter = 0.05;   // 每片葉子抖動的幅度（公尺）
uniform vec2 wind_dir = vec2(1.0, 0.35);   // 跟 grass.gdshader 一樣

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;   // 樹根（world_vertex_coords 下 VERTEX 已是世界座標）
	vec2 dir = normalize(wind_dir);
	float h = clamp((VERTEX.y - root.y) / 10.0, 0.0, 1.0);
	float gust = sin(dot(root.xz, dir) * 0.12 - TIME * 1.6) * 0.5 + 0.5;          // 跟草地同一波陣風
	float lean = (gust * 0.7 + sin(TIME * 1.1 + root.x * 0.37 + root.z * 0.23) * 0.3) * sway * h * h;
	vec3 p = VERTEX * 1.7;
	vec3 shake = vec3(sin(TIME * 5.3 + p.x + p.y * 0.7), sin(TIME * 4.1 + p.y + p.z * 0.9) * 0.6,
		sin(TIME * 6.1 + p.z + p.x * 0.5)) * flutter * (0.4 + gust) * h;
	VERTEX.xz += dir * lean;
	VERTEX += shake;
}

void fragment() {
	vec4 c = texture(leaf_tex, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;   // 跟原本的葉片材質一樣（描線照常畫）
}
