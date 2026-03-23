#!/usr/bin/env python3
"""
upload_screenshots.py — Upload App Store screenshots directly via ASC API.

Uploads all PNG files from metadata/{game}/screenshots/{locale}/{files}
to App Store Connect for the PREPARE_FOR_SUBMISSION version.

Device type is determined from image dimensions:
  1284×2778  → APP_IPHONE_65   (iPhone 6.5")
  1242×2208  → APP_IPHONE_55   (iPhone 5.5")
  2048×2732  → APP_IPAD_PRO_3GEN_129  (iPad Pro 12.9")

Usage:
    python3 upload_screenshots.py --game idle-civilizations [--dry-run]

Required env:
    ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH
"""

import argparse
import hashlib
import json
import math
import sys
import time
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).parent / "lib"))
from asc_client import ASCClient
from game_config import load_game

# Maps (width, height) → ASC screenshotDisplayType
DIMENSION_MAP = {
    (1284, 2778): "APP_IPHONE_65",
    (1242, 2208): "APP_IPHONE_55",
    (2048, 2732): "APP_IPAD_PRO_3GEN_129",
    # Portrait variants
    (2778, 1284): "APP_IPHONE_65",
    (2208, 1242): "APP_IPHONE_55",
    (2732, 2048): "APP_IPAD_PRO_3GEN_129",
    # Additional common sizes
    (1290, 2796): "APP_IPHONE_67",
    (1170, 2532): "APP_IPHONE_61",
    (1179, 2556): "APP_IPHONE_61",
    (2064, 2752): "APP_IPAD_PRO_3GEN_129",
}

REPO_ROOT = Path(__file__).resolve().parents[3]


def get_image_dimensions(path: Path) -> tuple[int, int]:
    """Read PNG dimensions without Pillow — parse the IHDR chunk directly."""
    with open(path, "rb") as f:
        f.read(8)   # PNG signature
        f.read(4)   # IHDR length
        f.read(4)   # "IHDR"
        w = int.from_bytes(f.read(4), "big")
        h = int.from_bytes(f.read(4), "big")
    return w, h


def md5_b64(path: Path) -> str:
    import base64
    data = path.read_bytes()
    digest = hashlib.md5(data).digest()
    return base64.b64encode(digest).decode()


def upload_asset(client: ASCClient, reservation: dict, file_path: Path) -> None:
    """Upload a file using the upload operations returned by ASC."""
    ops = reservation.get("uploadOperations", [])
    data = file_path.read_bytes()
    size = len(data)

    for op in ops:
        offset = op["offset"]
        length = op["length"]
        chunk = data[offset: offset + length]
        method = op["method"]
        url = op["url"]
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        resp = requests.request(method, url, headers=headers, data=chunk)
        resp.raise_for_status()


def commit_screenshot(client: ASCClient, screenshot_id: str, file_path: Path) -> None:
    size = file_path.stat().st_size
    checksum = md5_b64(file_path)
    client.patch(
        f"/v1/appScreenshots/{screenshot_id}",
        {
            "data": {
                "type": "appScreenshots",
                "id": screenshot_id,
                "attributes": {
                    "uploaded": True,
                    "sourceFileChecksum": checksum,
                },
            }
        },
    )


def find_or_create_screenshot_set(
    client: ASCClient, loc_id: str, display_type: str
) -> str:
    """Return the id of the screenshot set for this locale+displayType, creating if needed."""
    sets = client.get(
        f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets"
    ).get("data", [])
    for s in sets:
        if s["attributes"]["screenshotDisplayType"] == display_type:
            return s["id"]
    # Create it
    resp = client.post(
        "/v1/appScreenshotSets",
        {
            "data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": display_type},
                "relationships": {
                    "appStoreVersionLocalization": {
                        "data": {"type": "appStoreVersionLocalizations", "id": loc_id}
                    }
                },
            }
        },
    )
    return resp["data"]["id"]


