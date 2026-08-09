shader_type canvas_item;

// The night sky: a gradient with stars scattered through it.
//
// Generated rather than drawn, because the sky is the one thing on screen that
// wants to be enormous, seamless and cheap. A texture big enough not to repeat
// visibly on a tall phone screen would be a large file for something that is
// mostly one colour.
//
// Nothing is stored per star. The screen is divided into cells, each cell is
// hashed, and cells whose hash clears a threshold hold one star at a position
// the same hash decides. That makes the field stable frame to frame without a
// list of anything.

uniform vec4 top_colour : source_color = vec4(0.055, 0.043, 0.125, 1.0);
uniform vec4 horizon_colour : source_color = vec4(0.29, 0.18, 0.33, 1.0);

// Where the sky meets the street, as a fraction down the screen. Set from the
// projection so the two cannot drift apart.
uniform float horizon : hint_range(0.0, 1.0) = 0.36;

uniform float star_cells : hint_range(4.0, 400.0) = 90.0;
// Fraction of cells holding a star. Above about a fifth it stops reading as a
// night sky and starts reading as noise.
uniform float star_chance : hint_range(0.0, 1.0) = 0.12;
uniform float star_size : hint_range(0.001, 0.3) = 0.055;
uniform vec4 star_colour : source_color = vec4(1.0, 0.97, 0.9, 1.0);
// One knob for how much the stars stand out, kept separate from their colour so
// brightness can be tuned without also shifting the tint.
uniform float star_brightness : hint_range(0.0, 4.0) = 1.4;
uniform float twinkle_speed : hint_range(0.0, 8.0) = 1.3;
// How much of a star's brightness the twinkle takes away at its dimmest.
uniform float twinkle_depth : hint_range(0.0, 1.0) = 0.32;
// Stars thin out towards the horizon, the way haze thins them in real air.
uniform float thin_towards_horizon : hint_range(0.0, 1.0) = 0.8;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	// 1 at the top of the screen, 0 at the horizon and below.
	float height = clamp((horizon - UV.y) / max(horizon, 0.0001), 0.0, 1.0);

	vec3 sky = mix(horizon_colour.rgb, top_colour.rgb, height);

	// Cells are square in screen terms rather than in UV, so stars stay round
	// on a screen that is far taller than it is wide.
	vec2 grid = UV * vec2(star_cells, star_cells / max(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 0.0001));
	vec2 cell = floor(grid);
	float pick = hash21(cell);

	if (pick < star_chance) {
		vec2 place = vec2(hash21(cell + 11.7), hash21(cell + 27.3));
		float d = length(fract(grid) - place);

		float phase = pick * 6.2831853;
		float twinkle = 1.0 - twinkle_depth * (0.5 + 0.5 * sin(TIME * twinkle_speed + phase));

		// A little variety in brightness, so the field does not read as a grid.
		float brightness = (0.55 + 0.45 * hash21(cell + 5.1)) * star_brightness;
		float thinning = mix(1.0, height, thin_towards_horizon);

		float star = smoothstep(star_size, 0.0, d) * twinkle * brightness * thinning;
		sky += star_colour.rgb * star;
	}

	COLOR = vec4(sky, 1.0);
}
