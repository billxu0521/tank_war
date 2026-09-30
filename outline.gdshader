shader_type spatial;
// 描線（main.gd 的 _use_outline 掛一片蓋滿畫面的方塊）：畫完之後看深度和法線，
// 物件的輪廓（深度跳一大截）和稜線（法線轉很多）畫成深色線。遠處慢慢淡掉，不然整片山崖和林子變成一團線。
// 不用「模型放大一圈反過來畫」的做法：模型都是平面著色，每個面各自往外推會裂開，線斷成一截一截。
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec3 line_color : source_color = vec3(0.16, 0.09, 0.07);   // 深褐，再跟底下的顏色混一半：樹上是深橄欖、山崖上是深紅褐（同色系較暗的邊），不是一律黑線
uniform float width = 1.2;           // 線寬（像素，照 1080p 算，畫面小線就細）
uniform float depth_edge = 0.06;     // 深度差超過自己距離的這麼多比例才算輪廓：比例制，遠近一樣靈敏
uniform float normal_edge = 0.65;    // 法線夾角的 cos 小於 1 - 這個值才算稜線（約 70 度：只留真正的大轉折，門檻邊緣的切面會斷斷續續）
uniform float fade_start = 40.0;     // 公尺：輪廓線從這裡開始淡
uniform float fade_end = 110.0;
uniform float ridge_fade_start = 8.0;   // 稜線（板縫、環箍、切面）淡得快：近看有細節，遠看只剩外輪廓，不然建築像描圖紙
uniform float ridge_fade_end = 20.0;
uniform float near_dist = 1.5;       // 這麼近的是第一人稱的槍和手：另外一套描線（見 fragment）

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);   // 蓋滿整個畫面，不管相機在哪
}

float lin_depth(vec2 uv, mat4 inv_proj) {
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, texture(depth_tex, uv).r, 1.0);
	return -v.z / v.w;
}

vec3 nrm(vec2 uv) {
	return texture(normal_tex, uv).xyz * 2.0 - 1.0;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float d = lin_depth(uv, INV_PROJECTION_MATRIX);
	bool near = d < near_dist;
	vec2 px = width * (near ? 1.6 : 1.0) * (VIEWPORT_SIZE.y / 1080.0) / VIEWPORT_SIZE;
	px = max(px, 1.0 / VIEWPORT_SIZE);
	vec3 n = nrm(uv);
	float r = texture(normal_tex, uv).a;
	if (abs(r - 0.5) < 0.02) {   // 草和麥子（roughness 0.5 當記號）：不描線
		discard;
	}
	// 遠山（roughness 0.75 當記號，far_land.gd）：只畫跟天空交界的天際線，內部岩層不畫。
	// 遠山被霧蓋淡了，線還是原本的深度，看起來像浮在霧上；岩層靠平面著色的明暗就讀得出來
	bool cliff = abs(r - 0.75) < 0.05;
	float edge = 0.0;
	float ridge = 0.0;
	vec2 offs[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
	for (int i = 0; i < 4; i++) {
		vec2 u = uv + offs[i];
		float dn = lin_depth(u, INV_PROJECTION_MATRIX);
		// 只畫在近的那一側：線落在物件的邊上，不會畫到後面的背景上變粗
		if (dn - d > d * (near ? 0.015 : depth_edge) && (!cliff || dn > 1000.0)) {
			edge = 1.0;
		}
		// 槍和手：外輪廓也畫在背景那一側（槍是深色的，線畫在槍身上等於看不到），貼著槍描一圈深線
		if (dn < near_dist && d - dn > dn * 0.015) {
			edge = 1.0;
		}
		if (d < 500.0 && dot(n, nrm(u)) < 1.0 - (near ? 0.45 : normal_edge)) {
			ridge = near ? 1.0 : 0.5;   // 槍和手的零件交界要清楚（原本近處不畫稜線，槍和手糊成一團）
		}
	}
	float a = max(edge * (1.0 - smoothstep(fade_start, cliff ? 400.0 : fade_end, d)),
			ridge * (1.0 - smoothstep(ridge_fade_start, ridge_fade_end, d)));
	// 第一人稱：純深色、不透明，不跟底下混（深色的槍上，混色的線會跟槍同色）
	ALBEDO = near ? line_color * 0.6 : mix(line_color, texture(screen_tex, uv).rgb * 0.35, 0.5);
	ALPHA = near ? a : a * 0.65;
}
