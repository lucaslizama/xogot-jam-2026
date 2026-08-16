@tool
class_name HowToDiagram
extends Control

## A mock-up of one how-to-play step, drawn from the game's own placeholder pieces:
## the street, a house with a lit window, the cyan drop point, the pizza in hand, the
## stack of boxes left. Its job is to make the page readable and arguable before a
## frame of the real thing is drawn, and to show an artist the shot each step asks
## for rather than describing it in a sentence.
##
## The colours below are the ones the street, the houses, the strike dots and the
## pizza already use, so the page looks like the game it explains. Assign the
## step's art and the whole diagram is hidden, which is [HowToStep]'s doing.
##
## Everything is laid out in unit coordinates and multiplied up by the node's
## size, so one drawing fits whatever height a step is given.

## Which step this draws. Named DiagramKind rather than Kind because a bare name
## risks colliding with a built-in global enum, which fails to compile in a way
## nothing surfaces until the script is loaded.
enum DiagramKind {
	NONE, ## Nothing drawn, leaving the plain placeholder box and its note.
	FLICK, ## Drag and release: the gesture and where the pizza goes.
	CURVE, ## Twisting before the throw, and the bent flight it buys.
	LAND, ## One in the ring, one into the wall.
	STACK, ## The boxes left on the bike and the strike dots up top.
	ORDERS, ## The ticket, and the tap on the road that changes what is on the pizza.
	FLAVOURS, ## The tap on the road, and the three flavours it turns the pizza through.
}

@export var kind: DiagramKind = DiagramKind.FLICK:
	set(value):
		kind = value
		queue_redraw()

@export_group("Our art, where it exists")
## One box in the stack of pizzas left. Boxes are drawn as bars without it.
@export var box_art: Texture2D:
	set(value):
		box_art = value
		queue_redraw()
## The splat where a missed pizza ends up. Drawn as a smear without it.
@export var dropped_art: Texture2D:
	set(value):
		dropped_art = value
		queue_redraw()
## The pizza in hand and in the air. Drawn as a disc with a rim without it.
##
## The page has to show the game as it is now, or it teaches something the player
## then fails to recognise. That is a debt these diagrams take on by being drawings
## rather than screenshots: art lands in the game and the page keeps teaching the
## placeholders. Every slot here exists so paying it is a drag-and-drop.
@export var pizza_art: Texture2D:
	set(value):
		pizza_art = value
		queue_redraw()
## The flavours, in menu order, for the picture that has to show all three at once.
## Falls back to [member pizza_art], and then to discs with toppings on them.
@export var flavour_art: Array[Texture2D] = []:
	set(value):
		flavour_art = value
		queue_redraw()
## The small square each flavour gets on the order ticket, in the same order. This
## is what the real ticket puts beside a line, so the mock-up puts it there too.
@export var flavour_icons: Array[Texture2D] = []:
	set(value):
		flavour_icons = value
		queue_redraw()
## The buildings, several across one sheet. Without it a house is a box with a
## triangle on top.
@export var house_art: Texture2D:
	set(value):
		house_art = value
		queue_redraw()
## How many buildings sit side by side in [member house_art]. The street's own
## sprite reads the sheet the same way, with hframes.
@export_range(1, 16) var house_frames: int = 4:
	set(value):
		house_frames = maxi(1, value)
		queue_redraw()
## How wide a house is drawn, as a fraction of the picture's width. The frames are
## square, so this is its height in pixels too — which is not the same fraction
## down the picture, the picture being wider than it is tall. 0.19 puts the art in
## about the footprint the drawn house had, roughly 190 by 200 at the size these
## diagrams are given; much more and the roof leaves through the top of the frame.
@export_range(0.05, 0.6, 0.01) var house_size: float = 0.19:
	set(value):
		house_size = value
		queue_redraw()
## What scenery is multiplied by. A house nobody is waiting in is dark, and that
## contrast is the read the game asks for most often, so it is worth being able to
## push it here without touching the art.
@export var scenery_shade: Color = Color(0.42, 0.38, 0.55):
	set(value):
		scenery_shade = value
		queue_redraw()

