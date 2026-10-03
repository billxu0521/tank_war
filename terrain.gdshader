shader_type spatial;
// 地面（terrain.gd build() 用）：頂點顏色 × 灰階紋理。以前是 StandardMaterial3D，為了多一張「荒地小路」紋理換成自己寫：
// 頂點顏色的透明度 = 路的濃度（main.gd ground_color 填 Trails.weight），濃的地方近看紋理換成 path_dirt（踩實的乾土、龜裂、碎石），
// 草地的紋理（碎石、草梗）淡出去。三張紋理都用世界座標從正上方投影，不用另外算 UV（坡最陡 40 度，拉長看不出來）。
// 粗糙度 0.95：outline.gdshader 拿粗糙度當記號，地面不能撞到草（0.5）、遠山（0.75）、槍（0.65）、目標（0.87）

uniform sampler2D detail_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;   // 草地近看，一張 4 公尺
uniform sampler2D macro_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;    // 遠看的大塊深淺，一張 48 公尺
uniform sampler2D path_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;     // 荒地小路，一張 3 公尺
uniform float brightness = 1.2;   // 紋理平均比白暗，調亮補回來（跟沒貼圖時整體亮度差不多）
uniform float near_detail = 0.3;
// 地面的塵土光：20～80 公尺的地面往暖沙色混，像一層被夕陽照亮的塵土（代替貼地的沙塵霧：Godot 的高度霧照海拔算，谷地的鏡頭會整片被吃掉）
uniform vec3 dust_color : source_color = vec3(0.784, 0.541, 0.353);   // #C88A5A
uniform float dust_amount = 0.32;   // 森林裡樹幹後面要有亮的地面當背景，不然整片暗（第 80 版審查）
uniform float bottom_dark = 0.88;   // 畫面最下面四分之一的地面再暗一點：城鎮的路面是一大片亮色，前景壓不下來。只動地面，牆和人不受影響  // 近處細紋理的強度（美術風格評估：第一人稱腳邊像撒胡椒）

varying vec3 world;

vec3 to_linear(vec3 c) {   // 頂點顏色是 sRGB（以前 StandardMaterial 的 vertex_color_is_srgb）
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float raw = texture(detail_tex, world.xz / 4.0).r;
	float grass = raw;
	// 近處（10 公尺內）細紋理只留三成：腳邊的碎石黑點像撒胡椒；25 公尺外回到原本（遠處需要它打破整片同色）。
	// 往 0.9 收（紋理的平均亮度），整體亮度不變
	float near_k = mix(near_detail, 1.0, smoothstep(10.0, 25.0, length(VERTEX)));
	grass = mix(0.9, grass, near_k);
	float path = texture(path_tex, world.xz / 3.0).r;
	// 路邊：頂點每 2 公尺一個，濃度在中間是平滑漸層；拿近看紋理的明暗再咬一口，邊緣變成碎碎的（碎石、土塊散到草地上）
	float mask = smoothstep(0.35, 0.65, COLOR.a + (raw - 0.9) * 1.2);
	ALBEDO = to_linear(COLOR.rgb) * mix(grass, path, mask) * texture(macro_tex, world.xz / 48.0).r * brightness;
	ALBEDO = mix(ALBEDO, dust_color * 0.6, dust_amount * smoothstep(20.0, 80.0, length(VERTEX)));
	ALBEDO *= mix(1.0, bottom_dark, smoothstep(0.7, 1.0, SCREEN_UV.y));   // 0.6：塵土色本身太亮，直接混會把地面洗白
	ROUGHNESS = 0.95;
}
