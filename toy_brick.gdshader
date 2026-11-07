shader_type spatial;

// 玩具積木的材質：底色讀每個實例的顏色（MultiMesh use_colors），塑膠感（粗糙度低、有一點高光）。
// 每一面靠邊緣壓暗一條細邊（UV 0..1），看得出一塊一塊；不畫格線。
uniform float edge_width : hint_range(0.0, 0.2) = 0.05;
uniform float edge_dark : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	float e = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float k = mix(edge_dark, 1.0, smoothstep(0.0, edge_width, e));
	ALBEDO = COLOR.rgb * k;
	ROUGHNESS = 0.35;
	SPECULAR = 0.5;
}
