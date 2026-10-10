shader_type spatial;
// 地面（terrain.gd build() 用）：頂點顏色 × 灰階紋理。以前是 StandardMaterial3D，為了多一張「荒地小路」紋理換成自己寫：
// 頂點顏色的透明度 = 路的濃度（main.gd ground_color 填 Trails.weight），濃的地方近看紋理換成 path_dirt（踩實的乾土、龜裂、碎石），
// 草地的紋理（碎石、草梗）淡出去。三張紋理都用世界座標從正上方投影，不用另外算 UV（坡最陡 40 度，拉長看不出來）。
// 粗糙度 0.95：outline.gdshader 拿粗糙度當記號，地面不能撞到草（0.5）、遠山（0.75）、槍（0.65）、目標（0.87）

// 2026-10-09 起近看的兩張換成像素材質（tools/make_pixel_tex.py 的 grass、dirt）：16×16 一張鋪 1 公尺、最近點取樣
uniform sampler2D detail_tex : source_color, filter_nearest_mipmap, repeat_enable;   // 草地近看，一張 1 公尺
uniform sampler2D macro_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;    // 遠看的大塊深淺，一張 48 公尺
uniform sampler2D path_tex : source_color, filter_nearest_mipmap, repeat_enable;     // 荒地小路，一張 1 公尺
uniform float brightness = 1.2;   // 紋理平均比白暗，調亮補回來（跟沒貼圖時整體亮度差不多）
uniform float near_detail = 1.0;   // 像素材質：近處就是要看得到格子，不淡掉
uniform float detail_mean = 0.83;  // 近看紋理（grass.png）的平均亮度：淡掉時往這裡收；也拿來補亮度（brightness 是照以前平均 0.9 的紋理調的）
// 地面的塵土光：20～80 公尺的地面往暖沙色混，像一層被夕陽照亮的塵土（代替貼地的沙塵霧：Godot 的高度霧照海拔算，谷地的鏡頭會整片被吃掉）
uniform vec3 dust_color : source_color = vec3(0.784, 0.541, 0.353);   // #C88A5A
uniform float dust_amount = 0.32;   // 森林裡樹幹後面要有亮的地面當背景，不然整片暗（第 80 版審查）
uniform float bottom_dark = 0.88;   // 畫面最下面四分之一的地面再暗一點：城鎮的路面是一大片亮色，前景壓不下來。只動地面，牆和人不受影響  // 近處細紋理的強度（美術風格評估：第一人稱腳邊像撒胡椒）

// 四種地面材質（tools/make_pixel_tex.py 的 gravel、clay、mud、outcrop；GPT 建議，docs/image/ground/）：
// 權重在頂點的 CUSTOM0（main.gd ground_mix 算：坡、高度、植被、區域、雜訊），每種一張灰階像素圖 × 自己的顏色
uniform sampler2D gravel_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D clay_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D mud_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D outcrop_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 gravel_color : source_color = vec3(0.69, 0.54, 0.41);   // #b08a68：跟土同色相、亮一點偏黃（偏灰的話夕陽下整片地面變冷，審查）
uniform vec3 clay_color : source_color = vec3(0.80, 0.52, 0.30);
uniform vec3 mud_color : source_color = vec3(0.42, 0.29, 0.19);   // 濕泥往土色靠：太暗像燒焦、一灘油
uniform vec3 outcrop_color : source_color = vec3(0.65, 0.55, 0.45);   // #a58c74：偏灰的暖褐（偏紫的話整片地面變冷，審查）
// 試作用途遮罩：R 小鎮、G 通行磨耗、B 麥田、A 麥田通道。
// 非色彩資料，保持線性。只供隔離 runner 使用。
uniform sampler2D study_mask : filter_linear, repeat_disable;
uniform sampler2D detail_mask : filter_linear, repeat_disable;
// 端值試驗三個可分開調和的軸：0=v2外觀、1=極端。
uniform float semantic_strength : hint_range(0.0, 1.0) = 1.0;
uniform float detail_strength : hint_range(0.0, 1.0) = 1.0;
uniform float boundary_strength : hint_range(0.0, 1.0) = 1.0;
uniform float study_size = 168.0;
uniform float row_origin = -81.0;
// 全圖：R農莊院落、G林下覆蓋、B既有通行、A岩石接地；皆為線性資料。
uniform sampler2D landscape_mask : filter_linear, repeat_disable;
uniform sampler2D condition_mask : filter_linear, repeat_disable;
uniform float landscape_strength : hint_range(0.0, 1.0) = 0.3;
varying vec4 mixw;