@export_group("Colours")
## The night the game is played in, and the road under it.
@export var sky: Color = Color(0.196078, 0.160784, 0.278431)
## The ground either side of the paving. Without it anything standing off the road
## has nothing under it and floats in the sky, which is exactly how it looked.
@export var ground: Color = Color(0.196078, 0.243137, 0.309804)
@export var road: Color = Color(0.262745, 0.262745, 0.309804)
@export var road_edge: Color = Color(1, 0.894118, 0.470588, 0.5)
## The paint on the road. Fainter and thinner than the kerbs, or the marks read as
## slabs lying across the street rather than as markings on it.
@export var lane_mark: Color = Color(1, 0.894118, 0.470588, 0.3)
@export var horizon_glow: Color = Color(0.368627, 0.192157, 0.356863)
## Taken from the house placeholder, so a house here is the house there.
@export var wall: Color = Color(0.729412, 0.380392, 0.337255)
@export var roof: Color = Color(0.341176, 0.160784, 0.294118)
@export var window_lit: Color = Color(1, 0.894118, 0.470588)
## The drop point's cyan, the colour a waiting house is aimed at.
@export var ring: Color = Color(0.301961, 0.65098, 1, 0.55)
@export var pizza: Color = Color(1, 0.894118, 0.470588)
@export var pizza_rim: Color = Color(0.94902, 0.65098, 0.368627)
## The strike dots: clean, and crossed off.
@export var clean: Color = Color(1, 1, 0.921569)
@export var spent: Color = Color(0.921569, 0.337255, 0.294118)
## The gesture drawn over the scene, and the good and bad outcomes.
@export var gesture: Color = Color(1, 1, 0.921569, 0.85)
@export var good: Color = Color(0.235294, 0.639216, 0.439216)
@export var bad: Color = Color(0.921569, 0.337255, 0.294118)

@export_group("The order ticket")
## The card the order is written on, and the bar that is its clock.
@export var ticket_card: Color = Color(0.152941, 0.152941, 0.211765, 0.85)
@export var ticket_row: Color = Color(1, 1, 0.921569, 0.55)
@export var ticket_clock: Color = Color(0.301961, 0.65098, 1)
## Two flavours' worth of toppings. Not the same size as each other on purpose: at
## the size a pizza flies at, how many and how big is what tells them apart, and
## colour alone says nothing to a colour-blind player.
@export var topping_a: Color = Color(0.690196, 0.188235, 0.360784)
@export var topping_b: Color = Color(0.811765, 1, 0.439216)
## And a third, for the flavours picture, which is the only one that has to show the
## whole menu at once. The ticket never needs it: an order names two at most.
@export var topping_c: Color = Color(1, 0.729412, 0.298039)
## The ripple where a finger touched the road.
@export var tap_ring: Color = Color(1, 1, 0.921569, 0.7)

## The camera the game actually uses. The pizza sits in your hand at the bottom of
## the screen, the houses are along the top, and you flick up the screen at them,
## the way a ball is thrown in Pokemon Go. Up the screen is further away, so there
## is no road running off into the distance: the street is a band across the middle
## that scrolls right to left, and a throw that falls short lands lower, not nearer
## the middle.
##
## The sky ends here, and the pavement the houses stand on begins.
const HORIZON: float = 0.26
## Where the pavement ends and the road begins.
const FAR_KERB: float = 0.40
## The pizza in hand, big at the bottom centre, which is what you drag.
const IN_HAND: Vector2 = Vector2(0.5, 0.86)
const IN_HAND_RADIUS: float = 0.08
## The waiting house, and its drop point on the ground at the foot of it. The house
## is what you are aiming at, so the target belongs under the house and not out on
## the road, where it would read as a spot in the middle of the street.
const HOUSE_FOOT: Vector2 = Vector2(0.62, 0.36)
const DROP: Vector2 = Vector2(0.62, 0.40)
## The stack of boxes left, counted off in the corner out of the throw's way.
const STACK_CORNER: Vector2 = Vector2(0.03, 0.97)


func _draw() -> void:
	if kind == DiagramKind.NONE:
		return
	_draw_street()
	match kind:
		DiagramKind.FLICK:
			_draw_flick()
		DiagramKind.CURVE:
			_draw_curve()
		DiagramKind.LAND:
			_draw_land()
		DiagramKind.STACK:
			_draw_stack()
		DiagramKind.ORDERS:
			_draw_orders()
		DiagramKind.FLAVOURS:
			_draw_flavours()
		DiagramKind.NONE:
			pass
