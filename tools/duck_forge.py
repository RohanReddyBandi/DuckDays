#!/usr/bin/env python3
"""Build the duck sprites and scene decor from geometric primitives.

Hand-typing pixel art row by row gives lumpy curves. Composing the silhouette from
ellipses, deriving the 1px outline from that silhouette, and banding the shading off
each region's own centre keeps every edge smooth and lets all twelve styles share one
exact body.

Usage:
    python3 tools/duck_forge.py preview out.png    # contact sheet of every style
    python3 tools/duck_forge.py small out.png      # same, at widget scale
    python3 tools/duck_forge.py scene out.png      # decor sprites
    python3 tools/duck_forge.py swift              # emit the Swift tables
    python3 tools/duck_forge.py icon               # emit the app icon
"""
import struct
import sys
import zlib

W, H = 38, 32

OUTLINE, BODY, SHADE, LIGHT = "k", "b", "s", "h"
BEAK, BEAK_DARK, CHEEK, GLINT = "r", "e", "p", "w"
ACCENT, ACCENT_DARK, SHADOW = "a", "d", "g"

# ---------------------------------------------------------------- primitives

def ellipse(cx, cy, rx, ry, w=W, h=H):
    cells = set()
    for y in range(h):
        for x in range(w):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1.0:
                cells.add((x, y))
    return cells


def rect(x0, y0, x1, y1):
    return {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}


def ring(shape):
    out = set()
    for (x, y) in shape:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if (x + dx, y + dy) not in shape:
                    out.add((x + dx, y + dy))
    return out


def inner_edge(shape):
    return {(x, y) for (x, y) in shape
            if any((x + dx, y + dy) not in shape
                   for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)))}


def stamp(cells, shape, material, outline=True):
    """Draw an accessory on top, with its own dark rim so it reads against
    both the body and the background."""
    if outline:
        for c in ring(shape):
            if 0 <= c[0] < W and 0 <= c[1] < H:
                cells[c] = OUTLINE
    for c in shape:
        if 0 <= c[0] < W and 0 <= c[1] < H:
            cells[c] = material
    return cells


# ---------------------------------------------------------------- the duck
# Facing left: round head upper-left, wide float body, tail kicking up right.

HEAD = dict(cx=15.0, cy=11.5, rx=7.0, ry=7.0)
BELLY = dict(cx=22.0, cy=21.0, rx=14.0, ry=7.5)
TAIL = dict(cx=31.5, cy=16.0, rx=5.2, ry=5.0)
DROP = dict(cx=22.0, cy=29.0, rx=12.0, ry=1.8)

# Column the head is centred on. Accessories are placed relative to it so the
# whole set moves together if the duck ever shifts again.
HX = 15

# A wide flat bill. It has to start well left of the head's edge or the
# silhouette swallows it.
BILL = (rect(5, 12, 12, 12) | rect(2, 13, 12, 13) | rect(1, 14, 12, 14)
        | rect(2, 15, 12, 15) | rect(5, 16, 12, 16))
BILL_LOWER = rect(0, 15, 12, 16)

EYE_WHITE = (rect(13, 8, 16, 8) | rect(12, 9, 17, 11) | rect(13, 12, 16, 12))
EYE_PUPIL = rect(14, 9, 16, 11)
EYE_GLINT = {(14, 9)}
BLUSH = rect(18, 13, 19, 13)


def shade_band(cells, region, center, materials=(LIGHT, SHADE)):
    """Band a region light on top and dark underneath, measured from its own
    centre so the head and belly each read as a rounded volume."""
    light, dark = materials
    for (x, y) in region:
        if cells.get((x, y)) != BODY:
            continue
        dy = (y + 0.5 - center["cy"]) / center["ry"]
        dx = (x + 0.5 - center["cx"]) / center["rx"]
        if dy < -0.42:
            cells[(x, y)] = light
        elif dy > 0.46 or (dy > 0.1 and dx > 0.62):
            cells[(x, y)] = dark
    return cells


