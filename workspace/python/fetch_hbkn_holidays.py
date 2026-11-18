#!/usr/bin/env python3
"""SRC-13: Fetch Indonesia public holidays & HBKN flags CSV (2022..2026)."""

from __future__ import annotations

from pathlib import Path
import re
import sys
import requests

from open_source_common import (
    DEFAULT_TIMEOUT,
    resolve_data_dir,
    utc_now_iso,
    write_csv,
)


def classify_hbkn(local_name: str, name: str) -> tuple[str, bool]:
    """Classify a holiday name into an HBKN category and major-event flag."""
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
    """Fetch Indonesian holidays from Google ICS and Nager.Date into ref_hbkn_calendar.csv."""
    fetched_at = utc_now_iso()
    by_key: dict[tuple[str, str], dict] = {}

    ics_url = (
        "https://calendar.google.com/calendar/ical/"
        "id.indonesian%23holiday%40group.v.calendar.google.com/public/basic.ics"
    )
    ics_resp = requests.get(ics_url, timeout=DEFAULT_TIMEOUT)
    ics_resp.raise_for_status()
    for ev in re.findall(r"BEGIN:VEVENT(.*?)END:VEVENT", ics_resp.text, re.S):
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

    for year in range(2022, 2027):
        url = f"https://date.nager.at/api/v3/PublicHolidays/{year}/ID"
        resp = requests.get(url, timeout=DEFAULT_TIMEOUT)
        resp.raise_for_status()
        for item in resp.json():
            iso_date = item["date"]
            local_name = item.get("localName", "").strip()
            name = item.get("name", "").strip()
            category, is_major = classify_hbkn(local_name, name)
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
    data_dir = resolve_data_dir()
    print(f"Writing HBKN calendar snapshot under: {data_dir}")
    fetch_holidays(data_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
