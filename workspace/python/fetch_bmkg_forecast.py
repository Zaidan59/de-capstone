#!/usr/bin/env python3
"""SRC-08: Fetch BMKG public weather forecast snapshot CSV (requires non-browser User-Agent)."""

from __future__ import annotations

from pathlib import Path
import sys
import requests

from open_source_common import (
    DEFAULT_TIMEOUT,
    REGIONS,
    resolve_data_dir,
    utc_now_iso,
    write_csv,
)


def fetch_bmkg(data_dir: Path) -> None:
    """Fetch BMKG 3-hourly forecast slots for all 6 regions into bmkg_station_ref.csv."""
    fetched_at = utc_now_iso()
    headers = {"User-Agent": "curl/8.5.0", "Accept": "application/json"}
    rows: list[dict] = []

    for reg in REGIONS:
        url = f"https://api.bmkg.go.id/publik/prakiraan-cuaca?adm4={reg['adm4']}"
        resp = requests.get(url, headers=headers, timeout=DEFAULT_TIMEOUT)
        resp.raise_for_status()
        entry = resp.json()["data"][0]
        lokasi = entry["lokasi"]
        for day_slots in entry["cuaca"]:
            for slot in day_slots:
                rows.append(
                    {
                        "region_key": reg["key"],
                        "region_name": reg["name"],
                        "adm4_code": reg["adm4"],
                        "kotkab": lokasi.get("kotkab", ""),
                        "kecamatan": lokasi.get("kecamatan", ""),
                        "desa": lokasi.get("desa", ""),
                        "utc_datetime": slot.get("utc_datetime", ""),
                        "local_datetime": slot.get("local_datetime", ""),
                        "t_celsius": slot.get("t", ""),
                        "hu_pct": slot.get("hu", ""),
                        "tp_mm": slot.get("tp", ""),
                        "ws_kmh": slot.get("ws", ""),
                        "wd": slot.get("wd", ""),
                        "tcc_pct": slot.get("tcc", ""),
                        "weather_code": slot.get("weather", ""),
                        "weather_desc": slot.get("weather_desc", ""),
                        "analysis_date": slot.get("analysis_date", ""),
                        "fetched_at": fetched_at,
                    }
                )

    out_path = data_dir / "bmkg_station_ref.csv"
    write_csv(
        out_path,
        [
            "region_key",
            "region_name",
            "adm4_code",
            "kotkab",
            "kecamatan",
            "desa",
            "utc_datetime",
            "local_datetime",
            "t_celsius",
            "hu_pct",
            "tp_mm",
            "ws_kmh",
            "wd",
            "tcc_pct",
            "weather_code",
            "weather_desc",
            "analysis_date",
            "fetched_at",
        ],
        rows,
    )
    print(f"[SRC-08] Saved BMKG forecast snapshot {out_path.name}: {len(rows)} rows across {len(REGIONS)} regions")


def main() -> int:
    data_dir = resolve_data_dir()
    print(f"Writing BMKG forecast snapshot under: {data_dir}")
    fetch_bmkg(data_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