def build_base(blink=False):
    head = ellipse(**HEAD)
    belly = ellipse(**BELLY)
    tail = ellipse(**TAIL)

    solid = head | belly | tail
    bill = BILL - solid
    everything = solid | bill

    cells = {c: BODY for c in everything}

    # Volume first, so the outline pass can overwrite its edges cleanly.
    shade_band(cells, belly | tail, BELLY)
    shade_band(cells, head, HEAD)

    for c in bill:
        cells[c] = BEAK
    for c in bill & BILL_LOWER:
        cells[c] = BEAK_DARK

    for c in inner_edge(everything):
        cells[c] = OUTLINE

    # --- wing: an outlined shape on the flank -------------------------
    wing = ellipse(cx=25.5, cy=21.0, rx=4.8, ry=3.6)
    interior = {c for c in wing if cells.get(c) in (BODY, SHADE, LIGHT)}
    for c in interior:
        cells[c] = LIGHT
    for c in interior:
        if c[0] < 22:
            continue
        if any((c[0] + dx, c[1] + dy) not in interior
               for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))):
            cells[c] = OUTLINE

    # --- face ---------------------------------------------------------
    if blink:
        for c in rect(13, 10, 17, 10) | {(12, 9), (18, 9)}:
            cells[c] = OUTLINE
    else:
        for c in EYE_WHITE:
            cells[c] = GLINT
        for c in EYE_PUPIL:
            cells[c] = OUTLINE
        for c in EYE_GLINT:
            cells[c] = GLINT
    for c in BLUSH:
        if cells.get(c) in (BODY, SHADE, LIGHT):
            cells[c] = CHEEK

    return cells


def with_shadow(cells):
    """The cast shadow sits behind everything, only where the duck is not."""
    out = dict(cells)
    for c in ellipse(**DROP):
        if c not in cells:
            out[c] = SHADOW
    return out


# ---------------------------------------------------------------- accessories
# The crown of the head sits at row 5, centred on column 11.

def tuft(cells):
    return stamp(cells, {(15, 4), (15, 3), (16, 3), (16, 2)}, BODY)


def bow(cells):
    knot = {(15, 3)}
    stamp(cells, rect(12, 2, 14, 4) | rect(16, 2, 18, 4) | knot, ACCENT)
    for c in knot:
        cells[c] = ACCENT_DARK
    return cells


def tophat(cells):
    stamp(cells, rect(9, 5, 21, 5) | rect(12, 0, 18, 4), ACCENT)
    for c in rect(12, 3, 18, 3):
        cells[c] = ACCENT_DARK
    return cells


def scarf(cells):
    """Kept to the head end of the silhouette; a band across the whole float
    would read as a stripe on the belly, not a scarf."""
    band = {c for c, m in cells.items()
            if 17 <= c[1] <= 18 and 8 <= c[0] <= 23 and m in (BODY, SHADE, LIGHT, CHEEK)}
    for c in band:
        cells[c] = ACCENT
    for c in rect(19, 19, 21, 22):
        if cells.get(c) in (BODY, SHADE, LIGHT, ACCENT):
            cells[c] = ACCENT_DARK
    return cells


def flower(cells):
    petals = (rect(14, 0, 16, 1) | rect(11, 2, 13, 4)
              | rect(17, 2, 19, 4) | rect(14, 5, 16, 6))
    stamp(cells, petals | rect(14, 2, 16, 4), ACCENT)
    for c in rect(14, 2, 16, 4):
        cells[c] = ACCENT_DARK
    return cells


def halo(cells):
    stamp(cells, rect(12, 0, 18, 0) | {(11, 1), (19, 1)} | rect(12, 2, 18, 2),
          ACCENT, outline=False)
    return cells


def crown(cells):
    spikes = {(12, 1), (14, 1), (16, 1), (18, 1)}
    stamp(cells, spikes | rect(12, 2, 18, 4), ACCENT)
    cells[(15, 3)] = GLINT
    return cells


def beanie(cells):
    cap = rect(9, 5, 21, 5) | rect(10, 4, 20, 4) | rect(11, 3, 19, 3)
    stamp(cells, cap, ACCENT)
    for c in rect(9, 5, 21, 5):
        cells[c] = ACCENT_DARK
    stamp(cells, rect(14, 1, 16, 2), GLINT)
    return cells


def partyhat(cells):
    cone = ({(15, 0), (15, 1)} | rect(14, 2, 16, 2) | rect(14, 3, 16, 3)
            | rect(13, 4, 17, 4) | rect(12, 5, 18, 5))
    stamp(cells, cone, ACCENT)
    for c in rect(14, 3, 16, 3):
        cells[c] = ACCENT_DARK
    return cells


