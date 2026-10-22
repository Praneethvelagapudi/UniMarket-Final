"""Compare an exported confirmation with its authorized saved-record snapshot."""
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

from pypdf import PdfReader


def verify(pdf_path, snapshot_path):
    record = json.loads(Path(snapshot_path).read_text(encoding="utf-8"))
    reader = PdfReader(pdf_path)
    text = " ".join(" ".join(page.extract_text() or "" for page in reader.pages).split())
    checked = []
    for key in ("id", "title", "buyer", "seller", "pickupSpot", "paymentReference"):
        if key in record and record[key]:
            assert " ".join(str(record[key]).split()) in text, f"PDF differs from saved field: {key}"
            checked.append(key)
    whole, cents = f"{record['total']:.2f}".split(".")
    groups = [whole[-3:]]
    whole = whole[:-3]
    while whole:
        groups.insert(0, whole[-2:])
        whole = whole[:-2]
    assert f"₹{','.join(groups)}.{cents}" in text, "PDF differs from saved INR total"
    checked.append("total")
    assert "BOOKING CONFIRMATION" in text
    if record.get("paymentStatus") == "succeeded":
        assert "TEST PAYMENT SIMULATION - NO MONEY MOVED" in text
        assert "succeeded (no money moved)" in text
        checked.append("simulation status and disclaimer")
    for key in ("createdAtEpochMs", "pickupAtEpochMs"):
        if key in record:
            local = datetime.fromtimestamp(record[key] / 1000, tz=timezone(timedelta(minutes=record.get("timeZoneOffsetMinutes", 330))))
            expected = f"{local.day} {local:%b %Y}, {local.hour % 12 or 12}:{local:%M %p}"
            assert expected in text, f"PDF differs from saved timestamp: {key}"
            checked.append(key)
    print(f"PASS: {len(reader.pages)} page(s); saved-record fields match: {', '.join(checked)}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: verify_invoice.py <exported.pdf> <saved-record.json>")
    verify(sys.argv[1], sys.argv[2])