## The scene every step shares: a night sky with a skyline behind it, the houses
## along the top with the pavement under them, and the road across the middle.
## Nothing converges, because you are not looking down the street but across it.
func _draw_street() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), sky)
	_draw_skyline()
	# Pavement behind, road in front of it, and a kerb line where they meet.
	draw_rect(Rect2(_at(0.0, HORIZON), Vector2(size.x, size.y * (1.0 - HORIZON))), ground)
	draw_rect(Rect2(_at(0.0, FAR_KERB), Vector2(size.x, size.y * (1.0 - FAR_KERB))), road)
	draw_line(_at(0.0, FAR_KERB), _at(1.0, FAR_KERB), road_edge, 2.0)
	# Lane paint runs along the street, left to right, which is the way the whole
	# world moves. Nothing about it tapers: no part of the road is nearer than another.
	_draw_lane(0.48, 0.035, 0.006)
	_draw_lane(0.68, 0.05, 0.010)
	# A row of them across the top, most of it scenery, one lit and waiting. Telling
	# those apart at a glance is the read the game asks for most often.
	_draw_house(Vector2(0.16, HORIZON + 0.08), false, 0.75)
	_draw_house(Vector2(0.92, HORIZON + 0.06), false, 0.7)
	if kind != DiagramKind.STACK:
		_draw_house(HOUSE_FOOT, true, 1.0)


## Two dim rows of blocks along the skyline, the near row a little taller than the
## far one. They are what tells the eye the street is being seen from the side.
func _draw_skyline() -> void:
	for row in 2:
		var shade := sky.lightened(0.10 - row * 0.04)
		var tall := 0.16 - row * 0.05
		var step := 0.13 + row * 0.02
		var x := -0.04 + row * 0.05
		while x < 1.0:
			var top := HORIZON - tall * (0.6 + fmod(x * 7.0, 0.8))
			draw_rect(Rect2(_at(x, top), Vector2(size.x * step * 0.8, size.y * (HORIZON - top))), shade)
			x += step


## One row of lane paint across the road, at depth [param y]. Dashes of a fixed
## size, because at this camera nothing on the road is nearer than anything else.
func _draw_lane(y: float, dash: float, thick: float) -> void:
	var x := 0.02
	while x < 1.0:
		draw_rect(Rect2(_at(x, y), Vector2(size.x * dash, size.y * thick)), lane_mark)
		x += dash * 2.4


## A house standing along the far pavement, positioned by the point where it meets
## the ground, as the street positions them. A waiting one is lit and has a drop
## point on the road in front of it; scenery is dark and has none. [param shrink]
## sets how far back it is: the street sends them past at different distances, and
## a smaller number is a house further away. Named as it is because `scale` is a
## Control's own property, and a parameter called that shadows it.
func _draw_house(foot: Vector2, waiting: bool, shrink: float) -> void:
	var base := _at(foot.x, foot.y)
	if house_art != null:
		if waiting:
			_draw_ring(DROP)
		_draw_building(base, waiting, shrink)
		return
	var px := size.x * 0.18 * shrink
	var wall_h := size.y * 0.24 * shrink
	var wall_rect := Rect2(base - Vector2(px * 0.5, wall_h), Vector2(px, wall_h))
	if waiting:
		_draw_ring(DROP)
	draw_rect(wall_rect, wall if waiting else wall.darkened(0.5))
	var apex := Vector2(base.x, wall_rect.position.y - size.y * 0.09 * shrink)
	draw_colored_polygon(PackedVector2Array([
		Vector2(wall_rect.position.x, wall_rect.position.y),
		Vector2(wall_rect.end.x, wall_rect.position.y), apex,
	]), roof if waiting else roof.darkened(0.5))
	if waiting:
		var win := Rect2(wall_rect.position + wall_rect.size * Vector2(0.3, 0.18), wall_rect.size * Vector2(0.4, 0.3))
		draw_rect(win, window_lit)


