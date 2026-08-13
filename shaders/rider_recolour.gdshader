shader_type canvas_item;

// Turns one rider's art into somebody else's, by rotating her hues.
//
// The handoff needs two riders and only one has been drawn. A `modulate` tint was
// tried first and was not enough: multiplying leaves every hue where it was, so she
// read as the same girl standing in different light rather than as another rider.
// Rotating the hue moves green hair to purple and a pink scooter to mint, which is
// what a second uniform actually looks like.
//
// Her skin is spared. A band of hues around it is held back from the rotation, so
// the one part of her that has to stay believable does, while everything a player
// reads as "which rider is this" moves. The band is a hue and a width rather than a
// list of colours because the art is anti-aliased: every edge pixel is a blend of
// two colours and would miss an exact match, leaving a fringe of the old palette
// around every shape. Working in hue space, those blended pixels rotate smoothly
// with their neighbours.
//
// Skin is two colours, not one, and that is what the defaults are built around: the
// fill #ffb570 at hue 0.080 and the coral it is lined and shaded with, #e36956, at
// 0.022. A band centred on the fill covers the fill alone, which recoloured every
// line around her face, hands and arms while leaving the flat parts peach — a rider
// who looked ill rather than like somebody else. Centred between the two at 0.050
// with a half-width of 0.055, both sit inside it and every other colour in her
// palette is a full rotation away: the nearest, the scooter's #ff6b97 at 0.950, is
// 0.100 off, comfortably past where protection has let go.
//
// The pizza box in the aim pose is spared as well, and it takes two mechanisms to do
// it. The box is exactly two colours. Its face, #ba6156 at hue 0.018, is four
// thousandths from her skin's coral line, so the band that spares her spares that for
// free. Its shadowed side, #8c3f5d at 0.935, cannot be reached the same way: going
// round the wheel the order is magenta 0.917, box side 0.935, scooter 0.950, box face
// 0.018, skin, so any band wide enough to hold both ends of the box also holds the
// scooter — the colour a player actually reads the rider by. Widening it there would
// cost the recolour its point.
//
// So that one colour is spared by name rather than by hue, which is what the spare
// uniforms below are for. In hue it is inseparable from the scooter; in plain RGB it
// is 56 away from its nearest neighbour, so naming it is both easy and precise.
//
// The box is the shop's, not the rider's, and a courier does not repaint the packaging
// she is handed. That is the reason it is spared, and the reason to spare nothing else
// this way: the exception list exists for objects that are not part of who she is, and
// one entry has covered every such object so far.
//
// This is staging for a missing sprite, so it belongs on the node in the scene, not
// in rider.tscn. When a second rider is drawn, delete the material.

// How far round the wheel everything unprotected turns. 0.5 is the opposite side.
uniform float hue_shift : hint_range(-1.0, 1.0, 0.01) = 0.52;
// Multiplied into what has turned, for a rider who is meant to read duller or
// brighter as well as differently coloured. 1.0 leaves the art as drawn.
uniform float saturation : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float brightness : hint_range(0.0, 2.0, 0.01) = 1.0;

// The hue held back, and how wide a band around it. Skin's two colours sit at 0.022
// and 0.080, so the centre is between them and the width has to reach both. Widen it
// much past this and her clothes start surviving the rotation with her, which is the
// whole thing this is for; narrow it and her outlines go while her face stays.
uniform float keep_hue : hint_range(0.0, 1.0, 0.005) = 0.05;
uniform float keep_band : hint_range(0.0, 0.5, 0.005) = 0.055;
// How gradually protection lets go at the edge of the band. Zero, and deliberately.
//
// It was 0.02 on the assumption that a hard boundary would flip anti-aliased pixels
// visibly along her jaw. It does not: her face at eight times zoom is the same either
// way. What the soft edge did do is give the pixels inside the falloff a *part* of the
// rotation, and a part-rotated pixel is the one colour on her that belongs to neither
// the old palette nor the new. There were 106 of them, they sat along the coral line
// around her face and hands where it meets her hair, and they were visible in game as
// a few odd pixels. At zero every pixel is either kept whole or turned whole, so each
// one lands on a colour that exists somewhere in a coherent palette, which for flat
// art like this is what matters. Raise it only if a future sprite is drawn with real
// gradients, where a hard line would have somewhere to show.
//
// Whatever it is set to, band plus softness has to stay under the 0.100 that separates
// the band's centre from the scooter, or the scooter starts holding its colour too.
uniform float keep_softness : hint_range(0.0, 0.25, 0.005) = 0.0;

// One colour held back by name, for something in the sprite that is not the rider and
// that the hue band cannot reach. The default is the pizza box's shadowed side.
//
// Matched in plain RGB, which is the whole point: hue cannot tell it from the scooter,
// and RGB can tell it from everything. Tolerance is straight-line distance in unit RGB,
// so 0.10 is about 25 of 255 per channel. The nearest colours it must not swallow are
// the wheels' #5a265e at 0.22 and the scooter outline's #bd4882 at 0.24, so the default
// leaves better than a factor of two either side. Both were checked in game after this
// went in, and both still rotate.
//
// Zero tolerance turns this off, sparing only an exact match, which no anti-aliased
// pixel ever is.
uniform vec3 spare_colour : source_color = vec3(0.549, 0.247, 0.365);
uniform float spare_tolerance : hint_range(0.0, 0.5, 0.005) = 0.10;

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	// COLOR arrives already holding the texel, multiplied by the node's modulate. The
	// sprite is in hand before a line of this runs, and TEXTURE must not be sampled
	// and multiplied in on top of it: doing that squares every channel, which is not
	// a colour bug that announces itself. Squaring barely moves a hue, so she stayed
	// recognisably herself and merely looked two stops darker — read as the whole game
	// having dimmed, since she is the largest thing on the screen. #8fde5d hair came
	// out #50c122, which is 0.561 squared to 0.315 and 0.871 squared to 0.759, exactly.
	//
	// With nothing to change, COLOR is left exactly as it arrived, so the rider a run
	// opens on is the art as drawn to the bit rather than a round trip through HSV.
	// The test is on uniforms, identical for every pixel of the draw, so it is free.
	if (hue_shift != 0.0 || saturation != 1.0 || brightness != 1.0) {
		vec3 hsv = rgb_to_hsv(COLOR.rgb);

		// Distance round the wheel, so the band wraps rather than stopping at 0.0.
		float away = abs(fract(hsv.x - keep_hue + 0.5) - 0.5);
		// The epsilon is not cosmetic: smoothstep with its two edges equal is undefined
		// in GLSL, and keep_softness is meant to be settable to zero.
		float turn = smoothstep(keep_band, keep_band + max(keep_softness, 1e-4), away);

		// And nothing at all happens to the colour spared by name. Hard rather than
		// faded, for the reason keep_softness is zero: a part-turned pixel is the one
		// colour on her that belongs to no palette.
		turn *= step(spare_tolerance, distance(COLOR.rgb, spare_colour));

		hsv.x = fract(hsv.x + hue_shift * turn);
		hsv.y = clamp(hsv.y * mix(1.0, saturation, turn), 0.0, 1.0);
		hsv.z = clamp(hsv.z * mix(1.0, brightness, turn), 0.0, 1.0);

		COLOR = vec4(hsv_to_rgb(hsv), COLOR.a);
	}
}
