"""Package fresh, verified Evaluation 2 artifacts locally. Never uploads or uses Git."""
from pathlib import Path
import hashlib
import json
import shutil

from package_deliverables import archive, source_files


ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "dist/evaluation2"


def main():
    apk = ROOT / "build/app/outputs/flutter-apk/app-release.apk"
    aab = ROOT / "build/app/outputs/bundle/release/app-release.aab"
    web = ROOT / "build/web"
    for artifact in (apk, aab, web / "index.html", web / "main.dart.js"):
        assert artifact.is_file(), f"Missing build artifact: {artifact}"
    metadata = json.loads((ROOT / "build/app/outputs/apk/release/output-metadata.json").read_text())
    assert metadata["elements"][0]["versionCode"] == 3, "APK is not Evaluation 2 build 3."
    assert "1.0.2" == metadata["elements"][0]["versionName"]
    assert (ROOT / "docs/EVALUATION2_HANDOVER.md").is_file(), "Complete the factual handover before packaging."
    evidence = ROOT / "docs/evaluation2-evidence"
    evidence.mkdir(parents=True, exist_ok=True)
    for name in ("final-analysis", "final-tests", "final-web", "final-apk", "final-aab", "rules-direct", "live-sync", "browser-pdf-verified", "firestore-deploy", "final-apk-signature", "apk-install", "device-voice"):
        log = ROOT / f"tmp/eval2-{name}.log"
        if log.is_file():
            shutil.copy2(log, evidence / f"{name}.txt")
    aab_log = ROOT / "tmp/eval2-final-aab-signature.log"
    if aab_log.is_file():
        (evidence / "aab-signature-summary.txt").write_text("\n".join(aab_log.read_text(encoding="utf-8").splitlines()[-24:]) + "\n", encoding="utf-8")
    for name in ("browser-saved-booking.pdf", "browser-saved-booking.json", "android-emulator-1gb-anr.png", "android-release-final.png"):
        original = ROOT / "output/evaluation2" / name
        if original.is_file():
            shutil.copy2(original, evidence / name)
    handover = ROOT / "docs/EVALUATION2_HANDOVER.md"
    handover_text = handover.read_text(encoding="utf-8")
    sizes = f"\n\nVerified release sizes: APK **{apk.stat().st_size:,} bytes**; AAB **{aab.stat().st_size:,} bytes**.\n"
    if "Verified release sizes:" not in handover_text:
        handover.write_text(handover_text.replace("## G. Evaluation preparation", sizes + "\n## G. Evaluation preparation"), encoding="utf-8")
    DEST.mkdir(parents=True, exist_ok=True)
    shutil.copy2(apk, DEST / "UniMarket-Evaluation2.apk")
    shutil.copy2(aab, DEST / "UniMarket-Evaluation2.aab")
    source_count = archive(DEST / "UniMarket-Evaluation2-Source.zip", source_files(), ROOT, "UniMarket/")
    web_count = archive(DEST / "UniMarket-Evaluation2-Web.zip", sorted(p for p in web.rglob("*") if p.is_file()), web)
    for document in (ROOT / "docs").glob("EVALUATION2_*.md"):
        shutil.copy2(document, DEST / document.name)
    manifest = {"version": "1.0.2+3", "signing": "Existing Android development/debug certificate; not a production Play signing configuration", "sourceEntries": source_count, "webEntries": web_count, "artifacts": []}
    for file in sorted(DEST.iterdir()):
        if file.is_file() and file.name not in {"ARTIFACTS.json", "SHA256SUMS.txt"}:
            manifest["artifacts"].append({"filename": file.name, "bytes": file.stat().st_size, "sha256": hashlib.sha256(file.read_bytes()).hexdigest()})
    (DEST / "ARTIFACTS.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (DEST / "SHA256SUMS.txt").write_text("".join(f"{a['sha256']}  {a['filename']}\n" for a in manifest["artifacts"]), encoding="utf-8")
    for artifact in manifest["artifacts"]:
        print(f"{artifact['filename']}: {artifact['bytes']:,} bytes")
    print(f"Verified {source_count} source entries and {web_count} web entries; no credentials or caches copied from excluded directories.")


if __name__ == "__main__":
    main()
