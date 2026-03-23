#!/usr/bin/env python3
"""
setup_iap_details.py — Set localization, price, and availability for all IAP products
and subscriptions in App Store Connect.

Uses the URLs from the resource's own relationship links (supports both /v1/ and /v2/ products).

Usage:
    python3 setup_iap_details.py --game idle-civilizations [--dry-run]

Required env:
    ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH
"""

import argparse
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / "lib"))
from asc_client import ASCClient, BASE_URL
from game_config import load_game

# Maps displayPrice string → Apple price tier name (for matching price points)
PRICE_DISPLAY_MAP = {
    "0.99":  "1",
    "1.99":  "2",
    "2.99":  "3",
    "3.99":  "4",
    "4.99":  "5",
    "5.99":  "6",
    "6.99":  "7",
    "7.99":  "8",
    "8.99":  "9",
    "9.99":  "10",
    "14.99": "15",
    "19.99": "20",
    "24.99": "25",
    "29.99": "30",
    "39.99": "40",
    "49.99": "50",
    "59.99": "60",
    "69.99": "70",
    "79.99": "80",
    "99.99": "100",
}


def related_url(resource: dict, rel: str) -> str | None:
    return resource.get("relationships", {}).get(rel, {}).get("links", {}).get("related")


def en_us_locale(localizations: list) -> dict:
    for loc in localizations:
        if loc.get("locale") in ("en_US", "en-US"):
            return loc
    return localizations[0] if localizations else {}


def find_price_point(client: ASCClient, price_points_url: str, target_usd: str) -> str | None:
    """Find the price point ID matching the target USD price in USA territory."""
    url = price_points_url
    while url:
        r = client._session.get(
            url if url.startswith("http") else f"{BASE_URL}{url}",
            headers={**client._token_header()},
            params={"filter[territory]": "USA", "limit": 200} if "?" not in url else None,
        )
        if r.status_code != 200:
            return None
        data = r.json()
        for pp in data.get("data", []):
            attrs = pp.get("attributes", {})
            if attrs.get("customerPrice") == target_usd:
                return pp["id"]
        url = data.get("links", {}).get("next")
    return None


def set_iap_localization(client: ASCClient, iap: dict, name: str, description: str, dry_run: bool):
    locs_url = related_url(iap, "inAppPurchaseLocalizations")
    if not locs_url:
        print(f"    WARNING: no localization URL for {iap['attributes']['productId']}")
        return

    r = client._session.get(locs_url, headers=client._token_header())
    existing = r.json().get("data", []) if r.status_code == 200 else []
    en_loc = next((l for l in existing if l["attributes"].get("locale") in ("en-US", "en_US")), None)

    # Determine resource type for the relationship (v1 vs v2 products)
    iap_type = iap["type"]  # "inAppPurchases" or "inAppPurchasesV2"
    rel_type = iap_type  # relationship type matches resource type

    if en_loc:
        cur_name = en_loc["attributes"].get("name", "")
        cur_desc = en_loc["attributes"].get("description", "")
        if cur_name == name and cur_desc == description:
            print(f"    localization unchanged")
            return
        loc_id = en_loc["id"]
        loc_self_url = en_loc.get("links", {}).get("self") or f"{BASE_URL}/v1/inAppPurchaseLocalizations/{loc_id}"
        print(f"    UPDATE localization: {name!r}")
        if not dry_run:
            client._session.patch(
                loc_self_url if loc_self_url.startswith("http") else f"{BASE_URL}{loc_self_url}",
                headers={**client._token_header(), "Content-Type": "application/json"},
                data=json.dumps({"data": {"type": "inAppPurchaseLocalizations", "id": loc_id,
                    "attributes": {"name": name, "description": description}}}),
            )
    else:
        print(f"    CREATE localization: {name!r}")
        if not dry_run:
            client._session.post(
                f"{BASE_URL}/v1/inAppPurchaseLocalizations",
                headers={**client._token_header(), "Content-Type": "application/json"},
                data=json.dumps({"data": {"type": "inAppPurchaseLocalizations",
                    "attributes": {"locale": "en-US", "name": name, "description": description},
                    "relationships": {rel_type: {"data": {"type": rel_type, "id": iap["id"]}}}}}),
            )


