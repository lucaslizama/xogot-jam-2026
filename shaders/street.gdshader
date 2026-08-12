shader_type canvas_item;

// The road surface, drawn by inverting the street's projection.
//
// Every pixel works out where on the street it actually is, which is what makes
// this worth doing at all: the grain and the markings then scroll at the right
// rate at every depth, quickly under the wheel and barely at all near the
// horizon, instead of the whole surface sliding as one sheet.
//
// The projection puts a point at distance d on the screen row
//     y = horizon + (near_ground - horizon) * focal / (focal + d)
// so with t as that fraction, d = focal * (1 - t) / t, and the sideways
// position falls out of the same scale.

uniform vec2 screen_size = vec2(1170.0, 2532.0);
uniform float horizon_y = 900.0;
uniform float near_ground_y = 2100.0;
uniform float centre_x = 585.0;
uniform float focal = 28.0;
uniform float pixels_per_unit = 46.0;

// How far the world has slid past. The road scrolls with it.
uniform float travelled = 0.0;
// Where the tarmac stops and the verge begins.
uniform float road_far : hint_range(1.0, 200.0) = 18.0;

uniform vec4 asphalt : source_color = vec4(0.152941, 0.152941, 0.211765, 1.0);
uniform vec4 asphalt_grain : source_color = vec4(0.196078, 0.160784, 0.278431, 1.0);
uniform float grain_amount : hint_range(0.0, 1.0) = 0.35;
uniform float grain_scale : hint_range(0.05, 8.0) = 1.1;
uniform vec4 verge_colour : source_color = vec4(0.196078, 0.243137, 0.309804, 1.0);
uniform float verge_depth : hint_range(0.0, 20.0) = 1.6;

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

// Value noise, so the grain reads as tarmac rather than as a grid of tiles.
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
		discard;                       // above the horizon is sky, not road
	}

	float dist = focal * (1.0 - t) / t;
	if (dist > road_far + verge_depth) {
		discard;                       // beyond the verge the backdrop takes over
	}

	// Sideways position in world units, scrolled by how far the rider has gone.
	float side = (px.x - centre_x) / (pixels_per_unit * t) + travelled;

	// Two scales of grain, the finer one only near the camera, so distant road
	// does not dissolve into noise it could not resolve anyway.
	float near_weight = clamp(1.0 - dist / max(road_far, 0.001), 0.0, 1.0);
	float g = noise(vec2(side, dist) * grain_scale);
	g = mix(g, noise(vec2(side, dist) * grain_scale * 3.7), 0.35 * near_weight);

	vec3 colour = mix(asphalt.rgb, asphalt_grain.rgb, g * grain_amount);

	// The markings: a band at one depth, dashed along the street. Both edges are
	// softened against the pixel size at this depth, which is what keeps a far
	// dash from flickering as it scrolls.
	float across = abs(dist - lane_distance);
	float depth_px = max(pixels_per_unit * t, 0.0001);
	float edge = 1.5 / depth_px;
	float band = 1.0 - smoothstep(lane_width * 0.5 - edge, lane_width * 0.5 + edge, across);
	float along = mod(side, lane_dash + lane_gap);
	float dash = 1.0 - smoothstep(lane_dash - edge, lane_dash + edge, along);
	colour = mix(colour, lane_colour.rgb, band * dash * lane_colour.a);

	// The verge, past the tarmac.
	float verge = smoothstep(road_far - 0.15, road_far + 0.15, dist);
	colour = mix(colour, verge_colour.rgb, verge);

	// The same haze everything else recedes into.
	float haze = clamp((dist - haze_from) / max(haze_full - haze_from, 0.01), 0.0, 1.0) * haze_strength;
	colour = mix(colour, colour * haze_colour.rgb, haze);

	COLOR = vec4(colour, 1.0);
}