## One building off the sheet, standing on [param base], which is where it meets
## the ground exactly as the street places it.
##
## Which of the buildings it is comes from where it stands, so a row is not the same
## house three times over, and so it is the same house every time the page is
## drawn: a diagram that reshuffles itself on every redraw is a diagram nobody can
## point at.
##
## Waiting is drawn as the art is, scenery multiplied down. The game does this with
## a shader, three sets of parameters over one sprite; what matters to the page is
## only the outcome, that a house worth throwing at is bright and the rest of the
## street is not.
func _draw_building(base: Vector2, waiting: bool, shrink: float) -> void:
	var side := size.x * house_size * shrink
	var frame := absi(int(base.x)) % house_frames
	var sheet := house_art.get_size()
	var region := Rect2(Vector2(sheet.x / float(house_frames) * frame, 0.0),
		Vector2(sheet.x / float(house_frames), sheet.y))
	# Anchored at the foot: the sheet's frames stand on their bottom edge, which is
	# why the street can put a house on the pavement without knowing how tall it is.
	var where := Rect2(base - Vector2(side * 0.5, side), Vector2(side, side))
	draw_texture_rect_region(house_art, where, region, Color.WHITE if waiting else scenery_shade)


## The landing ring, lying flat on the road, so squashed into an ellipse.
func _draw_ring(centre: Vector2) -> void:
	var c := _at(centre.x, centre.y)
	var points := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		points.append(c + Vector2(cos(a) * size.x * 0.10, sin(a) * size.y * 0.035))
	draw_colored_polygon(points, ring)
	draw_polyline(points, Color(ring.r, ring.g, ring.b, 0.95), 3.0, true)


## The boxes still on the bike, counted off up the corner of the screen where they
## are out of the throw's way. This is the only pizza counter the game has.
## [param zoom] draws them bigger, which the stack step wants: there they are the
## subject rather than the corner of the picture. Not called `scale`, which is a
## Control's own property and would be shadowed by a parameter of that name.
func _draw_counter(left: int, thrown: int = 0, zoom: float = 1.0) -> void:
	for i in left:
		_draw_box(_box_slot(i, zoom), 1.0)
	# The ones already thrown, ghosted in the slots they came out of, so the counter
	# reads as something going down rather than a fixed pile of boxes.
	for i in thrown:
		_draw_box(_box_slot(left + i, zoom), 0.22)


## Where the [param i]th box up the stack sits, counting from the bottom.
func _box_slot(i: int, zoom: float) -> Rect2:
	var bar := Vector2(size.x * 0.13 * zoom, maxf(4.0, size.y * 0.026 * zoom))
	var corner := _at(STACK_CORNER.x, STACK_CORNER.y)
	return Rect2(Vector2(corner.x, corner.y - bar.y * (i + 1) * 1.5), bar)


## One box in the stack, the sprite if it is in, a bar in its colour if it is not.
func _draw_box(where: Rect2, alpha: float) -> void:
	if box_art != null:
		draw_texture_rect(box_art, where, false, Color(1.0, 1.0, 1.0, alpha))
	else:
		draw_rect(where, Color(pizza_rim.r, pizza_rim.g, pizza_rim.b, alpha))


## Drag the pizza and let go. The finger comes up the screen off the pizza, which is
## the throw: aim and power are one gesture, so the drawing has to be one arrow.
func _draw_flick() -> void:
	_draw_counter(4)
	_draw_pizza(IN_HAND, IN_HAND_RADIUS)
	# The finger, off to the side of the pizza and flicking up the screen. Drawn
	# beside it rather than across it, so the swipe and the flight stay two things.
	var from_px := _at(IN_HAND.x - 0.20, IN_HAND.y + 0.06)
	var to_px := _at(IN_HAND.x - 0.16, IN_HAND.y - 0.14)
	_dashed(from_px, to_px, gesture, 4.0)
	_arrow(to_px, (to_px - from_px).normalized(), gesture)
	draw_circle(from_px, size.x * 0.022, gesture)
	_arc(IN_HAND, Vector2(0.62, 0.22), DROP, gesture)


