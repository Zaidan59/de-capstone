#!/usr/bin/env python3
"""Fetch public, keyless REST API datasets for Capstone Group A03.

Covers:
  - SRC-05..07: Open-Meteo ERA5 archive (2022-01-01..2026-02-12) & live forecast
  - SRC-08: BMKG public weather forecast API (requires non-browser User-Agent)
  - SRC-09: Daily USD/IDR exchange rate (Frankfurter historical + open.er-api.com live)
  - SRC-13: Indonesia public holidays & HBKN flags (date.nager.at 2022..2026)

Manual-download / curated regulation sources (SRC-04, SRC-10..12) are intentionally
excluded from this script.
"""

from __future__ import annotations

import argparse
import csv
from datetime import datetime, timezone
import re
from pathlib import Path
import sys
import requests

DEFAULT_TIMEOUT = 20

REGIONS = [
    {
        "key": "garut",
        "name": "Kab. Garut",
        "lat": -7.2278,
        "lon": 107.9087,
        "archive_filename": "cuaca garut.csv",
        "adm4": "32.05.01.1001",
    },
    {
        "key": "magelang",
        "name": "Kab. Magelang",
        "lat": -7.4797,
        "lon": 110.2177,
        "archive_filename": "cuaca magelang.csv",
        "adm4": "33.08.09.2001",
    },
    {
        "key": "karawang",
        "name": "Kab. Karawang",
        "lat": -6.3073,
        "lon": 107.3019,
        "archive_filename": "cuaca karawang.csv",
        "adm4": "32.15.01.1001",
    },
    {
        "key": "indramayu",
        "name": "Kab. Indramayu",
        "lat": -6.3276,
        "lon": 108.3249,
        "archive_filename": "cuaca indramayu.csv",
        "adm4": "32.12.15.1001",
    },
    {
        "key": "brebes",
        "name": "Kab. Brebes",
        "lat": -6.8706,
        "lon": 109.0369,
        "archive_filename": "cuaca brebes.csv",
        "adm4": "33.29.09.2001",
    },
    {
        "key": "dki_jakarta",
        "name": "DKI Jakarta",
        "lat": -6.2088,
        "lon": 106.8456,
        "archive_filename": "cuaca dki_jakarta.csv",
        "adm4": "31.71.01.1001",
    },
]

ARCHIVE_START = "2022-01-01"
ARCHIVE_END = "2026-02-12"


