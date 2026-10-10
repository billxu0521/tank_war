shader_type spatial;
// 描線（main.gd 的 _use_outline 掛一片蓋滿畫面的方塊）：畫完之後看深度和法線，
// 半透明的東西（槍口火光、煙）看不到深度，所以這片要在它們之前畫（render_priority 最低），它們才蓋得住線
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
uniform float gun_mark = 0.65;       // 第一人稱的槍和手：粗糙度 = 這個（viewmodel.gd 的 OUTLINE_MARK），另外一套描線（見 fragment）。
                                     // 以前用「離鏡頭 1.5 公尺內」認，貼近牆和木桶時它們也被當成槍描粗線
uniform float paint_radius = 0.0;    // 油畫感（Kuwahara 濾鏡）的筆觸半徑，像素（照 1080p 算）；0 = 關。第 82 版起關掉：會把一面一面的邊抹糊（Shader 美術改善規格要的是面感）。以前 7。先抹色塊再描線，線才不會被抹糊
uniform float paint_sharp = 8.0;     // 八塊區域按「顏色多亂」加權：越大越像只挑最平的那塊（色塊邊緣越銳利）
uniform float paint_sharpen = 0.6;   // 抹完再銳化：色塊比周圍平均亮的再亮一點、暗的再暗一點，邊界更清楚（知識庫 Kuwahara 筆記：濾鏡後加銳化更像油畫）
uniform float paint_ground = 0.45;   // 朝上的面（地面、屋頂）和草：筆觸縮成這麼多倍。地面的紋理一抹就變一片糊
uniform float paint_far_start = 30.0;   // 公尺：從這裡開始筆觸變小，到 far_end 剩一半——遠處的恐龍、人才看得清（射擊遊戲要顧可讀性）
uniform float paint_far_end = 120.0;
// 美術風格指南（docs/美術/Low_Poly_西部奇幻FPS_美術風格指南.docx）第 7 節：陰影偏冷（main.tscn 環境光改藍紫）、面色差（這裡）。
// 「明暗分段」試過在這裡對整個畫面的亮度分段：場景亮度大多擠在同一段，結果整片洗平、沒了對比。
// 要做得在每個材質的打光（light()）裡分，等共用的「Master Shader」真的要做再說
uniform float face_var = 0.07;       // 每個面的明暗小偏移（指南 ±5～12%）：同一種材質朝不同方向的面，顏色不會一模一樣
uniform float style_far_start = 60.0;   // 公尺：面色差從這裡開始淡，到 far_end 沒有——遠景交給霧，指南要遠處降低對比
uniform float style_far_end = 200.0;
// 目標（恐龍、別人的牛仔、靶）：粗糙度 = 這個（viewmodel.gd 的 TARGET_MARK）。不抹油畫、不加面色差，
// 邊緣加夕陽色的輪廓光、線較粗較深、遠處也不淡掉——跟背景拉開（美術風格指南第 11 節：目標不能跟夕陽背景融在一起）
uniform float target_mark = 0.87;
// 前景壓暗：離鏡頭近的地方暗一點，跟參考圖一樣「前景暗、中景亮」（指南第 10 節）。目標和槍不壓
// 距離分層（Shader 美術改善規格第 8 節）：越遠飽和度、對比越低，再交給霧。不能只靠霧把東西洗掉，中景要先退一層。
// 對比只動亮度（往 dist_pivot 收），色相不變。目標、槍不動（遠處的恐龍要看得清楚）
uniform float dist_start = 30.0;     // 公尺：近景到這裡都是原樣
uniform float dist_end = 180.0;      // 公尺：到這裡降到最低
uniform float dist_sat = 0.70;       // 最遠的飽和度倍數（規格：中景 80～90%、遠景 60～75%）
uniform float dist_contrast = 0.60;  // 最遠的對比倍數（規格：中景 75～90%、遠景 50～70%）
uniform float dist_pivot = 0.14;     // 對比往這個亮度收（線性亮度）。0.30 太亮：遠山被拉亮成粉灰
uniform vec3 dist_haze : source_color = vec3(0.72, 0.44, 0.29);   // 降飽和不往灰收，往夕陽霧的色相收（main.tscn 的 fog_light_color）：灰會讓紅褐的山變成淡紫
uniform float gun_ridge = 1.0;       // 槍和手零件交界線的濃度。像素風（pixel_style.gd）調低：低解析度下一條線就是一整格，槍會被線塗黑
uniform float env_line = 0.45;       // 一般環境物件的線再淡這麼多倍（規格第 11 節：環境描線降 50～70%）；目標、槍不動
uniform float gun_lift = 0.8;        // 第一人稱的槍暗部提亮（規格第 12 節：要有中間調，不要被夕陽壓成黑色剪影）
uniform float near_dark = 0.75;          // 最近處的亮度倍數
uniform float near_dark_start = 12.0;    // 公尺：這麼近以內最暗（站著平視，畫面最下緣的地面大約在 5～10 公尺外，起點太近等於沒壓到）
uniform float near_dark_end = 35.0;      // 公尺：到這裡回到原本亮度
// 照亮度降飽和：只有暗部灰下來，中間調和亮部（夕陽照到的面、天邊）保持飽和（門檻在這個 l/(1+l) 的值上，受光面大約 0.2～0.4）——參考圖是「亮處濃橘、暗處灰紫」。
// 整體降飽和（Environment 的 adjustment_saturation）會連亮部的橘一起洗掉，暖冷對比跟著變小（第 68～70 版量到）
uniform float shadow_sat = 0.8;    // 最暗處的飽和度倍數（參考圖最暗 15% 幾乎沒有顏色：b 只有 4，中間調 17、亮部 42）
uniform vec3 shadow_tint : source_color = vec3(0.235, 0.224, 0.271);   // 暗部往指南的冷影色 #3C3945 混：只抽掉顏色會變灰泥，要往紫藍灰靠才是「冷」
uniform float tint_keep_warm = 0.0;   // 0 = 照舊；1 = 暖色像素不往冷影色推（夜晚的燈光）
uniform float shadow_tint_amount = 0.22;   // 0.35 時森林整片灰掉、樹冠看不出綠（第 77 版審查）
uniform float light_sat = 1.0;     // 最亮處
uniform float gun_sat = 0.4;
uniform float dither = 0.03;   // 抖色幅度（亮度的比例，±一半）       // 第一人稱槍和手的飽和度：環境光偏藍紫，深色槍身會被染成色盤外的深藍
uniform vec3 rim_color : source_color = vec3(1.0, 0.82, 0.42);   // 指南的高光色 #FFD06A
uniform float rim_strength = 0.9;
uniform vec3 rim_far_color : source_color = vec3(0.776, 0.353, 0.208);   // 遠處目標的輪廓光改成指南的強調色 #C65A35：小小一個也一眼看出是目標
uniform float rim_far_start = 30.0;   // 公尺：從這裡開始轉成強調色、輪廓光變強
uniform float rim_far_end = 60.0;
uniform float target_line_alpha = 0.6;   // 目標輪廓線的濃度（1 = 全黑不透明）
uniform float target_fade_end = 300.0;   // 公尺：目標的輪廓線到這裡才淡完（一般物件 fade_end）
// 逆光（2026-10-10）：面向太陽時遠處更朦朧（沿視線越遠越往夕陽色收），加上從太陽往外放射的光束（被樹、屋頂擋住的地方變成一條條暗縫）
uniform vec3 to_sun = vec3(0.88, 0.208, -0.43);   // 往太陽的方向（世界座標）：main.tscn 的 Sun，跟 far_land.gd 的 TO_SUN 一樣
uniform vec3 sun_haze_color : source_color = vec3(1.0, 0.62, 0.32);
uniform float sun_haze = 0.4;           // 正對太陽、最遠處最多混多少
uniform float sun_haze_power = 10.0;    // 越大越集中在太陽附近
uniform float sun_haze_density = 0.012; // 每公尺：越遠越朦朧（50 公尺約四成、150 公尺八成多）
uniform float sun_haze_bright = 1.6;    // 夕陽色的亮度（線性）：比天空地平線暗一點，遠景不會被洗成白
uniform float shafts = 0.8;             // 光束強度；0 = 關
uniform vec3 shaft_color : source_color = vec3(1.0, 0.7, 0.4);
uniform float heat = 0.0;   // 熱浪（時段：正午，period.gd）：遠處地平線附近的畫面左右扭動 1～2 像素。0 = 關
uniform float shaft_len = 1.0;          // 從這個像素往太陽方向取樣走多遠（畫面上的比例）

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