def set_iap_price(client: ASCClient, iap: dict, display_price: str, dry_run: bool):
    """Set the price for an IAP product using its price schedule."""
    iap_id = iap["id"]
    iap_type = iap["type"]
    price_points_url = related_url(iap, "pricePoints")
    price_schedule_url = related_url(iap, "iapPriceSchedule")

    if not price_points_url:
        print(f"    WARNING: no pricePoints URL")
        return

    # Check if manual prices are already configured (schedule object always exists, prices may not)
    existing_schedule_id = None
    if price_schedule_url:
        r = client._session.get(price_schedule_url, headers=client._token_header())
        if r.status_code == 200 and r.json().get("data"):
            existing_schedule_id = r.json()["data"]["id"]
            # Check if manual prices exist within the schedule
            r2 = client._session.get(
                f"{BASE_URL}/v1/inAppPurchasePriceSchedules/{existing_schedule_id}/manualPrices",
                headers=client._token_header(),
                params={"filter[territory]": "USA", "limit": 1},
            )
            if r2.status_code == 200 and r2.json().get("data"):
                print(f"    price already set")
                return

    # Find the price point for this price in USA
    price_point_id = find_price_point(client, price_points_url, display_price)
    if not price_point_id:
        print(f"    WARNING: could not find price point for ${display_price} in USA")
        return

    print(f"    SET price ${display_price} (point={price_point_id})")
    if dry_run:
        return

    included_price = {
        "type": "inAppPurchasePrices",
        "id": "${1}",
        "attributes": {"startDate": None},
        "relationships": {
            "inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": price_point_id}}
        },
    }

    # Always POST — PATCH is not supported; the schedule auto-created by ASC accepts
    # a CREATE that replaces/sets the manual prices on the existing schedule
    body = {
        "data": {
            "type": "inAppPurchasePriceSchedules",
            "relationships": {
                "inAppPurchase": {"data": {"type": iap_type, "id": iap_id}},
                "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${1}"}]},
            },
        },
        "included": [included_price],
    }
    r = client._session.post(
        f"{BASE_URL}/v1/inAppPurchasePriceSchedules",
        headers={**client._token_header(), "Content-Type": "application/json"},
        data=json.dumps(body),
    )
    if r.status_code not in (200, 201):
        errs = r.json().get("errors", [{}])
        print(f"    ERROR setting price: {errs[0].get('detail', r.text[:150])}")


def set_iap_availability(client: ASCClient, iap: dict, dry_run: bool):
    """Make IAP available in all territories."""
    avail_url = related_url(iap, "inAppPurchaseAvailability")
    if not avail_url:
        return

    r = client._session.get(avail_url, headers=client._token_header())
    if r.status_code == 200 and r.json().get("data"):
        attrs = r.json()["data"]["attributes"]
        if attrs.get("availableInNewTerritories") is True:
            print(f"    availability already set (all territories)")
            return

    print(f"    SET availability: all territories")
    if dry_run:
        return

    iap_type = iap["type"]
    r2 = client._session.post(
        f"{BASE_URL}/v1/inAppPurchaseAvailabilities",
        headers={**client._token_header(), "Content-Type": "application/json"},
        data=json.dumps({"data": {
            "type": "inAppPurchaseAvailabilities",
            "attributes": {"availableInNewTerritories": True},
            "relationships": {
                "inAppPurchase": {"data": {"type": iap_type, "id": iap["id"]}},
                "availableTerritories": {"data": []},
            },
        }}),
    )
    if r2.status_code not in (200, 201):
        errs = r2.json().get("errors", [{}])
        print(f"    ERROR setting availability: {errs[0].get('detail', r2.text[:150])}")


def set_subscription_price(client: ASCClient, sub: dict, display_price: str, dry_run: bool):
    sub_id = sub["id"]
    pid = sub["attributes"]["productId"]

    # Check existing prices
    existing = client.get(f"/v1/subscriptions/{sub_id}/prices", params={"limit": 1})
    if existing.get("data"):
        print(f"    price already set")
        return

    # Get price points for USA territory
    r = client._session.get(
        f"{BASE_URL}/v1/subscriptions/{sub_id}/pricePoints",
        headers=client._token_header(),
        params={"filter[territory]": "USA", "limit": 200},
    )
    if r.status_code != 200:
        print(f"    WARNING: could not fetch subscription price points ({r.status_code})")
        return

    price_point_id = None
    for pp in r.json().get("data", []):
        attrs = pp.get("attributes", {})
        if attrs.get("customerPrice") == display_price:
            price_point_id = pp["id"]
            break

    if not price_point_id:
        print(f"    WARNING: no price point found for ${display_price}")
        return

    print(f"    SET price ${display_price} (point={price_point_id})")
    if dry_run:
        return

    r2 = client._session.post(
        f"{BASE_URL}/v1/subscriptionPrices",
        headers={**client._token_header(), "Content-Type": "application/json"},
        data=json.dumps({"data": {
            "type": "subscriptionPrices",
            "attributes": {"startDate": None, "preserveCurrentPrice": False},
            "relationships": {
                "subscription": {"data": {"type": "subscriptions", "id": sub_id}},
                "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": price_point_id}},
            },
        }}),
    )
    if r2.status_code not in (200, 201):
        errs = r2.json().get("errors", [{}])
        err = errs[0]
        if err.get("code") == "ENTITY_ERROR.RELATIONSHIP.INVALID" and "pricing information" in err.get("detail", ""):
            print(f"    MANUAL REQUIRED: Apple API blocked price setting (likely Paid Applications Agreement")
            print(f"    or banking not fully active). Set price manually in ASC UI:")
            print(f"    App Store Connect → {pid.split('.')[-2].replace('_', ' ').title()} → set ${display_price}/{'month' if 'monthly' in pid else 'year'}")
        else:
            print(f"    ERROR: {err.get('detail', r2.text[:200])}")


