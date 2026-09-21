shader_type spatial;
render_mode cull_disabled;
uniform float flow_time=0.0;
void fragment() {
 float ripples=pow(0.5+0.5*sin(UV.y*83.0-flow_time*5.0+sin(UV.x*26.0)*2.0),8.0);
 ALBEDO=mix(vec3(0.025,0.085,0.09),vec3(0.13,0.25,0.24),ripples*0.55);
 ROUGHNESS=0.3; METALLIC=0.22;
}