// 廣義 Kuwahara（Papari／Kyprianidis 的多項式權重版）：周圍一個圓分成八塊扇形，各算平均色和亂度（變異數），
// 亂度小的那塊權重大，加權平均。細碎紋理被抹成一塊塊，物件邊緣兩側各取各的，不會糊在一起——看起來像筆刷塗的。
// 圓形、八塊：沒有方頭麥克筆的方塊痕跡；加權平均不是「挑一塊」：兩塊差不多時不會跳來跳去，轉鏡頭不閃。
// 扇形權重用多項式近似高斯（不用每個點算 exp × 8），參數照 Acerola 的實作。
// ponytail: 不分方向的版本，筆觸不會順著形狀拉長；要那樣得換「各向異性 Kuwahara」，要多輪計算（CompositorEffect）
vec3 kuwahara(vec2 uv, vec2 texel, float r) {
	vec4 m[8];
	vec3 s[8];
	for (int k = 0; k < 8; k++) {
		m[k] = vec4(0.0);
		s[k] = vec3(0.0);
	}
	const float zero_cross = 0.58;
	float zeta = 1.0 / r;
	float eta = (zeta + cos(zero_cross)) / (sin(zero_cross) * sin(zero_cross));
	// ponytail: 最多取 11×11 個點，半徑大於 5 就跳著取（筆觸夠大，跳格看不出來）；要更細就提高 5，代價是平方成長
	int n = min(int(ceil(r)), 5);
	float stride = r / float(n);
	vec3 all_sum = vec3(0.0);
	float all_w = 0.0;
	for (int y = -n; y <= n; y++) {
		for (int x = -n; x <= n; x++) {
			vec2 v = vec2(float(x), float(y)) / float(n) * 0.5;   // 圓周 = 0.5
			if (dot(v, v) > 0.25) {
				continue;
			}
			vec3 c = texture(screen_tex, uv + vec2(float(x), float(y)) * stride * texel).rgb;
			c = c / (1.0 + c);   // 亮度壓一下再比較：太陽照到的亮面（數值很大）不會讓整塊的亂度爆掉
			float w[8];
			float vxx = zeta - eta * v.x * v.x;
			float vyy = zeta - eta * v.y * v.y;
			w[0] = max(0.0, v.y + vxx);  w[2] = max(0.0, -v.x + vyy);
			w[4] = max(0.0, -v.y + vxx); w[6] = max(0.0, v.x + vyy);
			vec2 u = 0.70710678 * vec2(v.x - v.y, v.x + v.y);   // 轉 45 度算另外四塊
			vxx = zeta - eta * u.x * u.x;
			vyy = zeta - eta * u.y * u.y;
			w[1] = max(0.0, u.y + vxx);  w[3] = max(0.0, -u.x + vyy);
			w[5] = max(0.0, -u.y + vxx); w[7] = max(0.0, u.x + vyy);
			float sum = 0.0;
			for (int k = 0; k < 8; k++) {
				w[k] *= w[k];
				sum += w[k];
			}
			float g = exp(-3.125 * dot(v, v));
			all_sum += c * g;
			all_w += g;
			if (sum < 1e-6) {   // 正中間那點：八塊平分
				for (int k = 0; k < 8; k++) {
					m[k] += vec4(c, 1.0) * g * 0.125; s[k] += c * c * g * 0.125;
				}
				continue;
			}
			for (int k = 0; k < 8; k++) {
				float wk = w[k] * g / sum;
				m[k] += vec4(c * wk, wk);
				s[k] += c * c * wk;
			}
		}
	}
	vec3 out_c = vec3(0.0);
	float wsum = 0.0;
	for (int k = 0; k < 8; k++) {
		vec3 mean = m[k].rgb / m[k].a;
		vec3 v = abs(s[k] / m[k].a - mean * mean);
		float w = 1.0 / (1.0 + pow(1000.0 * (v.r + v.g + v.b), paint_sharp * 0.5));
		out_c += mean * w;
		wsum += w;
	}
	// 太陽附近亮度極高，八塊的權重可能全部算成 0：0/0 會變成無效值（NaN），泛光（glow）再把它糊到整個畫面——
	// 面向太陽的畫面整片變黑（第 78 版）。全部是 0 的時候改用整個圓的平均
	vec3 c = wsum > 1e-6 ? out_c / wsum : all_sum / all_w;
	// 銳化：跟整個圓的平均比，拉開差距。用迴圈裡順手算好的平均，不用再多跑一輪。
	// 乘 (1 - c)：越亮推越少——燈籠、窗光已經接近頂，再往上推壓回去會爆成一團白。
	// 推多少有上限：亮窗旁邊的牆比平均暗很多，不設限會被壓出一圈黑框
	c = clamp(c + clamp(paint_sharpen * (c - all_sum / all_w), -0.05, 0.05) * (1.0 - c), 0.0, 0.98);
	return c / (1.0 - c);   // 壓回去
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

// ranch地面光學分類：由深度重建位置＋地形高度辨認地面，不拿材質粗糙度當身分。
uniform sampler2D sample_mask : filter_linear, repeat_disable;
uniform sampler2D ground_height : filter_linear, repeat_disable;
uniform float grid_n = 85.0;
bool study_ground(vec2 uv, mat4 ip, mat4 iv) {
    float depth=texture(depth_tex,uv).r;
    vec4 v=ip*vec4(uv*2.0-1.0,depth,1.0);
    v/=v.w;
    vec3 wp=(iv*v).xyz;
    vec2 guv=(wp.xz+84.0)/168.0;
    float mask=texture(sample_mask,guv).b;
    // 原條件mask<=0.005必為false；提早退出避免區域外四次高度讀取。
    if (mask<=0.005) return false;
    vec2 huv=(guv*(grid_n-1.0)+0.5)/grid_n;
    vec2 cell=clamp(guv*(grid_n-1.0),vec2(0.0),vec2(grid_n-1.001));
    ivec2 ij=ivec2(floor(cell));vec2 f=fract(cell);
    float a=texelFetch(ground_height,ij,0).r;
    float b=texelFetch(ground_height,ij+ivec2(1,0),0).r;
    float c=texelFetch(ground_height,ij+ivec2(0,1),0).r;
    float d=texelFetch(ground_height,ij+ivec2(1,1),0).r;
    float h=f.x+f.y<=1.0 ? a+(b-a)*f.x+(c-a)*f.y : d+(c-d)*(1.0-f.x)+(b-d)*(1.0-f.y);
    return mask>0.005 && abs(wp.y-h)<0.075;
}

bool is_gun(vec2 uv, mat4 ip, mat4 iv) {
	float r=texture(normal_tex,uv).a;
    if (abs(r-gun_mark)>=0.015) return false;
    return !study_ground(uv,ip,iv);
}

// 樹葉（leaves.gdshader 的粗糙度 0.81）：跟遠山一樣只畫天際線，不畫內部每張卡片的邊。
// 遠山的範圍 0.7～0.8 剛好擦邊，所以遠山那邊要先排除葉子
bool leaf(float r) {
	return abs(r - 0.81) < 0.012;
}

bool is_target(vec2 uv, mat4 ip, mat4 iv) {
	float r=texture(normal_tex,uv).a;
    if (abs(r-target_mark)>=0.015) return false;
    return !study_ground(uv,ip,iv);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float d = lin_depth(uv, INV_PROJECTION_MATRIX);
	bool near = is_gun(uv,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX);
	bool target = is_target(uv,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX);
	vec2 px = width * (near || target ? 1.6 : 1.0) * (VIEWPORT_SIZE.y / 1080.0) / VIEWPORT_SIZE;
	px = max(px, 1.0 / VIEWPORT_SIZE);
	vec3 n = nrm(uv);
	float r = texture(normal_tex, uv).a;
	bool ground_sample = false;
	bool ambiguous = abs(r-0.5)<0.02 || leaf(r) || abs(r-0.75)<0.05;
	if (ambiguous) ground_sample = study_ground(uv,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX);
	bool grass = !ground_sample && abs(r - 0.5) < 0.02;   // 草和麥子（roughness 0.5 當記號）：不描線、不加面色差（草的法線是一根根算的，會變雜點）
	// 遠山（roughness 0.75 當記號，far_land.gd）：只畫跟天空交界的天際線，內部岩層不畫。
	// 遠山被霧蓋淡了，線還是原本的深度，看起來像浮在霧上；岩層靠平面著色的明暗就讀得出來
	bool lf = !ground_sample && leaf(r);
	bool cliff = !ground_sample && abs(r - 0.75) < 0.05 && !lf;
	float edge = 0.0;
	float ridge = 0.0;
	vec2 offs[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
	for (int i = 0; i < 4; i++) {
		vec2 u = uv + offs[i];
		float dn = lin_depth(u, INV_PROJECTION_MATRIX);
		// 只畫在近的那一側：線落在物件的邊上，不會畫到後面的背景上變粗
		if (dn - d > d * (near ? 0.015 : depth_edge) && (!(cliff || lf) || dn > 1000.0)) {
			edge = 1.0;
		}
		// 槍和手：外輪廓也畫在背景那一側（槍是深色的，線畫在槍身上等於看不到），貼著槍描一圈深線
		if (is_gun(u,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX) && d - dn > dn * 0.015) {
			edge = 1.0;
		}
		// 目標也是：背景那一側也畫，線變兩倍粗，剪影從背景跳出來
		if (is_target(u,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX) && d - dn > dn * depth_edge) {
			edge = 2.0;
		}
		if (d < 500.0 && !lf && dot(n, nrm(u)) < 1.0 - (near ? 0.45 : normal_edge)) {
			ridge = near ? gun_ridge : 0.5;   // 槍和手的零件交界要清楚（原本近處不畫稜線，槍和手糊成一團）
		}
	}
	if (grass) {
		edge = 0.0; ridge = 0.0;
	}
	bool target_edge = target || edge > 1.5;   // 目標身上，或貼著目標的背景
	edge = min(edge, 1.0);
	float a = max(edge * (1.0 - smoothstep(fade_start, cliff ? 400.0 : (target_edge ? target_fade_end : fade_end), d)),
			ridge * (1.0 - smoothstep(ridge_fade_start, ridge_fade_end, d)));
	vec2 uv_c = uv;
	if (heat > 0.0 && !near && d > 30.0 && d < 500.0) {
		// 熱浪：只扭取色的位置，描線照原本的深度算（線不會跟著抖）。越遠越扭、只在畫面中段（地平線附近）
		float band = 1.0 - smoothstep(0.08, 0.25, abs(uv.y - 0.5));
		uv_c.x += sin(uv.y * 420.0 + TIME * 7.0) * 1.5 / VIEWPORT_SIZE.x * heat * smoothstep(30.0, 120.0, d) * band;
	}
	vec3 under = texture(screen_tex, uv_c).rgb;
	// 第一人稱：純深色、不透明，不跟底下混（深色的槍上，混色的線會跟槍同色）
	// 目標的線也是純深色，但淡 40%（全不透明太搶，像貼紙）
	bool solid_line = near || (target_edge && edge > 0.0);
	vec3 line = solid_line ? line_color * 0.6 : mix(line_color, under * 0.35, 0.5);
	a = near ? a : (solid_line ? a * target_line_alpha : a * 0.65 * env_line);
	// 槍和手不做風格處理：第一人稱要乾淨（指南第 11 節）
	vec3 base = under;
	if (target) {
		// 輪廓光：面越側著對鏡頭（相機座標的法線 z 越小）越亮，像夕陽從背後打亮邊緣
		float rim = pow(1.0 - clamp(n.z, 0.0, 1.0), 3.0);
		float far_k = smoothstep(rim_far_start, rim_far_end, d);
		base += mix(rim_color, rim_far_color, far_k) * rim * rim_strength * (1.0 + 0.3 * far_k);   // 加倍會把 60 公尺的恐龍洗成淡金色
	} else if (!near && d < 500.0) {   // d >= 500 是天空
		float pr = paint_radius * VIEWPORT_SIZE.y / 1080.0;
		pr *= mix(1.0, 0.5, smoothstep(paint_far_start, paint_far_end, d));
		vec3 wn = (INV_VIEW_MATRIX * vec4(n, 0.0)).xyz;   // 法線是相機座標，轉成世界座標才知道是不是朝上
		if (grass || wn.y > 0.8) {
			pr *= paint_ground;
		}
		if (pr >= 1.0) {
			base = kuwahara(uv, 1.0 / VIEWPORT_SIZE, pr);
		}
		float k = 1.0 - smoothstep(style_far_start, style_far_end, d);
		base *= mix(near_dark, 1.0, smoothstep(near_dark_start, near_dark_end, d));
		float far = smoothstep(dist_start, dist_end, d);
		if (far > 0.0) {
			float l0 = max(dot(base, vec3(0.2126, 0.7152, 0.0722)), 1e-4);
			float l1 = dist_pivot + (l0 - dist_pivot) * mix(1.0, dist_contrast, far);
			base *= max(l1, 0.0) / l0;
			vec3 haze = dist_haze / dot(dist_haze, vec3(0.2126, 0.7152, 0.0722)) * max(l1, 0.0);
			base = mix(haze, base, mix(1.0, dist_sat, far));
		}
		if (!grass) {
			// 面色差：照世界座標的法線方向挑亂數。平面著色的面法線一樣 → 整面同一個偏移；法線先粗分，圓滑的面才不會變雜點
			base *= 1.0 + (hash3(floor(wn * 3.0 + 0.5)) * 2.0 - 1.0) * face_var * k;
		}
	}
	// 槍也要：不然環境光的藍紫把深色槍身染成色盤外的深藍（指南金屬色是暖灰 #554D46）；但槍不往冷影色混
	if (d < 500.0) {   // 天空不處理：天頂的暗紫紅會被當成暗部洗成灰紫
		float l = dot(base, vec3(0.2126, 0.7152, 0.0722));
		float dark = 1.0 - smoothstep(0.02, 0.15, l / (1.0 + l));   // 1 = 最暗
		base = mix(vec3(l), base, mix(light_sat, shadow_sat, dark));
		// 往冷影色混：保持原本亮度，只換色相（色調乘上 shadow_tint 的「形狀」，亮度照原來的 l）
		vec3 tint = shadow_tint / dot(shadow_tint, vec3(0.2126, 0.7152, 0.0722)) * l;
		// 夜晚（tint_keep_warm = 1）：燈照到的暖色不往冷影色推，不然油燈的光圈混成粉紫（period.gd 午夜）
		float warm_px = tint_keep_warm * smoothstep(0.0, 0.04, base.r - base.b);
		base = mix(base, tint, near ? 0.0 : shadow_tint_amount * dark * (1.0 - warm_px));
		if (near) {
			// 槍的藍是中間調，上面的暗部處理碰不到，再降一次；只降深色的槍，手和袖子（亮的）不動，不然手變灰
			// 只降「偏藍」的暗部（環境光把烤藍槍身染成深藍）：暖色（炸彈長矛的纏布、紅炸藥包、木頭）不動。
			// 以前不分色相一律降，暖色中暗部被洗成灰白（審查第三輪）
			// 偏藍（含中性灰）的像素照以前的算法降；暖色不動
			float blue = smoothstep(-0.01, 0.02, base.b - base.r);
			base = mix(base, mix(vec3(l), base, mix(gun_sat, 1.0, smoothstep(0.08, 0.25, l / (1.0 + l)))), blue);
			base *= 1.0 + gun_lift * (1.0 - smoothstep(0.03, 0.2, l / (1.0 + l)));
		}
	}
	// 逆光：視線方向（只看方向，跟深度無關）跟太陽方向的夾角
	vec4 vp = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, 0.5, 1.0);
	vec3 vdir = normalize(vp.xyz / vp.w);
	vec3 sun_v = normalize((VIEW_MATRIX * vec4(normalize(to_sun), 0.0)).xyz);
	float facing = max(dot(vdir, sun_v), 0.0);
	if (d < 500.0 && !near) {
		// 面向太陽時遠處更朦朧：遠山一層層變成剪影。目標只吃一半，不要整隻被洗掉
		float amt = (1.0 - exp(-d * sun_haze_density)) * pow(facing, sun_haze_power) * sun_haze * (target ? 0.5 : 1.0);
		base = mix(base, sun_haze_color * sun_haze_bright, amt);
	}
	if (shafts > 0.0 && sun_v.z < 0.0 && facing > 0.0) {
		// 光束：從這個像素往太陽在畫面上的位置走，數沿路有幾點是天空。被樹葉、屋頂擋住的方向就少，畫面上變成放射狀的亮條和暗縫。
		// ponytail: 單輪 16 點、起點加亂數打散色階；要更細的光束得另開一輪低解析度的遮罩（CompositorEffect）
		vec4 sc = PROJECTION_MATRIX * vec4(sun_v * 100.0, 1.0);
		vec2 sun_uv = sc.xy / sc.w * 0.5 + 0.5;
		vec2 stp = (sun_uv - uv) * shaft_len / 16.0;
		vec2 q = uv + stp * fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
		float lit = 0.0;
		float w = 1.0;
		for (int i = 0; i < 16; i++) {
			q += stp;
			if (q.x > 0.0 && q.x < 1.0 && q.y > 0.0 && q.y < 1.0 && lin_depth(q, INV_PROJECTION_MATRIX) >= 500.0) {
				lit += w;
			}
			w *= 0.96;
		}
		base += shaft_color * lit / 12.0 * shafts * pow(facing, 8.0) * (near ? 0.3 : (d >= 500.0 ? 0.35 : 1.0));   // 天空本來就亮，光束主要加在被照到的空氣（物體前面）
	}
	// 抖色：每個像素亮度 ±1.5% 的固定雜訊，把天空漸層、太陽光暈的一圈圈色階打散（引擎的去色帶在這片方塊之前就做完了）
	base *= 1.0 + (fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * dither;
	ALBEDO = mix(base, line, a);
	ALPHA = 1.0;
}