def sunglasses(cells):
    lens = rect(12, 8, 18, 11) - {(12, 8), (18, 8), (12, 11), (18, 11)}
    arm = rect(19, 9, 21, 9)
    stamp(cells, lens | arm, ACCENT_DARK)
    for c in [(13, 9), (14, 10)]:
        cells[c] = ACCENT
    return cells


def sprout(cells):
    stamp(cells, {(15, 3), (15, 4)} | {(13, 2), (14, 2), (13, 1)}
          | {(17, 2), (16, 2), (17, 1)}, ACCENT)
    return cells


# ---------------------------------------------------------------- decor
# Scene furniture, shared by every style and recoloured from its palette.

def _grid(cells, w, h):
    return ["".join(cells.get((x, y), ".") for x in range(w)) for y in range(h)]


def _outlined(shape, w, h, fill=GLINT):
    cells = {c: fill for c in shape}
    for c in inner_edge(shape):
        cells[c] = OUTLINE
    return _grid(cells, w, h)


# Three genuinely different clouds rather than one sprite stretched to three
# widths. Drawn at the same pixel size, so their outlines match everything else.
def cloud_small_sprite():
    w, h = 11, 6
    return _outlined(ellipse(4.0, 3.6, 3.0, 2.2, w, h)
                     | ellipse(7.0, 3.2, 2.8, 2.4, w, h)
                     | ellipse(5.5, 4.2, 5.0, 1.6, w, h), w, h)


def cloud_mid_sprite():
    w, h = 15, 8
    return _outlined(ellipse(4.5, 4.4, 3.2, 2.6, w, h)
                     | ellipse(8.5, 3.4, 3.8, 3.0, w, h)
                     | ellipse(11.5, 4.6, 2.8, 2.2, w, h)
                     | ellipse(7.5, 5.2, 6.8, 2.0, w, h), w, h)


def cloud_long_sprite():
    w, h = 19, 9
    return _outlined(ellipse(5.0, 5.0, 3.6, 3.0, w, h)
                     | ellipse(10.0, 4.0, 4.0, 3.6, w, h)
                     | ellipse(14.5, 5.4, 3.2, 2.6, w, h)
                     | ellipse(9.5, 6.2, 8.6, 1.8, w, h), w, h)


def sun_sprite():
    w = h = 13
    disc = ellipse(6.5, 6.5, 5.6, 5.6, w, h)
    cells = {c: ACCENT for c in disc}
    for c in inner_edge(disc):
        cells[c] = OUTLINE
    return _grid(cells, w, h)


def moon_sprite():
    w = h = 13
    disc = ellipse(6.5, 6.5, 5.6, 5.6, w, h)
    bite = ellipse(9.6, 4.6, 4.8, 4.8, w, h)
    shape = disc - bite
    cells = {c: ACCENT for c in shape}
    for c in inner_edge(shape):
        cells[c] = OUTLINE
    return _grid(cells, w, h)


def star_sprite():
    cells = {(1, 0): ACCENT, (0, 1): ACCENT, (1, 1): GLINT,
             (2, 1): ACCENT, (1, 2): ACCENT}
    return _grid(cells, 3, 3)


def star_big_sprite():
    cells = {(2, 0): ACCENT, (2, 1): ACCENT, (0, 2): ACCENT, (1, 2): ACCENT,
             (2, 2): GLINT, (3, 2): ACCENT, (4, 2): ACCENT,
             (2, 3): ACCENT, (2, 4): ACCENT}
    return _grid(cells, 5, 5)


def wave_sprite():
    """Tiles horizontally into a scalloped waterline."""
    return ["..wwww..", ".wwwwww.", "wwwwwwww"]


# ---------------------------------------------------------------- styles


# ---- second dozen -------------------------------------------------------

def visor(cells):
    stamp(cells, rect(9, 4, 21, 5), ACCENT_DARK)
    stamp(cells, rect(3, 6, 12, 6) | rect(4, 7, 11, 7), ACCENT)
    return cells


def bandana(cells):
    stamp(cells, rect(9, 4, 21, 6), ACCENT)
    for c in [(12, 5), (16, 5), (20, 5), (14, 4), (18, 4)]:
        cells[c] = GLINT
    stamp(cells, rect(21, 5, 24, 7), ACCENT)
    stamp(cells, {(24, 8), (25, 9)}, ACCENT_DARK)
    return cells


