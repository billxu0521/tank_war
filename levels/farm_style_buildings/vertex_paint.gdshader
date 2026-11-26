shader_type spatial;
render_mode cull_back;

uniform vec4 shadow_paint : source_color;
uniform vec4 timber_paint : source_color;
uniform vec4 cut_paint : source_color;

void fragment() {
	float value = dot(COLOR.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 wood = mix(shadow_paint.rgb, timber_paint.rgb, smoothstep(0.035, 0.28, value));
	ALBEDO = mix(wood, cut_paint.rgb, smoothstep(0.27, 0.69, value));
	ROUGHNESS = 0.87;
	SPECULAR = 0.23;
}
