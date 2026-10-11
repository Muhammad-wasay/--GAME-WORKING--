shader_type spatial;
render_mode specular_schlick_ggx;

// Color aur Texture ke liye uniforms
uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;

// Cel-shading ki sharpness aur bands control karne ke liye
uniform float cutoff : hint_range(0.0, 1.0) = 0.5;
uniform float smoothing : hint_range(0.0, 0.1) = 0.02;

void fragment() {
    // Model par texture aur color apply karna
    vec4 col = texture(texture_albedo, UV) * albedo;
    ALBEDO = col.rgb;
}

void light() {
    // Light direction aur normal ka angle nikalna
    float normal_dot_light = dot(NORMAL, LIGHT);
    
    // Smoothstep se cel-shading ke steps/bands banana
    float light_level = smoothstep(cutoff - smoothing, cutoff + smoothing, normal_dot_light);
    
    // Final diffuse light calculation
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * light_level;
}