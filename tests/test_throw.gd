extends Node

# Checks the throw maths without drawing anything. Run with:
#   godot-4.6 --headless res://tests/test_throw.tscn

var _failures: Array[String] = []
var _checks: int = 0

const STEP: float = 1.0 / 120.0


func _ready() -> void:
	_test_harder_flick_goes_further()
	_test_power_is_clamped()
	_test_aim_leans_the_right_way()
	_test_spin_curves_the_flight()
	_test_spin_bends_early_not_late()
	_test_straight_drag_has_no_windup()
	_test_hooked_flick_has_windup()
	_test_circling_beats_hooking()
	_test_windup_survives_a_fast_sampling_device()
	_test_idle_wobble_loads_no_spin()
	_test_preview_matches_the_real_flight()
	_test_preview_is_bounded()
	_test_projection_shrinks_with_distance()
	_test_projection_ground_meets_horizon()

	print("\n=== %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAIL  ", f)
	if _failures.is_empty():
		print("  all good")
	get_tree().quit(1 if _failures.size() > 0 else 0)


# --- flight -----------------------------------------------------------------

func _test_harder_flick_goes_further() -> void:
	var soft := _land(_flick(900.0), 0.0)
	var hard := _land(_flick(4200.0), 0.0)
	_check("a harder flick lands further up the street (%.1f vs %.1f)" % [soft.distance, hard.distance],
		hard.distance > soft.distance * 1.5)


func _test_power_is_clamped() -> void:
	var feeble := _land(_flick(1.0), 0.0)
	var absurd := _land(_flick(500000.0), 0.0)
	var full := _land(_flick(4200.0), 0.0)
	_check("a nervous flick still leaves the bike (got %.2f)" % feeble.distance, feeble.distance > 0.5)
	_check("an absurd flick is capped at full power (%.2f vs %.2f)" % [absurd.distance, full.distance],
		absurd.distance <= full.distance + 0.01)


func _test_aim_leans_the_right_way() -> void:
	var left := _land(Vector2(-2000.0, -3000.0), 0.0)
	var straight := _land(_flick(3000.0), 0.0)
	var right := _land(Vector2(2000.0, -3000.0), 0.0)
	_check("a straight flick lands on the rider's line (got %.3f)" % straight.side, absf(straight.side) < 0.01)
	_check("leaning the flick left lands left (got %.2f)" % left.side, left.side < -1.0)
	_check("leaning the flick right lands right (got %.2f)" % right.side, right.side > 1.0)


func _test_spin_curves_the_flight() -> void:
	var straight := _land(_flick(3000.0), 0.0)
	var curved := _land(_flick(3000.0), 7.5)
	var other := _land(_flick(3000.0), -7.5)
	_check("spin pushes the pizza off the straight line (got %.2f)" % curved.side, curved.side > 1.0)
	_check("opposite spin curves the other way (got %.2f)" % other.side, other.side < -1.0)
	_check("no spin means no drift (got %.3f)" % straight.side, absf(straight.side) < 0.01)


## A curve must banana out and then settle into a straight diagonal. If the
## drift kept accelerating to the end it would be a spiral, and unaimable.
func _test_spin_bends_early_not_late() -> void:
	var tuning := PizzaPhysics.new()
	var flight := PizzaFlight.new(tuning, tuning.launch_from(_flick(3000.0), 7.5))
	var trail: Array[float] = []
	while not flight.step(STEP):
		trail.append(flight.side)
	if trail.size() < 9:
		_check("curved flight lasted long enough to sample (%d steps)" % trail.size(), false)
		return

	var third: int = trail.size() / 3
	var first: float = trail[third] - trail[0]
	var middle: float = trail[third * 2] - trail[third]
	var last: float = trail[trail.size() - 1] - trail[third * 2]

	_check("the curve is still building over the first third (%.2f vs %.2f)" % [first, middle],
		first < middle)
	_check("the curve has settled by the end, not spiralling (middle %.2f vs last %.2f)" % [middle, last],
		absf(last - middle) < middle * 0.35)


# --- gesture ----------------------------------------------------------------

