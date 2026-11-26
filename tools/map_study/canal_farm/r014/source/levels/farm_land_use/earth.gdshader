shader_type spatial;
render_mode cull_disabled;
uniform sampler2D soil_map : source_color,repeat_disable,filter_linear_mipmap_anisotropic;
uniform sampler2D a_map : source_color,repeat_disable,filter_linear_mipmap_anisotropic;
uniform sampler2D usage_map : repeat_disable,filter_linear_mipmap_anisotropic;
uniform sampler2D zones : repeat_disable,filter_linear_mipmap_anisotropic;
uniform int role=0;
uniform float water_level=-1.38;
uniform vec4 old_track : source_color=vec4(.72,.63,.52,1.);
varying vec3 p3;
void vertex(){p3=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
	vec2 p=p3.xz;
	vec2 uv=clamp((p+84.)/168.,vec2(.0005),vec2(.9995));
	vec3 weights=texture(zones,uv).rgb;
	vec4 usage=texture(usage_map,uv);
	vec3 old=texture(soil_map,uv).rgb;
	vec3 a=texture(a_map,uv).rgb;
	float edge=sin(p.x*.52+p.y*.22)+.62*sin(p.y*.88-p.x*.14)+.24*sin(p.x*1.71+p.y*.33);
	float broad=sin(p.x*.105+sin(p.y*.09)*1.9)+sin(p.y*.175-p.x*.029)*.7;
	float outer=1.-smoothstep(81.,88.,max(abs(p.x),abs(p.y)));
	float road=smoothstep(.32,.74,usage.r+edge*.15)*outer;
	vec3 turf=mix(vec3(.205,.250,.100),vec3(.295,.310,.123),smoothstep(-.15,.15,broad+edge*.16));
	vec3 tilled=mix(vec3(.274,.201,.106),vec3(.345,.319,.145),smoothstep(.23,.78,usage.b));
	vec3 c=mix(turf,tilled,usage.g*outer*.89);
	vec3 track=mix(vec3(.428,.296,.179),vec3(.499,.352,.207),.5+.5*sin(p.y*.49+p.x*.21));
	c=mix(c,track,max(road,usage.a*outer*.87))*(.93+dot(old,vec3(.28,.60,.12))*.19);
	c=mix(c,vec3(.232,.270,.112),smoothstep(.07,.30,usage.r)*(1.-smoothstep(.38,.74,usage.r))*.55);
	// 土院可見乾土；有車行碾壓的地點降低草色。
	float green=smoothstep(.85,1.08,a.g/max(.001,a.r));
	a=mix(a,vec3(.45,.335,.217),weights.b*green*.72);
	vec3 result=mix(mix(old,a,weights.r),c,weights.g);
	if(role==1) result=mix(c,vec3(.228,.286,.128),.48);
	if(role==2){
		// 沿用現役渠岸的沖淤及水位。只有西段回到田面的上緣接入同一層路土。
		float shape=sin(p.x*.51+1.2*sin(p.y*.39))+.62*cos(p.y*.95+p.x*.17)+.24*sin(p.x*1.8+p.y*.57);
		float elevation=p3.y+.065*shape;
		float wet=(1.-smoothstep(water_level+.035,water_level+.46,elevation))*(1.-smoothstep(58.12,58.4,p.x));
		float silt=smoothstep(water_level+.07,water_level+.21,elevation)*(1.-smoothstep(water_level+.24,water_level+.46,elevation));
		vec3 clay=mix(vec3(.355,.249,.135),vec3(.408,.30,.172),smoothstep(-.12,.12,shape)*.72);
		clay=mix(clay,vec3(.372,.291,.173),silt*.75);
		clay=mix(clay,vec3(.195,.177,.104),wet*.90);
		result=mix(clay,mix(result,old,smoothstep(37.,44.,p.x)),smoothstep(-.16,.015,p3.y));
	}
	if(role==4){
		float wear=1.-smoothstep(.012,.045,min(distance(COLOR.rgb,vec3(.429,.242,.100)),distance(COLOR.rgb,vec3(.546,.342,.147))));
		result=mix(COLOR.rgb,a*.94,wear*.94*weights.r*(1.-weights.g));
	}
	if(role==5) result=mix(old_track.rgb,a*(.96+.032*sin(p.x*.28+p.y*.47)),weights.r*(1.-weights.g));
	if(role==6){
		float bare=smoothstep(.005,.13,-p3.y);
		float fleck=sin(p.x*13.2+p.y*5.1)*cos(p.y*7.3-p.x*3.7);
		vec3 cut_soil=mix(vec3(.235,.171,.095), vec3(.274,.211,.133), .5+.5*fleck);
		result=mix(result,cut_soil,bare*.61);
	}
	ALBEDO=result;
	ROUGHNESS=.94;
	SPECULAR=.16;
}
