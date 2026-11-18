#!/usr/bin/env python3
"""SRC-05..07: Fetch Open-Meteo ERA5 archives and live weather snapshot CSVs."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys
import requests

from open_source_common import (
    ARCHIVE_END,
    ARCHIVE_START,
    DEFAULT_TIMEOUT,
    REGIONS,
    resolve_data_dir,
    utc_now_iso,
    write_csv,
)


def fetch_openmeteo(data_dir: Path, refresh_existing: bool = False) -> None:
    """Download historical ERA5 CSV archives (if missing/forced) and live forecast."""
    weather_dir = data_dir / "weather"
    weather_dir.mkdir(parents=True, exist_ok=True)
    fetched_at = utc_now_iso()

    for reg in REGIONS:
        target = weather_dir / reg["archive_filename"]
        if target.exists() and not refresh_existing:
            print(f"[SRC-05..07] Skip existing archive: {target.name}")
            continue
        url = (
            "https://archive-api.open-meteo.com/v1/archive"
            f"?latitude={reg['lat']}&longitude={reg['lon']}"
            f"&start_date={ARCHIVE_START}&end_date={ARCHIVE_END}"
            "&daily=temperature_2m_max,precipitation_sum,rain_sum"
            "&timezone=Asia%2FJakarta&format=csv"
        )
        resp = requests.get(url, timeout=DEFAULT_TIMEOUT)
        resp.raise_for_status()
        target.write_text(resp.text, encoding="utf-8")
        data_rows = max(0, len(resp.text.strip().splitlines()) - 4)
        print(f"[SRC-05..07] Saved ERA5 archive {target.name}: {data_rows} daily rows")

    live_rows: list[dict] = []
    for reg in REGIONS:
        url = (
            "https://api.open-meteo.com/v1/forecast"
            f"?latitude={reg['lat']}&longitude={reg['lon']}"
            "&daily=temperature_2m_max,precipitation_sum,rain_sum"
            "&past_days=7&forecast_days=3&timezone=Asia%2FJakarta"
        )
        resp = requests.get(url, timeout=DEFAULT_TIMEOUT)
        resp.raise_for_status()
        daily = resp.json()["daily"]
        for d, tmax, precip, rain in zip(
            daily["time"],
            daily["temperature_2m_max"],
            daily["precipitation_sum"],
            daily["rain_sum"],
        ):
            live_rows.append(
                {
                    "region_key": reg["key"],
                    "region_name": reg["name"],
                    "date": d,
                    "temperature_2m_max_c": tmax,
                    "precipitation_sum_mm": precip,
                    "rain_sum_mm": rain,
                    "fetched_at": fetched_at,
                    "source_api": "api.open-meteo.com/v1/forecast",
                }
            )

    live_path = weather_dir / "openmeteo_live_latest.csv"
    write_csv(
        live_path,
        [
            "region_key",
            "region_name",
            "date",
            "temperature_2m_max_c",
            "precipitation_sum_mm",
            "rain_sum_mm",
            "fetched_at",
            "source_api",
        ],
        live_rows,
    )
    print(f"[SRC-05..07] Saved live Open-Meteo snapshot {live_path.name}: {len(live_rows)} rows")


def main() -> int:
    parser = argparse.ArgumentParser(description="Fetch Open-Meteo weather datasets (SRC-05..07).")
    parser.add_argument(
        "--refresh-existing",
        action="store_true",
        help="Re-download existing Open-Meteo archive files (e.g., Garut/Karawang).",
    )
    args = parser.parse_args()
    data_dir = resolve_data_dir()
    print(f"Writing Open-Meteo datasets under: {data_dir / 'weather'}")
    fetch_openmeteo(data_dir, refresh_existing=args.refresh_existing)
    return 0


if __name__ == "__main__":
    sys.exit(main())
