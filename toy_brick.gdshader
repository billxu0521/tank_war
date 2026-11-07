shader_type spatial;

// 玩具積木的材質：底色讀每個實例的顏色（MultiMesh use_colors），塑膠感（粗糙度低、有一點高光）。
// 每一面四邊靠邊緣壓暗一條細邊，邊寬用公尺算（模型座標 ±0.5 乘每塊的尺寸），所以每塊的接縫看得出來、不畫格線。
uniform float edge_width = 0.04;   // 邊寬（公尺）
uniform float edge_dark : hint_range(0.0, 1.0) = 0.6;

varying vec3 lp;   // 模型座標（每個面的範圍 ±0.5）
varying vec3 ln;   // 模型座標的法線
varying vec3 sz;   // 這一塊的尺寸（公尺）

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
	sz = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
}

void fragment() {
	// 每個軸離面邊界的距離（公尺）；法線那一軸不算（那一軸永遠在面上）
	vec3 d = (0.5 - abs(lp)) * sz;
	float e = min(d.x + step(0.5, abs(ln.x)) * 1000.0,
		min(d.y + step(0.5, abs(ln.y)) * 1000.0, d.z + step(0.5, abs(ln.z)) * 1000.0));
	float k = mix(edge_dark, 1.0, smoothstep(0.0, edge_width, e));
	ALBEDO = COLOR.rgb * k;
	ROUGHNESS = 0.35;
	SPECULAR = 0.5;
}
