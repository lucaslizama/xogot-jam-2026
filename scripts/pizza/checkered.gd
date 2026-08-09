class_name Checkered
extends RefCounted

## The pizzeria tablecloth, drawn once and shared. Both the result button and the
## street badge ring their edge with the same red-and-white checks; keeping the
## drawing here means the two can never drift apart.


## Fill the rect, then lay one check-thick ring of red/white squares around its
## edge. [param dim] multiplies every colour, so a caller can darken on press or
## lift on hover without knowing how the checks are laid out.
static func draw(ci: CanvasItem, area: Vector2, check_size: float, fill: Color,
		a: Color, b: Color, dim: float = 1.0) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, area), _shade(fill, dim))
	if check_size <= 0.0:
		return
	var da := _shade(a, dim)
	var db := _shade(b, dim)
	var cols := int(ceil(area.x / check_size))
	var rows := int(ceil(area.y / check_size))
	var bounds := Rect2(Vector2.ZERO, area)
	for c in cols:
		for r in rows:
			# Only the outermost ring of checks; the middle stays fill.
			if c != 0 and c != cols - 1 and r != 0 and r != rows - 1:
				continue
			var cell := Rect2(c * check_size, r * check_size, check_size, check_size).intersection(bounds)
			ci.draw_rect(cell, da if (c + r) % 2 == 0 else db)


static func _shade(c: Color, dim: float) -> Color:
	return Color(c.r * dim, c.g * dim, c.b * dim, c.a)
