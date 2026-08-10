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
}

@export_group("What counts as dead centre")
## How much of the drop point's radius counts as a bullseye. At 0.35 the middle
## third or so of the ring is the sweet spot, which is small enough to feel earned
## and large enough to hit on purpose.
@export_range(0.05, 1.0, 0.01) var bullseye_fraction: float = 0.35

@export_group("What each is worth")
@export_range(0, 500, 5) var tip_bullseye: int = 50
@export_range(0, 500, 5) var tip_nice: int = 30
@export_range(0, 500, 5) var tip_scraped: int = 15

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
@export var label_bullseye: String = "Bullseye!"
@export var label_nice: String = "Nice!"
@export var label_scraped: String = "Scraped it"
## Shown under the tier once a streak is paying. %d is how many in a row.
@export var label_streak: String = "%d in a row"
## The tip that throw earned. %d is the amount.
@export var label_tip: String = "+%d"
## The running total. %d is the amount.
@export var label_total: String = "%d"
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
		ThrowTier.BULLSEYE:
			return tip_bullseye
		ThrowTier.NICE:
			return tip_nice
		_:
			return tip_scraped


func label_for(tier: ThrowTier) -> String:
	match tier:
		ThrowTier.BULLSEYE:
			return label_bullseye
		ThrowTier.NICE:
			return label_nice
		_:
			return label_scraped


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
