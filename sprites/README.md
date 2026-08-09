Art goes here.

Each piece drops into a slot that is already waiting for it, and the coloured
rectangle it replaces disappears by itself. See docs/art-brief.md for the list
and the sizes.

To place one: open the scene the piece belongs to, select its node, and drop the
image into the empty texture slot in the inspector. Houses have three, one for
each state, plus one for the drop point.

The how-to-play steps live in `scenes/ui/how_to_play.tscn`. Select a step —
Flick, Curve, Land, Stack — and its picture, its note and its caption are all on
that one node. A moving step is a strip of frames in the same slot with
`frame_count` set; see the art brief.
