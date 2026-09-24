shader_type canvas_item;
uniform sampler2D paving : filter_nearest, repeat_enable;
void fragment() {
	vec4 step = texture(TEXTURE, UV);
	float relief = dot(step.rgb, vec3(0.299, 0.587, 0.114));
	vec3 grain = texture(paving, UV * vec2(0.47, 0.51) + vec2(0.18,0.12)).rgb;
	float weathering = dot(grain, vec3(0.299,0.587,0.114));
	// Preserve tread relief and the authored silhouette while matching weathered paving.
	float tone = smoothstep(0.045, 0.83, relief);
	vec3 stone = mix(vec3(0.105,0.137,0.140), vec3(0.44,0.47,0.43), tone);
	stone *= mix(0.86,1.10,smoothstep(0.12,0.65,weathering));
	float moss = smoothstep(0.014,0.055,grain.g-grain.b) * (1.0-smoothstep(0.20,0.48,relief));
	stone = mix(stone,stone*vec3(0.84,0.99,0.77),moss*0.35);
	COLOR = vec4(stone,step.a);
}
