#!/usr/bin/env python3
"""
Generate all Idle Civilizations game assets into the Xcode asset catalog.

Usage:
    pip3 install Pillow
    python3 tools/generate_assets.py

Produces 53 PNG images (512×512) placed in correct .imageset folders inside
apps/IdleCivilizations/Resources/Assets.xcassets.
"""

from PIL import Image, ImageDraw, ImageFont
import json, os, math

REPO_ROOT  = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
XCASSETS   = os.path.join(REPO_ROOT, "apps/IdleCivilizations/Resources/Assets.xcassets")
EMOJI_FONT = "/System/Library/Fonts/Apple Color Emoji.ttc"
SIZE       = 512

ERA_COLORS = {
    "stone_age":             ("#8B7355", "#4A3520"),
    "bronze_age":            ("#CD7F32", "#7A3E10"),
    "ancient_empires":       ("#C4A44D", "#6B4A08"),
    "classical_world":       ("#5B8DB8", "#1E4A70"),
    "medieval_era":          ("#6B4F7C", "#2E1A40"),
    "renaissance":           ("#C44B24", "#6A1A08"),
    "industrial_revolution": ("#607080", "#252E38"),
    "space_age":             ("#1E4A7E", "#050E20"),
}

# (asset_name, emoji, era_key)
ASSETS = [
    # ── Stone Age ──────────────────────────────────────────────────────────────
    ("unit_campfire",             "🔥", "stone_age"),
    ("unit_berry_gatherer",       "🍇", "stone_age"),
    ("unit_fishing_spot",         "🎣", "stone_age"),
    ("unit_hunting_lodge",        "🏹", "stone_age"),
    ("unit_tribal_elder",         "🧙", "stone_age"),
    # ── Bronze Age ─────────────────────────────────────────────────────────────
    ("unit_mine",                 "⛏️", "bronze_age"),
    ("unit_smelter",              "🔨", "bronze_age"),
    ("unit_marketplace",          "🏪", "bronze_age"),
    ("unit_warship",              "⚓", "bronze_age"),
    ("unit_bronze_palace",        "🏛️", "bronze_age"),
    # ── Ancient Empires ────────────────────────────────────────────────────────
    ("unit_grain_farm",           "🌾", "ancient_empires"),
    ("unit_aqueduct",             "🌊", "ancient_empires"),
    ("unit_amphitheatre",         "🎭", "ancient_empires"),
    ("unit_army_barracks",        "⚔️", "ancient_empires"),
    ("unit_great_pyramid",        "🔺", "ancient_empires"),
    # ── Classical World ────────────────────────────────────────────────────────
    ("unit_forum",                "📜", "classical_world"),
    ("unit_colosseum",            "🏟️", "classical_world"),
    ("unit_temple",               "🕌", "classical_world"),
    ("unit_silk_road_bazaar",     "🧣", "classical_world"),
    ("unit_roman_legions",        "🛡️", "classical_world"),
    # ── Medieval Era ───────────────────────────────────────────────────────────
    ("unit_mill",                 "🌾", "medieval_era"),
    ("unit_castle",               "🏰", "medieval_era"),
    ("unit_cathedral",            "⛪", "medieval_era"),
    ("unit_knights_order",        "🗡️", "medieval_era"),
    ("unit_black_prince",         "👑", "medieval_era"),
    # ── Renaissance ────────────────────────────────────────────────────────────
    ("unit_printing_press",       "📖", "renaissance"),
    ("unit_university",           "🎓", "renaissance"),
    ("unit_art_studio",           "🎨", "renaissance"),
    ("unit_shipyard",             "⛵", "renaissance"),
    ("unit_da_vinci_workshop",    "✏️", "renaissance"),
    # ── Industrial Revolution ──────────────────────────────────────────────────
    ("unit_coal_mine",            "🏭", "industrial_revolution"),
    ("unit_steam_engine",         "🚂", "industrial_revolution"),
    ("unit_railway_line",         "🛤️", "industrial_revolution"),
    ("unit_factory",              "🔧", "industrial_revolution"),
    ("unit_power_station",        "⚡", "industrial_revolution"),
    # ── Space Age ──────────────────────────────────────────────────────────────
    ("unit_radio_tower",          "📡", "space_age"),
    ("unit_computer_lab",         "💻", "space_age"),
    ("unit_satellite",            "🛰️", "space_age"),
    ("unit_space_rocket",         "🚀", "space_age"),
    ("unit_lunar_base",           "🌕", "space_age"),
    # ── Milestones / Wonders ───────────────────────────────────────────────────
    ("ms_lascaux_cave",           "🦬", "stone_age"),
    ("ms_stonehenge",             "🗿", "bronze_age"),
    ("ms_great_library",          "📚", "ancient_empires"),
    ("ms_parthenon",              "🏛️", "classical_world"),
    ("ms_notre_dame",             "⛪", "medieval_era"),
    ("ms_sistine_chapel",         "🖼️", "renaissance"),
    ("ms_crystal_palace",         "🔮", "industrial_revolution"),
    ("ms_international_space_station", "🛸", "space_age"),
    # ── Character Portraits ────────────────────────────────────────────────────
    ("char_og_the_elder",         "👴", "stone_age"),
    ("char_hammurabi",            "📜", "bronze_age"),
    ("char_julius_caesar",        "⚔️", "classical_world"),
    ("char_da_vinci",             "🎨", "renaissance"),
    ("char_nikola_tesla",         "⚡", "industrial_revolution"),
]