## Twist first and the flight bends, which is how a house off to one side is reached
## at all. The straight throw is drawn faint beside it, falling short.
func _draw_curve() -> void:
	_draw_counter(4)
	_draw_pizza(IN_HAND, IN_HAND_RADIUS)
	_spin_arrow(IN_HAND, IN_HAND_RADIUS + 0.03)
	# The bent throw comes round to the drop point. The straight one dies out on the
	# road, and short here means low, because up the screen is further away.
	_arc(IN_HAND, Vector2(0.24, 0.30), DROP, gesture)
	_arc(IN_HAND, Vector2(0.56, 0.70), Vector2(0.66, 0.78), Color(gesture.r, gesture.g, gesture.b, 0.28))


## The three things that can happen: into the ring, into the house, or neither.
## The first two both count, so both are ticked and only a throw that reaches
## nothing gets the cross — the rule the game plays, drawn rather than described.
func _draw_land() -> void:
	_draw_counter(4)
	_draw_pizza(IN_HAND, IN_HAND_RADIUS)
	_arc(IN_HAND, Vector2(0.62, 0.22), DROP, good)
	_tick(Vector2(0.44, 0.44), good)
	# Into the facade, ticked out to the side of it where the mark sits clear of the
	# lit window: the window is a target of its own and a tick on it would read as
	# the window being the only part that counts.
	_arc(IN_HAND, Vector2(0.60, 0.16), Vector2(0.56, 0.28), good)
	_tick(Vector2(0.76, 0.24), good)
	# The miss falls short onto the empty road, well left of the ring, with the splat
	# where it stopped. Neither mark may touch the ring or the house: a cross on
	# either would blame the two things the player is being told to aim at.
	_arc(IN_HAND, Vector2(0.34, 0.26), Vector2(0.30, 0.52), bad)
	_cross(Vector2(0.30, 0.62), bad)
	var splat := _at(0.30, 0.52)
	var splat_size := Vector2(size.x * 0.09, size.y * 0.07)
	if dropped_art != null:
		draw_texture_rect(dropped_art, Rect2(splat - splat_size * 0.5, splat_size), false)
	else:
		draw_rect(Rect2(splat - splat_size * 0.5, splat_size), pizza_rim)


## What is left: the boxes on the bike, and the strike dots along the top. The stack
## is the only pizza counter the game has, so it is worth a step of its own, and here
## it is drawn big rather than tucked in the corner.
func _draw_stack() -> void:
	_draw_dots(3, 1)
	_draw_counter(5, 2, 1.9)
	_draw_pizza(IN_HAND, IN_HAND_RADIUS)


## The one step nobody would find on their own: that a tap on the road, away from
## the pizza, changes what is on the next one.
##
## Three things and a line between two of them. The ticket says what the shop wants,
## the ripple says where to tap, and the arrow says which of the two the tap changes.
## Without the arrow the picture is a ticket and a finger with no relationship
## between them, which is exactly the thing the page has to establish.
func _draw_orders() -> void:
	_draw_ticket()
	# Well away from the pizza, because that is the whole rule: a touch near it takes
	# hold of it, and only one further off is read as a tap.
	var tap := Vector2(0.26, 0.66)
	_draw_tap(tap)
	_arc(tap, Vector2(0.34, 0.82), IN_HAND + Vector2(-IN_HAND_RADIUS * 1.5, 0.0), gesture)
	# The flavour the ticket's first line asks for, so the picture shows the tap
	# having already produced what was wanted.
	_draw_topped_pizza(IN_HAND, IN_HAND_RADIUS, topping_a, 8, 0.15, _flavour_art(0))


## The swap on its own: the tap, and the three flavours it turns the pizza through.
##
## Drawn as three pizzas in a row rather than one changing, because a still picture
## cannot show a thing becoming another thing, and a row says "these are what there
## are" — which is also the fact the page is short of. The one in hand is the middle
## of the three and full size; the other two are smaller and set back, so the row
## reads as a menu behind the pizza rather than three pizzas on the road.
##
## They differ by how many toppings and how big, not only by colour. Same reason as
## everywhere else: at the size a pizza flies at, hue alone tells a colour-blind
## player nothing.
func _draw_flavours() -> void:
	var small := IN_HAND_RADIUS * 0.62
	# Second and third on the menu to the sides, the first in hand, so the row is
	# the menu in its own order rather than three pizzas in no particular one.
	_draw_topped_pizza(Vector2(0.22, 0.72), small, topping_a, 8, 0.15, _flavour_art(1))
	_draw_topped_pizza(Vector2(0.78, 0.72), small, topping_b, 13, 0.1, _flavour_art(2))
	_draw_topped_pizza(IN_HAND, IN_HAND_RADIUS, topping_c, 5, 0.19, _flavour_art(0))
	# Well away from the pizza, because that is the whole rule: a touch near it takes
	# hold of it, and only one further off is read as a tap.
	var tap := Vector2(0.26, 0.6)
	_draw_tap(tap)
	_arc(tap, Vector2(0.34, 0.78), IN_HAND + Vector2(-IN_HAND_RADIUS * 1.5, 0.0), gesture)


