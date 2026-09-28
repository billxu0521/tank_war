shader_type sky;
// 黃昏的天空：上藍下橘的漸層、太陽和光暈、會慢慢飄的雲（main.gd 的 _use_sky 套上去）。
// 反射／環境光的那一趟（AT_CUBEMAP_PASS）不畫雲和太陽盤：雲每幀在動，那一趟要是也算就每幀重算一次，很貴

uniform vec3 top_color : source_color = vec3(0.24, 0.38, 0.62);
uniform vec3 horizon_color : source_color = vec3(0.93, 0.72, 0.50);
uniform vec3 ground_color : source_color = vec3(0.50, 0.44, 0.36);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.90, 0.78);      // 被夕陽照到的那面
uniform vec3 cloud_shade : source_color = vec3(0.52, 0.50, 0.60);   // 背光那面偏紫灰
uniform float cloud_cover = 0.48;     // 0 晴天 .. 1 陰天
uniform float cloud_speed = 0.006;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float up = d.y;
	vec3 col = mix(horizon_color, top_color, pow(max(up, 0.0), 0.45));
	if (up < 0.0) {
		col = mix(horizon_color, ground_color, pow(-up, 0.35));
	}
	float sa = max(dot(d, LIGHT0_DIRECTION), 0.0);
	col += LIGHT0_COLOR * pow(sa, 6.0) * 0.35;   // 太陽周圍一大片暖光
	if (!AT_CUBEMAP_PASS) {
		col += LIGHT0_COLOR * smoothstep(0.9993, 0.9997, sa) * 6.0;   // 太陽盤
		if (up > 0.0) {
			// 雲貼在一片很高的平面上：越接近地平線越扁、越擠
			vec2 uv = d.xz / (up + 0.1) * 0.9 + TIME * cloud_speed * vec2(1.0, 0.35);
			float n = fbm(uv * 1.6);
			float c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.22, n);
			// 往太陽方向挪一點再取一次：差值當成雲的厚薄，朝太陽那邊亮、背後暗
			float lit = clamp(0.6 + (n - fbm(uv * 1.6 + LIGHT0_DIRECTION.xz * 0.12)) * 4.0, 0.0, 1.0);
			vec3 cc = mix(cloud_shade, cloud_lit, lit) + LIGHT0_COLOR * pow(sa, 3.0) * 0.4;
			col = mix(col, cc, c * smoothstep(0.0, 0.12, up) * 0.95);
		}
	}
	COLOR = col;
}
