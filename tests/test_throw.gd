extends Node

# Checks the throw maths without drawing anything. Run with:
#   godot-4.6 --headless res://tests/test_throw.tscn

var _failures: Array[String] = []
var _checks: int = 0

## The floor under the check count. See [method _report].
const EXPECTED: int = 73

const STEP: float = 1.0 / 120.0


func _ready() -> void:
	var per_test := {}
	for test in _tests():
		var before := _checks
		test.call()
		per_test[test.get_method()] = _checks - before
	_report(per_test)


## Every test, in the order they run. A list rather than a run of calls so the
## runner can see what each one contributed; see [method _report].
func _tests() -> Array[Callable]:
	return [
		_test_harder_flick_goes_further,
		_test_power_is_clamped,
		_test_aim_leans_the_right_way,
		_test_spin_curves_the_flight,
		_test_the_arc_holds_its_shape,
		_test_straight_drag_has_no_windup,
		_test_hooked_flick_has_windup,
		_test_circling_beats_hooking,
		_test_windup_survives_a_fast_sampling_device,
		_test_up_and_down_loads_no_spin,
		_test_idle_wobble_loads_no_spin,
		_test_wind_up_runs_down_when_the_finger_stops,
		_test_a_throw_begins_where_it_was_let_go,
		_test_preview_matches_the_real_flight,
		_test_preview_is_bounded,
		_test_projection_shrinks_with_distance,
		_test_projection_ground_meets_horizon,
	]



# --- flight -----------------------------------------------------------------

func _test_harder_flick_goes_further() -> void:
	var soft := _land(_flick(900.0), 0.0)
	var hard := _land(_flick(4200.0), 0.0)
	_check("a harder flick lands further up the street (%.1f vs %.1f)" % [soft.distance, hard.distance],
		hard.distance > soft.distance * 1.5)


func _test_power_is_clamped() -> void:
	var ceiling := PizzaPhysics.new().full_power_flick
	var feeble := _land(_flick(1.0), 0.0)
	var absurd := _land(_flick(500000.0), 0.0)
	var full := _land(_flick(ceiling), 0.0)
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


## The arc has to hold its shape for the whole flight rather than straightening
## out near the end, and it has to curve the same way throughout. What would be
## unusable is a curve that tightens without bound or doubles back.
func _test_the_arc_holds_its_shape() -> void:
	var tuning := PizzaPhysics.new()
	for share in [0.66, 0.8, 1.0]:
		var flick: float = tuning.full_power_flick * share
		var flight := PizzaFlight.new(tuning, tuning.launch_from(_flick(flick), 99.0))
		var trail: Array[float] = []
		while not flight.step(STEP):
			trail.append(flight.side)
		if trail.size() < 9:
			_check("a throw at %.0f px/s lasted long enough to sample" % flick, false)
			continue

		var third: int = trail.size() / 3
		var first: float = trail[third] - trail[0]
		var middle: float = trail[third * 2] - trail[third]
		var last: float = trail[trail.size() - 1] - trail[third * 2]

		_check("at %.0f px/s the arc keeps opening rather than straightening (%.2f, %.2f, %.2f)"
				% [flick, first, middle, last], first < middle and middle < last)
		_check("at %.0f px/s it opens at a steady rate, not tightening away (last %.2f vs middle %.2f)"
				% [flick, last, middle], last < middle * 1.8)

		var reversed := false
		for i in range(1, trail.size()):
			if trail[i] < trail[i - 1] - 0.0001:
				reversed = true
		_check("at %.0f px/s the curve never doubles back" % flick, not reversed)


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


## Dragging the pizza straight up and down reverses direction, and a reversal
## reads as a half turn in a single reading, with the sign decided by a pixel of
## sideways noise. That banked random wind-up and made the pizza jump.
func _test_up_and_down_loads_no_spin() -> void:
	var t := PizzaPhysics.new()
	for noisy in [false, true]:
		var g := ThrowGesture.new()
		var at := Vector2(600.0, 1600.0)
		g.begin(at, 0.0)
		var time := 0.0
		for sweep in 6:
			var dir: float = -1.0 if sweep % 2 == 0 else 1.0
			for i in 60:
				time += 1.0 / 120.0
				var wobble: float = sin(time * 91.7) * 1.5 if noisy else 0.0
				g.update(at + Vector2(wobble, dir * float(i) * 6.0), time)
			at += Vector2(0.0, dir * 354.0)
		_check("six up-and-down sweeps%s load no spin (windup %.2f rad)"
				% [" with a wobbling thumb" if noisy else "", g.windup()],
			is_zero_approx(t.spin_from(g.windup())))

	# The fix must not have deafened the recogniser to real circling.
	var circle := ThrowGesture.new()
	var centre := Vector2(600.0, 1200.0)
	circle.begin(centre + Vector2(130.0, 0.0), 0.0)
	var clock := 0.0
	for i in range(1, 241):
		var a: float = TAU * float(i) / 240.0
		clock += 1.0 / 120.0
		circle.update(centre + Vector2(cos(a), sin(a)) * 130.0, clock)
	_check("a genuine circle still winds fully (spin %.2f)" % t.spin_from(circle.windup()),
		is_equal_approx(t.spin_from(circle.windup()), 1.0))


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


