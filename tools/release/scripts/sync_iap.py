#!/usr/bin/env python3
"""
sync_iap.py — Sync .storekit IAP products to App Store Connect.

Strategy:
  - GET all existing IAP products from ASC
  - Diff by productId: create missing, patch changed, skip identical
  - NEVER delete — ASC IAP deletion requires removing from App Store first
  - Subscription groups handled separately (require group context)
  - Supports --dry-run (prints diff, makes no writes)

Usage:
    python3 sync_iap.py --game idle-civilizations [--dry-run]

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

# .storekit type → ASC product type
SK_TYPE_TO_ASC = {
    "NonConsumable":          "NON_CONSUMABLE",
    "Consumable":             "CONSUMABLE",
    "NonRenewingSubscription": "NON_RENEWING_SUBSCRIPTION",
}

SUBSCRIPTION_PERIOD_MAP = {
    "P1W": "ONE_WEEK",
    "P1M": "ONE_MONTH",
    "P2M": "TWO_MONTHS",
    "P3M": "THREE_MONTHS",
    "P6M": "SIX_MONTHS",
    "P1Y": "ONE_YEAR",
}


def parse_storekit(path: Path) -> dict:
    with open(path) as f:
        return json.load(f)


def en_us_locale(localizations: list) -> dict:
    for loc in localizations:
        if loc.get("locale") in ("en_US", "en-US"):
            return loc
    return localizations[0] if localizations else {}


def sync_products(client: ASCClient, app_id: str, products: list, dry_run: bool):
    print(f"\n→ Syncing {len(products)} IAP product(s)...")

    existing_raw = client.get_all(f"/v1/apps/{app_id}/inAppPurchasesV2")
    existing = {item["attributes"]["productId"]: item for item in existing_raw}

    created = updated = skipped = 0

    for product in products:
        pid      = product["productID"]
        asc_type = SK_TYPE_TO_ASC.get(product["type"])
        if not asc_type:
            print(f"  SKIP {pid}: unsupported type '{product['type']}'")
            continue

        loc = en_us_locale(product.get("localizations", [{}]))

        if pid in existing:
            existing_id = existing[pid]["id"]
            existing_attrs = existing[pid]["attributes"]
            new_name = loc.get("displayName") or product.get("referenceName", pid)
            if existing_attrs.get("name") != new_name:
                print(f"  UPDATE {pid} → name: {existing_attrs.get('name')!r} → {new_name!r}")
                if not dry_run:
                    client.patch(f"/v1/inAppPurchasesV2/{existing_id}", {
                        "data": {
                            "type": "inAppPurchasesV2",
                            "id":   existing_id,
                            "attributes": {"name": new_name},
                        }
                    })
                updated += 1
            else:
                skipped += 1
        else:
            name = loc.get("displayName") or product.get("referenceName", pid)
            print(f"  CREATE {pid} ({asc_type}) — {name}")
            if not dry_run:
                resp = client.post("/v1/inAppPurchasesV2", {
                    "data": {
                        "type": "inAppPurchasesV2",
                        "attributes": {
                            "productId":        pid,
                            "referenceName":    product.get("referenceName", name),
                            "name":             name,
                            "inAppPurchaseType": asc_type,
                            "availableInAllTerritories": True,
                            "taxCategory":      "GENERAL",
                        },
                        "relationships": {
                            "app": {"data": {"type": "apps", "id": app_id}}
                        }
                    }
                })
                iap_id = resp["data"]["id"]
                # Add en-US localization
                client.post("/v1/inAppPurchaseLocalizations", {
                    "data": {
                        "type": "inAppPurchaseLocalizations",
                        "attributes": {
                            "locale":      "en-US",
                            "name":        loc.get("displayName", name),
                            "description": loc.get("description", ""),
                        },
                        "relationships": {
                            "inAppPurchaseV2": {"data": {"type": "inAppPurchasesV2", "id": iap_id}}
                        }
                    }
                })
            created += 1

    print(f"  Products: {created} created, {updated} updated, {skipped} unchanged")


def sync_subscription_groups(client: ASCClient, app_id: str, groups: list, dry_run: bool):
    if not groups:
        return
    print(f"\n→ Syncing {len(groups)} subscription group(s)...")

    existing_groups = client.get_all(f"/v1/apps/{app_id}/subscriptionGroups")
    existing_by_name = {g["attributes"]["referenceName"]: g for g in existing_groups}

    for group in groups:
        group_name = group["name"]

        if group_name in existing_by_name:
            group_id = existing_by_name[group_name]["id"]
            print(f"  EXISTS subscription group '{group_name}' (id={group_id})")
        else:
            print(f"  CREATE subscription group '{group_name}'")
            for sub in group.get("subscriptions", []):
                loc  = en_us_locale(sub.get("localizations", [{}]))
                name = loc.get("displayName") or sub.get("referenceName", sub["productID"])
                print(f"    CREATE {sub['productID']} — {name}")
            if dry_run:
                continue  # can't fetch subs of a group that doesn't exist yet
            else:
                resp = client.post("/v1/subscriptionGroups", {
                    "data": {
                        "type": "subscriptionGroups",
                        "attributes": {"referenceName": group_name},
                        "relationships": {
                            "app": {"data": {"type": "apps", "id": app_id}}
                        }
                    }
                })
                group_id = resp["data"]["id"]

        # Sync subscriptions within group
        existing_subs_raw = client.get_all(f"/v1/subscriptionGroups/{group_id}/subscriptions")
        existing_subs = {s["attributes"]["productId"]: s for s in existing_subs_raw}

        for sub in group.get("subscriptions", []):
            pid    = sub["productID"]
            loc    = en_us_locale(sub.get("localizations", [{}]))
            period = SUBSCRIPTION_PERIOD_MAP.get(sub.get("recurringSubscriptionPeriod", "P1M"), "ONE_MONTH")
            name   = loc.get("displayName") or sub.get("referenceName", pid)

            if pid in existing_subs:
                print(f"    EXISTS {pid}")
            else:
                print(f"    CREATE {pid} ({period}) — {name}")
                if not dry_run:
                    resp = client.post("/v1/subscriptions", {
                        "data": {
                            "type": "subscriptions",
                            "attributes": {
                                "productId":               pid,
                                "referenceName":           sub.get("referenceName", name),
                                "name":                    name,
                                "subscriptionPeriod":      period,
                                "reviewNote":              "",
                                "availableInAllTerritories": True,
                                "familySharable":          sub.get("familyShareable", False),
                            },
                            "relationships": {
                                "group": {"data": {"type": "subscriptionGroups", "id": group_id}}
                            }
                        }
                    })
                    sub_id = resp["data"]["id"]
                    client.post("/v1/subscriptionLocalizations", {
                        "data": {
                            "type": "subscriptionLocalizations",
                            "attributes": {
                                "locale":      "en-US",
                                "name":        loc.get("displayName", name),
                                "description": loc.get("description", ""),
                            },
                            "relationships": {
                                "subscription": {"data": {"type": "subscriptions", "id": sub_id}}
                            }
                        }
                    })


def main():
    parser = argparse.ArgumentParser(description="Sync .storekit IAP products to App Store Connect")
    parser.add_argument("--game",    required=True, help="Game ID from config/games.yml")
    parser.add_argument("--dry-run", action="store_true", help="Print diff without making changes")
    args = parser.parse_args()

    game = load_game(args.game)
    app_id = game.get("app_id")
    if not app_id:
        print("ERROR: app_id is not set in config/games.yml for this game.")
        print("  Find it in App Store Connect → My Apps → select app → App Information → Apple ID.")
        sys.exit(1)

    print(f"Game:    {game['display_name']} ({game['bundle_id']})")
    print(f"App ID:  {app_id}")
    print(f"Source:  {game['storekit_config_path']}")
    if args.dry_run:
        print("Mode:    DRY RUN (no changes will be made)\n")

    sk = parse_storekit(game["storekit_config_path"])
    client = ASCClient.from_env()

    sync_products(client, app_id, sk.get("products", []), args.dry_run)
    sync_subscription_groups(client, app_id, sk.get("subscriptionGroups", []), args.dry_run)

    print("\n✓ IAP sync complete")


if __name__ == "__main__":
    main()
