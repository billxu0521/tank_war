shader_type spatial;
// 草地（main.gd 的 _grass_field）：一叢一個 instance，顏色是地面顏色（sRGB）。
// 風一波一波掃過、葉尖抖動；鏡頭腳邊的草往外倒；遠處壓進地面（不用透明，顏色本來就跟地面一樣）
render_mode cull_disabled, specular_disabled, world_vertex_coords;

uniform float wind_strength = 0.22;
uniform vec2 wind_dir = vec2(1.0, 0.35);
uniform vec3 dry_tint : source_color = vec3(0.85, 0.75, 0.45); // 黃昏的乾草尖
uniform float fade_start = 30.0;
uniform float fade_end = 42.0;   // 要比 visibility_range_end(45) 小
uniform float push_radius = 1.2;

varying float tip;
varying vec3 ground;

vec3 to_linear(vec3 c) { // instance color 是 sRGB（跟地形的 vertex_color_is_srgb 一致）
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	tip = UV.y;
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
	VERTEX.y = mix(root.y, VERTEX.y, keep);                                  // 遠處壓進地面
	NORMAL = vec3(0.0, 1.0, 0.0);                                            // 跟地面同光照
	ground = to_linear(COLOR.rgb);
}

void fragment() {
	vec3 base = ground * 0.55;
	vec3 top = mix(ground, to_linear(dry_tint), 0.12) * 1.05;
	ALBEDO = mix(base, top, tip);
	ROUGHNESS = 0.5;   // 記號：描線（outline.gdshader）看到 0.5 就跳過，草葉一根根描線會變成一片雜訊。反光關了，粗糙度不影響外觀
	BACKLIGHT = vec3(0.3) * tip;   // 逆光的草尖透光
}
