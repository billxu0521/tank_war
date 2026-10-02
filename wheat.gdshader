shader_type spatial;
// 麥子卡片（main.gd wheat_card）：以前是 StandardMaterial3D（只繞垂直軸轉的看板），為了近處變少、穗尖不那麼跳改成自己寫。
// 美術風格評估：麥田近景一根根亮黃色的穗尖跟暗地面明度差太大，整片變成細雜訊
render_mode cull_disabled, specular_disabled;

uniform sampler2D card_tex : source_color, filter_linear_mipmap;
uniform float near_thin = 0.4;        // 近處藏掉幾成（跟 grass.gdshader 一樣）
uniform float near_thin_dist = 14.0;  // 公尺
uniform float tip_dim = 0.75;         // 穗尖亮度倍數
uniform float tip_sat = 0.6;          // 穗尖飽和度倍數

void vertex() {
	// 只繞垂直軸轉、保留縮放（StandardMaterial 的 BILLBOARD_FIXED_Y + billboard_keep_scale 產生的那段）
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	// 近處藏掉一部分：照根的位置固定挑（同一株一直是同一種，不會閃），縮成一點
	vec3 root = MODEL_MATRIX[3].xyz;
	if (fract(sin(dot(root.xz, vec2(12.9898, 78.233))) * 43758.5453) < near_thin) {
		VERTEX *= smoothstep(near_thin_dist - 3.0, near_thin_dist, distance(root.xz, CAMERA_POSITION_WORLD.xz));
	}
}

void fragment() {
	vec4 c = texture(card_tex, UV);
	float l = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
	float tip = 1.0 - smoothstep(0.25, 0.5, UV.y);   // 圖的上半部是穗
	ALBEDO = mix(c.rgb, mix(vec3(l), c.rgb, tip_sat) * tip_dim, tip);
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.5;   // 描線跳過的記號（見 outline.gdshader），一根根麥稈描線會變成一片雜訊
}