def chefhat(cells):
    band = rect(9, 5, 21, 5)
    # Lobes, and a filler row only at the very bottom — filling rows 3 and 4
    # squares the whole thing off into a box.
    puff = (ellipse(11.5, 2.6, 3.6, 3.0) | ellipse(18.5, 2.6, 3.6, 3.0)
            | ellipse(15.0, 1.8, 4.2, 3.0) | rect(11, 4, 19, 4))
    stamp(cells, band | puff, ACCENT)
    for c in band:
        cells[c] = ACCENT_DARK
    return cells


def wizardhat(cells):
    cone = ({(15, 0)} | rect(14, 1, 16, 1) | rect(13, 2, 17, 3)
            | rect(12, 4, 18, 4) | rect(8, 5, 22, 5))
    stamp(cells, cone, ACCENT)
    for c in rect(8, 5, 22, 5):
        cells[c] = ACCENT_DARK
    cells[(15, 2)] = GLINT
    return cells


def snorkel(cells):
    stamp(cells, rect(10, 7, 20, 13), ACCENT_DARK)
    for c in rect(11, 8, 19, 12):
        cells[c] = GLINT
    # Re-draw the eye on top, so it reads as looking through the glass rather
    # than as a blank white box stuck to the head.
    for c in EYE_PUPIL:
        cells[c] = OUTLINE
    for c in EYE_GLINT:
        cells[c] = GLINT
    stamp(cells, rect(21, 4, 22, 10), ACCENT)
    return cells


def cowboyhat(cells):
    stamp(cells, ellipse(15.0, 5.5, 9.5, 1.9) | rect(11, 1, 19, 4), ACCENT)
    for c in rect(11, 3, 19, 3):
        cells[c] = ACCENT_DARK
    return cells


def beret(cells):
    stamp(cells, ellipse(14.0, 3.9, 6.8, 2.1) | {(9, 5), (10, 5)}, ACCENT)
    stamp(cells, {(18, 1)}, ACCENT_DARK)
    return cells


def horns(cells):
    stamp(cells, {(11, 4), (11, 3), (11, 2), (12, 2)}, ACCENT)
    stamp(cells, {(19, 4), (19, 3), (19, 2), (18, 2)}, ACCENT)
    return cells


def antennae(cells):
    stamp(cells, {(12, 4), (12, 3), (11, 2)}, ACCENT_DARK)
    stamp(cells, {(18, 4), (18, 3), (19, 2)}, ACCENT_DARK)
    stamp(cells, {(10, 1), (11, 1)}, ACCENT)
    stamp(cells, {(19, 1), (20, 1)}, ACCENT)
    return cells


def innertube(cells):
    """A ring around the float. Only the front arc is drawn — the back of the
    tube would be hidden behind the duck anyway."""
    outer = ellipse(21.0, 24.0, 17.5, 5.2)
    inner = ellipse(21.0, 24.0, 11.5, 2.4)
    band = {c for c in outer - inner
            if c[1] >= 23 or c[0] <= 6 or c[0] >= 35}
    for c in band:
        cells[c] = ACCENT
    for c in inner_edge(band):
        cells[c] = OUTLINE
    for c in band:
        if c[1] >= 26 and cells.get(c) == ACCENT:
            cells[c] = ACCENT_DARK
    return cells


def propeller(cells):
    stamp(cells, rect(10, 5, 20, 5) | rect(11, 4, 19, 4) | rect(13, 3, 17, 3), ACCENT)
    stamp(cells, {(15, 2)}, ACCENT_DARK)
    stamp(cells, rect(8, 1, 22, 1), ACCENT_DARK)
    return cells


def laurel(cells):
    left = {(8, 5), (9, 5), (9, 4), (10, 4), (10, 3), (11, 3), (11, 2), (12, 2)}
    right = {(22, 5), (21, 5), (21, 4), (20, 4), (20, 3), (19, 3),
             (19, 2), (18, 2)}
    stamp(cells, left | right, ACCENT)
    return cells


def S(id, name, accessory, body, beak, cheek, bg0, bg1, accent, accent_dark,
      ink, font, water, night, upper=False):
    return dict(id=id, name=name, accessory=accessory, body=body, beak=beak,
                cheek=cheek, bg0=bg0, bg1=bg1, accent=accent,
                accent_dark=accent_dark, ink=ink, font=font, water=water,
                night=night, upper=upper)


