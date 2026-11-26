shader_type spatial;
render_mode cull_disabled;

uniform float water_level = -1.38;
varying vec3 where;

void vertex() {
	where = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float grain = sin(where.x*2.7+where.z*1.3)*sin(where.z*3.2-where.x*.49);
	float beds = sin(where.x*.64+where.z*.92)*.05 + grain*.013;
	float east = smoothstep(58.0,58.35,where.x);
	float damp = 1.0-smoothstep(water_level+.02, water_level+.35,
		where.y + beds - east*.22);
	vec3 dirt = mix(vec3(.35,.255,.145),vec3(.134,.098,.065),damp);
	ALBEDO = dirt*(1.0+.084*grain);
	ROUGHNESS = mix(.98,.74,damp);
	SPECULAR = .18;
}

