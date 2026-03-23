#!/usr/bin/env python3
"""
submit_for_review.py — Submit the latest valid build for App Store review.

Strategy:
  1. Find the "Prepare for Submission" App Store version
  2. Find the latest VALID build for that version (or the app's latest)
  3. Attach the build to the version if not already attached
  4. POST /v1/appStoreVersionSubmissions to request review

Usage:
    python3 submit_for_review.py --game idle-civilizations [--dry-run] [--auto-release]

Required env:
    ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH
"""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / "lib"))
from asc_client import ASCClient
from game_config import load_game


def find_prepare_version(client: ASCClient, app_id: str) -> dict:
    versions = client.get_all(
        f"/v1/apps/{app_id}/appStoreVersions",
        params={"filter[appStoreState]": "PREPARE_FOR_SUBMISSION", "limit": 5}
    )
    if not versions:
        raise RuntimeError(
            "No version in 'Prepare for Submission' state found. "
            "Create a new version in App Store Connect first."
        )
    # Return most recently created
    versions.sort(key=lambda v: v["attributes"].get("createdDate", ""), reverse=True)
    return versions[0]


def find_latest_valid_build(client: ASCClient, app_id: str) -> dict:
    builds = client.get_all(
        f"/v1/apps/{app_id}/builds",
        params={
            "filter[processingState]": "VALID",
            "limit": 5,
            "sort": "-uploadedDate",
        }
    )
    if not builds:
        raise RuntimeError(
            "No VALID builds found for this app. "
            "Upload a build via TestFlight first."
        )
    return builds[0]


def get_attached_build(client: ASCClient, version_id: str) -> dict | None:
    """Return the build currently attached to this App Store version, or None."""
    resp = client.get(f"/v1/appStoreVersions/{version_id}/build")
    return resp.get("data")


def attach_build(client: ASCClient, version_id: str, build_id: str, dry_run: bool):
    print(f"  Attaching build {build_id} to version {version_id}...")
    if dry_run:
        return
    client.patch(f"/v1/appStoreVersions/{version_id}/relationships/build", {
        "data": {"type": "builds", "id": build_id}
    })


def set_auto_release(client: ASCClient, version_id: str, auto_release: bool, dry_run: bool):
    release_type = "AFTER_APPROVAL" if auto_release else "MANUAL"
    print(f"  Setting release type to {release_type}...")
    if dry_run:
        return
    client.patch(f"/v1/appStoreVersions/{version_id}", {
        "data": {
            "type": "appStoreVersions",
            "id": version_id,
            "attributes": {"releaseType": release_type}
        }
    })


def submit(client: ASCClient, version_id: str, dry_run: bool):
    print("  Submitting for App Store review...")
    if dry_run:
        print("  DRY RUN — no submission made.")
        return
    client.post("/v1/appStoreVersionSubmissions", {
        "data": {
            "type": "appStoreVersionSubmissions",
            "relationships": {
                "appStoreVersion": {
                    "data": {"type": "appStoreVersions", "id": version_id}
                }
            }
        }
    })
    print("  ✓ Submitted for review!")


def main():
    parser = argparse.ArgumentParser(description="Submit app for App Store review")
    parser.add_argument("--game",         required=True, help="Game ID from config/games.yml")
    parser.add_argument("--dry-run",      action="store_true", help="Print plan without making changes")
    parser.add_argument("--auto-release", action="store_true", help="Auto-release after approval")
    args = parser.parse_args()

    game = load_game(args.game)
    app_id = game.get("app_id")
    if not app_id:
        print("ERROR: app_id not set in config/games.yml")
        sys.exit(1)

    print(f"\nGame:   {game['display_name']} ({game['bundle_id']})")
    print(f"App ID: {app_id}")
    if args.dry_run:
        print("Mode:   DRY RUN\n")

    client = ASCClient.from_env()

    # 1. Find the version to submit
    version = find_prepare_version(client, app_id)
    version_id    = version["id"]
    version_str   = version["attributes"]["versionString"]
    version_state = version["attributes"]["appStoreState"]
    print(f"\nVersion: {version_str} (id={version_id}, state={version_state})")

    # 2. Find the latest valid build
    build = find_latest_valid_build(client, app_id)
    build_id      = build["id"]
    build_version = build["attributes"]["version"]
    uploaded      = build["attributes"].get("uploadedDate", "")[:16].replace("T", " ")
    print(f"Build:   {build_version} (id={build_id}, uploaded {uploaded})")

    # 3. Attach build if not already attached
    current_build = get_attached_build(client, version_id)
    if current_build and current_build["id"] == build_id:
        print("  Build already attached — skipping.")
    else:
        if current_build:
            print(f"  Replacing attached build {current_build['id']}")
        attach_build(client, version_id, build_id, args.dry_run)

    # 4. Set release type
    set_auto_release(client, version_id, args.auto_release, args.dry_run)

    # 5. Submit
    submit(client, version_id, args.dry_run)

    print("\n✓ Review submission complete")


if __name__ == "__main__":
    main()
