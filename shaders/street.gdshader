shader_type canvas_item;

// The road surface, drawn by inverting the street's projection.
uniform vec2 screen_size = vec2(1170.0, 2532.0);
uniform float horizon_y = 900.0;
uniform float near_ground_y = 2100.0;
uniform float centre_x = 585.0;
uniform float focal = 28.0;
uniform float pixels_per_unit = 46.0;

uniform float travelled = 0.0;
uniform float road_far : hint_range(1.0, 200.0) = 18.0;

uniform vec4 asphalt : source_color = vec4(0.152941, 0.152941, 0.211765, 1.0);
uniform vec4 asphalt_grain : source_color = vec4(0.196078, 0.160784, 0.278431, 1.0);
uniform float grain_amount : hint_range(0.0, 1.0) = 0.35;
uniform float grain_scale : hint_range(0.05, 8.0) = 1.1;

// NEW: Stepped grain parameters
uniform bool use_stepped_grain = false;
uniform float grain_steps : hint_range(2.0, 20.0, 1.0) = 4.0;

// NEW: Gradient mapping parameters
uniform bool use_gradient = false;
// Note: In the inspector, assign a "GradientTexture1D" to this.
uniform sampler2D grain_gradient : repeat_disable; 

uniform vec4 verge_colour : source_color = vec4(0.196078, 0.243137, 0.309804, 1.0);
uniform float verge_depth : hint_range(0.0, 20.0) = 1.6;

uniform vec4 outer_layer_colour : source_color = vec4(0.14902, 0.18824, 0.24706, 1.0);
uniform float outer_layer_depth : hint_range(0.0, 1000.0) = 20.0;

uniform vec4 lane_colour : source_color = vec4(1.0, 0.894118, 0.470588, 0.7);
uniform float lane_distance : hint_range(0.0, 60.0) = 7.0;
uniform float lane_width : hint_range(0.1, 10.0) = 1.1;
uniform float lane_dash : hint_range(0.5, 40.0) = 7.0;
uniform float lane_gap : hint_range(0.5, 40.0) = 9.0;

uniform vec4 haze_colour : source_color = vec4(0.278431, 0.231373, 0.470588, 1.0);
uniform float haze_from = 18.0;
uniform float haze_full = 260.0;
uniform float haze_strength : hint_range(0.0, 1.0) = 0.75;

float hash21(vec2 p) {
    p = fract(p * vec2(127.11, 311.7));
    p += dot(p, p + 34.19);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(cell);
    float b = hash21(cell + vec2(1.0, 0.0));
    float c = hash21(cell + vec2(0.0, 1.0));
    float d = hash21(cell + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 px = UV * screen_size;

    float t = (px.y - horizon_y) / (near_ground_y - horizon_y);
    if (t <= 0.0001) {
        discard;
    }

    float dist = focal * (1.0 - t) / t;
    
    if (dist > road_far + verge_depth + outer_layer_depth) {
        discard;
    }

    float side = (px.x - centre_x) / (pixels_per_unit * t) + travelled;

    float near_weight = clamp(1.0 - dist / max(road_far, 0.001), 0.0, 1.0);
    float g = noise(vec2(side, dist) * grain_scale);
    g = mix(g, noise(vec2(side, dist) * grain_scale * 3.7), 0.35 * near_weight);

    // --- NEW: Modify the noise value ---
    
    if (use_stepped_grain) {
        // Quantizes the noise into distinct bands
        g = floor(g * grain_steps) / (grain_steps - 1.0);
    }
    
    if (use_gradient) {
        // Maps the noise value (0.0 to 1.0) to the X-axis of the gradient texture.
        // We use the red channel (.r) to dictate the new intensity.
        g = texture(grain_gradient, vec2(g, 0.5)).r;
    }
    
    // -----------------------------------

    vec3 colour = mix(asphalt.rgb, asphalt_grain.rgb, g * grain_amount);

    float across = abs(dist - lane_distance);
    float depth_px = max(pixels_per_unit * t, 0.0001);
    float edge = 1.5 / depth_px;
    float band = 1.0 - smoothstep(lane_width * 0.5 - edge, lane_width * 0.5 + edge, across);
    float along = mod(side, lane_dash + lane_gap);
    float dash = 1.0 - smoothstep(lane_dash - edge, lane_dash + edge, along);
    colour = mix(colour, lane_colour.rgb, band * dash * lane_colour.a);

    float verge = smoothstep(road_far - 0.15, road_far + 0.15, dist);
    colour = mix(colour, verge_colour.rgb, verge);
    
    float outer_layer = smoothstep(road_far + verge_depth - 0.15, road_far + verge_depth + 0.15, dist);
    colour = mix(colour, outer_layer_colour.rgb, outer_layer);

    float haze = clamp((dist - haze_from) / max(haze_full - haze_from, 0.01), 0.0, 1.0) * haze_strength;
    colour = mix(colour, colour * haze_colour.rgb, haze);

    COLOR = vec4(colour, 1.0);
}