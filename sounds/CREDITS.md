# Sound credits

Every sound effect here is Creative Commons Zero. CC0 puts them in the public
domain: no attribution is required and none is owed. Credited anyway, because
knowing where a thing came from is worth more than a licence demanding it.

- Impact Sounds, Kenney, CC0. https://kenney.nl/assets/impact-sounds
- RPG Audio, Kenney, CC0. https://kenney.nl/assets/rpg-audio

The music is not CC0 and its credit is not a courtesy:

- Mediterranean Breeze, Eric Matyas, CC BY 4.0. https://soundimage.org/world/

CC BY requires attribution, so that one is on the game's own credits page as well
as here. Anything else from soundimage.org carries the same condition; a track that
replaces it must be credited there before it ships, or the build is in breach.

## What each one was, and what was done to it

| in this game | from | pitched |
| --- | --- | --- |
| pick_up | impactGeneric_light_000 | up a quarter |
| throw | footstep_grass_000 | up half |
| delivered_000 to 002 | impactWood_light_000 to 002 | up two fifths |
| missed_000 to 002 | bookPlace1 to 3, from RPG Audio | up a fifth and a half |
| strike | impactPunch_medium_000 | up most of an octave, cleared below 260 Hz, then muffled |
| round_won | impactBell_heavy_000 | up four fifths |
| round_lost | impactGlass_heavy_000 | down a sixth |

## Why the miss is a box now

It was impactTin_medium, and a tin can bouncing on tarmac reads as a vase going
over rather than as a pizza landing in the road. A wet splat was tried next and
was worse in the other direction: what it sounds like is something being stood on.

What actually happens is a flat cardboard box slapping down, so that is what the
sound is: `bookPlace1` to `3` from Kenney's RPG Audio, a hardback set down on a
table, pitched up half again. Three files from one gesture, which is what the bank
wants of a sound that fires on every miss — three of the same event rather than
three different events.

Measured like the rest: they lose 32, 24 and 22 per cent of their power below
400 Hz, inside the limit set below. Each was trimmed to the hit and normalised to
-1 dBFS. Two other characters got as far as being built and are not here —
`dropLeather` and `impactPlank_medium` both keep 70 to 90 per cent of their energy
under 400 Hz however far they are pitched, so on a phone they are almost nothing.

## A miss is two sounds, and the second one was the problem

Missing plays `missed`, and because a miss also spends a strike it plays `strike`
half a beat later, from `_on_strikes_changed`. That is deliberate: the box landing
and the count going down are two facts, and a player who has run out of strikes
should hear which one just happened.

It does mean replacing `missed` alone changed less than half of what a miss sounds
like. `strike` was impactMetal_medium_003, and a metal impact under a cardboard one
is what was still being heard as something breaking. It is now `impactPunch_medium_000`: a body blow, which is what losing one of three
chances should feel like, and which cannot be mistaken for anything breaking.

Two doors were tried on the way here, `doorClose_1` plain and then muffled, and
both stayed recognisably a door. What gives a door away is the latch, a bright
click and a rattle of hardware; muffling removes it, but then the whole sound reads
as coming from the next room.

The punch needed the opposite treatment. Straight, even pitched up most of an
octave, it kept 62 per cent of its power below 400 Hz, which on a phone is a sound
that barely exists — the pack's punches are mostly chest and very little slap.
Rolling off below 260 Hz throws away what was inaudible anyway and leaves the part
that lands, and takes it to 31 per cent, inside the same limit as everything else.
The 1800 Hz roll-off from the doors is kept on top: it is what stops the punch from
having a click of its own, and it is the reason this one still sounds soft-edged
next to the cardboard slap of the miss rather than competing with it.

Anyone changing one of these two should listen to both together. They never play
apart.

## Why several of them are pitched

Phone speakers give up somewhere around 400 Hz. Measuring the pack showed that
every material that suits a cardboard box has almost all of its energy below
that: the soft impacts sit at about 100 Hz and lose 100 per cent of their power
down there, the wooden ones and the planks little better. On a phone they were
being filtered out to nearly nothing.

Pitching them up moves that energy into the band a phone can reproduce while
keeping the recording's character, which is not the same as replacing it with
something bright and synthetic. Each one was measured after the change rather
than trusted: none of them now loses more than about a third of its power below
400 Hz, and most lose under a fifth.

Nothing from Kenney's Interface Sounds pack survives here. Those are synthesised
tones, made for menus, and they were the reason the game sounded robotic. The
irony was that they were the only things clearly audible on a phone, so they
were doing all the talking.

These are still stand-ins, chosen by measurement rather than by ear. Anything
can be replaced by dropping a file into the sound bank, and a sound can be given
more variants without touching any code.

## The music

`sounds/music/` holds what ships. One track is in so far, under the menu and under
every street, and each street plays it faster than the last: `music_speed` on the
level, 1.0, 1.07 and 1.15, which is the evening getting away from you without three
recordings having to exist.

`GameMusic` will take a track per street when there are three worth having. Until
then they can be tried without committing anything: drop a file at
`sounds/audition/music_2.mp3` and street two plays it, numbered from 1 to match the
street badge. That folder is ignored by git, so an audition cannot end up in a
release by accident — which also means a track that is going to ship has to move
into `sounds/music/` and be credited here, and on the credits page too unless it is
CC0.