def resolve_data_dir() -> Path:
    container_path = Path("/config/workspace/data")
    if container_path.exists():
        return container_path
    return Path(__file__).resolve().parents[1] / "data"


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def write_csv(path: Path, fieldnames: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def fetch_openmeteo(data_dir: Path, refresh_existing: bool = False) -> None:
    weather_dir = data_dir / "weather"
    weather_dir.mkdir(parents=True, exist_ok=True)
    fetched_at = utc_now_iso()

    for reg in REGIONS:
        target = weather_dir / reg["archive_filename"]
        if target.exists() and not refresh_existing:
            print(f"[SRC-05..07] Skip existing archive: {target.name}")
        else:
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


def fetch_bmkg(data_dir: Path) -> None:
    fetched_at = utc_now_iso()
    headers = {"User-Agent": "curl/8.5.0", "Accept": "application/json"}
    rows: list[dict] = []

    for reg in REGIONS:
        url = f"https://api.bmkg.go.id/publik/prakiraan-cuaca?adm4={reg['adm4']}"
        resp = requests.get(url, headers=headers, timeout=DEFAULT_TIMEOUT)
        resp.raise_for_status()
        payload = resp.json()
        entry = payload["data"][0]
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


def fetch_fx(data_dir: Path) -> None:
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


def classify_hbkn(local_name: str, name: str) -> tuple[str, bool]:
    text = f"{local_name} {name}".lower()
    if "ramadan" in text:
        return "RAMADAN", True
    if "idul adha" in text:
        return "IDUL_ADHA", True
    if "idul fitri" in text or "lebaran" in text:
        return "IDUL_FITRI", True
    if "natal" in text or "tahun baru" in text or "christmas" in text or "new year" in text:
        if "hijriah" in text or "muharam" in text or "imlek" in text or "saka" in text:
            return "PUBLIC_HOLIDAY", False
        return "NATARU", True
    return "PUBLIC_HOLIDAY", False


def fetch_holidays(data_dir: Path) -> None:
    fetched_at = utc_now_iso()
    by_key: dict[tuple[str, str], dict] = {}

    # 1. Google Public Calendar Indonesian Holidays (includes Ramadan, Idul Fitri, Idul Adha)
    ics_url = (
        "https://calendar.google.com/calendar/ical/"
        "id.indonesian%23holiday%40group.v.calendar.google.com/public/basic.ics"
    )
    ics_resp = requests.get(ics_url, timeout=DEFAULT_TIMEOUT)
    ics_resp.raise_for_status()
    events = re.findall(r"BEGIN:VEVENT(.*?)END:VEVENT", ics_resp.text, re.S)
    for ev in events:
        dt_match = re.search(r"DTSTART;VALUE=DATE:(\d{8})", ev)
        sm_match = re.search(r"SUMMARY:([^\r\n]+)", ev)
        if not dt_match or not sm_match:
            continue
        raw_dt = dt_match.group(1)
        year = int(raw_dt[:4])
        if year < 2022 or year > 2026:
            continue
        iso_date = f"{raw_dt[:4]}-{raw_dt[4:6]}-{raw_dt[6:8]}"
        local_name = sm_match.group(1).strip()
        category, is_major = classify_hbkn(local_name, local_name)
        by_key[(iso_date, local_name)] = {
            "holiday_date": iso_date,
            "year": year,
            "local_name": local_name,
            "name": local_name,
            "country_code": "ID",
            "fixed": False,
            "global_holiday": True,
            "hbkn_category": category,
            "is_hbkn_major": is_major,
            "source_api": "calendar.google.com/id.indonesian",
            "fetched_at": fetched_at,
        }

    # 2. Nager.Date Public Holidays API (adds English names / cross-check for national holidays)
    for year in range(2022, 2027):
        url = f"https://date.nager.at/api/v3/PublicHolidays/{year}/ID"
        resp = requests.get(url, timeout=DEFAULT_TIMEOUT)
        resp.raise_for_status()
        for item in resp.json():
            iso_date = item["date"]
            local_name = item.get("localName", "").strip()
            name = item.get("name", "").strip()
            category, is_major = classify_hbkn(local_name, name)
            # Avoid duplicate row if Google ICS already captured the same date
            if any(k[0] == iso_date for k in by_key):
                continue
            by_key[(iso_date, local_name)] = {
                "holiday_date": iso_date,
                "year": year,
                "local_name": local_name,
                "name": name,
                "country_code": item.get("countryCode", "ID"),
                "fixed": item.get("fixed", False),
                "global_holiday": item.get("global", True),
                "hbkn_category": category,
                "is_hbkn_major": is_major,
                "source_api": "date.nager.at",
                "fetched_at": fetched_at,
            }

    rows = [by_key[k] for k in sorted(by_key)]
    out_path = data_dir / "ref_hbkn_calendar.csv"
    write_csv(
        out_path,
        [
            "holiday_date",
            "year",
            "local_name",
            "name",
            "country_code",
            "fixed",
            "global_holiday",
            "hbkn_category",
            "is_hbkn_major",
            "source_api",
            "fetched_at",
        ],
        rows,
    )
    print(f"[SRC-13] Saved public holidays & HBKN {out_path.name}: {len(rows)} rows (2022..2026)")


def main() -> int:
    parser = argparse.ArgumentParser(description="Fetch open REST API datasets for Capstone Group A03.")
    parser.add_argument(
        "--only",
        choices=["all", "weather", "bmkg", "fx", "holidays"],
        default="all",
        help="Run only a specific API group.",
    )
    parser.add_argument(
        "--refresh-existing",
        action="store_true",
        help="Re-download existing Open-Meteo archive files (e.g., Garut/Karawang).",
    )
    args = parser.parse_args()

    data_dir = resolve_data_dir()
    print(f"Writing API datasets under: {data_dir}")

    if args.only in ("all", "weather"):
        fetch_openmeteo(data_dir, refresh_existing=args.refresh_existing)
    if args.only in ("all", "bmkg"):
        fetch_bmkg(data_dir)
    if args.only in ("all", "fx"):
        fetch_fx(data_dir)
    if args.only in ("all", "holidays"):
        fetch_holidays(data_dir)

    return 0


if __name__ == "__main__":
    sys.exit(main())
