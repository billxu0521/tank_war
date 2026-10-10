shader_type spatial;
// 麥子卡片（main.gd wheat_card）：以前是 StandardMaterial3D（只繞垂直軸轉的看板），為了近處變少、穗尖不那麼跳改成自己寫。
// 美術風格評估：麥田近景一根根亮黃色的穗尖跟暗地面明度差太大，整片變成細雜訊
render_mode cull_disabled, specular_disabled;

uniform sampler2D card_tex : source_color, filter_nearest_mipmap;   // 最近點：像素風（2026-10-09）
uniform float near_thin = 0.4;        // 近處藏掉幾成（跟 grass.gdshader 一樣）
uniform float near_thin_dist = 14.0;  // 公尺
uniform float tip_dim = 0.75;         // 穗尖亮度倍數
uniform float tip_sat = 0.6;          // 穗尖飽和度倍數
// 麥浪（2026-10-10 環境感）：跟草地（grass.gdshader）同一個方向、同一波陣風。風吹過的那一條穗尖翻亮，遠看一波波掃過麥田
uniform vec2 wind_dir = vec2(1.0, 0.35);
uniform float wind_strength = 0.35;   // 公尺：卡片頂端最多被吹偏多少
uniform float wave_lift = 0.35;
uniform vec3 backlight : source_color = vec3(1.0, 0.85, 0.55);   // 逆光透光的顏色（時段：午夜改銀藍，period.gd）       // 陣風經過時穗尖亮多少

varying float v_gust;

void vertex() {
	// 只繞垂直軸轉、保留縮放（StandardMaterial 的 BILLBOARD_FIXED_Y + billboard_keep_scale 產生的那段）
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	// 近處藏掉一部分：照根的位置固定挑（同一株一直是同一種，不會閃），縮成一點
	vec3 root = MODEL_MATRIX[3].xyz;
	vec2 dir = normalize(wind_dir);
	v_gust = sin(dot(root.xz, dir) * 0.12 - TIME * 1.6) * 0.5 + 0.5;
	float flutter = sin(TIME * 3.7 + root.x * 1.3 + root.z * 1.9) * 0.2;
	float h = clamp(VERTEX.y / 2.6, 0.0, 1.0);
	vec3 off = vec3(dir.x, 0.0, dir.y) * (v_gust + flutter) * wind_strength * h * h;
	// 看板座標的兩個水平軸（跟上面 MODELVIEW 用的一樣），把世界的風向換成卡片自己的方向
	vec3 ax = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 az = normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0)));
	VERTEX += vec3(dot(off, ax), -length(off) * 0.3, dot(off, az));   // 被吹彎的穗頭也矮一點
	// 貼臉的那叢縮掉（1.5 公尺內）：一張 1.3 公尺寬的卡片貼在鏡頭前是一整片平的黃色色塊
	VERTEX *= smoothstep(0.6, 1.5, distance(root.xz, CAMERA_POSITION_WORLD.xz));
	if (fract(sin(dot(root.xz, vec2(12.9898, 78.233))) * 43758.5453) < near_thin) {
		VERTEX *= smoothstep(near_thin_dist - 3.0, near_thin_dist, distance(root.xz, CAMERA_POSITION_WORLD.xz));
	}
}

void fragment() {
	vec4 c = texture(card_tex, UV);
	float l = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
	float tip = 1.0 - smoothstep(0.25, 0.5, UV.y);   // 圖的上半部是穗
	ALBEDO = mix(c.rgb, mix(vec3(l), c.rgb, tip_sat) * tip_dim * (1.0 + wave_lift * v_gust * v_gust), tip);
	ALPHA = c.a;
	// 逆光透光（2026-10-10）：面向夕陽時麥穗發金光。只有穗那一段透，麥稈不透，不然整片變成一面亮牆
	BACKLIGHT = backlight * mix(0.05, 0.5, tip * tip);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.5;   // 描線跳過的記號（見 outline.gdshader），一根根麥稈描線會變成一片雜訊
}
