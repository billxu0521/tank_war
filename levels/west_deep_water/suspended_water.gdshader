shader_type spatial;
render_mode cull_back;

uniform sampler2D opaque_depth : hint_depth_texture, repeat_disable, filter_nearest;
varying vec3 water_pos;

void vertex() {
	water_pos = VERTEX;
}

void fragment() {
	// 與原渠相同的緩流色紋。此段不含西灘的固定砂紋。
	vec2 p = water_pos.xz;
	float center = 6.0 + max(-69.0-p.x,0.0)*0.1875;
	vec2 along = vec2(p.x,p.y-center);
	vec2 cell = vec2((along.x-TIME*0.30)*0.37,along.y*0.93);
	float r = length((fract(cell)-vec2(.47,.5))/vec2(.31,.047));
	float aa = max(.07,fwidth(r));
	float stripe = 1.0-smoothstep(1.0-aa,1.0+aa,r);
	float pockets = smoothstep(.28,.82,sin(along.y*1.8+along.x*.13)*sin(along.x*.42));
	float distant = 1.0-smoothstep(.04,.25,fwidth(cell.y));
	ALBEDO = COLOR.rgb*(1.0+stripe*pockets*distant*.10);
	ROUGHNESS = .82;
	SPECULAR = .19;

	// 用進入水面後到第一個實體的視線長度估算濁水透光量。
	float depth = textureLod(opaque_depth,SCREEN_UV,0.).r;
	vec3 ndc = vec3(SCREEN_UV*2.0-1.0,depth);
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		ndc.z = depth*2.0-1.0;
	#endif
	vec4 hit = INV_PROJECTION_MATRIX*vec4(ndc,1.0);
	float path = length(hit.xyz/hit.w-VERTEX);
	float incidence = max(dot(normalize(NORMAL),VIEW),0.0);
	float reach = smoothstep(-82.0,-77.0,p.x)*(1.0-smoothstep(-69.0,-64.0,p.x));
	float transmission = .80 * exp(-.83*path) * smoothstep(.10,.48,incidence);
	ALPHA = 1.0-reach*transmission;
}
