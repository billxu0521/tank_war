shader_type spatial;
render_mode cull_disabled;
varying float lightness;
void vertex() {
	// 斷塊的原始變換仍由 ToyBuild 更新，隱藏後頂點一併縮回。
	if (abs(UV.x - floor(INSTANCE_CUSTOM.r * 8.0 + .5)) > .25) {
		VERTEX = vec3(0.0);
	}
	lightness = mix(.88,1.10,INSTANCE_CUSTOM.g);
}
void fragment() {
	ALBEDO = COLOR.rgb * lightness;
	ROUGHNESS = .94;
	SPECULAR = .18;
}