func _test_straight_drag_has_no_windup() -> void:
	var g := ThrowGesture.new()
	g.begin(Vector2(500.0, 2000.0), 0.0)
	for i in range(1, 21):
		g.update(Vector2(500.0, 2000.0 - i * 40.0), i * 0.01)
	g.release(Vector2(500.0, 1200.0), 0.21)
	_check("a straight drag winds up nothing (got %.4f rad)" % g.windup(), absf(g.windup()) < 0.05)


func _test_hooked_flick_has_windup() -> void:
	var g := ThrowGesture.new()
	g.begin(Vector2(500.0, 2000.0), 0.0)
	# Straight up, then bending right: a hook.
	for i in range(1, 11):
		g.update(Vector2(500.0, 2000.0 - i * 40.0), i * 0.01)
	for i in range(1, 11):
		g.update(Vector2(500.0 + i * i * 4.0, 1600.0 - i * 40.0), 0.1 + i * 0.01)
	g.release(Vector2(900.0, 1200.0), 0.21)
	_check("a hooked flick winds up some spin (got %.3f rad)" % g.windup(), g.windup() > 0.2)


func _test_circling_beats_hooking() -> void:
	var hook := ThrowGesture.new()
	hook.begin(Vector2(500.0, 2000.0), 0.0)
	for i in range(1, 11):
		hook.update(Vector2(500.0 + i * i * 4.0, 2000.0 - i * 40.0), i * 0.01)
	hook.release(Vector2(900.0, 1600.0), 0.11)

	# Start on the circle, not at its centre, and release without leaving it:
	# a stray first or last segment adds turning that is the fixture's fault,
	# not the recogniser's.
	var circle := ThrowGesture.new()
	var centre := Vector2(500.0, 2000.0)
	var on_circle := func(i: int) -> Vector2:
		return centre + Vector2(cos(TAU * float(i) / 24.0), sin(TAU * float(i) / 24.0)) * 90.0
	circle.begin(on_circle.call(0), 0.0)
	var time := 0.0
	for i in range(1, 49):
		time += 0.005
		circle.update(on_circle.call(i), time)
	circle.release(on_circle.call(48), time + 0.005)

	_check("two circles wind up more than a hook (%.2f vs %.2f rad)" % [circle.windup(), hook.windup()],
		absf(circle.windup()) > absf(hook.windup()) * 2.0)
	_check("two circles land near two full turns (got %.2f rad)" % circle.windup(),
		absf(absf(circle.windup()) - 2.0 * TAU) < 1.0)


## A 120 Hz phone reports touch in steps of a couple of pixels. Reading the
## direction between consecutive samples made those steps pure noise, and
## discarding them as noise threw away the whole gesture: circling the pizza on
## a real device produced no wind-up at all while a coarse test passed happily.
## The reading must not depend on how often the device reports.
func _test_windup_survives_a_fast_sampling_device() -> void:
	var readings: Array[float] = []
	for samples_per_turn in [24, 60, 240, 480]:
		var g := ThrowGesture.new()
		var centre := Vector2(600.0, 1200.0)
		g.begin(centre + Vector2(130.0, 0.0), 0.0)
		var time := 0.0
		for i in range(1, samples_per_turn + 1):
			var a: float = TAU * float(i) / float(samples_per_turn)
			time += 1.0 / 120.0
			g.update(centre + Vector2(cos(a), sin(a)) * 130.0, time)
		readings.append(g.windup())

	for i in readings.size():
		_check("one circle reads as a full turn at %d samples (got %.2f rad)"
				% [[24, 60, 240, 480][i], readings[i]],
			absf(absf(readings[i]) - TAU) < 0.5)
	var spread: float = readings.max() - readings.min()
	_check("and reads the same however fast the device samples (spread %.2f rad)" % spread,
		spread < 0.4)


