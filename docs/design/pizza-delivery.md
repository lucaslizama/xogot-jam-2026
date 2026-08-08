# Pizza delivery

The jam entry for Xogot Jam 2026, theme Handoff. Portrait, touch only, built for iPhone.

## The loop

A delivery rider pedals down a street that never ends. He sits at the bottom of the screen
and never moves sideways; the world scrolls past him instead, houses sliding right to left in
parallax layers. On the back of his bike is a stack of pizza boxes, and that stack is the
whole of his ammunition. Every throw takes one off the top, so the player can always see
exactly how much of the level is left without a single number on screen.

Houses go by at different distances. Each has a drop point, and the pizza has to land in it.
Anything else and the box hits the wall and slides down it, which costs a strike.

Strikes are dots along the top of the screen. A failed throw turns one into a cross. When the
last dot is crossed the delivery is blown and the level ends there. Otherwise the level runs
until the stack is empty, and if a dot is still clean when the last box leaves the bike, the
round is won. Later levels hand out fewer dots and scroll faster.

That gives three knobs that feel different from each other: how many strikes, how many pizzas
against how many waiting houses, and how fast the street moves.

## Throwing

The throw is the game, so it has more going on than anything else.

Drag on the pizza and release. How fast the finger is moving at release sets how hard the box
is thrown, which is to say how far up the street it reaches. The direction of the flick aims
it left or right.

Spin curves the flight, and there are two ways to get it. The deliberate way is to hold the
pizza and rotate it before throwing, which winds up a spin the player can see on the box; that
is the skilful version, for the shots that need to bend around something or reach a drop point
off to one side. The other way is simply throwing with a hooked flick rather than a straight
one, which imparts spin from the curvature of the gesture itself. A player who never learns
the pre-spin will still curve pizzas by accident and start to understand why.

Both feed the same number, so there is one spin value and one curve behaviour, not two
systems.

## The view

Up the screen means further away. The rider is at the bottom in the foreground, houses recede
toward a vanishing point, and a thrown pizza shrinks as it travels. Drop points sit on the
ground at a given distance, so aiming is a matter of both direction and power: too soft and
the box lands short, too hard and it sails past the house.

This is a flat drawing pretending to have depth rather than a 3D scene. Positions are kept as
sideways offset, height off the ground, and distance from the rider, and that gets projected
to the screen every frame. It keeps the art 2D and keeps the flight maths simple enough to
test without drawing anything at all.

## What is deliberately absent

There is no HUD beyond the strike dots. Pizzas left are the stack on the bike. Progress
through the level is the same stack. Which house wants a pizza is shown by the house.

## Where the theme fits

Handoff is the throw itself: the pizza leaves your hands and everything after that is
committed. You cannot steer it once it is gone. The whole game is a series of moments where
you have done all you can and now you watch.

## The street

The street is endless. Houses are generated as it scrolls rather than laid out by hand, so a
level has a density and a speed rather than a length, and it ends when the stack does. Later
levels can pack the houses tighter, move them further out, or send them past faster, and none
of that needs anything authored.

## Still open

The art direction is untouched. So is sound, and so is whatever happens between one level and
the next.
