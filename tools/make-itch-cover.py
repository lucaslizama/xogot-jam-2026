#!/usr/bin/env python3
"""Compose the itch.io cover for Pizza Flicker: 630x500, the size itch asks for.

    python3 tools/make-itch-cover.py      # needs Pillow

Not a screenshot. The game is portrait and its own screen is mostly road, which
makes a poor landscape thumbnail, so this stages the same moment on purpose: the
rider bottom left, the pizza a moment from a lit window, the arc between them.

Every colour is read off the game rather than invented. The sky, haze, asphalt,
verge and lane are the values in data/daylight/sunrise.tres; the rest are pear36
entries already authored somewhere in the project, because the whole game was
snapped to pear36 at the artist's request and a cover in other colours would be
the one thing on the page that is off palette. The rider and the pizza are the
real sprites, and the type is the game's own Fredoka and Nunito.

Uploading it is a manual step: butler pushes builds, not page art, so the cover
is set under Edit game > Cover image on itch.
"""
import os
import random
from PIL import Image, ImageDraw, ImageFont

W, H = 630, 500
HORIZON = 322

# --- the palette, all of it already in the project -------------------------
SKY_TOP = (71, 59, 120)        # sunrise.tres sky_top
SKY_HORIZON = (255, 145, 102)  # sunrise.tres sky_horizon
HAZE = (242, 166, 94)          # sunrise.tres haze_colour
ASPHALT = (50, 62, 79)         # sunrise.tres asphalt
GRAIN = (67, 67, 79)           # sunrise.tres asphalt_grain
VERGE = (61, 110, 112)         # sunrise.tres verge
LANE = (255, 228, 120)         # sunrise.tres lane
CREAM = (255, 255, 235)        # line_owed / ui cream
WINDOW = (255, 228, 120)       # tip_popup colour_window family
DARK = (62, 53, 70)            # pear36 3e3546
DEEP = (75, 91, 171)           # pear36 4b5bab
MAGENTA = (189, 72, 130)       # pear36 bd4882, the brand colour

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

img = Image.new("RGB", (W, H), SKY_TOP)
d = ImageDraw.Draw(img)


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


# --- sky, hazing into the horizon -----------------------------------------
for y in range(HORIZON):
    t = y / HORIZON
    col = lerp(SKY_TOP, SKY_HORIZON, t ** 1.6)
    if t > 0.72:                      # the haze sunrise.tres asks for
        col = lerp(col, HAZE, (t - 0.72) / 0.28 * 0.62)
    d.line([(0, y), (W, y)], fill=col)

# stars, thinning out well before the horizon, at sunrise's own brightness
rng = random.Random(7)
for _ in range(90):
    x, y = rng.randrange(W), rng.randrange(int(HORIZON * 0.62))
    fade = 0.35 * (1.0 - y / (HORIZON * 0.62))
    d.point((x, y), fill=lerp(img.getpixel((x, y)), CREAM, fade))

# --- the row of houses along the horizon ----------------------------------
# Wider and taller towards the right, so the eye travels that way with the throw.
houses = [(-10, 96, 74), (86, 78, 58), (168, 92, 66), (262, 84, 52),
          (352, 118, 96), (474, 104, 72), (582, 70, 54)]
for x, w, h in houses:
    top = HORIZON - h
    body = lerp(DARK, DEEP, 0.25)
    d.rectangle([x, top, x + w, HORIZON], fill=body)
    d.polygon([(x - 6, top), (x + w + 6, top), (x + w * 0.5, top - 20)], fill=DARK)
    # a lit window or two, kept small so the target house below reads as special
    for i in range(2):
        wx = x + 14 + i * (w - 40)
        wy = top + 18
        if wx + 18 < x + w:
            d.rectangle([wx, wy, wx + 17, wy + 21],
                        fill=lerp(WINDOW, HAZE, 0.35))

# The house the pizza is heading for: nearer, bigger, its window properly lit.
tx, ty, tw, th = 428, 150, 150, 172
d.rectangle([tx, ty + 26, tx + tw, HORIZON + 6], fill=DARK)
d.polygon([(tx - 14, ty + 26), (tx + tw + 14, ty + 26), (tx + tw * 0.5, ty - 16)],
          fill=lerp(DARK, MAGENTA, 0.22))