def run(game_id: str, dry_run: bool):
    game = load_game(game_id)
    client = ASCClient.from_env()
    app_id = game["app_id"]

    with open(game["storekit_config_path"]) as f:
        sk = json.load(f)

    # Build lookup from productId → storekit product
    sk_products = {p["productID"]: p for p in sk.get("products", [])}
    sk_subs = {}
    for group in sk.get("subscriptionGroups", []):
        for sub in group.get("subscriptions", []):
            sk_subs[sub["productID"]] = sub

    # ── IAP Products ──────────────────────────────────────────────────────────
    iaps = client.get_all(f"/v1/apps/{app_id}/inAppPurchasesV2")
    iap_map = {iap["attributes"]["productId"]: iap for iap in iaps}

    print(f"\n→ Setting up {len(iaps)} IAP product(s)...")
    for pid, iap in sorted(iap_map.items()):
        sk_p = sk_products.get(pid)
        if not sk_p:
            print(f"  SKIP {pid}: not in .storekit")
            continue

        loc = en_us_locale(sk_p.get("localizations", [{}]))
        name = loc.get("displayName", pid)
        desc = loc.get("description", "")
        price = sk_p.get("displayPrice", "0.99")

        print(f"  {pid}")
        set_iap_localization(client, iap, name, desc, dry_run)
        set_iap_price(client, iap, price, dry_run)
        set_iap_availability(client, iap, dry_run)
        time.sleep(0.3)

    # ── Subscriptions ─────────────────────────────────────────────────────────
    groups = client.get_all(f"/v1/apps/{app_id}/subscriptionGroups")
    print(f"\n→ Setting up subscriptions...")
    for group in groups:
        subs = client.get_all(f"/v1/subscriptionGroups/{group['id']}/subscriptions")
        for sub in subs:
            pid = sub["attributes"]["productId"]
            sk_s = sk_subs.get(pid)
            if not sk_s:
                print(f"  SKIP {pid}: not in .storekit")
                continue

            loc = en_us_locale(sk_s.get("localizations", [{}]))
            name = loc.get("displayName", pid)
            desc = (loc.get("description") or "")[:55]
            price = sk_s.get("displayPrice", "2.99")

            print(f"  {pid}")

            # Update localization if needed
            sub_id = sub["id"]
            existing_locs = client.get_all(f"/v1/subscriptions/{sub_id}/subscriptionLocalizations")
            en_loc = next((l for l in existing_locs if l["attributes"]["locale"] == "en-US"), None)
            if en_loc:
                if en_loc["attributes"].get("name") != name or en_loc["attributes"].get("description", "") != desc:
                    print(f"    UPDATE localization: {name!r}")
                    if not dry_run:
                        client.patch(f"/v1/subscriptionLocalizations/{en_loc['id']}", {
                            "data": {"type": "subscriptionLocalizations", "id": en_loc["id"],
                                     "attributes": {"name": name, "description": desc}}})
                else:
                    print(f"    localization ok")
            else:
                print(f"    CREATE localization: {name!r}")
                if not dry_run:
                    client.post("/v1/subscriptionLocalizations", {"data": {"type": "subscriptionLocalizations",
                        "attributes": {"locale": "en-US", "name": name, "description": desc},
                        "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sub_id}}}}})

            set_subscription_price(client, sub, price, dry_run)
            time.sleep(0.3)

    print("\n✓ Setup complete")


def main():
    parser = argparse.ArgumentParser(description="Set IAP prices, localizations, and availability")
    parser.add_argument("--game", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    run(args.game, args.dry_run)


if __name__ == "__main__":
    main()