STYLES = [
    S("classic",  "Ducky",   tuft,       "F2D91C", "E8621F", "F0389E", "7CC9F0", "BFE7FA", "FFE066", "C2185B", "16324F", "rounded",    "3FA9E0", False),
    S("mint",     "Ribbon",      bow,        "9BE8C8", "F2994A", "FF7BA9", "2E5E52", "5C9A85", "FFD1E3", "E85D93", "EAF7F1", "default",    "1F4A40", True, upper=True),
    S("blossom",  "Daisy",   flower,     "FFC7DE", "F2994A", "E85D93", "FFEAF3", "FFD0E6", "FFFFFF", "FFC94D", "8C3A5E", "serif",      "F5A8CC", False),
    S("midnight", "Frosty",  beanie,     "9BAEF0", "F2B04A", "C77DFF", "1B1B3A", "40356E", "B8C4FF", "5A4FCF", "E6EAFF", "rounded",    "141230", True),
    S("cocoa",    "Cozy",     scarf,      "DCA96B", "D9622E", "E0577E", "3E2B23", "7A5540", "E8574E", "A5322B", "F5E3D0", "serif",      "2C1D18", True),
    S("lemon",    "Dapper",     tophat,     "FFE066", "F2994A", "FF6F91", "FFF9E3", "FFEDB0", "5AA9E6", "2E6DA4", "8A6A1F", "monospaced", "FFD98A", False, upper=True),
    S("royal",    "Royal",     crown,      "F2D91C", "E8621F", "F0389E", "3B1E6B", "6E45A8", "FFD966", "B8860B", "F5E6B8", "serif",      "2A1450", True, upper=True),
    S("bubblegum", "Birthday", partyhat,  "FFA3D4", "F2994A", "E83E8C", "FFE7F5", "FFC7E6", "7EE0E0", "2FB5B5", "A8306B", "rounded",    "F79FD0", False),
    S("cloud",    "Angel",     halo,       "FDFDFD", "F2B04A", "FFA0C0", "9FD4F0", "D9EFFA", "FFE066", "E0A800", "3D6B8A", "default",    "6FB8E0", False),
    S("cool",     "Cool",      sunglasses, "F2D91C", "E8621F", "F0389E", "2BB5A0", "7FDFCE", "F2F2F2", "1F2933", "0E3B36", "monospaced", "17968A", False, upper=True),
    S("moss",     "Sprout",      sprout,     "CBE86B", "F2994A", "E86A9A", "2F4A2E", "5E8A55", "8FD14F", "3E6B37", "E8F5D0", "rounded",    "203A22", True),
    S("sunny",    "Sporty",     visor,      "FFD93D", "E8621F", "FF7BA9", "58C0EE", "A8E4FB", "FF6B4A", "B83B22", "10394F", "rounded",    "2F9BD1", False),
    S("corsair",  "Pirate",   bandana,    "E3C08A", "D9622E", "E0577E", "16323C", "2F5C63", "D64545", "8C2626", "EAF4F2", "serif",      "0E2229", True, upper=True),
    S("kitchen",  "Chef",   chefhat,    "FFF0C7", "F2994A", "FF9BB0", "F5EDE0", "E8DBC6", "FFFFFF", "C9A227", "6B5730", "serif",      "D9C9A8", False),
    S("arcane",   "Wizard",    wizardhat,  "C79BF0", "F2B04A", "FF7BD5", "241040", "51268C", "8FE3FF", "3A1D70", "F0E4FF", "serif",      "170A2B", True, upper=True),
    S("reef",     "Scuba",      snorkel,    "7FE3D8", "F2994A", "FF7BA9", "1E7A8C", "63C6D6", "FFE066", "0E4B57", "05323B", "monospaced", "13606E", False),
    S("prairie",  "Cowboy",   cowboyhat,  "E8B96B", "D9622E", "E0577E", "E39B5C", "F5D3A8", "8C4A2F", "5E2E1B", "42210F", "serif",      "C4713C", False, upper=True),
    S("atelier",  "Artist",   beret,      "F2B8C6", "E8621F", "E85D93", "2B2F45", "555B7A", "E8574E", "9E2F2A", "F5E9EE", "serif",      "1B1E2E", True),
    S("ember",    "Mischief",     horns,      "FF9E5E", "D94A1F", "E0577E", "3B0F14", "7A2320", "FF4D4D", "8C1C1C", "FFD9C4", "rounded",    "2A0A0E", True, upper=True),
    S("cosmos",   "Alien",    antennae,   "B8F0C6", "F2B04A", "C77DFF", "0D1030", "2B2F6B", "7CFFB2", "1F6B45", "DFF7E6", "monospaced", "070A22", True),
    S("lagoon",   "Floaty",    innertube,  "FFDE59", "E8621F", "F0389E", "36C9D6", "9BEDF2", "FF6B9D", "C2185B", "064450", "rounded",    "1FA3B5", False),
    S("breeze",   "Whirly",    propeller,  "9BD4FF", "F2994A", "FF8FB0", "FFF6D6", "FFE9A8", "FF6B6B", "C23B3B", "3A5E7A", "rounded",    "7FC4E8", False),
    S("olive",    "Laurel",     laurel,     "F2E8D0", "D9A02E", "E0938A", "3A4227", "6B7A45", "E8D98A", "8C7A2E", "F0F2DC", "serif",      "252B18", True, upper=True),
]


