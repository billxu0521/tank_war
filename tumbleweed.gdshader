shader_type spatial;
// 風滾草（ambience.gd）：永遠面向鏡頭的一張圖（tools/make_tumbleweed.py），滾動 = 在畫面上轉圈（spin，每顆自己的角度）。
// 逆光時讓光透過乾枝（跟樹葉一樣），夕陽下整團邊緣是亮的
render_mode cull_disabled, specular_disabled;

uniform sampler2D tex : source_color, filter_nearest_mipmap;
instance uniform float spin = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	float c = cos(spin);
	float s = sin(spin);
	VERTEX.xy = mat2(vec2(c, s), vec2(-s, c)) * VERTEX.xy;
}

void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	BACKLIGHT = vec3(0.7);
	ROUGHNESS = 0.5;   // 描線跳過的記號（見 outline.gdshader）：一根根細枝描線會變成一片雜訊
}
