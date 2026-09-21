shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float opacity = 0.2;
uniform float drift = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
}
void fragment() {
 float n=noise(UV*5.0+vec2(drift,0.0))*0.65+noise(UV*12.0-vec2(0.0,drift))*0.35;
 float radial=1.0-smoothstep(0.17,0.49,length(UV-0.5));
 ALBEDO=mix(vec3(0.18,0.20,0.20),vec3(0.36,0.38,0.37),n);
 ALPHA=radial*(0.45+0.55*n)*opacity;
}
