# Font credits

Both faces come from Google Fonts under the SIL Open Font License. The OFL asks
that the licence travel with the files, which is what `OFL-Fredoka.txt` and
`OFL-Nunito.txt` are here for. It does not ask for a credit on screen; the
credits page names them anyway, on the same reasoning as `sounds/CREDITS.md`.

- Fredoka, Milena Brandão and contributors, OFL. https://fonts.google.com/specimen/Fredoka
- Nunito, Vernon Adams and contributors, OFL. https://fonts.google.com/specimen/Nunito

## What is in this folder, and what was done to it

| file | from | weight |
| --- | --- | --- |
| Fredoka-SemiBold.ttf | Fredoka[wdth,wght].ttf | wght 600, wdth 100 |
| Nunito-Regular.ttf | Nunito[wght].ttf | wght 400 |
| Nunito-SemiBold.ttf | Nunito[wght].ttf | wght 600 |

Google ships both as single variable fonts. Godot imports a variable font at its
default instance unless a `FontVariation` says otherwise, and the default here is
the *thinnest* weight either family has: Fredoka Light at 300, Nunito ExtraLight
at 200. Left alone, a 128 px title would have come out spindly and a caption
close to invisible on a phone.

So each weight this game uses was cut from the variable original as a static font
with `fontTools.varLib.instancer`, and the variable files were not kept. One file
is one weight, there is nothing to configure at import, and no way to end up with
the wrong one by accident.

## Which one is used where

Nothing chooses a font by hand. `data/ui_theme.tres` holds every size and colour,
and a label or button picks its look with a `theme_type_variation`. Broadly:
Fredoka carries the titles, the buttons and the names, Nunito carries anything
meant to be read as a sentence. Change it there and it changes everywhere.