def darken(hexcolor, factor=0.80):
    r, g, b = hexrgb(hexcolor)
    return "%02X%02X%02X" % (round(r * factor), round(g * factor), round(b * factor))


def lighten(hexcolor, factor=0.46):
    r, g, b = hexrgb(hexcolor)
    mix = lambda c: round(c + (255 - c) * factor)
    return "%02X%02X%02X" % (mix(r), mix(g), mix(b))


def style_palette(row):
    return {
        OUTLINE: "17171A", GLINT: "FFFFFF", BODY: row["body"],
        SHADE: darken(row["body"], 0.74), LIGHT: lighten(row["body"]),
        BEAK: row["beak"], BEAK_DARK: darken(row["beak"], 0.72),
        CHEEK: row["cheek"], ACCENT: row["accent"],
        ACCENT_DARK: row["accent_dark"], SHADOW: darken(row["water"], 0.62),
    }, row["bg0"], row["bg1"]


def style_cells(row, blink=False, shadow=True):
    cells = row["accessory"](build_base(blink=blink))
    return with_shadow(cells) if shadow else cells


# ---------------------------------------------------------------- rendering

def hexrgb(h):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def png(path, pixels, width, height):
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw += bytes(pixels[y][x])

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    blob = b"\x89PNG\r\n\x1a\n"
    blob += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    blob += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    blob += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(blob)


def blit(pixels, grid, palette, ox, oy, cell, width, height):
    for y, line in enumerate(grid):
        for x, token in enumerate(line):
            if token == ".":
                continue
            color = hexrgb(palette[token])
            for yy in range(cell):
                py = oy + y * cell + yy
                if not (0 <= py < height):
                    continue
                rowpix = pixels[py]
                for xx in range(cell):
                    px = ox + x * cell + xx
                    if 0 <= px < width:
                        rowpix[px] = color


