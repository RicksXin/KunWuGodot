shader_type canvas_item;
uniform sampler2D paving : filter_nearest;
uniform sampler2D occupancy : filter_nearest, repeat_disable;
uniform sampler2D soil : filter_nearest, repeat_enable;
uniform vec2 grid_origin;
uniform vec2 grid_size;
varying vec2 local_point;
float filled(vec2 cell) { return texture(occupancy,(cell-grid_origin+vec2(0.5))/grid_size).r; }
void vertex() { local_point = VERTEX; }
void fragment() {
 vec4 original = texture(TEXTURE, UV);
 vec2 plane = vec2(local_point.x + 2.0*local_point.y, -local_point.x + 2.0*local_point.y);
 vec2 phase = plane / vec2(640.0, 480.0);
 vec2 reflected = 1.0-abs(mod(phase,2.0)-1.0);
 vec3 slabs = texture(paving, reflected).rgb;
 vec2 grid = vec2(local_point.x/128.0+local_point.y/64.0-1.0,local_point.y/64.0-local_point.x/128.0);
 vec2 cell = floor(grid+vec2(0.5));
 vec2 within = grid-cell;
 float distance_edge = 1.0;
 if(filled(cell+vec2(1,0))<0.5) distance_edge=min(distance_edge,0.5-within.x);
 if(filled(cell-vec2(1,0))<0.5) distance_edge=min(distance_edge,0.5+within.x);
 if(filled(cell+vec2(0,1))<0.5) distance_edge=min(distance_edge,0.5-within.y);
 if(filled(cell-vec2(0,1))<0.5) distance_edge=min(distance_edge,0.5+within.y);
 vec3 dirt = texture(soil,plane/vec2(110.0,90.0)).rgb;
 float noise = dot(dirt,vec3(0.333));
 float border = 1.0-smoothstep(0.015,0.28+noise*0.20,distance_edge);
 vec3 moss = vec3(0.28,0.30,0.19)*(0.65+noise);
 vec3 ground = mix(slabs,moss,border*0.86);
 float grey = dot(ground,vec3(0.299,0.587,0.114));
 ground = mix(vec3(grey),ground,0.65)*vec3(0.66,0.73,0.79);
 COLOR = vec4(ground,original.a);
}