def delete_existing_screenshots(client: ASCClient, set_id: str) -> None:
    shots = client.get(f"/v1/appScreenshotSets/{set_id}/appScreenshots").get("data", [])
    for s in shots:
        client.delete(f"/v1/appScreenshots/{s['id']}")
        time.sleep(0.2)


def upload_screenshot(
    client: ASCClient, set_id: str, file_path: Path, display_type: str, dry_run: bool
) -> None:
    size = file_path.stat().st_size
    if dry_run:
        print(f"    [dry-run] would upload {file_path.name} → {display_type}")
        return

    # Reserve upload slot
    resp = client.post(
        "/v1/appScreenshots",
        {
            "data": {
                "type": "appScreenshots",
                "attributes": {
                    "fileName": file_path.name,
                    "fileSize": size,
                },
                "relationships": {
                    "appScreenshotSet": {
                        "data": {"type": "appScreenshotSets", "id": set_id}
                    }
                },
            }
        },
    )
    screenshot_id = resp["data"]["id"]
    reservation = resp["data"]["attributes"]

    # Upload bytes via the presigned URL(s)
    upload_asset(client, reservation, file_path)

    # Commit
    commit_screenshot(client, screenshot_id, file_path)
    print(f"    ✓ {file_path.name}")


def run(game_id: str, dry_run: bool) -> None:
    game = load_game(game_id)
    client = ASCClient.from_env()
    app_id = game["app_id"]

    # Find version in PREPARE_FOR_SUBMISSION
    versions = client.get_all(
        f"/v1/apps/{app_id}/appStoreVersions",
        params={"filter[appStoreState]": "PREPARE_FOR_SUBMISSION", "filter[platform]": "IOS"},
    )
    if not versions:
        print("ERROR: No version in PREPARE_FOR_SUBMISSION state.")
        sys.exit(1)
    version = versions[0]
    version_id = version["id"]
    version_str = version["attributes"]["versionString"]
    print(f"Target: v{version_str} (id={version_id})")

    # Get localizations
    locs = client.get_all(f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")
    loc_map = {loc["attributes"]["locale"]: loc["id"] for loc in locs}
    print(f"Localizations: {list(loc_map.keys())}")

    screenshots_dir = REPO_ROOT / game["metadata_path"] / "screenshots"
    if not screenshots_dir.exists():
        print(f"ERROR: Screenshots dir not found: {screenshots_dir}")
        sys.exit(1)

    total = 0
    for locale_dir in sorted(screenshots_dir.iterdir()):
        if not locale_dir.is_dir():
            continue
        locale = locale_dir.name
        if locale not in loc_map:
            print(f"  Skipping locale {locale} (not in ASC localizations)")
            continue
        loc_id = loc_map[locale]

        # Group PNGs by display type
        by_type: dict[str, list[Path]] = {}
        for png in sorted(locale_dir.rglob("*.png")):
            if png.name.startswith("."):
                continue
            try:
                w, h = get_image_dimensions(png)
            except Exception as e:
                print(f"  WARNING: Could not read dimensions of {png.name}: {e}")
                continue
            display_type = DIMENSION_MAP.get((w, h))
            if not display_type:
                print(f"  WARNING: Unknown dimensions {w}×{h} for {png.name} — skipping")
                continue
            by_type.setdefault(display_type, []).append(png)

        print(f"\n[{locale}]")
        for display_type, files in sorted(by_type.items()):
            print(f"  {display_type}: {len(files)} screenshots")
            set_id = find_or_create_screenshot_set(client, loc_id, display_type)
            if not dry_run:
                delete_existing_screenshots(client, set_id)
            for f in sorted(files):
                upload_screenshot(client, set_id, f, display_type, dry_run)
                total += 1

    print(f"\n✓ Uploaded {total} screenshots" if not dry_run else f"\n[dry-run] Would upload {total} screenshots")


def main():
    parser = argparse.ArgumentParser(description="Upload App Store screenshots via ASC API")
    parser.add_argument("--game", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    run(args.game, args.dry_run)


if __name__ == "__main__":
    main()
