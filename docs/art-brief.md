# Pizza Flicker, art brief

A phone game, held upright. You are a delivery rider on a road that never ends,
and the houses slide past on your left and right. On the back of your bike is a
stack of pizza boxes. You take one, you throw it at a house that is waiting for
it, and you watch. If it lands in the right spot the delivery counts. If not, it
hits the wall.

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
| House | 318 x 303 | 636 x 606 |
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

## Notes on the tricky ones

**The house needs three versions.** One that is waiting for a pizza, one that
has been served, and one that is only scenery. The player has to tell the three
apart in a glance from across the street, and roughly half the houses that go by
are scenery, so this is the single most important read in the game. A lit window
does the job at the moment, which is a low bar to clear.

**The drop point lies flat on the road**, in front of the house. Draw it as a
circle seen face on; the game squashes it to sit on the ground. It is much
bigger than it sounds, wider than the house is, because it is the target and it
has to be aimable.

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

**The skyline rows** are three bands of buildings behind the street, each
further back than the last. One silhouette is drawn over and over across the
row, so it should tile happily beside copies of itself. Detail is wasted here;
these are behind everything and mostly dark.

## What is not needed yet

No animation. Nothing moves under its own power at the moment: the rider does
not pedal, the boxes do not open, nobody comes to the door. That will come, and
knowing it is coming is worth keeping in mind, but a single still image of each
thing on the list above is enough to replace everything on screen today.

No user interface art. The buttons and cards are plain and can stay plain for
now.

Sound is already in, though it is placeholder too: public domain impacts and
interface beeps standing in until someone makes something better. Anyone who
wants to replace them can, one at a time, the same way the pictures go in.

## How it goes in

Each piece drops into a slot that is already waiting for it, and the rectangle
it replaces disappears on its own. Nothing has to be rebuilt or rewired, so
individual pieces can arrive one at a time and be seen in the game immediately,
rather than everything having to land at once.

Transparent PNG is the format. Anything else can be converted.
