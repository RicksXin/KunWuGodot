shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform float phase = 0.0;
uniform float pulse = 1.0;
uniform float tongue = 0.0;
void fragment() {
    // glTF flips Blender V: the exported flame base is V=1.
    float h = clamp(1.0 - UV.y, 0.0, 1.0);
    float facing = pow(clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 1.3);
    float ripple = 0.82 + 0.18 * sin(UV.x * 18.84956 - h * 15.0 + phase * 5.0 + tongue);
    float fade = smoothstep(0.0, 0.12, h) * (1.0 - smoothstep(0.62, 1.0, h));
    vec3 outer = mix(vec3(0.015, 0.32, 0.9), vec3(0.005, 0.07, 0.38), h);
    float core = pow(facing, 3.0) * (1.0 - smoothstep(0.12, 0.72, h));
    ALBEDO = mix(outer, vec3(0.58, 0.94, 1.0), core) * pulse * 1.5;
    ALPHA = facing * fade * ripple * 0.72;
}
