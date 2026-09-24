shader_type canvas_item;
uniform float phase = 0.0;
uniform bool spirit_light = false;
void fragment() {
	vec4 c = COLOR;
	// Only the bright amber opening breathes; stone geometry remains still.
	float amber = smoothstep(0.32,0.6,c.r) * smoothstep(0.12,0.35,c.r-c.b) * smoothstep(0.12,0.3,c.g);
	float jade = smoothstep(0.25,0.6,c.g) * smoothstep(0.03,0.16,max(c.g,c.b)-c.r);
	float glow_mask = spirit_light ? jade : amber;
	float pulse = 0.93 + 0.07*sin(TIME*2.6+phase) + 0.025*sin(TIME*7.1+phase*2.0);
	COLOR = vec4(c.rgb*mix(1.0,pulse,glow_mask),c.a);
}
