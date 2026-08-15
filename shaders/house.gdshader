shader_type canvas_item;

uniform sampler2D mask_texture : filter_nearest; // Change to filter_linear if you want smooth blending
uniform vec4 color_r : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color_g : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Global sprite adjustments
uniform vec4 global_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float desaturation : hint_range(0.0, 1.0) = 0.0;
uniform float darken : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    // Sample the base sprite texture
    vec4 base_color = texture(TEXTURE, UV);
    
    // Sample the RGB mask texture
    vec4 mask = texture(mask_texture, UV);
    
    // Calculate the tint for each channel
    vec3 r_tint = mix(vec3(1.0), color_r.rgb, mask.r);
    vec3 g_tint = mix(vec3(1.0), color_g.rgb, mask.g);
    vec3 b_tint = mix(vec3(1.0), color_b.rgb, mask.b);
    
    // Multiply the base color by all three mask tints
    vec3 final_color = base_color.rgb * r_tint * g_tint * b_tint;
    
    // --- GLOBAL TINT ---
    // Multiply the result by the global tint color
    final_color *= global_tint.rgb;
    
    // --- DESATURATION ---
    // Calculate the perceived luminance (grayscale) using standard dot product weights
    float luminance = dot(final_color, vec3(0.299, 0.587, 0.114));
    // Mix the colored pixel with the grayscale version based on the slider
    final_color = mix(final_color, vec3(luminance), desaturation);
    
    // --- DARKENING ---
    // Mix the resulting color towards black (0.0 = no change, 1.0 = pitch black)
    final_color = mix(final_color, vec3(0.0), darken);
    
    // Output final color, multiplying the base alpha by the global tint's alpha
    COLOR = vec4(final_color, base_color.a * global_tint.a);
}