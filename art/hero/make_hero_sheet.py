# make_hero_sheet.py — the hero's pixel frames, as text, turned into PNGs.
#
# v5: the hero is a small hooded wanderer in a round white mask with one
# straight horn, and a cloak. Every frame is 18x19, facing right. The art is drawn inside the frame
# with a 1-pixel margin, and the script adds a 1-pixel dark OUTLINE around
# everything (like Celeste does), so the hero pops off any background.
# The 8x11 hitbox is columns 5..12, rows 7..17 (the hood and horn rise above it).
#
# The cloak's TAIL is not in these frames: the game simulates it (a rope of
# points hung from the back of the hood, drawn as a strip that narrows to its
# tip, like Maddy's hair), see TAIL_ANCHOR. It stays while gliding.
# The pips stay as floating HUD pips over the head.
#
# Run:  python art/hero/make_hero_sheet.py
# Writes hero_sheet.png (1x, frames in a row), hero_sheet_x8.png (preview)
# and hero_frames.json (the same frames, for the HTML preview page).

import json
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ART_W = 16       # the rows below are drawn 16 wide...
PAD_X = 1        # ...and padded by 1 column each side, so a leaning horn keeps its outline
FRAME_W, FRAME_H = ART_W + 2 * PAD_X, 19
OUTLINE = "O"

# One letter per colour. '.' is transparent.
PALETTE = {
    "O": "#1c1419",  # outline (added by the script)
    "W": "#f6f2ea",  # mask
    "w": "#c9c4cc",  # mask, shaded underside (cool grey)
    "K": "#1c1419",  # eyes
    "b": "#58c6ea",  # the wind mark on the mask's brow
    "h": "#efe2bf",  # horn, ivory (carved from the same piece as the mask)
    "j": "#c2b08a",  # horn, shaded back
    "C": "#b8743a",  # cloak and hood, ochre
    "c": "#7c4a25",  # cloak shade
    "t": "#3f6f78",  # tunic, teal, shade
    "T": "#5a9aa2",  # tunic, teal
    "B": "#3a2723",  # sash
    "S": "#d2a777",  # wrapped hands
    "D": "#4b3a32",  # boots
}

# ---- heads: horn + hood + mask, rows 1..11 of the frame (11 rows) ----
# A round white mask with ONE straight horn (unicorn / triceratops): it rises
# from the mask's top front edge at 45 degrees, 2 px wide tapering to a point,
# ivory with a shaded underside. The hood stops short of it, so the horn grows
# out of the mask itself rather than being stuck through the hood.
HEAD_STAND = [
    "................",
    "..............h.",
    ".............hj.",
    "......cCCCC.hj..",
    ".....cCCCCChj...",
    "....cCwWbbWWWW..",
    "...ccCWWWWWWWW..",
    "...cCCWWKWWKWW..",
    "...cCCWWKWWKWW..",
    "....cCwWWWWWWw..",
    ".....cCwwwwww...",
]
HEAD_UP = [  # rising: eyes one row higher, looking up
    "................",
    "..............h.",
    ".............hj.",
    "......cCCCC.hj..",
    ".....cCCCCChj...",
    "....cCwWbbWWWW..",
    "...ccCWWKWWKWW..",
    "...cCCWWKWWKWW..",
    "...cCCWWWWWWWW..",
    "....cCwWWWWWWw..",
    ".....cCwwwwww...",
]
HEAD_LEAN = ["." + row[:-1] for row in HEAD_STAND]  # running: one pixel forward (into the padding)
HEAD_ROWS = len(HEAD_STAND)
BODY_TOP = 1 + HEAD_ROWS  # first body row in the frame

# ---- bodies: rows 12..17 (6 rows); row 18 is left for the outline ----
BODY = {
    "idle": [
        ".....cCCCCCC....",
        "....cCCtTTCCS...",
        "....cCCBBBBCS...",
        "....cCCtTTCC....",
        "....cccCCCCC....",
        "......DD.DDD....",
    ],
    "run_a": [
        ".....cCCCCCC....",
        "....cCCtTTCCCS..",
        "...ScCCBBBBCC...",
        "....cCCtTTCCC...",
        "...cccCCCCCC....",
        "...DD......DD...",
    ],
    "run_b": [
        ".....cCCCCCC....",
        "....cCCtTTCCS...",
        "....SCCBBBBC....",
        "....cCCtTTCCC...",
        "....ccCCCCCC....",
        "....DD...DDD....",
    ],
    "run_c": [
        ".....cCCCCCC....",
        "....cCCtTTCC....",
        "....cCSBBBBC....",
        "....cCCtTTCC....",
        ".....cCCCCC.....",
        "......DDD.......",
    ],
    "run_d": [
        ".....cCCCCCC....",
        "...ScCCtTTCC....",
        "....cCCBBBBCCS..",
        "....cCCtTTCCC...",
        "...cccCCCCCC....",
        "...DDD.....DD...",
    ],
    "run_e": [
        ".....cCCCCCC....",
        "....cCCtTTCC....",
        "....cCCBBBBCS...",
        "....cCCtTTCCC...",
        "....ccCCCCCC....",
        ".....DD..DD.....",
    ],
    "run_f": [
        ".....cCCCCCC....",
        "....cCCtTTCC....",
        "....cCCBBBSC....",
        "....cCCtTTCC....",
        ".....cCCCCC.....",
        ".......DD.......",
    ],
    "rise": [
        "....ScCCCCCCS...",
        "....cCCtTTCC....",
        "....cCCBBBBC....",
        "....cCCtTTCC....",
        ".....cCCCCC.....",
        "......DD.DD.....",
    ],
    "fall": [
        "...S.cCCCCCC.S..",
        "....cCCtTTCC....",
        "....cCCBBBBC....",
        "...cCCCtTTCCC...",
        "..ccCCCCCCCCCc..",
        "....DD....DD....",
    ],
    # glide: arms held out to the sides, cloak closed; the tail streams behind
    "glide_up": [
        "..SScCCCCCCSS...",
        "....cCCtTTCC....",
        "....cCCBBBBC....",
        "....cCCtTTCC....",
        "....ccCCCCCC....",
        ".....D....D.....",
    ],
    "glide_down": [
        ".....cCCCCCC....",
        "..SScCCtTTCCSS..",
        "....cCCBBBBC....",
        "....cCCtTTCC....",
        "....ccCCCCCC....",
        ".....D....D.....",
    ],
}