win = [tx + 40, ty + 62, tx + 108, ty + 132]
d.rectangle([win[0] - 5, win[1] - 5, win[2] + 5, win[3] + 5], fill=lerp(DARK, CREAM, 0.18))
d.rectangle(win, fill=WINDOW)
d.line([((win[0] + win[2]) // 2, win[1]), ((win[0] + win[2]) // 2, win[3])], fill=DARK, width=4)
d.line([(win[0], (win[1] + win[3]) // 2), (win[2], (win[1] + win[3]) // 2)], fill=DARK, width=4)
# light spilling out of it
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
for r in range(64, 0, -8):
    gd.ellipse([win[0] - r, win[1] - r, win[2] + r, win[3] + r],
               fill=(*WINDOW, 5))
img = Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB")
d = ImageDraw.Draw(img)

# --- the road -------------------------------------------------------------
d.rectangle([0, HORIZON, W, HORIZON + 16], fill=VERGE)
d.rectangle([0, HORIZON + 16, W, H], fill=ASPHALT)
# grain, spaced wider as it comes towards you, the way the road shader does it
y, step = HORIZON + 24, 6
while y < H:
    d.line([(0, y), (W, y)], fill=lerp(ASPHALT, GRAIN, 0.55))
    step *= 1.26
    y += int(step)
# the lane markings, two runs of dashes at the depths the game divides the road at
for lane_y, dash, gap, thick in ((HORIZON + 44, 26, 20, 5), (H - 66, 44, 34, 9)):
    x = -20
    while x < W:
        d.rectangle([x, lane_y, x + dash, lane_y + thick], fill=lerp(ASPHALT, LANE, 0.8))
        x += dash + gap

# --- the rider, the real sprite -------------------------------------------
rider = Image.open(f"{ROOT}/sprites/DeliveryGirl_aim.png").convert("RGBA")
bbox = rider.getbbox()
rider = rider.crop(bbox)
target_h = 232
scale = target_h / rider.height
rider = rider.resize((round(rider.width * scale), target_h), Image.LANCZOS)
rider_x, rider_y = 8, H - target_h - 10
# a soft shadow under the wheels so she is standing on the road, not floating
shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ImageDraw.Draw(shadow).ellipse(
    [rider_x + 30, H - 40, rider_x + rider.width - 24, H - 4], fill=(0, 0, 0, 70))
img = Image.alpha_composite(img.convert("RGBA"), shadow)

# --- the throw ------------------------------------------------------------
# A curving flight from her raised hand to the lit window: the whole game in one
# line. It leaves steeply so it clears her own head rather than cutting across her.
start = (rider_x + round(rider.width * 0.34), rider_y + round(target_h * 0.30))
end = ((win[0] + win[2]) // 2 - 8, (win[1] + win[3]) // 2)
ctrl = (start[0] + (end[0] - start[0]) * 0.35, start[1] - 210)
trail = Image.new("RGBA", (W, H), (0, 0, 0, 0))
td = ImageDraw.Draw(trail)
steps = 26
for i in range(steps):
    t = i / (steps - 1)
    x = (1 - t) ** 2 * start[0] + 2 * (1 - t) * t * ctrl[0] + t ** 2 * end[0]
    y = (1 - t) ** 2 * start[1] + 2 * (1 - t) * t * ctrl[1] + t ** 2 * end[1]
    if i % 2:                       # dashed, like the aim preview in game
        continue
    r = 8.0 - 4.5 * t               # thinning as it gets away from you
    a = round(215 * (0.30 + 0.70 * (1 - t)))
    td.ellipse([x - r, y - r, x + r, y + r], fill=(*CREAM, a))
img = Image.alpha_composite(img, trail)

# She goes on over the trail, not under it: the first few dots are behind her head,
# so the throw reads as having left over her shoulder instead of through her hair.
img.alpha_composite(rider, (rider_x, rider_y))

# the pizza itself, mid-flight, the real sprite
pizza = Image.open(f"{ROOT}/sprites/pizza_win.png").convert("RGBA")
pizza = pizza.crop(pizza.getbbox())
pizza_size = 94
pizza = pizza.resize((pizza_size, pizza_size), Image.LANCZOS).rotate(-18, expand=True,
                                                                    resample=Image.BICUBIC)
# Caught a moment from the window, which is the shot the game is about.
pt = 0.85
px = (1 - pt) ** 2 * start[0] + 2 * (1 - pt) * pt * ctrl[0] + pt ** 2 * end[0]
py = (1 - pt) ** 2 * start[1] + 2 * (1 - pt) * pt * ctrl[1] + pt ** 2 * end[1]
img.alpha_composite(pizza, (round(px - pizza.width / 2), round(py - pizza.height / 2)))

# --- the title ------------------------------------------------------------
title_font = ImageFont.truetype(f"{ROOT}/fonts/Fredoka-SemiBold.ttf", 78)
tag_font = ImageFont.truetype(f"{ROOT}/fonts/Nunito-SemiBold.ttf", 24)
d = ImageDraw.Draw(img)


def stroked(pos, text, font, fill, outline, width, anchor=None):
    d.text(pos, text, font=font, fill=outline, stroke_width=width, stroke_fill=outline,
           anchor=anchor)
    d.text(pos, text, font=font, fill=fill, anchor=anchor)


# Sat on the sky, left of the target house, clear of both the rider and the arc.
stroked((30, 16), "PIZZA", title_font, CREAM, DARK, 9)
stroked((30, 92), "FLICKER", title_font, WINDOW, DARK, 9)
# Down on the asphalt, right-aligned, where there is nothing else to fight with.
stroked((W - 22, H - 30), "flick it. curve it. hit the window.", tag_font, CREAM, DARK,
        5, anchor="rm")

os.makedirs(f"{ROOT}/press", exist_ok=True)
img.convert("RGB").save(f"{ROOT}/press/itch-cover.png")
# itch shows the cover as small as 315x250 in its lists, which is the size that
# decides whether the title is readable. Written out so it can be checked.
img.convert("RGB").resize((315, 250), Image.LANCZOS).save(
    f"{ROOT}/press/itch-cover-thumb.png")
print("wrote press/itch-cover.png at 630x500, and the 315x250 it is listed at")