## The ticket as it appears in the corner of the screen: two lines, each a flavour
## and a bar standing in for its wording, and the clock under them part run down.
##
## The flavour beside a line is the icon the real ticket uses, not the pizza: the
## ticket shows a small square rather than the box you throw, and a page that
## showed the box would have a player looking for something that is not there.
func _draw_ticket() -> void:
	var card := Rect2(_at(0.04, 0.05), Vector2(size.x * 0.42, size.y * 0.2))
	draw_rect(card, ticket_card)

	var lines := [
		{"colour": topping_a, "count": 8, "size": 0.055, "filled": 0.62},
		{"colour": topping_b, "count": 13, "size": 0.04, "filled": 0.34},
	]
	for i in lines.size():
		var line: Dictionary = lines[i]
		var y := 0.1 + i * 0.062
		_draw_topped_pizza(Vector2(0.09, y), 0.026, line["colour"], line["count"],
			line["size"], _flavour_icon(i))
		# A bar rather than words: the diagram is drawn without a font, and a row of
		# blocks reads as writing at this size anyway.
		var bar := Rect2(_at(0.135, y - 0.012),
			Vector2(size.x * 0.26 * line["filled"], size.y * 0.024))
		draw_rect(bar, ticket_row)

	# The clock, part gone, which is what makes an order a decision rather than a
	# list to work through at leisure.
	var track := Rect2(_at(0.06, 0.215), Vector2(size.x * 0.38, size.y * 0.018))
	draw_rect(track, ticket_row)
	draw_rect(Rect2(track.position, Vector2(track.size.x * 0.55, track.size.y)),
		ticket_clock)


## A finger's touch: the point, and two rings going out from it.
func _draw_tap(at: Vector2) -> void:
	var c := _at(at.x, at.y)
	var r := size.y * 0.03
	draw_circle(c, r, tap_ring)
	for ring_index in 2:
		var out := r * (1.9 + ring_index * 1.1)
		draw_arc(c, out, 0.0, TAU, 28,
			Color(tap_ring, tap_ring.a * (0.5 - ring_index * 0.2)), 4.0, true)


## The pizza with something on it. `spots` and `spot_size` are what tell one flavour
## from another, the same way the drawn ones did.
##
## `art` is the finished picture of that flavour. Given one, it is the whole pizza
## and nothing is drawn on top: the toppings are already in the picture, and a
## second set of dots over them would be the placeholder showing through the art
## meant to replace it.
func _draw_topped_pizza(at: Vector2, radius: float, spot: Color, spots: int,
		spot_size: float, art: Texture2D = null) -> void:
	if art != null:
		_draw_art(art, at, radius)
		return
	_draw_pizza(at, radius)
	var c := _at(at.x, at.y)
	var r := size.x * radius
	for i in spots:
		# The same golden-angle spiral PizzaFlavour lays its toppings out on, so the
		# page and the game deal the same pizza.
		var angle := float(i) * 2.399963
		var reach: float = 0.64 * sqrt((float(i) + 0.5) / float(spots))
		draw_circle(c + Vector2(cos(angle), sin(angle)) * r * reach, r * spot_size, spot)


## A picture centred on a point, square, sized by the same radius the drawn pizza
## uses so swapping one for the other does not change the layout around it.
func _draw_art(art: Texture2D, at: Vector2, radius: float) -> void:
	var c := _at(at.x, at.y)
	var r := size.x * radius
	draw_texture_rect(art, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)


## Which picture a flavour has, by its place on the menu. Empty slots and a short
## array both mean "not drawn yet", which is what makes the page survive art
## arriving one flavour at a time.
func _flavour_art(index: int) -> Texture2D:
	if index >= 0 and index < flavour_art.size() and flavour_art[index] != null:
		return flavour_art[index]
	return pizza_art