## A finger that stops circling should watch the spin run down, not hold it
## forever off one flick of the wrist. And the wind-up must be capped, or the
## surplus has to drain before anything visibly changes.
func _test_wind_up_runs_down_when_the_finger_stops() -> void:
	var t := PizzaPhysics.new()
	var g := ThrowGesture.new()
	var centre := Vector2(600.0, 1200.0)
	g.begin(centre + Vector2(130.0, 0.0), 0.0)
	var time := 0.0
	for i in range(1, 81):                      # two full circles
		var a: float = TAU * float(i) / 40.0
		time += 1.0 / 120.0
		g.update(centre + Vector2(cos(a), sin(a)) * 130.0, time)

	g.limit(t.full_spin_windup * 1.25)
	_check("wind-up is capped rather than banking every turn (got %.2f rad)" % g.windup(),
		absf(g.windup()) <= t.full_spin_windup * 1.25 + 0.01)
	_check("and is still fully wound at the cap (spin %.2f)" % t.spin_from(g.windup()),
		is_equal_approx(t.spin_from(g.windup()), 1.0))

	# One second of a still finger, bled a sixtieth at a time.
	var trail: Array[float] = []
	for frame in 90:
		g.bleed(t.windup_bleed / 60.0)
		trail.append(t.spin_from(g.windup()))
	_check("the spin falls rather than holding (%.2f -> %.2f)" % [trail[0], trail[trail.size() - 1]],
		trail[trail.size() - 1] < trail[0])
	_check("it reaches nothing within a second and a half (got %.2f)" % trail[trail.size() - 1],
		is_zero_approx(trail[trail.size() - 1]))
	var monotonic := true
	for i in range(1, trail.size()):
		if trail[i] > trail[i - 1] + 0.001:
			monotonic = false
	_check("and falls smoothly the whole way, never rising", monotonic)


# --- the aim preview --------------------------------------------------------

## The preview is only honest if it is produced by the same maths that flies.
## A pizza held up the screen leaves from up there. Without this the flight always
## began at the rider's own release height, so letting go anywhere but low down
## made the pizza appear to drop to the bottom of the screen before setting off.
func _test_a_throw_begins_where_it_was_let_go() -> void:
	var tuning := PizzaPhysics.new()
	var from_the_hand := PizzaFlight.new(tuning, tuning.launch_from(_flick(3000.0), 0.0))
	_check("a throw with nothing said starts at the rider's release height (%.1f)"
			% from_the_hand.height,
		is_equal_approx(from_the_hand.height, tuning.release_height))

	var launch: Dictionary = tuning.launch_from(_flick(3000.0), 0.0)
	launch["start_height"] = 30.0
	var from_up_high := PizzaFlight.new(tuning, launch)
	_check("one told where it was starts there (%.1f)" % from_up_high.height,
		is_equal_approx(from_up_high.height, 30.0))

	var low := _fly(from_the_hand)
	var high := _fly(from_up_high)
	_check("and being higher keeps it up longer, so it goes further (%.1f vs %.1f)"
			% [low.distance, high.distance],
		high.distance > low.distance)
	_check("both still come down (%.2f, %.2f)" % [low.height, high.height],
		low.has_landed() and high.has_landed())


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
	return _fly(PizzaFlight.new(tuning, tuning.launch_from(flick, windup)))


## Run a flight already built, for when the launch needed something said to it.
func _fly(flight: PizzaFlight) -> PizzaFlight:
	var guard := 0
	while not flight.has_landed() and guard < 100000:
		flight.step(STEP)
		guard += 1
	return flight


func _check(what: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures.append(what)


## Say how it went, and refuse to call a short run a good one.
##
## A GDScript error inside a test kills the rest of that test and nothing else:
## the run carries on, the summary prints, and the only trace is a check count
## that quietly dropped. That happened three times in one afternoon and was
## noticed each time by eye. So the count is held to a floor, and a test that
## made no checks at all is named.
##
## Raise EXPECTED in the same commit that adds checks. Lowering it is a decision,
## not a tidy-up: it means checks that used to run no longer do.
func _report(per_test: Dictionary) -> void:
	print("\n=== %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAIL  ", f)

	var silent := PackedStringArray()
	for name in per_test:
		if per_test[name] == 0:
			silent.append(name)
	var short := _checks < EXPECTED
	if short:
		print("  SHORT  %d checks, expected at least %d. A test died part way and"
			% [_checks, EXPECTED])
		print("         took its remaining checks with it. Per test:")
		for name in per_test:
			print("           %-56s %d" % [name, per_test[name]])
	for name in silent:
		print("  SILENT  %s made no checks at all" % name)

	if _failures.is_empty() and not short and silent.is_empty():
		print("  all good")
	get_tree().quit(1 if _failures.size() > 0 or short or not silent.is_empty() else 0)
