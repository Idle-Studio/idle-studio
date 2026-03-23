#!/usr/bin/env python3
"""
sync_gamecenter.py — Sync Game Center leaderboards and achievements from
ThemePackage JSON to App Store Connect.

Source of truth: games/<name>/idle-civilizations.json
  - "leaderboards": { "globalTokens": "com.idlestudio...", ... }
  - "achievements": [ { "id": "reach_bronze", "displayName": "...", ... } ]

Strategy:
  - GET existing Game Center leaderboards and achievements via ASC API
  - Diff: create missing, skip existing (manual edits in ASC are preserved)
  - Never delete — deletions require removing from all existing versions first
  - Supports --dry-run

Usage:
    python3 sync_gamecenter.py --game idle-civilizations [--dry-run]

Required env:
    ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH
"""

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / "lib"))
from asc_client import ASCClient
from game_config import load_game


def load_theme(path: Path) -> dict:
    with open(path) as f:
        return json.load(f)


def get_or_create_gc_detail(client: ASCClient, app_id: str, dry_run: bool) -> str:
    """Return the gameCenterDetail ID for the app, creating it if absent."""
    # The collection endpoint is not allowed; fetch via the app relationship instead
    resp = client.get(f"/v1/apps/{app_id}/gameCenterDetail")
    data = resp.get("data")
    if data:
        gc_id = data["id"]
        print(f"  Game Center detail: {gc_id}")
        return gc_id
    print("  Creating Game Center detail record...")
    if dry_run:
        return "DRY_RUN_GC_ID"
    resp = client.post("/v1/gameCenterDetails", {
        "data": {
            "type": "gameCenterDetails",
            "relationships": {
                "app": {"data": {"type": "apps", "id": app_id}}
            }
        }
    })
    return resp["data"]["id"]


def sync_leaderboards(client: ASCClient, gc_id: str, leaderboards: dict, dry_run: bool):
    """leaderboards is the dict from ThemePackage: {"globalTokens": "com.id...", ...}"""
    if not leaderboards:
        return
    print(f"\n→ Syncing {len(leaderboards)} leaderboard(s)...")

    if gc_id == "DRY_RUN_GC_ID":
        existing_raw = []
    else:
        existing_raw = client.get_all(f"/v1/gameCenterDetails/{gc_id}/gameCenterLeaderboards")
    existing_ids = {lb["attributes"]["referenceName"] for lb in existing_raw}
    existing_product_ids = {lb["attributes"].get("vendorIdentifier") for lb in existing_raw}

    for key, product_id in leaderboards.items():
        ref_name = key  # e.g. "globalTokens"
        if product_id in existing_product_ids:
            print(f"  EXISTS {product_id}")
            continue
        display_name = {
            "globalTokens":  "Legacy Tokens — Global",
            "weeklyGold":    "Weekly Gold — Global",
            "countryTokens": "Legacy Tokens — Country",
        }.get(key, key.replace("_", " ").title())

        print(f"  CREATE {product_id} — {display_name}")
        if not dry_run:
            resp = client.post("/v1/gameCenterLeaderboards", {
                "data": {
                    "type": "gameCenterLeaderboards",
                    "attributes": {
                        "referenceName":    ref_name,
                        "vendorIdentifier": product_id,
                        "submissionType":   "BEST_SCORE",
                        "scoreSortType":    "DESC",
                        "defaultFormatter": "INTEGER",
                    },
                    "relationships": {
                        "gameCenterDetail": {
                            "data": {"type": "gameCenterDetails", "id": gc_id}
                        }
                    }
                }
            })
            lb_id = resp["data"]["id"]
            # Add en-US localization
            client.post("/v1/gameCenterLeaderboardLocalizations", {
                "data": {
                    "type": "gameCenterLeaderboardLocalizations",
                    "attributes": {
                        "locale": "en-US",
                        "name":   display_name,
                    },
                    "relationships": {
                        "gameCenterLeaderboard": {
                            "data": {"type": "gameCenterLeaderboards", "id": lb_id}
                        }
                    }
                }
            })


def sync_achievements(client: ASCClient, gc_id: str, achievements: list, dry_run: bool):
    if not achievements:
        return
    print(f"\n→ Syncing {len(achievements)} achievement(s)...")

    if gc_id == "DRY_RUN_GC_ID":
        existing_raw = []
    else:
        existing_raw = client.get_all(f"/v1/gameCenterDetails/{gc_id}/gameCenterAchievements")
    existing_ref_names = {a["attributes"]["referenceName"] for a in existing_raw}

    for ach in achievements:
        ach_id   = ach["id"]      # e.g. "reach_bronze"
        name     = ach["displayName"]
        desc     = ach.get("description", "")
        points   = ach.get("points", 10)
        hidden   = ach.get("isSecret", False)

        if ach_id in existing_ref_names:
            print(f"  EXISTS {ach_id}")
            continue

        print(f"  CREATE {ach_id} — {name} ({points} pts)")
        if not dry_run:
            vendor_id = f"com.idlestudio.idleciv.achievement.{ach_id}"
            resp = client.post("/v1/gameCenterAchievements", {
                "data": {
                    "type": "gameCenterAchievements",
                    "attributes": {
                        "referenceName":    ach_id,
                        "vendorIdentifier": vendor_id,
                        "points":           points,
                        "showBeforeEarned": not hidden,
                        "repeatable":       False,
                    },
                    "relationships": {
                        "gameCenterDetail": {
                            "data": {"type": "gameCenterDetails", "id": gc_id}
                        }
                    }
                }
            })
            ach_asc_id = resp["data"]["id"]
            client.post("/v1/gameCenterAchievementLocalizations", {
                "data": {
                    "type": "gameCenterAchievementLocalizations",
                    "attributes": {
                        "locale":            "en-US",
                        "name":              name,
                        "beforeEarnedDescription": desc,
                        "afterEarnedDescription":  desc,
                    },
                    "relationships": {
                        "gameCenterAchievement": {
                            "data": {"type": "gameCenterAchievements", "id": ach_asc_id}
                        }
                    }
                }
            })


def main():
    parser = argparse.ArgumentParser(
        description="Sync Game Center config from ThemePackage JSON to App Store Connect"
    )
    parser.add_argument("--game",    required=True, help="Game ID from config/games.yml")
    parser.add_argument("--dry-run", action="store_true", help="Print diff without making changes")
    args = parser.parse_args()

    game = load_game(args.game)
    app_id = game.get("app_id")
    if not app_id:
        print("ERROR: app_id is not set in config/games.yml for this game.")
        sys.exit(1)

    theme = load_theme(game["theme_json_path"])

    print(f"Game:   {game['display_name']} ({game['bundle_id']})")
    print(f"App ID: {app_id}")
    if args.dry_run:
        print("Mode:   DRY RUN (no changes will be made)\n")

    client = ASCClient.from_env()

    gc_id = get_or_create_gc_detail(client, app_id, args.dry_run)
    sync_leaderboards(client, gc_id, theme.get("leaderboards", {}), args.dry_run)
    sync_achievements(client, gc_id, theme.get("achievements", []), args.dry_run)

    print("\n✓ Game Center sync complete")


if __name__ == "__main__":
    main()
