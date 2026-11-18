"""Shared constants and CSV helpers for Group A03 open-source API fetchers."""

from __future__ import annotations

import csv
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_TIMEOUT = 20
ARCHIVE_START = "2022-01-01"
ARCHIVE_END = "2026-02-12"

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


def resolve_data_dir() -> Path:
    """Return the workspace data directory inside Workbench or on the host."""
    container_path = Path("/config/workspace/data")
    if container_path.exists():
        return container_path
    return Path(__file__).resolve().parents[1] / "data"


def utc_now_iso() -> str:
    """Return current UTC timestamp in ISO-8601 format."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def write_csv(path: Path, fieldnames: list[str], rows: list[dict]) -> None:
    """Write rows to UTF-8 CSV with LF line endings."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
