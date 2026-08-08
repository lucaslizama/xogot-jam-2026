# The food journey game

Shelved on 7 August 2026, the first day of Xogot Jam 2026, because the scope did not fit the
ten days available. Nothing here is wrong; it was simply too much game for the window.
Written down so it can be picked up properly some day.

## The idea

A restaurant takes an order: one or two dishes, say a hamburger and fries. Then, without
warning, the screen cuts away to the very start of that food's life. For the burger it is a
cow in a field. For the fries it is a potato patch. You play a quick minigame there, harvest
the thing, and then a pair of hands passes it to the next person in the chain.

Every ingredient follows the same shape. Harvest first, always. Then one or more transport
games, however many that ingredient's route actually needs: driving the meat to town while
dodging traffic, a crate down a conveyor, whatever the journey demands. A potato might take
two legs where beef takes one. Last comes cooking, once at the restaurant, made from
whatever managed to arrive.

Then the next dish, a little faster and a little meaner, until the order is done.

The theme was Handoff, and the whole game is one long handoff: field to truck, truck to
kitchen, kitchen to plate. The player is every pair of hands in the chain, one after another.

## Why it is worth building

Nobody has quite made this. WarioWare minigames are gloriously random; these ones would sit
on a spine that means something, and the player would learn the shape of it without being
told. You start to recognise the beat: harvest, move, move, cook. That familiarity is what
lets the difficulty ramp hurt.

There is also a quiet second thing the game says, about how much work is behind a plate of
food. It never has to say it out loud.

## What was already decided

Four calls were made and they still look right.

Failure works like WarioWare. Four hearts, one lost per failed minigame, game over at zero,
and the score is how many orders you got out. The tempting alternative was letting quality
carry down the chain, so a botched harvest hands the driver bruised potatoes and the final
plate reflects every mistake along the way. That version is more interesting and more true to
the theme. It is also two systems instead of one, and it needs a HUD that can teach both. It
belongs in the unhurried version of this game.

Landscape minigames never rotate the device. The phone stays in portrait and the game rotates
its own content inside the window. This dodges every platform orientation headache and, better,
keeps landscape games testable on a desktop.

Ingredient routes are written by hand rather than shuffled from a pool. Potato goes field,
truck, kitchen. Beef goes field, truck. Pacing you can feel is worth more than variety you
cannot control, at least until there are enough minigames for a pool to be worth having.

The handoff between games is a short cutscene, not something the player performs. Hands pass
the parcel, a card says what is coming next and how to play it, and the whole beat doubles as
the loading window. An interactive version, a single well timed tap to catch the thing, would
put the theme directly in the player's thumbs. It fires ten or more times a run though, so it
has to be tuned properly or it turns into noise.

## What already exists

The harness was built and it works. A persistent scene owns the run so that nothing is ever
torn down between minigames, which is what lets hearts survive without saving anything to
disk. Minigames are described by small data files carrying their prompt word, control hint,
orientation, clock, and whether surviving the clock counts as a win, so the runner never
needs to know anything specific about any of them. Adding a minigame means adding a scene and
a data file.

Landscape works by giving the minigame a genuinely landscape viewport and rotating that into
the portrait window, with touch input mapped back through the same rotation. A minigame is
authored the right way up and never learns it is being turned. Tilt input reads the device
sensor with a keyboard fallback, so tilt games can be played at a desk.

Three placeholder minigames prove the chain end to end, and a test suite covers the letterbox
maths, the input mapping through rotation, hearts counting down across separate minigames,
and both endings.

## If it gets picked up again

The harness is the boring part and it is done. What the idea actually needs is minigames, a
lot of them, and that is a matter of months rather than days. Build a handful of real ones
first, one per phase, and find out what the contract got wrong while it is still cheap to
change. Then decide whether quality carrying down the chain is worth the second system. It
probably is, once there is no clock.
