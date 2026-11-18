#!/usr/bin/env python3
"""SRC-09: Fetch daily USD/IDR exchange rate snapshot CSV (Frankfurter + open.er-api.com)."""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import sys
import requests

from open_source_common import (
    ARCHIVE_START,
    DEFAULT_TIMEOUT,
    resolve_data_dir,
    utc_now_iso,
    write_csv,
)


def fetch_fx(data_dir: Path) -> None:
    """Fetch historical and live USD/IDR exchange rates into bi_jisdor_daily.csv."""
    fetched_at = utc_now_iso()
    today_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    by_date: dict[str, dict] = {}

    hist_url = f"https://api.frankfurter.app/{ARCHIVE_START}..{today_str}?from=USD&to=IDR"
    hist_resp = requests.get(hist_url, timeout=DEFAULT_TIMEOUT)
    hist_resp.raise_for_status()
    for d, rate_obj in sorted(hist_resp.json().get("rates", {}).items()):
        if "IDR" in rate_obj:
            by_date[d] = {
                "rate_date": d,
                "base_currency": "USD",
                "quote_currency": "IDR",
                "usd_idr_rate": rate_obj["IDR"],
                "source_api": "api.frankfurter.app",
                "fetched_at": fetched_at,
            }

    live_resp = requests.get("https://open.er-api.com/v6/latest/USD", timeout=DEFAULT_TIMEOUT)
    live_resp.raise_for_status()
    live_json = live_resp.json()
    live_idr = live_json.get("rates", {}).get("IDR")
    if live_idr is not None:
        live_dt = datetime.fromtimestamp(live_json["time_last_update_unix"], tz=timezone.utc).strftime("%Y-%m-%d")
        if live_dt not in by_date:
            by_date[live_dt] = {
                "rate_date": live_dt,
                "base_currency": "USD",
                "quote_currency": "IDR",
                "usd_idr_rate": live_idr,
                "source_api": "open.er-api.com",
                "fetched_at": fetched_at,
            }

    rows = [by_date[k] for k in sorted(by_date)]
    out_path = data_dir / "bi_jisdor_daily.csv"
    write_csv(
        out_path,
        ["rate_date", "base_currency", "quote_currency", "usd_idr_rate", "source_api", "fetched_at"],
        rows,
    )
    print(f"[SRC-09] Saved USD/IDR FX rates {out_path.name}: {len(rows)} rows ({rows[0]['rate_date']}..{rows[-1]['rate_date']})")


def main() -> int:
    data_dir = resolve_data_dir()
    print(f"Writing USD/IDR FX snapshot under: {data_dir}")
    fetch_fx(data_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
