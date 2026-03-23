#!/usr/bin/env python3
"""
fetch_reports.py — Pull sales and download reports from App Store Connect.

Uses the ASC Reporting API (Sales and Trends).
Reports are returned as gzipped TSV files.

Usage:
    python3 fetch_reports.py --game idle-civilizations [--days 7] [--output ./reports]

Required env:
    ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH
"""

import argparse
import gzip
import io
import os
import sys
import time
import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / "lib"))
from asc_client import ASCClient
from game_config import load_game


def fetch_sales_report(client: ASCClient, vendor_id: str, report_date: str) -> str | None:
    """
    Fetch SALES/SUMMARY report for a specific date.
    vendor_id: Apple Vendor Number (from Payments and Financial Reports in ASC)
    report_date: YYYY-MM-DD
    Returns TSV text or None if not available yet.
    """
    params = {
        "filter[reportType]":        "SALES",
        "filter[reportSubType]":     "SUMMARY",
        "filter[frequency]":         "DAILY",
        "filter[reportDate]":        report_date,
        "filter[vendorNumber]":      vendor_id,
    }
    try:
        # The sales report endpoint returns gzipped data directly, not JSON
        import requests
        import jwt

        token = client._token_header()["Authorization"].split(" ")[1]
        url = "https://api.appstoreconnect.apple.com/v1/salesReports"
        resp = requests.get(url, headers={"Authorization": f"Bearer {token}"}, params=params)

        if resp.status_code == 404:
            return None  # Report not available yet
        resp.raise_for_status()

        # Response is gzipped TSV
        return gzip.decompress(resp.content).decode("utf-8")
    except Exception as e:
        print(f"  Warning: could not fetch report for {report_date}: {e}")
        return None


def parse_tsv_report(tsv: str) -> list[dict]:
    lines = tsv.strip().splitlines()
    if not lines:
        return []
    headers = lines[0].split("\t")
    rows = []
    for line in lines[1:]:
        values = line.split("\t")
        rows.append(dict(zip(headers, values)))
    return rows


def summarize_rows(rows: list[dict], bundle_id: str) -> dict:
    units = 0
    proceeds = 0.0
    for row in rows:
        if row.get("Apple Identifier") and bundle_id in str(row.get("Apple Identifier", "")):
            try:
                units    += int(row.get("Units", 0))
                proceeds += float(row.get("Developer Proceeds", 0))
            except (ValueError, TypeError):
                pass
    return {"units": units, "proceeds": proceeds}


def main():
    parser = argparse.ArgumentParser(description="Pull App Store sales/download reports")
    parser.add_argument("--game",   required=True, help="Game ID from config/games.yml")
    parser.add_argument("--days",   type=int, default=7, help="Number of days to pull (default: 7)")
    parser.add_argument("--output", default="./reports", help="Output directory for TSV files")
    args = parser.parse_args()

    game = load_game(args.game)
    vendor_id = os.environ.get("ASC_VENDOR_NUMBER")
    if not vendor_id:
        print("ERROR: Set ASC_VENDOR_NUMBER env var (find it in ASC → Payments and Financial Reports).")
        sys.exit(1)

    output_dir = Path(args.output) / args.game
    output_dir.mkdir(parents=True, exist_ok=True)

    client = ASCClient.from_env()

    print(f"Fetching {args.days}-day sales report for {game['display_name']}...")
    print(f"Vendor: {vendor_id}")
    print()

    total_units = 0
    total_proceeds = 0.0
    today = datetime.date.today()

    for i in range(1, args.days + 1):
        report_date = (today - datetime.timedelta(days=i)).strftime("%Y-%m-%d")
        tsv = fetch_sales_report(client, vendor_id, report_date)

        if tsv is None:
            print(f"  {report_date}  — not available")
            continue

        # Save raw report
        out_file = output_dir / f"sales_{report_date}.tsv"
        out_file.write_text(tsv)

        rows    = parse_tsv_report(tsv)
        summary = summarize_rows(rows, game["bundle_id"])
        total_units    += summary["units"]
        total_proceeds += summary["proceeds"]

        print(f"  {report_date}  downloads: {summary['units']:>6}  proceeds: ${summary['proceeds']:>8.2f}")

    print()
    print(f"{'─' * 45}")
    print(f"  TOTAL ({args.days}d)   downloads: {total_units:>6}  proceeds: ${total_proceeds:>8.2f}")
    print(f"  Reports saved to: {output_dir}/")


if __name__ == "__main__":
    main()
