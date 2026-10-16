shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 0.1) = 0.0;

void fragment() {
	vec2 dir = (vec2(0.5) - SCREEN_UV) * strength;
	vec4 col = vec4(0.0);
	for (int i = 0; i < 5; i++) {
		col += texture(screen_tex, SCREEN_UV + dir * float(i));
	}
	COLOR = col / 5.0;
}