## Carrying the pizza around racks up small turns that were never an attempt to
## curve anything. Below the deadzone they must count for nothing.
func _test_idle_wobble_loads_no_spin() -> void:
	var t := PizzaPhysics.new()
	for wobble in [0.2, 0.6, 1.0, -0.9]:
		_check("a wobble of %.1f rad loads no spin (got %.3f)" % [wobble, t.spin_from(wobble)],
			is_zero_approx(t.spin_from(wobble)))
	_check("deliberate winding still reaches full spin (got %.2f)" % t.spin_from(t.full_spin_windup),
		is_equal_approx(t.spin_from(t.full_spin_windup), 1.0))
	_check("and the other way round (got %.2f)" % t.spin_from(-t.full_spin_windup),
		is_equal_approx(t.spin_from(-t.full_spin_windup), -1.0))
	var half := t.spin_deadzone + (t.full_spin_windup - t.spin_deadzone) * 0.5
	_check("halfway past the deadzone is half spin (got %.2f)" % t.spin_from(half),
		absf(t.spin_from(half) - 0.5) < 0.01)


# --- the aim preview --------------------------------------------------------

## The preview is only honest if it is produced by the same maths that flies.
func _test_preview_matches_the_real_flight() -> void:
	var tuning := PizzaPhysics.new()
	for spin in [0.0, 6.0, -6.0]:
		for speed in [1200.0, 2400.0, 3600.0]:
			var launch := tuning.launch_from(_flick(speed), spin)
			var path := PizzaFlight.trace(tuning, launch)
			var flown := PizzaFlight.new(tuning, launch)
			while not flown.step(1.0 / 120.0):
				pass
			var predicted := path[path.size() - 1]
			var gap := Vector2(predicted.x - flown.side, predicted.z - flown.distance).length()
			_check("preview landing matches the flown one at flick %.0f spin %.0f (off by %.3f)"
					% [speed, spin, gap], gap < 0.05)
			_check("preview ends on the ground at flick %.0f spin %.0f (height %.3f)"
					% [speed, spin, predicted.y], absf(predicted.y) < 0.01)


func _test_preview_is_bounded() -> void:
	var tuning := PizzaPhysics.new()
	var path := PizzaFlight.trace(tuning, tuning.launch_from(_flick(4200.0), 0.0), 26)
	_check("the preview has enough points to draw an arc (got %d)" % path.size(), path.size() >= 8)
	_check("and is capped so a long throw is not a thousand points (got %d)" % path.size(),
		path.size() <= 26)


# --- projection -------------------------------------------------------------

func _test_projection_shrinks_with_distance() -> void:
	var p := StreetProjection.new()
	_check("nothing is shrunk at the rider (got %.4f)" % p.scale_at(0.0), is_equal_approx(p.scale_at(0.0), 1.0))
	_check("further is smaller (%.3f vs %.3f)" % [p.scale_at(10.0), p.scale_at(60.0)],
		p.scale_at(60.0) < p.scale_at(10.0))
	_check("very far is nearly nothing (got %.4f)" % p.scale_at(100000.0), p.scale_at(100000.0) < 0.01)


func _test_projection_ground_meets_horizon() -> void:
	var p := StreetProjection.new()
	var near := p.project(0.0, 0.0, 0.0)
	var far := p.project(0.0, 0.0, 100000.0)
	_check("ground at the rider sits on the near row (got %.1f)" % near.y, is_equal_approx(near.y, p.near_ground_y))
	_check("ground far away converges on the horizon (got %.1f, want %.1f)" % [far.y, p.horizon_y],
		absf(far.y - p.horizon_y) < 1.0)
	_check("a point on the rider's line is centred (got %.1f)" % near.x, is_equal_approx(near.x, p.centre_x))
	var offset := p.project(5.0, 0.0, 0.0)
	var offset_far := p.project(5.0, 0.0, 80.0)
	_check("the same sideways offset is narrower when far (%.1f vs %.1f)"
			% [offset.x - p.centre_x, offset_far.x - p.centre_x],
		absf(offset_far.x - p.centre_x) < absf(offset.x - p.centre_x))


# --- helpers ----------------------------------------------------------------

func _flick(speed: float) -> Vector2:
	return Vector2(0.0, -speed)


func _land(flick: Vector2, windup: float) -> PizzaFlight:
	var tuning := PizzaPhysics.new()
	var flight := PizzaFlight.new(tuning, tuning.launch_from(flick, windup))
	var guard := 0
	while not flight.has_landed() and guard < 100000:
		flight.step(STEP)
		guard += 1
	return flight


func _check(what: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures.append(what)
