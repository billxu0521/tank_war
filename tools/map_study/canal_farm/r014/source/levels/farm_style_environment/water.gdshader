shader_type spatial;
render_mode cull_back;
uniform sampler2D shore_limits : repeat_disable, filter_linear;
varying vec3 pos;
void vertex(){ pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
	vec2 p=pos.xz;
	// 每四分之一公尺取母圖實際明渠兩岸水線；堤下另沿涵洞軸線。
	float t=(clamp((p.x+84.0)*4.0,0.0,511.0)+.5)/512.0;
	vec2 edge=texture(shore_limits,vec2(t,.5)).rg;
	if (p.x< -84.0) {edge+=(-84.0-p.x)*3.6/42.0;}
	if (p.x>=44.0){
		float z=mix(-5.45,-8.27273,clamp((p.x-44.0)/14.0,0.0,1.0));
		edge=vec2(z-.58,z+.58);
	}
	float cross_pos=(p.y-edge.x)/max(.25,edge.y-edge.x);
	float rim=min(cross_pos,1.0-cross_pos)+.026*sin(p.x*.83+p.y*.62);
	float shoal=smoothstep(-56.,-51.,p.x)*(1.0-smoothstep(-43.,-38.,p.x));
	vec3 deep=mix(vec3(.076,.215,.183),vec3(.145,.30,.227),shoal);
	vec3 col=mix(vec3(.298,.352,.206),mix(vec3(.165,.321,.244),deep,smoothstep(.21,.29,rim)),smoothstep(.015,.12,rim));
	float phase=p.x-.33*TIME;
	float curve=cross_pos+.050*sin(phase*.68)+.030*sin(p.x*1.17+p.y*.32);
	float band=abs(fract(curve*4.3+sin(phase*.26)*.28)-.5);
	float streak=(1.0-smoothstep(.013,.065+fwidth(band),band))*smoothstep(.38,.77,sin(phase*.58+cross_pos*14.0)*cos(p.x*.23+p.y*.17));
	col=mix(col,vec3(.42,.52,.348),streak*.48*smoothstep(.06,.17,rim));
	float join=1.0-smoothstep(-85.5,-82.0,p.x)+smoothstep(-64.,-60.5,p.x);
	ALBEDO=mix(COLOR.rgb,col,clamp(join,0.,1.));
	ROUGHNESS=.84;
	SPECULAR=.18;
}
