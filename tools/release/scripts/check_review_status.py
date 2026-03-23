#!/usr/bin/env python3
"""
check_review_status.py — Show App Store review status and recent TestFlight builds.

Polls:
  - GET /v1/apps/{id}/appStoreVersions (most recent versions + review state)
  - GET /v1/builds?filter[app]=... (last 5 builds)

Usage:
    python3 check_review_status.py --game idle-civilizations

Required env:
    ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH
"""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / "lib"))
from asc_client import ASCClient
from game_config import load_game

# Human-readable review state mapping
REVIEW_STATE_LABELS = {
    "PREPARE_FOR_SUBMISSION":        "📝  Prepare for Submission",
    "WAITING_FOR_REVIEW":            "⏳  Waiting for Review",
    "IN_REVIEW":                     "🔍  In Review",
    "PENDING_CONTRACT":              "📃  Pending Contract",
    "WAITING_FOR_EXPORT_COMPLIANCE": "🔒  Waiting for Export Compliance",
    "PENDING_DEVELOPER_RELEASE":     "✅  Approved — Pending Developer Release",
    "PROCESSING_FOR_DISTRIBUTION":   "⚙️   Processing for Distribution",
    "READY_FOR_DISTRIBUTION":        "🚀  Ready for Distribution (Live)",
    "INVALID_BINARY":                "❌  Invalid Binary",
    "REJECTED":                      "🚫  Rejected",
    "METADATA_REJECTED":             "📋  Metadata Rejected",
    "REMOVED_FROM_SALE":             "🔕  Removed from Sale",
    "DEVELOPER_REMOVED_FROM_SALE":   "🔕  Developer Removed from Sale",
    "DEVELOPER_REJECTED":            "↩️   Developer Rejected",
}

BUILD_STATE_LABELS = {
    "PROCESSING":              "⚙️   Processing",
    "FAILED":                  "❌  Failed",
    "INVALID":                 "⛔  Invalid",
    "VALID":                   "✅  Valid — Ready for TestFlight",
    "EXPIRED":                 "🕑  Expired",
}


def print_app_store_versions(client: ASCClient, app_id: str):
    versions = client.get_all(
        f"/v1/apps/{app_id}/appStoreVersions",
        params={"limit": 5, "sort": "-createdDate"}
    )
    print("\n── App Store Versions ────────────────────────────────")
    if not versions:
        print("  No versions found.")
        return
    for v in versions[:5]:
        attrs   = v["attributes"]
        version = attrs.get("versionString", "?")
        state   = attrs.get("appStoreState", "UNKNOWN")
        label   = REVIEW_STATE_LABELS.get(state, f"  {state}")
        created = attrs.get("createdDate", "")[:10]
        print(f"  v{version:10s}  {label}  (created {created})")


def print_testflight_builds(client: ASCClient, app_id: str):
    builds = client.get_all(
        f"/v1/apps/{app_id}/builds",
        params={
            "limit": 10,
            "sort":  "-uploadedDate",
        }
    )
    print("\n── Recent TestFlight Builds ──────────────────────────")
    if not builds:
        print("  No builds found.")
        return
    for b in builds[:10]:
        attrs    = b["attributes"]
        version  = attrs.get("version", "?")
        state    = attrs.get("processingState", "UNKNOWN")
        label    = BUILD_STATE_LABELS.get(state, f"  {state}")
        uploaded = attrs.get("uploadedDate", "")[:16].replace("T", " ")
        beta_ok  = "🟢 external" if attrs.get("externalBuildState") == "IN_BETA_REVIEW" or \
                   attrs.get("externalBuildState") == "READY_FOR_BETA_SUBMISSION" else ""
        print(f"  build {version:10s}  {label:<40s}  {uploaded}  {beta_ok}")


def main():
    parser = argparse.ArgumentParser(description="Show App Store review status and TestFlight builds")
    parser.add_argument("--game", required=True, help="Game ID from config/games.yml")
    args = parser.parse_args()

    game = load_game(args.game)
    app_id = game.get("app_id")
    if not app_id:
        print("ERROR: app_id is not set in config/games.yml for this game.")
        sys.exit(1)

    print(f"\n{game['display_name']} — {game['bundle_id']}")
    print(f"App ID: {app_id}")

    client = ASCClient.from_env()
    print_app_store_versions(client, app_id)
    print_testflight_builds(client, app_id)
    print()


if __name__ == "__main__":
    main()