func _flavour_icon(index: int) -> Texture2D:
	if index >= 0 and index < flavour_icons.size() and flavour_icons[index] != null:
		return flavour_icons[index]
	return null


## The strike dots as the game shows them: clean, and crossed off once spent.
func _draw_dots(total: int, crossed: int) -> void:
	var r := size.y * 0.05
	for i in total:
		var c := _at(0.5 + (i - (total - 1) * 0.5) * 0.12, 0.12)
		if i < crossed:
			draw_line(c - Vector2(r, r), c + Vector2(r, r), spent, 5.0, true)
			draw_line(c - Vector2(r, -r), c + Vector2(r, -r), spent, 5.0, true)
		else:
			draw_circle(c, r, clean)


func _draw_pizza(at: Vector2, radius: float = IN_HAND_RADIUS) -> void:
	if pizza_art != null:
		_draw_art(pizza_art, at, radius)
		return
	var c := _at(at.x, at.y)
	var r := size.x * radius
	draw_circle(c, r, pizza)
	draw_arc(c, r, 0.0, TAU, 24, pizza_rim, maxf(3.0, r * 0.22), true)


## The wind-up: an arrow curling round the pizza, because a still picture has to
## say "turn this" somehow.
func _spin_arrow(at: Vector2, radius: float) -> void:
	var c := _at(at.x, at.y)
	var r := size.x * radius
	draw_arc(c, r, PI * 0.15, PI * 1.5, 24, gesture, 4.0, true)
	var end := c + Vector2(cos(PI * 1.5), sin(PI * 1.5)) * r
	_arrow(end, Vector2(cos(PI * 1.5 + PI * 0.5), sin(PI * 1.5 + PI * 0.5)), gesture)


## A flight path: a dashed curve from the hand, bending through [param control],
## ending in an arrowhead so it reads as a direction and not a wire.
func _arc(from: Vector2, control: Vector2, to: Vector2, colour: Color) -> void:
	var points := PackedVector2Array()
	for i in 25:
		var t := i / 24.0
		var p := _at(from.x, from.y).lerp(_at(control.x, control.y), t).lerp(
				_at(control.x, control.y).lerp(_at(to.x, to.y), t), t)
		points.append(p)
	# Every other segment, which is a dashed line without a dash pattern to set.
	for i in range(0, points.size() - 1, 2):
		draw_line(points[i], points[i + 1], colour, 4.0, true)
	var last := points[points.size() - 1]
	_arrow(last, (last - points[points.size() - 3]).normalized(), colour)


func _tick(at: Vector2, colour: Color) -> void:
	var c := _at(at.x, at.y)
	var r := size.y * 0.045
	draw_line(c + Vector2(-r, 0.0), c + Vector2(-r * 0.2, r * 0.7), colour, 6.0, true)
	draw_line(c + Vector2(-r * 0.2, r * 0.7), c + Vector2(r, -r * 0.8), colour, 6.0, true)


func _cross(at: Vector2, colour: Color) -> void:
	var c := _at(at.x, at.y)
	var r := size.y * 0.04
	draw_line(c - Vector2(r, r), c + Vector2(r, r), colour, 6.0, true)
	draw_line(c - Vector2(r, -r), c + Vector2(r, -r), colour, 6.0, true)


func _arrow(at: Vector2, dir: Vector2, colour: Color) -> void:
	if dir.length() < 0.001:
		return
	var d := dir.normalized()
	var side := Vector2(-d.y, d.x)
	var l := size.y * 0.035
	draw_colored_polygon(PackedVector2Array([
		at + d * l, at - d * l * 0.4 + side * l * 0.5, at - d * l * 0.4 - side * l * 0.5,
	]), colour)


func _dashed(from: Vector2, to: Vector2, colour: Color, width: float) -> void:
	var steps := 12
	for i in range(0, steps, 2):
		var a := from.lerp(to, i / float(steps))
		var b := from.lerp(to, (i + 1) / float(steps))
		draw_line(a, b, colour, width, true)


func _at(x: float, y: float) -> Vector2:
	return Vector2(x * size.x, y * size.y)
