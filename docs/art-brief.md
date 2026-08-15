# Pizza Flicker, art brief

A phone game, held upright. You are a delivery rider on a road that never ends,
and the houses slide past on your left and right. On the back of your bike is a
stack of pizza boxes. You take one, you throw it at a house that is waiting for
it, and you watch. Hit the house, or land in the ring at its feet, and the
delivery counts; straight through the lit window pays best. Reach neither and the
pizza is on the road.

The whole game is that one throw, repeated. Everything on screen exists to make
the throw readable: where the pizza is, how far it has flown, which house wants
one, how many boxes are left.

Everything listed here is currently a coloured rectangle. Nothing about the
placement or the sizes will change when real art arrives, because each rectangle
already occupies exactly the space its picture will.

## The style is open

Nothing has been decided. It is a game about a rushed delivery rider, so
anything from warm and cartoonish to grubby and neon would work. A different
vision is welcome, and it is easier to argue about a sketch than about a
paragraph.

Two constraints, and they are the only two. It has to read at speed, because
things are moving and the player has about a second to decide what to throw at.
And it has to read small, because the houses are set back from the road and end
up a third of the screen at most.

## What the camera is doing

The road runs across the bottom of the screen. Further up the screen means
further away, so the houses sit back from the road and shrink as they recede.
The rider is seen from behind, a little way up the road, so the player is
looking past his shoulder at the street.

Anything standing on the ground is positioned by the point where it touches the
ground, not by its middle. Draw with that contact point at the bottom centre of
the image.

## The list

Sizes are the largest each piece is ever drawn on screen. Drawing at twice that
gives room to spare and costs nothing.

| Piece | Biggest on screen | Draw at |
| --- | --- | --- |
| House, one building | 380 x 380 | 760 x 760 |
| Drop point | 419 x 419 | 838 x 838 |
| Rider and bike | 160 x 233 | 320 x 466 |
| Pizza held in hand | 420 x 420 | 840 x 840 |
| Pizza in flight | 74 x 74 | 148 x 148 |
| Pizza shadow | 60 x 60 | 120 x 120 |
| Strike marker | 84 x 84 | 168 x 168 |
| One box in the stack | 190 x 21 | 380 x 42 |
| Skyline silhouette, near row | 364 x 448 | 728 x 896 |
| Skyline silhouette, middle row | 322 x 429 | 644 x 858 |
| Skyline silhouette, far row | 302 x 408 | 604 x 816 |

The how-to-play page wants four more, and they are the only pieces in the game
that may move. Each one shows a thing the player does: the pizza in hand at the
bottom, the houses along the top, and the throw going up the screen between them.

| Piece | Biggest on screen | Draw at |
| --- | --- | --- |
| How to play, the flick | 1042 x 700 | 2084 x 1400 |
| How to play, the curve | 1042 x 700 | 2084 x 1400 |
| How to play, landing and missing | 1042 x 700 | 2084 x 1400 |
| How to play, the stack and the strikes | 1042 x 560 | 2084 x 1120 |

## Notes on the tricky ones

**The house needs three versions.** One that is waiting for a pizza, one that
has been served, and one that is only scenery. The player has to tell the three
apart in a glance from across the street, and roughly half the houses that go by
are scenery, so this is the single most important read in the game. A lit window
does the job at the moment, which is a low bar to clear.

**The houses in now are one sheet of four buildings**, laid out left to right, and
the size above is one of those buildings rather than the whole strip. A house
picks one when the street places it, and may be mirrored, so a building has to
read both ways round. The size and the lit windows of each one are measured off
the sheet and written down, because a throw is judged against them: draw a
building differently, or add a window to it, and those numbers want taking again.
Say so when a new sheet lands and it can be measured in a couple of minutes.

**The drop point lies flat on the ground at the foot of the house**, not out on
the road: the house is what is being aimed at, so the target belongs under it.
Draw it as a circle seen face on; the game squashes it to sit on the ground. It is
much bigger than it sounds, about as wide as the house, because it is the target
and it has to be aimable.

**The pizza in hand rotates**, and rotating is how the player sees they are
loading a curve. A shape that looks the same every quarter turn cannot show
that, so it needs something clearly off centre: a label, a corner, a smear of
sauce. Anything that tells you which way up it is.

**The pizza in flight is tiny**, and gets tinier as it goes. Its shadow on the
road is doing most of the work of telling the player where it is, so the shadow
matters more than it sounds and the box itself can be very simple.

**The stack of boxes on the bike** is the pizza counter. One box is drawn per
pizza left, stacked upward, and they vanish from the top as they are thrown.
They are thin slivers seen edge on, so a side view of a closed box is all that
is needed.

**The how-to-play pictures can be still or moving.** A still is one PNG and goes
in like everything else. A loop goes in the same slot: lay the frames out left to
right in one strip, drop it in, then set `frame_count` on the step to how many
frames there are and `frames_per_second` to how fast they should run. The engine
cannot import an animated GIF, so export the strip instead. Until the pictures
land, each step draws a mock-up of itself out of the game's own placeholder
pieces, which is a fine thing to draw over.

**The skyline rows** are three bands of buildings behind the street, each
further back than the last. One silhouette is drawn over and over across the
row, so it should tile happily beside copies of itself. Detail is wasted here;
these are behind everything and mostly dark.

## What is not needed yet

No animation. Nothing moves under its own power at the moment: the rider does
not pedal, the boxes do not open, nobody comes to the door. That will come, and
knowing it is coming is worth keeping in mind, but a single still image of each
thing on the list above is enough to replace everything on screen today.

No user interface art beyond the menu's pizza box, which is in. The buttons and
cards are otherwise plain and can stay plain for now.

Sound is already in, though it is placeholder too: public domain impacts and
interface beeps standing in until someone makes something better. Anyone who
wants to replace them can, one at a time, the same way the pictures go in.

## How it goes in

Each piece drops into a slot that is already waiting for it, and the rectangle
it replaces disappears on its own. Nothing has to be rebuilt or rewired, so
individual pieces can arrive one at a time and be seen in the game immediately,
rather than everything having to land at once.

The house works a little differently, because it has three faces and they are
worth building separately. Open the house scene and there is a node for each one,
named Waiting, Served and Scenery. Put the picture inside the node it belongs to
and the game shows that node whenever the house is in that state. Because each
state is a node in its own right it can carry anything a node can: a shader, an
animation, a script of its own. The three do not have to be built the same way,
and a served house that lights up for a moment is entirely possible without
touching the other two.

The drop point is a node as well. Anything placed inside it is stretched to
whatever size the ring is that round and squashed flat onto the ground, so draw
the marker as a circle seen face on and let the game do the rest.

The same scene holds a node called Hitbox. That is the part of the house a pizza
can actually hit: the outline of the body, the lit windows inside it, and the line
below which a throw is arriving at the door rather than striking the wall. It
draws itself on the canvas while the scene is open, never in the running game, so
the shape can be dragged to fit a new drawing and then forgotten about. It is
worth fitting properly. What the outline covers is exactly what the throw is
judged against, so a house drawn wider than its outline will let pizzas through
the parts that stick out.

Transparent PNG is the format. Anything else can be converted.
