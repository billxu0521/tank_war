shader_type sky;
// 黃昏的天空：上藍下橘的漸層、太陽和光暈、會慢慢飄的雲（main.gd 的 _use_sky 套上去）。
// 反射／環境光的那一趟（AT_CUBEMAP_PASS）不畫雲和太陽盤：雲每幀在動，那一趟要是也算就每幀重算一次，很貴

uniform vec3 mid_color : source_color = vec3(0.71, 0.46, 0.37);   // 中段的粉紫
uniform vec3 top_color : source_color = vec3(0.35, 0.19, 0.25);   // 天頂的暗紫紅 #5A3040：上暗下亮，視線被拉向地平線（美術風格評估 2026-10-02 第 1 點）
uniform vec3 horizon_color : source_color = vec3(1.0, 0.55, 0.16);   // 地平線：全畫面最亮最橘的地方
uniform vec3 ground_color : source_color = vec3(0.55, 0.40, 0.30);
uniform vec3 cloud_lit : source_color = vec3(0.95, 0.64, 0.29);     // 雲朝太陽的亮邊 #F2A34A
uniform vec3 cloud_shade : source_color = vec3(0.416, 0.22, 0.282);  // 雲的主體（厚的中心）：暗紫紅 #6A3848（參考圖滿天背光的雲）
uniform vec3 cloud_edge : source_color = vec3(0.6, 0.35, 0.35);      // 背光雲的邊緣 #9A5A5A：單一個紫色會變成一條貼上去的色帶
uniform float cloud_cover = 0.52;     // 0 晴天 .. 1 陰天；天空上半部大約三到四成有雲（美術風格評估第 77 版第 5 點）
uniform float cloud_speed = 0.006;
uniform float halo = 1.0;   // 太陽周圍兩層暖光的強度（像素風開著時調弱：pixel_style.gd 的 SKY）
uniform float stars = 0.0;        // 星星（時段：午夜，period.gd）。0 = 沒有
uniform float disk_size = 0.998;  // 太陽／月亮盤的大小（越接近 1 越小）
uniform float disk_bright = 6.0;  // 盤的亮度：月亮調暗，不然泛光把它暈成一團
uniform float rays = 0.0;   // 耶穌光：從太陽往上放射的光束（參考圖 survival_style.png）。0 = 關；像素風開著時打開

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
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.35, max(up, 0.0)));   // 橘色帶從地平線往上漸漸變粉紫
	// 再往上暗成紫紅。從 0.15（約 9 度）就開始：平視時畫面上緣只到 17 度左右，從更高才開始暗的話玩家根本看不到。
	// 環境光那一趟（AT_CUBEMAP_PASS）不加：天空也是環境光的來源，天頂一暗整個場景跟著變暗變紫（第 69 版）
	if (!AT_CUBEMAP_PASS) {
		col = mix(col, top_color, smoothstep(0.15, 0.6, max(up, 0.0)));
	}
	if (up < 0.0) {
		col = mix(horizon_color, ground_color, pow(-up, 0.35));
	}
	float sa = max(dot(d, LIGHT0_DIRECTION), 0.0);
	col += LIGHT0_COLOR * vec3(1.0, 0.8, 0.5) * pow(sa, 6.0) * 0.35 * halo;   // 太陽周圍一大片暖光（壓掉藍色，不然亮起來會被推成白）
	if (!AT_CUBEMAP_PASS) {
		col += LIGHT0_COLOR * smoothstep(disk_size, disk_size + 0.0017 * (1.0 - disk_size) / 0.002, sa) * disk_bright;   // 太陽盤：邊緣柔一點，泛光（glow）再把它暈開
		col += LIGHT0_COLOR * vec3(1.0, 0.75, 0.45) * pow(sa, 80.0) * 0.8 * halo;   // 太陽周圍 10 度內的光暈
		if (rays > 0.0 && up > -0.02) {
			// 耶穌光：繞著太陽的角度切成一條條光束（雜訊決定寬窄，軟邊：硬邊太像貼上去的，使用者 2026-10-06），離太陽 4 度起、60 度內漸漸淡掉，
			// 只往上半邊放射（地平線以下被地面擋住）。畫在雲之前：雲會蓋住光束，光從雲縫透出來（使用者：要在雲後面）
			vec3 sd = LIGHT0_DIRECTION;
			vec3 t1 = normalize(cross(sd, vec3(0.0, 1.0, 0.0)));
			vec3 t2 = cross(t1, sd);
			float ang = atan(dot(d, t2), dot(d, t1));
			float dist = acos(clamp(dot(d, sd), -1.0, 1.0));
			float beam = noise(vec2(ang * 19.0, 1.3)) * 0.6 + noise(vec2(ang * 47.0, 4.1)) * 0.4;
			beam = smoothstep(0.4, 0.75, beam);   // 細、多條、寬窄不一，邊緣漸層
			float fade = smoothstep(0.03, 0.1, dist) * (1.0 - smoothstep(0.15, 1.1, dist)) * smoothstep(-0.6, 0.2, sin(ang));   // 靠近太陽最明顯、往外很快淡掉；往上和兩側扇開，往下的被地面擋住
			// 跟著底下天空的亮度走：亮的地方（地平線附近）明顯，暗的天頂幾乎看不到（暗底上一點亮差就被調色盤跳一階，很硬）
			float bright = dot(col, vec3(0.3, 0.59, 0.11));
			col += LIGHT0_COLOR * vec3(1.0, 0.5, 0.2) * beam * fade * rays * smoothstep(0.0, 0.3, bright);
		}
		if (stars > 0.0 && up > 0.05) {
			// 星星：方向切成細格子，每格亂數挑少數幾格亮，亮度也亂；畫在雲之前，雲會蓋住
			vec3 cell = floor(d * 260.0);
			float h = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
			float s = step(0.9975, h) * (0.4 + 0.6 * fract(h * 371.0));
			col += vec3(0.85, 0.9, 1.0) * s * stars * smoothstep(0.05, 0.25, up);
		}
		if (up > 0.0) {
			// 雲：少數幾條又扁又長的橫條（取樣時高度方向壓很密、水平方向拉很開），硬邊、只有兩個色階。
			// 用方向本身取樣（不是投影到平面），從哪個方向看都是橫條，也沒有接縫
			vec2 uv = vec2(d.x * 1.3 + d.z * 0.9 + TIME * cloud_speed, up * 7.0);   // 高度方向越密雲越細，7 大約是一條條厚一點的橫雲
			float n = fbm(uv * 1.6);
			// 雲量照方位慢慢變（一個畫面寬大約兩三個起伏）：同一個高度不會整圈都有雲，長帶被切成一片一片
			float az = atan(d.z, d.x);
			float cover = cloud_cover + (noise(vec2(az * 2.5, 3.7)) - 0.5) * 0.3;
			// 仰角 6 度以下沒有雲、20 度以上全有（sin 6° ≈ 0.1、sin 20° ≈ 0.34）：貼著地平線斜看，雲層被壓扁成一條等寬的長帶（第 78、80 版審查）
			float band = smoothstep(0.1, 0.34, up) * (1.0 - smoothstep(0.6, 0.85, up));
			float c = smoothstep(1.0 - cover, 1.0 - cover + 0.03, n) * band;
			float thick = smoothstep(1.0 - cover, 1.0 - cover + 0.12, n);   // 0 = 雲邊，1 = 雲的中心
			vec3 shade = mix(cloud_edge, cloud_shade, thick);
			// 朝太陽那一側整朵亮橘，其他方向只有薄的雲邊沾一點橘
			float lit = clamp(pow(sa, 6.0) + (1.0 - thick) * pow(sa, 1.5) * 0.6, 0.0, 1.0);
			c *= mix(1.0, 0.7, thick * (1.0 - lit));   // 背光的雲心透一點底下的天空，不是一塊實心的紫
			col = mix(col, mix(shade, cloud_lit, lit), c);
		}
	}
	COLOR = col;
}
