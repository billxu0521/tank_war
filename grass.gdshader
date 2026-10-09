shader_type spatial;
// 草地（main.gd 的 _grass_field）：一叢一個 instance，顏色是地面顏色（sRGB）。
// 風一波一波掃過、葉尖抖動；鏡頭腳邊的草往外倒；遠處壓進地面（不用透明，顏色本來就跟地面一樣）
render_mode cull_disabled, specular_disabled, world_vertex_coords;

uniform float wind_strength = 0.22;
uniform vec2 wind_dir = vec2(1.0, 0.35);
uniform vec3 dry_tint : source_color = vec3(0.55, 0.58, 0.20); // 乾草尖：偏黃綠（參考圖的草叢），不跟地面一樣橘
uniform float fade_start = 30.0;
uniform float fade_end = 42.0;   // 要比 visibility_range_end(45) 小
uniform float push_radius = 1.2;
uniform float near_thin = 0.4;        // 近處藏掉幾成
uniform float near_thin_dist = 14.0;  // 公尺：這麼近以內藏（往外 3 公尺內慢慢長出來）

varying float tip;
varying float across;   // 0～1：葉子的左到右
varying vec3 ground;


vec3 to_linear(vec3 c) { // instance color 是 sRGB（跟地形的 vertex_color_is_srgb 一致）
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	tip = UV.y;
	across = UV.x;
	vec3 root = MODEL_MATRIX[3].xyz;   // 這一叢的根（world_vertex_coords 下 VERTEX 已是世界座標）
	vec2 dir = normalize(wind_dir);
	float gust = sin(dot(root.xz, dir) * 0.12 - TIME * 1.6) * 0.5 + 0.5;   // 一波一波掃過草原
	float flutter = sin(TIME * 4.3 + root.x * 1.7 + root.z * 2.3) * 0.15;
	vec2 off = dir * (gust + flutter) * wind_strength;
	vec2 away = root.xz - CAMERA_POSITION_WORLD.xz;                         // 腳邊的草被撥開
	off += normalize(away + 1e-4) * (1.0 - smoothstep(0.3, push_radius, length(away))) * 0.45;
	float bend = tip * tip;
	VERTEX.xz += off * bend;
	VERTEX.y -= dot(off, off) * 0.6 * bend;                                  // 彎下去時變矮，不會拉長
	float keep = 1.0 - smoothstep(fade_start, fade_end, distance(root.xz, CAMERA_POSITION_WORLD.xz));
	// 近處（14 公尺內）四成的叢藏起來（照根的位置挑，同一叢一直是同一種，不會閃）：腳邊一整片草尖亮點是近景最大的雜訊
	float near_d = distance(root.xz, CAMERA_POSITION_WORLD.xz);
	if (fract(sin(dot(root.xz, vec2(12.9898, 78.233))) * 43758.5453) < near_thin) {
		keep *= smoothstep(near_thin_dist - 3.0, near_thin_dist, near_d);
	}
	keep *= smoothstep(0.5, 1.5, near_d);   // 貼臉的草壓矮：離鏡頭一公尺內的葉子透視放大，像一根根扁平的蘆葦桿（審查）
	VERTEX.y = mix(root.y, VERTEX.y, keep);                                  // 遠處壓進地面
	NORMAL = vec3(0.0, 1.0, 0.0);                                            // 跟地面同光照
	ground = to_linear(COLOR.rgb);
}

void fragment() {
	// 像素草：葉子下面四分之三同寬，最上面兩階收尖（寬 1 → 1/2 → 1/4），邊緣一階一階。
	// 顏色三段：根部短短一段稍暗、中段主色、尖端偏亮偏黃（像素重點）。從根部一路分段收窄、三段明暗差大的話像竹筍（第五輪審查）
	float w = tip < 0.75 ? 1.0 : (tip < 0.88 ? 0.5 : 0.25);
	if (abs(across - 0.5) * 2.0 > w) {
		discard;
	}
	vec3 dry = to_linear(dry_tint);
	vec3 mid = mix(ground, dry, 0.55) * 0.8;          // 往乾黃橄欖偏：跟褐色地面拉開
	float far = smoothstep(15.0, 20.0, length(VERTEX));   // 遠處的亮尖淡回主色：只留剪影，一格一格的黃點移動時會爬動閃爍
	vec3 col = tip < 0.2 ? mid * 0.9 : (tip < 0.75 ? mid : mix(mix(ground, dry, 0.9) * 1.4, mid, far));
	ALBEDO = col;
	ROUGHNESS = 0.5;   // 記號：描線（outline.gdshader）看到 0.5 就跳過，草葉一根根描線會變成一片雜訊。反光關了，粗糙度不影響外觀
	BACKLIGHT = vec3(tip < 0.75 ? 0.15 : mix(0.6, 0.15, far));   // 逆光的草尖透光：只有尖端那一段亮（像素重點），逆光時整叢才不會一片暗褐
}
