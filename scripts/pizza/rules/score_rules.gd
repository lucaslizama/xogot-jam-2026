class_name ScoreRules
extends Resource

## What a delivery is worth, and how much better a good one is than a lucky one.
##
## Before this, a throw either counted or it did not, which meant a pizza dropped
## dead centre and one that scraped the wall on its way down were the same result.
## The flight already knows how close it came; this turns that into something the
## player can feel, and into a number worth beating.
##
## Everything here is a value, not a rule of the game, so it all belongs in the
## editor. Change what a tier is worth without opening a script.

## How well a delivery went. Prefixed rather than named Tier, because a bare name
## in a class can collide with a built-in global enum and the class then fails to
## compile with nothing to say why.
enum ThrowTier {
	## Dead centre of the drop point.
	BULLSEYE,
	## Somewhere in the ring.
	NICE,
	## Into the house itself. It counts, and it is the easiest way to score, so it
	## is worth the least.
	SCRAPED,
	## Clean through the lit window. Added last rather than in its proper place in
	## the order, so the numbers behind the other three do not shift under any
	## saved resource that recorded one.
	WINDOW,
}

@export_group("What counts as dead centre")
## How much of the drop point's radius counts as a bullseye. At 0.35 the middle
## third or so of the ring is the sweet spot, which is small enough to feel earned
## and large enough to hit on purpose.
@export_range(0.05, 1.0, 0.01) var bullseye_fraction: float = 0.35

@export_group("What each is worth")
## Deliberately big numbers. A tip of 30 reads as small change and lands with no
## weight; the same throw paying 300 reads as a reward, and a long run ending in
## the thousands is worth telling someone about. Nothing else depends on the
## scale, so it can be pushed further without anything having to keep up.
## Through the window pays most. It asks for a throw that is both long enough to
## reach the wall and tight enough to find a target a fifth of its width, which is
## two kinds of accuracy at once where the drop point asks for one.
@export_range(0, 5000, 10) var tip_window: int = 800
@export_range(0, 5000, 10) var tip_bullseye: int = 500
@export_range(0, 5000, 10) var tip_nice: int = 300
@export_range(0, 5000, 10) var tip_scraped: int = 150

@export_group("Streak")
## How many deliveries in a row before a streak starts paying. Two, so the bonus
## is for keeping something going rather than for a single lucky throw.
@export_range(2, 10) var streak_starts_at: int = 2
## What each delivery past that adds to the multiplier.
@export_range(0.0, 1.0, 0.01) var streak_step: float = 0.15
## The most a streak can multiply by, so a long run does not run away with the
## score and make everything before it meaningless.
@export_range(1.0, 10.0, 0.1) var streak_cap: float = 2.5

@export_group("Wording")
## One of these is picked at random each time, so the same throw twice running
## does not say the same thing twice and the street keeps a bit of a voice. Add a
## line and it joins the rotation; leave one entry and it never varies.
@export var labels_window: PackedStringArray = [
	"Through the window!", "Straight in!", "Room service!", "Right on the table!",
]
@export var labels_bullseye: PackedStringArray = [
	"Bullseye!", "Right on the mat!", "Perfect drop!", "Nailed it!",
]
@export var labels_nice: PackedStringArray = [
	"Nice!", "Good throw", "Tidy", "That'll do",
]
@export var labels_scraped: PackedStringArray = [
	"Off the wall", "Scraped it", "Close enough", "They'll find it",
]
## Shown under the tier once a streak is paying. %d is how many in a row.
@export var label_streak: String = "%d in a row"
## The tip that throw earned. %d is the amount. The currency is written here
## rather than drawn anywhere, so a street somewhere else spends something else.
@export var label_tip: String = "+$%d"
## The running total. %d is the amount.
@export var label_total: String = "$%d"
## Said when a streak worth having is broken, in place of a tier. Empty says
## nothing, which is the kinder option if it starts to feel like nagging.
@export var label_streak_lost: String = "Streak lost"


## Which tier a delivery earned. `miss` is how far from the drop point it landed;
## a throw that hit the house rather than the ring has no meaningful miss and is
## passed `scraped` instead.
func tier_for(miss: float, drop_radius: float, scraped: bool) -> ThrowTier:
	if scraped:
		return ThrowTier.SCRAPED
	if miss <= drop_radius * bullseye_fraction:
		return ThrowTier.BULLSEYE
	return ThrowTier.NICE


func tip_for(tier: ThrowTier) -> int:
	match tier:
		ThrowTier.WINDOW:
			return tip_window
		ThrowTier.BULLSEYE:
			return tip_bullseye
		ThrowTier.NICE:
			return tip_nice
		_:
			return tip_scraped


## One of the things this tier might say. Empty wording says nothing rather than
## putting a blank box over the street.
func label_for(tier: ThrowTier) -> String:
	var choices: PackedStringArray = labels_scraped
	match tier:
		ThrowTier.WINDOW:
			choices = labels_window
		ThrowTier.BULLSEYE:
			choices = labels_bullseye
		ThrowTier.NICE:
			choices = labels_nice
	if choices.is_empty():
		return ""
	return choices[randi() % choices.size()]


## What a run of `streak` deliveries multiplies a tip by. One until the streak is
## long enough to pay, then rising a step at a time up to the cap.
func multiplier_for(streak: int) -> float:
	if streak < streak_starts_at:
		return 1.0
	return minf(streak_cap, 1.0 + float(streak - streak_starts_at + 1) * streak_step)


## What a delivery at this tier, at this point in a run, is actually worth.
func award_for(tier: ThrowTier, streak: int) -> int:
	return int(round(float(tip_for(tier)) * multiplier_for(streak)))


## True once a streak is long enough that losing it is worth saying out loud.
func streak_is_paying(streak: int) -> bool:
	return streak >= streak_starts_at
