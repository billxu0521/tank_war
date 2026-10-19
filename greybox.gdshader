shader_type spatial;
// 灰盒（素模）材質：灰底＋世界座標的 1 公尺格線，看得出距離和高度。牆、地板、地面共用（greybox.gd）
// 朝上的面（地板、屋頂、地面）用 floor_color，其他面用 base

uniform vec3 base : source_color = vec3(0.72);
uniform vec3 floor_color : source_color = vec3(0.5);
uniform float line = 0.22;   // 格線壓暗多少

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// 1 像素寬的格線（fwidth 讓遠處不閃）；每 5 公尺一條粗一點
float grid(vec2 p) {
	vec2 g = abs(fract(p - 0.5) - 0.5) / fwidth(p);
	vec2 g5 = abs(fract(p / 5.0 - 0.5) - 0.5) / fwidth(p / 5.0) * 0.5;
	return 1.0 - min(min(min(g.x, g.y), min(g5.x, g5.y)), 1.0);
}

void fragment() {
	vec3 n = abs(wn);
	vec2 uv = n.y > max(n.x, n.z) ? wp.xz : (n.x > n.z ? wp.zy : wp.xy);
	vec3 c = wn.y > 0.7 ? floor_color : base;
	ALBEDO = c * (1.0 - line * grid(uv));
	ROUGHNESS = 0.95;
	SPECULAR = 0.0;
}