def compose(head: list, head_offset_y: int, body: list) -> list:
    """Body at rows 12..17, then the head on top at rows 1..11, pushed down by
    head_offset_y (1 = a squash: the chin covers the shoulders)."""
    grid = [["."] * FRAME_W for _ in range(FRAME_H)]
    for row_index, row in enumerate(body):
        for col_index, letter in enumerate(row):
            grid[BODY_TOP + row_index][col_index + PAD_X] = letter
    for row_index, row in enumerate(head):
        for col_index, letter in enumerate(row):
            if letter != ".":
                grid[1 + row_index + head_offset_y][col_index + PAD_X] = letter
    return add_outline(grid)


def add_outline(grid: list) -> list:
    """Every empty pixel touching a filled one (up, down, left, right)
    becomes outline. Diagonals stay empty, so corners look rounded."""
    out = [row[:] for row in grid]
    for y in range(FRAME_H):
        for x in range(FRAME_W):
            if grid[y][x] != ".":
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < FRAME_W and 0 <= ny < FRAME_H and grid[ny][nx] != ".":
                    out[y][x] = OUTLINE
                    break
    return ["".join(row) for row in out]


# name -> (head, head_offset_y, body). Order = order on the sheet.
FRAMES = [
    ("idle_0", HEAD_STAND, 0, "idle"),
    ("idle_1", HEAD_STAND, 1, "idle"),  # breathing out: the head dips
    ("run_0", HEAD_LEAN, 1, "run_a"),
    ("run_1", HEAD_LEAN, 1, "run_b"),
    ("run_2", HEAD_LEAN, 0, "run_c"),
    ("run_3", HEAD_LEAN, 1, "run_d"),
    ("run_4", HEAD_LEAN, 1, "run_e"),
    ("run_5", HEAD_LEAN, 0, "run_f"),
    ("rise", HEAD_UP, 0, "rise"),
    ("fall", HEAD_STAND, 0, "fall"),
    ("glide_0", HEAD_STAND, 0, "glide_up"),
    ("glide_1", HEAD_STAND, 0, "glide_down"),
]

# Where the simulated TAIL hangs from, per frame, facing right: the back of
# the hood, so it is the hood's long tail (a liripipe) falling down the back,
# a narrowing strip like Maddy's hair. Gliding keeps it too: it streams behind.
TAIL_ANCHOR = {}
for _name, _head, _offset, _body in FRAMES:
    lean = 1 if _head is HEAD_LEAN else 0
    TAIL_ANCHOR[_name] = [4 + lean + PAD_X, 8 + _offset]  # the back of the hood, moves with the head


def hex_to_rgba(hex_color: str) -> tuple:
    hex_color = hex_color.lstrip("#")
    return (int(hex_color[0:2], 16), int(hex_color[2:4], 16), int(hex_color[4:6], 16), 255)


def main() -> None:
    grids = {name: compose(head, offset, BODY[body]) for name, head, offset, body in FRAMES}
    for name, grid in grids.items():
        assert len(grid) == FRAME_H and all(len(r) == FRAME_W for r in grid), name
        for row in grid:
            for letter in row:
                assert letter == "." or letter in PALETTE, (name, letter)

    sheet = Image.new("RGBA", (FRAME_W * len(FRAMES), FRAME_H), (0, 0, 0, 0))
    for frame_index, (name, _, _, _) in enumerate(FRAMES):
        for y, row in enumerate(grids[name]):
            for x, letter in enumerate(row):
                if letter != ".":
                    sheet.putpixel((frame_index * FRAME_W + x, y), hex_to_rgba(PALETTE[letter]))
    sheet.save(os.path.join(HERE, "hero_sheet.png"))

    zoom, gap = 8, 2
    preview = Image.new("RGBA", ((FRAME_W + gap) * len(FRAMES) * zoom, FRAME_H * zoom), (88, 96, 110, 255))
    for frame_index in range(len(FRAMES)):
        frame = sheet.crop((frame_index * FRAME_W, 0, (frame_index + 1) * FRAME_W, FRAME_H))
        frame = frame.resize((FRAME_W * zoom, FRAME_H * zoom), Image.NEAREST)
        preview.alpha_composite(frame, (frame_index * (FRAME_W + gap) * zoom, 0))
    preview.save(os.path.join(HERE, "hero_sheet_x8.png"))

    with open(os.path.join(HERE, "hero_frames.json"), "w", encoding="utf-8") as out:
        json.dump(
            {
                "frame_size": [FRAME_W, FRAME_H],
                "palette": PALETTE,
                "frames": grids,
                "order": [name for name, _, _, _ in FRAMES],
                "tail_anchor": TAIL_ANCHOR,
            },
            out,
            indent=1,
        )
    print("[HeroSheet] wrote", len(FRAMES), "frames")


if __name__ == "__main__":
    main()
