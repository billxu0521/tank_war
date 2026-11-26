shader_type spatial;
render_mode cull_back;

uniform bool shoal_marks = true;
varying vec3 water_pos;

void vertex() {
	water_pos = VERTEX;
}

float patch(vec2 p, vec2 center, vec2 radius) {
	float r = length((p-center)/radius);
	float aa = max(0.07, fwidth(r));
	return 1.0-smoothstep(1.0-aa,1.0+aa,r);
}

void fragment() {
	vec2 p = water_pos.xz;
	float center = 6.0 + max(-69.0-p.x,0.0)*0.1875
		+ clamp(p.x+47.0,0.0,21.0)*0.285714 + max(p.x+26.0,0.0)/30.0;
	if (p.x>4.0) {
		center = 13.0-clamp(p.x-4.0,0.0,18.0)*5.0/18.0
			-clamp(p.x-22.0,0.0,29.0)*15.0/29.0-max(p.x-51.0,0.0)*2.0/11.0;
	}
	vec2 along = vec2(p.x,p.y-center);
	// 幾小段斷開的鈍色水紋沿渠移動。斜看時減弱細紋，保留中央的角色輪廓。
	vec2 cell = vec2((along.x-TIME*0.30)*0.37,along.y*0.93);
	float stripe = patch(fract(cell),vec2(0.47,0.5),vec2(0.31,0.047));
	float pockets = smoothstep(0.28,0.82,sin(along.y*1.8+along.x*.13)*sin(along.x*.42));
	float quiet = smoothstep(1.1,3.9,abs(p.x+47.0));
	float distant = 1.0-smoothstep(0.04,0.25,fwidth(cell.y));
	vec3 col = COLOR.rgb*(1.0+stripe*pockets*quiet*distant*0.10);
	// 淺灘兩側的沉積透色固定在原處；不隨流紋移動。
	if (shoal_marks) {
		float sand = patch(p,vec2(-51.0,2.6),vec2(.88,.28))
			+patch(p,vec2(-50.2,2.9),vec2(.34,.16))
			+patch(p,vec2(-43.0,10.0),vec2(.72,.24));
		col = mix(col,vec3(.26,.30,.215),min(sand,1.0)*.36);
	}
	ALBEDO = col;
	ROUGHNESS = .82;
	SPECULAR = .19;
}
