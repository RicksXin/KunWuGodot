shader_type canvas_item;
uniform float flow_time = 0.0;
uniform float vertical_texture_scale = 1.0;
varying vec4 tint;
void vertex() { tint = COLOR; }
vec2 mirrored(vec2 uv) { return 1.0 - abs(mod(uv, 2.0) - 1.0); }
void fragment() {
	vec2 water_uv = UV * vec2(1.0, vertical_texture_scale);
	// Keep submerged stones still; only the light water ripples travel downstream.
	vec4 bed = texture(TEXTURE, mirrored(water_uv));
	vec2 moving_uv = water_uv - vec2(0.0, flow_time * 0.085);
	moving_uv.x += sin(UV.y * 28.0 - flow_time * 1.6) * 0.005;
	vec3 moving = texture(TEXTURE, mirrored(moving_uv)).rgb;
	float foam = smoothstep(0.38, 0.73, dot(moving, vec3(0.2126,0.7152,0.0722)));
	vec3 water = bed.rgb * 0.86 + vec3(0.39,0.55,0.53) * foam * 0.38;
	COLOR = vec4(water, bed.a) * tint;
}
