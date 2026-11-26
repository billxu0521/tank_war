shader_type spatial;
render_mode cull_disabled;
uniform sampler2D soil_map : source_color, repeat_disable, filter_linear_mipmap_anisotropic;
uniform int role = 0;
// 0 田面、1 田埂、2 渠床與坡趾、3 場外平田。
uniform float water_level = -1.38;
varying vec3 pos;
void vertex() { pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 p=pos.xz;
	float shape=sin(p.x*.51+1.2*sin(p.y*.39))+.62*cos(p.y*.95+p.x*.17)+.24*sin(p.x*1.8+p.y*.57);
	vec3 topsoil=texture(soil_map,clamp((p+84.0)/168.0,vec2(.0005),vec2(.9995))).rgb;
	if (role==0) {
		ALBEDO=topsoil;
	} else if (role==3) {
		vec2 edge=clamp(p,vec2(-83.8),vec2(83.8));
		float away=distance(p,edge);
		vec3 pasture=mix(vec3(.39,.285,.147),vec3(.33,.27,.131),smoothstep(-.12,.12,shape));
		vec3 outer=mix(topsoil,pasture,smoothstep(.25,5.5,away));
		// 原場外田紋、農路和渠槽本來就有頂點色差。
		float track=1.0-smoothstep(.52,.70,COLOR.r);
		ALBEDO=mix(outer,vec3(.35,.245,.128),track*.49);
	} else if (role==1) {
		float crown=smoothstep(.1,.62,pos.y+shape*.12);
		vec3 flank=mix(vec3(.314,.227,.095),vec3(.368,.273,.125),smoothstep(.04,.15,shape));
		ALBEDO=mix(mix(topsoil,flank,smoothstep(-.02,.14,pos.y)),vec3(.35,.29,.125),crown*.70);
	} else {
		float wet=(1.0-smoothstep(water_level+.035,water_level+.46,pos.y+.065*shape))*(1.0-smoothstep(58.12,58.4,p.x));
		float silt=smoothstep(water_level+.07,water_level+.21,pos.y+.065*shape)*(1.0-smoothstep(water_level+.24,water_level+.46,pos.y+.065*shape));
		vec3 clay=mix(vec3(.355,.249,.135),vec3(.408,.30,.172),smoothstep(-.12,.12,shape)*.72);
		clay=mix(clay,vec3(.372,.291,.173),silt*.75);
		clay=mix(clay,vec3(.195,.177,.104),wet*.90);
		ALBEDO=mix(clay,topsoil,smoothstep(-.16,.015,pos.y));
	}
	ROUGHNESS=.94;
	SPECULAR=.16;
}
