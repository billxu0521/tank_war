shader_type spatial;
// 樹的葉片卡（blender/tree.py、grove.py 的 leafcard 材質）：透明底挖空、不接收影子，加上風吹。
// main.gd 的 _flatten_models 開場時把 leafcard 材質換成這個，貼圖沿用 glb 裡的。
// 風跟草地（grass.gdshader）同一個方向、同一波：整棵樹冠跟著陣風慢慢晃，每片葉子再各自細細抖；
// 越高晃越多（樹根附近不動），樹幹沒有晃，所以幅度要小，不然葉子會跟枝條脫開。
render_mode cull_back, specular_disabled, shadows_disabled, world_vertex_coords, diffuse_lambert_wrap;   // 包覆打光：背光那半邊不會沉成一片深灰

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap;
uniform float sway = 0.18;      // 整棵樹冠晃動的幅度（公尺，樹頂那邊）
uniform float flutter = 0.05;   // 每片葉子抖動的幅度（公尺）
uniform vec2 wind_dir = vec2(1.0, 0.35);   // 跟 grass.gdshader 一樣
uniform float leaf_blur = 2.5;   // 顏色模糊幾級（每級解析度減半）：0 = 原本的貼圖
// 樹冠當成一顆球打光：法線改成「從樹冠中心往外」。每張葉片卡朝向不同，用自己的法線會一張亮一張暗變成迷彩；
// 當成一顆球，整個樹冠分成受光面、背光面兩三段大明暗（美術風格評估第 4 點）
uniform float crown_height = 3.5;   // 樹冠中心離樹根幾公尺（照模型原本大小，會跟著樹的縮放）
uniform float crown_round = 0.45;    // 球面法線佔幾成：1 = 完全當球，0 = 卡片原本的法線。0.85 時夕陽從樹後面來，朝鏡頭那半顆整片變暗變灰（第 76 版）

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;   // 樹根（world_vertex_coords 下 VERTEX 已是世界座標）
	vec3 center = root + vec3(0.0, crown_height * length(MODEL_MATRIX[1].xyz), 0.0);
	NORMAL = normalize(mix(NORMAL, normalize(VERTEX - center), crown_round));
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
	// 顏色取貼圖模糊幾級的版本（mipmap 偏移）：葉片內部的迷彩斑點和零星亮點抹成整片，樹冠讀起來是大塊明暗。
	// 輪廓（透明度）照原本清晰度挖：葉緣形狀不變（美術風格評估：樹冠內部太碎）
	ALBEDO = texture(leaf_tex, UV, leaf_blur).rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.81;   // 記號：outline.gdshader 對葉子只畫跟天空交界的外輪廓，不畫每張卡片的邊（卡片邊緣一圈圈細黑線很吵）
}
