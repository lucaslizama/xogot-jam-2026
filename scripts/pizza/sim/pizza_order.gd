class_name PizzaOrder
extends RefCounted

## One ticket: a few flavours, how many of each, and how long there is to deliver
## them.
##
## Only ever counts and a clock. It does not know what a house is, what a throw is
## or what it is worth beyond the number it was told, which is what lets the whole
## thing be tested with no screen and no street.

## The flavours asked for, one entry each and no repeats: three pepperoni is one
## line saying three, not three lines saying one.
var wants: Array[PizzaFlavour] = []
## How many of each are wanted, and how many have arrived. Kept alongside [member
## wants] rather than inside it so a line is read as one index across three arrays.
var needed := PackedInt32Array()
var done := PackedInt32Array()

var seconds_left: float = 0.0
var seconds_total: float = 0.0
## What filling it pays, copied off the rules when it was written so a rules file
## edited mid-street cannot change what an open ticket promised.
var pays: int = 0
var gives_strike_back: bool = false


func line_count() -> int:
	return wants.size()


## What one line is asking for. Returns needed and done as a pair so a caller
## drawing the ticket does not have to index three arrays itself.
func line(index: int) -> Vector2i:
	if index < 0 or index >= needed.size():
		return Vector2i.ZERO
	return Vector2i(needed[index], done[index])


func line_is_filled(index: int) -> bool:
	var counts := line(index)
	return counts.y >= counts.x and counts.x > 0


func is_filled() -> bool:
	for i in needed.size():
		if done[i] < needed[i]:
			return false
	return not needed.is_empty()


func has_run_out() -> bool:
	return seconds_left <= 0.0


## How much of the clock is left, 1 at the start and 0 when it is gone. What the
## bar on the ticket draws.
func fraction_left() -> float:
	if seconds_total <= 0.0:
		return 0.0
	return clampf(seconds_left / seconds_total, 0.0, 1.0)


## Count a delivery against the ticket. True if this one was wanted and was still
## wanted; false for a flavour the ticket never asked for, and false for a line
## already full, so an extra pepperoni cannot fill the hawaiian line.
func take(flavour: PizzaFlavour) -> bool:
	if flavour == null:
		return false
	for i in wants.size():
		if wants[i] == flavour and done[i] < needed[i]:
			done[i] += 1
			return true
	return false


## Everything asked for and everything arrived, across all lines. For a caller that
## wants to say "2 of 3" about the whole ticket rather than line by line.
func total_needed() -> int:
	var sum := 0
	for n in needed:
		sum += n
	return sum


func total_done() -> int:
	var sum := 0
	for d in done:
		sum += d
	return sum