varying vec3 world;

// 像素貼圖一張 1 公尺，整片地每公尺重複一次看得出規律（第二輪審查）：每一格照位置亂數轉 0／90／180／270 度、要不要翻面。
// 用 textureGrad 拿連續座標的變化量，格子交界才不會因為座標跳動選錯 mipmap 出現細線
vec4 tile_rand(sampler2D tex, vec2 p) {
	vec2 cell = floor(p);
	vec2 f = p - cell;
	float h = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	int r = int(h * 8.0);
	if ((r & 1) == 1) f.x = 1.0 - f.x;
	if ((r & 2) == 2) f = vec2(f.y, f.x);
	if ((r & 4) == 4) f.y = 1.0 - f.y;
	return textureGrad(tex, f, dFdx(p), dFdy(p));
}

vec3 to_linear(vec3 c) {   // 頂點顏色是 sRGB（以前 StandardMaterial 的 vertex_color_is_srgb）
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	mixw = CUSTOM0;
}

void fragment() {
	float raw = tile_rand(detail_tex, world.xz).r;
	float grass = raw;
	// 近處（10 公尺內）細紋理只留三成：腳邊的碎石黑點像撒胡椒；25 公尺外回到原本（遠處需要它打破整片同色）。
	// 往 0.9 收（紋理的平均亮度），整體亮度不變
	float near_k = mix(near_detail, 1.0, smoothstep(10.0, 25.0, length(VERTEX)));
	grass = mix(detail_mean, grass, near_k) * 0.9 / detail_mean;
	float path = tile_rand(path_tex, world.xz + 0.5).r;
	// 路邊：頂點每 2 公尺一個，濃度在中間是平滑漸層；拿近看紋理的明暗再咬一口，邊緣變成碎碎的（碎石、土塊散到草地上）
	float mask = smoothstep(0.35, 0.65, COLOR.a + (raw - detail_mean) * 1.2);
	ALBEDO = to_linear(COLOR.rgb) * mix(grass, path, mask) * texture(macro_tex, world.xz / 48.0).r * brightness;
	// 疊上四種地面：權重在頂點之間平滑過渡，再拿紋理的明暗咬一口，邊緣一格一格碎掉（不是一條平滑的線）
	vec4 w = clamp(mixw + (raw - detail_mean) * 1.2, 0.0, 1.0);   // 咬得深一點：邊界碎成一格一格，不是一條圓弧
	w = smoothstep(vec4(0.3), vec4(0.7), w);
	ALBEDO = mix(ALBEDO, gravel_color * tile_rand(gravel_tex, world.xz).rgb, w.r);
	ALBEDO = mix(ALBEDO, clay_color * tile_rand(clay_tex, world.xz * 0.5).rgb, w.g);
	ALBEDO = mix(ALBEDO, mud_color * tile_rand(mud_tex, world.xz).rgb, w.b);
	ALBEDO = mix(ALBEDO, outcrop_color * tile_rand(outcrop_tex, world.xz * 0.5).rgb, w.a);
	vec2 study_uv = (world.xz + study_size * 0.5) / study_size;
	vec4 use_mask = texture(study_mask, study_uv);
	vec4 activity = texture(detail_mask, study_uv);
	// 保持同一用途布局，用強邊界暴露「磨耗看起來像畫線」的失敗端值。
	use_mask.g = mix(use_mask.g, smoothstep(0.15, 0.85, use_mask.g), boundary_strength);
	use_mask.a = mix(use_mask.a, smoothstep(0.15, 0.85, use_mask.a), boundary_strength);
	activity = mix(activity, smoothstep(vec4(0.04), vec4(0.60), activity), boundary_strength);
	float macro = texture(macro_tex, world.xz / 48.0).r;
	float gravel = tile_rand(gravel_tex, world.xz).r;
	float fine = mix(0.88, path, mix(0.40, 1.0, detail_strength));
	vec3 yard = to_linear(mix(vec3(0.44, 0.34, 0.24), vec3(0.28, 0.20, 0.12), semantic_strength)) * mix(fine, gravel, mix(0.20, 0.70, detail_strength)) * macro * brightness;
	vec3 compacted = to_linear(mix(vec3(0.66, 0.54, 0.41), vec3(0.84, 0.70, 0.48), semantic_strength)) * mix(0.90, path, mix(0.24, 0.38, detail_strength)) * macro * brightness;
	vec3 loose_stones = to_linear(mix(vec3(0.57, 0.46, 0.34), vec3(0.70, 0.60, 0.44), semantic_strength)) * mix(0.86, gravel, mix(0.58, 1.0, detail_strength)) * macro * brightness;
	vec3 town = mix(yard, compacted, use_mask.g);
	town = mix(town, loose_stones, activity.r * mix(0.75, 1.0, semantic_strength));
	town *= 1.0 - activity.g * mix(0.18, 0.65, semantic_strength);
	// 現存麥株 STEP=0.8m、起點田界+0.5m。行列跟隨種植軸向，遠處淡出。
	float row_phase = (world.x - row_origin) / 0.8;
	float row_visibility = (1.0 - smoothstep(mix(10.0, 22.0, semantic_strength), mix(26.0, 48.0, semantic_strength), length(VERTEX))) * (1.0 - smoothstep(0.18, 0.5, fwidth(row_phase)));
	float furrow = 0.5 + 0.5 * cos(row_phase * 6.283185);
	vec3 cultivated = to_linear(mix(vec3(0.48, 0.36, 0.24), vec3(0.34, 0.23, 0.13), semantic_strength)) * (1.0 - furrow * mix(0.17, 0.65, semantic_strength) * row_visibility) * fine * macro * brightness;
	float travel = max(use_mask.a, activity.a * 0.85);
	vec3 field = mix(cultivated, compacted * 0.94, travel);
	vec3 loose_soil = to_linear(mix(vec3(0.52, 0.40, 0.27), vec3(0.61, 0.43, 0.24), semantic_strength)) * mix(fine, gravel, mix(0.34, 0.75, detail_strength)) * macro * brightness;
	field = mix(field, loose_soil, activity.b * (1.0 - travel * 0.7));
	vec4 land = clamp(texture(landscape_mask, study_uv) * landscape_strength / 0.30, vec4(0.0), vec4(1.0));
	vec4 condition = texture(condition_mask, study_uv);
	// 全場先壓低細碎斑點，保留場所大尺度顏色；路／林／院落再解釋使用。
	vec3 natural = to_linear(COLOR.rgb) * mix(0.90, raw, 0.34) * macro * brightness;
	natural = mix(natural, outcrop_color * mix(0.86, tile_rand(outcrop_tex, world.xz * 0.5).r, 0.40) * macro * brightness, w.a * 0.42);
	vec3 farm_soil = to_linear(vec3(0.49, 0.38, 0.26)) * mix(0.89, path, 0.48) * macro * brightness;
	farm_soil = mix(farm_soil, compacted * 0.94, condition.b);
	natural = mix(natural, farm_soil, land.r);
	// 樹冠範圍只提供覆蓋線索；局部變化打斷圓圈，通行削弱落葉層。
	float litter_detail = tile_rand(detail_tex, world.xz * 0.7).r;
	vec3 litter = to_linear(vec3(0.39, 0.32, 0.23)) * mix(0.88, litter_detail, 0.40) * macro * brightness;
	litter = mix(litter, to_linear(vec3(0.33, 0.29, 0.21)) * macro * brightness, condition.g * 0.36);
	natural = mix(natural, litter, land.g * (1.0 - land.b * 0.84));
	natural = mix(natural, loose_stones * 0.92, land.a * 0.46);
	natural = mix(natural, compacted * 0.93, land.b * 0.88);
	natural = mix(natural, loose_soil, condition.a * (1.0 - land.b * 0.7) * 0.48);
	ALBEDO = natural;
	ALBEDO = mix(ALBEDO, town, use_mask.r);
	ALBEDO = mix(ALBEDO, field, use_mask.b);
	ALBEDO = mix(ALBEDO, dust_color * 0.6, dust_amount * smoothstep(20.0, 80.0, length(VERTEX)));
	ALBEDO *= mix(1.0, bottom_dark, smoothstep(0.7, 1.0, SCREEN_UV.y));   // 0.6：塵土色本身太亮，直接混會把地面洗白
	ROUGHNESS = 0.95;
}
