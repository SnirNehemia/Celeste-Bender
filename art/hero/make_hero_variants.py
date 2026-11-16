# make_hero_variants.py — two triceratops-style masks on the same body, for
# comparing side by side (hero_variants.json, hero_variants_x8.png).
#
# It reuses the bodies, palette, outline and frame layout of
# make_hero_sheet.py and only swaps the HEAD (rows 1..11 of each frame).
#   "frill": a big terracotta bony frill fanned out behind a round mask,
#            one long brow horn and a nose horn (the triceratops read).
#   "cowl":  the ochre hood stays; the mask grows two long brow horns side by
#            side and a small nose horn on the snout (three horns, no frill).
# For each frame it also writes ANCHORS, the points a simulated dynamic
# element can hang from: head_back, shoulder, hip (facing right, frame pixels).
#
# Run:  python art/hero/make_hero_variants.py

import json
import os
from PIL import Image

import make_hero_sheet as base

HERE = os.path.dirname(os.path.abspath(__file__))

PALETTE = dict(base.PALETTE)
PALETTE.update({
    "F": "#c4553c",  # frill, terracotta
    "f": "#8a3427",  # frill, shade
    "y": "#f2c35e",  # frill spots, gold
})

HEADS = {
    "frill": [
        "..hhhhh.........",
        ".hFFyFFh......h.",
        "hFyFFFFFh....hj.",
        "hFFFFyFFFh..hj..",
        "hfFyFFWWWWWhj...",
        "hfFFFWWWWWWWWh..",
        ".hfFWWKWWKWWWW..",
        ".hfFWWKWWKWWWw..",
        "..hfwWWWWWWWw...",
        "...hcwwwwwww....",
        ".....cCwwww.....",
    ],
    "cowl": [
        "..........h...h.",
        ".........hj..hj.",
        "....cC..hj..hj..",
        "...cCC.hj..hj...",
        "...cCwWWWWWWWW..",
        "...cCWWWWWWWWWh.",
        "...cCWWKWWKWWWW.",
        "...cCWWKWWKWWWw.",
        "...ccwWWWWWWWw..",
        "....cCwwwwwww...",
        ".....cCwwww.....",
    ],
}
# where the back of each head is (art columns), for the dynamic elements
HEAD_BACK = {"frill": [1, 8], "cowl": [4, 8]}


def build(mask: str) -> tuple:
    stand = HEADS[mask]
    lean = ["." + row[:-1] for row in stand]
    frames, anchors, order = {}, {}, []
    for name, head, offset, body in base.FRAMES:
        is_lean = head is base.HEAD_LEAN
        use = lean if is_lean else stand
        grid = base.compose(use, offset, base.BODY[body])
        frames[name] = grid
        order.append(name)
        shift = 1 if is_lean else 0
        hx, hy = HEAD_BACK[mask]
        anchors[name] = {
            "head_back": [hx + shift + base.PAD_X, hy + offset],
            "shoulder": [5 + base.PAD_X, base.BODY_TOP + 1],
            "hip": [5 + base.PAD_X, base.BODY_TOP + 4],
        }
    return frames, anchors, order


def main() -> None:
    out = {"frame_size": [base.FRAME_W, base.FRAME_H], "palette": PALETTE, "masks": {}}
    zoom = 8
    strips = []
    for mask in HEADS:
        frames, anchors, order = build(mask)
        for name, grid in frames.items():
            for row in grid:
                assert len(row) == base.FRAME_W, (mask, name)
                for letter in row:
                    assert letter == "." or letter in PALETTE, (mask, name, letter)
        out["masks"][mask] = {"frames": frames, "anchors": anchors, "order": order}
        strip = Image.new("RGBA", (base.FRAME_W * len(order), base.FRAME_H), (88, 96, 110, 255))
        for i, name in enumerate(order):
            for y, row in enumerate(frames[name]):
                for x, letter in enumerate(row):
                    if letter != ".":
                        strip.putpixel((i * base.FRAME_W + x, y), base.hex_to_rgba(PALETTE[letter]))
        strips.append(strip.resize((strip.width * zoom, strip.height * zoom), Image.NEAREST))
    sheet = Image.new("RGBA", (strips[0].width, sum(s.height for s in strips)), (0, 0, 0, 255))
    y = 0
    for strip in strips:
        sheet.paste(strip, (0, y))
        y += strip.height
    sheet.save(os.path.join(HERE, "hero_variants_x8.png"))
    with open(os.path.join(HERE, "hero_variants.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, indent=1)
    print("[HeroVariants] wrote", ", ".join(HEADS))


if __name__ == "__main__":
    main()