def hex_to_rgb(h: str) -> tuple:
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def make_gradient(size: int, top_hex: str, bot_hex: str) -> Image.Image:
    """Smooth vertical gradient, top→bottom."""
    img = Image.new("RGBA", (size, size))
    draw = ImageDraw.Draw(img)
    r1, g1, b1 = hex_to_rgb(top_hex)
    r2, g2, b2 = hex_to_rgb(bot_hex)
    for y in range(size):
        t = y / (size - 1)
        # Ease-in-out curve for a richer feel
        t = t * t * (3 - 2 * t)
        r = int(r1 + (r2 - r1) * t)
        g = int(g1 + (g2 - g1) * t)
        b = int(b1 + (b2 - b1) * t)
        draw.line([(0, y), (size - 1, y)], fill=(r, g, b, 255))
    return img


def add_inner_glow(img: Image.Image, top_hex: str, size: int) -> Image.Image:
    """Subtle radial inner glow from top-center (light source feel)."""
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    r, g, b = hex_to_rgb(top_hex)
    # Lighten the top-center
    for radius in range(size // 2, 0, -2):
        alpha = int(30 * math.exp(-3.5 * radius / (size / 2)))
        lr = min(255, r + 80)
        lg = min(255, g + 80)
        lb = min(255, b + 80)
        cx, cy = size // 2, size // 4
        draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
                     outline=(lr, lg, lb, alpha), width=2)
    return Image.alpha_composite(img, glow)


def add_vignette(img: Image.Image, size: int) -> Image.Image:
    """Dark edges vignette for depth."""
    vignette = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(vignette)
    max_r = int(size * 0.72)
    for r in range(max_r, 0, -2):
        # Quadratic falloff from edge
        t = 1.0 - (r / max_r)
        alpha = int(110 * t * t)
        cx = cy = size // 2
        draw.ellipse([cx - r, cy - r, cx + r, cy + r],
                     outline=(0, 0, 0, alpha), width=2)
    return Image.alpha_composite(img, vignette)


def draw_emoji_centered(img: Image.Image, emoji: str, size: int, emoji_px: int) -> None:
    """Render Apple Color Emoji centered on img."""
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype(EMOJI_FONT, emoji_px)
    except OSError:
        print(f"  ⚠️  Apple Color Emoji font not found, using fallback")
        font = ImageFont.load_default()

    # Use getbbox for accurate centering
    bbox = draw.textbbox((0, 0), emoji, font=font, embedded_color=True)
    w = bbox[2] - bbox[0]
    h = bbox[3] - bbox[1]
    x = (size - w) // 2 - bbox[0]
    y = (size - h) // 2 - bbox[1]
    # Slight upward shift for visual balance
    y -= int(size * 0.03)
    draw.text((x, y), emoji, font=font, embedded_color=True)


def write_imageset(name: str, img: Image.Image) -> None:
    """Write image + Contents.json into the asset catalog."""
    folder = os.path.join(XCASSETS, f"{name}.imageset")
    os.makedirs(folder, exist_ok=True)

    img_path = os.path.join(folder, f"{name}.png")
    img.save(img_path, "PNG", optimize=True)

    contents = {
        "images": [
            {
                "filename": f"{name}.png",
                "idiom": "universal",
                "scale": "1x"
            }
        ],
        "info": {
            "author": "generate_assets.py",
            "version": 1
        }
    }
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)


def generate_icon(name: str, emoji: str, era: str) -> None:
    top, bot = ERA_COLORS[era]
    img = make_gradient(SIZE, top, bot)
    img = add_inner_glow(img, top, SIZE)
    draw_emoji_centered(img, emoji, SIZE, emoji_px=int(SIZE * 0.56))
    img = add_vignette(img, SIZE)
    write_imageset(name, img)
    print(f"  ✓  {name}  {emoji}")


def main() -> None:
    print(f"Generating {len(ASSETS)} assets → {XCASSETS}\n")
    for name, emoji, era in ASSETS:
        generate_icon(name, emoji, era)
    print(f"\n✅  Done — {len(ASSETS)} assets written.")


if __name__ == "__main__":
    main()
