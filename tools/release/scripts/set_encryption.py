#!/usr/bin/env python3
"""
set_encryption.py — Mark a build as using no non-exempt encryption in ASC.

Usage:
    python3 set_encryption.py --game idle-civilizations --build 202603231832

Required env:
    ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH
"""

import argparse
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / "lib"))
from asc_client import ASCClient, BASE_URL
from game_config import load_game


def run(game_id: str, build_number: str):
    game = load_game(game_id)
    client = ASCClient.from_env()
    app_id = game["app_id"]

    # Poll until the build appears (it may still be processing)
    for attempt in range(20):
        r = client._session.get(
            f"{BASE_URL}/v1/builds",
            headers=client._token_header(),
            params={
                "filter[app]": app_id,
                "filter[version]": build_number,
                "fields[builds]": "version,processingState,usesNonExemptEncryption",
                "limit": 1,
            },
        )
        builds = r.json().get("data", [])
        if builds:
            b = builds[0]
            state = b["attributes"].get("processingState")
            if state not in ("PROCESSING", "VALID"):
                print(f"  build {build_number} state={state}, waiting...")
                time.sleep(15)
                continue

            if b["attributes"].get("usesNonExemptEncryption") is False:
                print(f"  encryption already set to None for build {build_number}")
                return

            bid = b["id"]
            r2 = client._session.patch(
                f"{BASE_URL}/v1/builds/{bid}",
                headers={**client._token_header(), "Content-Type": "application/json"},
                json={"data": {"type": "builds", "id": bid,
                               "attributes": {"usesNonExemptEncryption": False}}},
            )
            if r2.status_code in (200, 201):
                print(f"  ✓ build {build_number}: encryption set to None")
            else:
                errs = r2.json().get("errors", [{}])
                print(f"  WARNING: {errs[0].get('detail', r2.text[:150])}")
            return
        else:
            print(f"  build {build_number} not found yet (attempt {attempt+1}/20), waiting 15s...")
            time.sleep(15)

    print(f"  WARNING: build {build_number} never appeared in ASC after polling")


def main():
    parser = argparse.ArgumentParser(description="Set encryption=None on a TestFlight build")
    parser.add_argument("--game", required=True)
    parser.add_argument("--build", required=True, help="CFBundleVersion / build number")
    args = parser.parse_args()
    run(args.game, args.build)


if __name__ == "__main__":
    main()
