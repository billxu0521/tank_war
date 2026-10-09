shader_type spatial;
// 地被（main.gd 的 _groundcover_field：荒地乾穗草、鼠尾草叢、匍匐藤；GPT 建議，docs/image/ground/）。
// 顏色在網格的頂點色；頂點色透明度 1 的是「穗頭」，改用每叢自己的顏色（INSTANCE_CUSTOM，一叢一色）。
// 風跟草地（grass.gdshader）同一波；遠處壓進地面、貼臉的縮掉
render_mode cull_disabled, specular_disabled, world_vertex_coords;
uniform vec2 wind_dir = vec2(1.0, 0.35);
uniform float wind_strength = 0.12;
uniform float fade_start = 22.0;
uniform float fade_end = 29.0;
varying vec3 col;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float h = max(VERTEX.y - root.y, 0.0);
	vec2 dir = normalize(wind_dir);
	float gust = sin(dot(root.xz, dir) * 0.12 - TIME * 1.6) * 0.5 + 0.5;
	VERTEX.xz += dir * gust * wind_strength * h * h * 4.0;
	float d = distance(root.xz, CAMERA_POSITION_WORLD.xz);
	float keep = (1.0 - smoothstep(fade_start, fade_end, d)) * smoothstep(0.4, 1.2, d);
	VERTEX = mix(root, VERTEX, keep);
	NORMAL = vec3(0.0, 1.0, 0.0);   // 跟地面同光照
	// 穗頭遠處漸漸變回草色：遠處一點一點的彩色會變成彩色雜訊、移動時閃（審查）
	col = COLOR.a > 0.5 ? mix(INSTANCE_CUSTOM.rgb, vec3(0.2, 0.17, 0.07), smoothstep(16.0, 26.0, d)) : COLOR.rgb;
}

void fragment() {
	ALBEDO = col;
	ROUGHNESS = 0.5;   // 描線跳過的記號（見 outline.gdshader）：一片片小葉子描線會變成一片雜訊
}
