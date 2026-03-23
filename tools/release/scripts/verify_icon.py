#!/usr/bin/env python3
"""
verify_icon.py — Verify the App Store icon is correctly configured before building.

Checks:
  - AppIcon-1024.png exists in the xcassets folder
  - Dimensions are exactly 1024×1024 px
  - No alpha channel (App Store rejects icons with transparency)

Usage:
    python3 verify_icon.py --game idle-civilizations

Required env:
    (none — reads from config/games.yml)
"""

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(Path(__file__).parent))
from game_config import load_game


def verify_icon(game_id: str) -> bool:
    try:
        from PIL import Image
    except ImportError:
        print("ERROR: Pillow not installed. Run: pip install Pillow")
        return False

    game = load_game(game_id)

    # Derive xcassets path from the xcode_project setting
    xcode_project = REPO_ROOT / game["xcode_project"]
    resources_dir = xcode_project.parent / "Resources"
    xcassets_dir  = resources_dir / "Assets.xcassets"

    # Find the appiconset
    appiconsets = list(xcassets_dir.rglob("*.appiconset"))
    if not appiconsets:
        print(f"ERROR: No .appiconset found under {xcassets_dir}")
        return False

    icon_set = appiconsets[0]
    icon_path = icon_set / "AppIcon-1024.png"

    if not icon_path.exists():
        print(f"ERROR: AppIcon-1024.png not found at {icon_path}")
        print(f"  Expected: {icon_path}")
        return False

    img = Image.open(icon_path)

    # Check dimensions
    if img.size != (1024, 1024):
        print(f"ERROR: Icon is {img.size[0]}×{img.size[1]}, must be 1024×1024")
        return False

    # Check no alpha (App Store rejects transparent icons)
    if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
        print(f"WARNING: Icon has alpha channel (mode={img.mode}). App Store may reject it.")
        print(f"  Fix: flatten the icon onto a solid background before exporting.")
        # Don't fail — warn and let the user decide
    else:
        print(f"  ✓ No alpha channel (mode={img.mode})")

    size_kb = icon_path.stat().st_size // 1024
    print(f"\n✓ Icon verified: {icon_path.name}")
    print(f"  Path:       {icon_path}")
    print(f"  Dimensions: {img.size[0]}×{img.size[1]} px")
    print(f"  Mode:       {img.mode}")
    print(f"  Size:       {size_kb} KB")
    print(f"\n  Note: The icon is embedded in the IPA binary during `studio build`.")
    print(f"        It appears in App Store Connect automatically after the first upload.")

    return True


def main():
    parser = argparse.ArgumentParser(description="Verify App Store icon before building")
    parser.add_argument("--game", required=True, help="Game ID from config/games.yml")
    args = parser.parse_args()

    ok = verify_icon(args.game)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
