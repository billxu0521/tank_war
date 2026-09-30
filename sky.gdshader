shader_type sky;
// 黃昏的天空：上藍下橘的漸層、太陽和光暈、會慢慢飄的雲（main.gd 的 _use_sky 套上去）。
// 反射／環境光的那一趟（AT_CUBEMAP_PASS）不畫雲和太陽盤：雲每幀在動，那一趟要是也算就每幀重算一次，很貴

uniform vec3 top_color : source_color = vec3(0.71, 0.46, 0.37);   // 上半部的粉紫
uniform vec3 horizon_color : source_color = vec3(1.0, 0.55, 0.16);   // 地平線：全畫面最亮最橘的地方
uniform vec3 ground_color : source_color = vec3(0.55, 0.40, 0.30);
uniform vec3 cloud_lit : source_color = vec3(0.94, 0.59, 0.35);     // 雲的下緣：被夕陽照到
uniform vec3 cloud_shade : source_color = vec3(0.78, 0.49, 0.43);   // 雲的上半：偏粉紫（不要藍）
uniform float cloud_cover = 0.40;     // 0 晴天 .. 1 陰天；參考圖的雲只佔天空一成左右
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
	vec3 col = mix(horizon_color, top_color, smoothstep(0.0, 0.55, max(up, 0.0)));   // 橘色帶從地平線往上漸漸變粉紫，約四成高才轉完
	if (up < 0.0) {
		col = mix(horizon_color, ground_color, pow(-up, 0.35));
	}
	float sa = max(dot(d, LIGHT0_DIRECTION), 0.0);
	col += LIGHT0_COLOR * vec3(1.0, 0.8, 0.5) * pow(sa, 6.0) * 0.35;   // 太陽周圍一大片暖光（壓掉藍色，不然亮起來會被推成白）
	if (!AT_CUBEMAP_PASS) {
		col += LIGHT0_COLOR * smoothstep(0.9993, 0.9997, sa) * 6.0;   // 太陽盤
		if (up > 0.0) {
			// 雲：少數幾條又扁又長的橫條（取樣時高度方向壓很密、水平方向拉很開），硬邊、只有兩個色階。
			// 用方向本身取樣（不是投影到平面），從哪個方向看都是橫條，也沒有接縫
			vec2 uv = vec2(d.x * 1.3 + d.z * 0.9 + TIME * cloud_speed, up * 7.0);   // 高度方向越密雲越細，7 大約是一條條厚一點的橫雲
			float n = fbm(uv * 1.6);
			float band = smoothstep(0.06, 0.14, up) * (1.0 - smoothstep(0.32, 0.48, up));   // 只放在天空中下段
			float c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.015, n) * band;
			float top = step(1.0 - cloud_cover + 0.06, n);   // 雲比較厚的地方（上半）用粉紫，邊上用受光的橘
			col = mix(col, mix(cloud_lit, cloud_shade, top), c);
		}
	}
	COLOR = col;
}