def contact_sheet(path, cell=8, cols=4, pad=6, blink=False):
    tile_w, tile_h = W * cell + pad * 2, H * cell + pad * 2
    rows = (len(STYLES) + cols - 1) // cols
    width, height = tile_w * cols, tile_h * rows
    pixels = [[(20, 20, 24)] * width for _ in range(height)]

    for i, row in enumerate(STYLES):
        palette, bg0, bg1 = style_palette(row)
        grid = _grid(style_cells(row, blink=blink), W, H)
        ox, oy = (i % cols) * tile_w, (i // cols) * tile_h
        top, bottom = hexrgb(bg0), hexrgb(bg1)
        for y in range(tile_h):
            t = y / (tile_h - 1)
            bg = tuple(round(top[k] + (bottom[k] - top[k]) * t) for k in range(3))
            for x in range(tile_w):
                pixels[oy + y][ox + x] = bg
        blit(pixels, grid, palette, ox + pad, oy + pad, cell, width, height)

    png(path, pixels, width, height)
    print(f"wrote {path} ({width}x{height}, {len(STYLES)} styles)")


def scene_sheet(path, cell=10):
    parts = [cloud_small_sprite(), cloud_mid_sprite(), cloud_long_sprite(),
             sun_sprite(), moon_sprite(), star_sprite(), star_big_sprite(),
             wave_sprite()]
    palette, _, _ = style_palette(STYLES[0])
    gap = 2
    width = sum((len(p[0]) + gap) for p in parts) * cell
    height = max(len(p) for p in parts) * cell + cell * 2
    pixels = [[(60, 120, 180)] * width for _ in range(height)]
    x = cell
    for p in parts:
        blit(pixels, p, palette, x, cell, cell, width, height)
        x += (len(p[0]) + gap) * cell
    png(path, pixels, width, height)
    print(f"wrote {path}")


def app_icon(path, style_id="classic", size=1024, cell=28):
    row = next(r for r in STYLES if r["id"] == style_id)
    palette, bg0, bg1 = style_palette(row)
    grid = _grid(style_cells(row), W, H)
    top, bottom = hexrgb(bg0), hexrgb(bg1)
    pixels = []
    for y in range(size):
        t = y / (size - 1)
        bg = tuple(round(top[k] + (bottom[k] - top[k]) * t) for k in range(3))
        pixels.append([bg] * size)
    blit(pixels, grid, palette,
         (size - W * cell) // 2, (size - H * cell) // 2, cell, size, size)
    png(path, pixels, size, size)
    print(f"wrote {path} ({size}x{size}, {style_id} style)")


def emit_swift(path):
    L = [
        "// Generated by tools/duck_forge.py — do not edit by hand.",
        "// Regenerate with: python3 tools/duck_forge.py swift",
        "",
        "extension DuckStyle {",
        f"    static let spriteColumns = {W}",
        f"    static let spriteRows = {H}",
        "",
        "    static let all: [DuckStyle] = [",
    ]
    for row in STYLES:
        L += [
            "        DuckStyle(",
            f'            id: "{row["id"]}", name: "{row["name"]}",',
            f'            body: 0x{row["body"]}, shade: 0x{darken(row["body"], 0.74)},'
            f' light: 0x{lighten(row["body"])},',
            f'            beak: 0x{row["beak"]}, beakDark: 0x{darken(row["beak"], 0.72)},'
            f' cheek: 0x{row["cheek"]},',
            f'            accent: 0x{row["accent"]}, accentDark: 0x{row["accent_dark"]},',
            f'            bgTop: 0x{row["bg0"]}, bgBottom: 0x{row["bg1"]}, ink: 0x{row["ink"]},',
            f'            water: 0x{row["water"]}, waterDeep: 0x{darken(row["water"], 0.72)},',
            f'            font: .{row["font"]}, uppercaseCaption: {str(row["upper"]).lower()},'
            f' night: {str(row["night"]).lower()},',
            "            rows: [",
        ]
        for g in _grid(style_cells(row), W, H):
            L.append(f'                "{g}",')
        L += ["            ],", "            blinkRows: ["]
        for g in _grid(style_cells(row, blink=True), W, H):
            L.append(f'                "{g}",')
        L += ["            ]", "        ),"]
    L += ["    ]", "}", ""]

    L += ["/// Scene furniture, recoloured from whichever style is active.",
          "enum DuckDecor {"]
    for name, grid in [("cloudSmall", cloud_small_sprite()),
                       ("cloudMid", cloud_mid_sprite()),
                       ("cloudLong", cloud_long_sprite()),
                       ("sun", sun_sprite()), ("moon", moon_sprite()),
                       ("star", star_sprite()), ("starBig", star_big_sprite()),
                       ("wave", wave_sprite())]:
        L.append(f"    static let {name}: [String] = [")
        for g in grid:
            L.append(f'        "{g}",')
        L.append("    ]")
    L += ["}", ""]

    with open(path, "w") as f:
        f.write("\n".join(L))
    print(f"wrote {path} ({len(STYLES)} styles, {W}x{H} sprites)")


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "preview"
    arg = sys.argv[2] if len(sys.argv) > 2 else None
    if mode == "icon":
        app_icon(arg or "DuckDays/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
    elif mode == "swift":
        emit_swift(arg or "Shared/DuckStyles+Generated.swift")
    elif mode == "scene":
        scene_sheet(arg or "decor.png")
    elif mode == "blink":
        contact_sheet(arg or "ducks-blink.png", blink=True)
    elif mode == "small":
        contact_sheet(arg or "ducks-small.png", cell=3, cols=6, pad=4)
    else:
        contact_sheet(arg or "ducks.png")