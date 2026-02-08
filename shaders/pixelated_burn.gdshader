shader_type canvas_item;

// Burn effect shader for Level 5 transition
// Uses SCREEN coordinates so burn spreads from one point across all objects

uniform vec2 burn_center_screen = vec2(1700.0, 150.0);  // Screen pixel position of sun
uniform vec2 screen_size = vec2(1920.0, 1080.0);  // Screen resolution
uniform float burn_radius : hint_range(0.0, 3000.0) = 0.0;  // Current burn radius in pixels
uniform float border_width : hint_range(10.0, 200.0) = 80.0;
uniform float burn_noise_mult : hint_range(0.0, 200.0) = 50.0;
uniform float pixel_size : hint_range(1.0, 20.0) = 4.0;
uniform float blend_steps : hint_range(2.0, 16.0) = 8.0;

uniform sampler2D noise_texture : hint_default_white;
uniform vec4 burn_color_1 : source_color = vec4(1.0, 0.5, 0.0, 1.0);  // Orange
uniform vec4 burn_color_2 : source_color = vec4(1.0, 0.2, 0.0, 1.0);  // Red-orange
uniform vec4 burn_color_3 : source_color = vec4(0.3, 0.0, 0.0, 1.0);  // Dark red

void fragment() {
    // Get screen position
    vec2 screen_pos = FRAGCOORD.xy;
    
    // Pixelate screen position
    vec2 snapped_pos = floor(screen_pos / pixel_size) * pixel_size;
    
    // Noise sampling using normalized coords
    vec2 noise_uv = snapped_pos / screen_size;
    float noise_val = texture(noise_texture, noise_uv * 3.0).r;
    
    // Calculate distance from burn center with noise
    float dist = length(burn_center_screen - snapped_pos) + noise_val * burn_noise_mult;
    
    // Create burn mask
    float mask = clamp((dist - (burn_radius - border_width)) / (2.0 * border_width), 0.0, 1.0);
    mask = 1.0 - mask;
    mask = floor(mask * blend_steps) / blend_steps;
    
    // Inside burn radius = burned away (transparent)
    float inside_burn = float(dist < burn_radius - border_width * 0.5);
    
    // Border coloring (gradient from burn_color_1 to burn_color_3)
    vec4 burn_gradient;
    if (mask > 0.66) {
        burn_gradient = mix(burn_color_2, burn_color_1, (mask - 0.66) / 0.34);
    } else if (mask > 0.33) {
        burn_gradient = mix(burn_color_3, burn_color_2, (mask - 0.33) / 0.33);
    } else {
        burn_gradient = burn_color_3;
    }
    
    // Apply burn effect
    float burn_blend = pow(mask, 0.3);
    COLOR.rgb = mix(COLOR.rgb, burn_gradient.rgb, burn_blend);
    
    // Make burned area transparent
    COLOR.a *= 1.0 - inside_burn;
}
