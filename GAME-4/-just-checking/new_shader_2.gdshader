shader_type spatial;

render_mode unshaded, cull_front;

uniform float outline_size = 0.01;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void vertex() {
    VERTEX += NORMAL * outline_size;
}

void fragment() {
    ALBEDO = outline_color.rgb;
}