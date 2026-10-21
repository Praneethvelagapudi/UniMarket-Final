"""Package the demo builds and source without local credentials or caches."""

from pathlib import Path
import hashlib
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "dist"
EXCLUDED_DIRS = {
    ".git", ".dart_tool", ".idea", ".gradle", ".cxx", ".pub-cache",
    ".pub", "node_modules", "tmp", "dist", "build", "coverage",
    "ephemeral", ".symlinks", "Pods", "__pycache__", "output",
}
EXCLUDED_NAMES = {
    "local.properties", ".flutter-plugins-dependencies", "key.properties",
    "GeneratedPluginRegistrant.java", ".last_build_id",
}
EXCLUDED_SUFFIXES = {".log", ".iml", ".pyc", ".jks", ".keystore"}


def source_files(folder=ROOT):
    for entry in sorted(folder.iterdir()):
        if entry.is_symlink():
            continue
        if entry.is_dir():
            if entry.name not in EXCLUDED_DIRS:
                yield from source_files(entry)
        elif entry.name not in EXCLUDED_NAMES and entry.suffix not in EXCLUDED_SUFFIXES:
            yield entry


def archive(path, files, base, prefix=""):
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as bundle:
        for file in files:
            bundle.write(file, prefix + file.relative_to(base).as_posix())
    with zipfile.ZipFile(path) as bundle:
        assert bundle.testzip() is None, f"Archive verification failed: {path}"
        return len(bundle.namelist())


def main():
    apk = ROOT / "build/app/outputs/flutter-apk/app-release.apk"
    web = ROOT / "build/web"
    assert apk.is_file() and (web / "index.html").is_file(), "Build APK and web first."
    OUTPUT.mkdir(exist_ok=True)
    shutil.copy2(apk, OUTPUT / "UniMarket.apk")
    source_count = archive(OUTPUT / "UniMarket_Source.zip", source_files(), ROOT, "UniMarket/")
    web_count = archive(OUTPUT / "UniMarket_Web.zip", sorted(p for p in web.rglob("*") if p.is_file()), web)
    artifacts = [OUTPUT / name for name in ("UniMarket.apk", "UniMarket_Source.zip", "UniMarket_Web.zip")]
    for name in ("UniMarket_Review1.pptx", "DEMO_ACCESS.txt"):
        assert (OUTPUT / name).is_file(), f"Finish {name} before packaging."
    for source, name in [
        (ROOT / "README.md", "README.md"),
        (ROOT / "docs/PROJECT_GUIDE.md", "PROJECT_GUIDE.md"),
        (ROOT / "docs/DEMO_RUNBOOK.md", "DEMO_RUNBOOK.md"),
        (ROOT / "docs/FINAL_RUBRIC_CHECKLIST.md", "FINAL_RUBRIC_CHECKLIST.md"),
        (ROOT / "docs/UniMarket_Blueprint.pdf", "UniMarket_Blueprint.pdf"),
    ]:
        shutil.copy2(source, OUTPUT / name)
    artifacts += [OUTPUT / "UniMarket_Review1.pptx", OUTPUT / "UniMarket_Blueprint.pdf"]
    checksums = "".join(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n" for path in artifacts)
    (OUTPUT / "SHA256SUMS.txt").write_text(checksums, encoding="utf-8")
    complete_files = [OUTPUT / name for name in (
        "UniMarket.apk", "UniMarket_Source.zip", "UniMarket_Web.zip", "UniMarket_Review1.pptx",
        "DEMO_ACCESS.txt", "README.md", "PROJECT_GUIDE.md", "DEMO_RUNBOOK.md",
        "FINAL_RUBRIC_CHECKLIST.md", "UniMarket_Blueprint.pdf", "SHA256SUMS.txt",
    )]
    complete_count = archive(OUTPUT / "UniMarket_Complete_PRIVATE.zip", complete_files, OUTPUT, "UniMarket/")
    for path in artifacts:
        print(f"{path.name}: {path.stat().st_size:,} bytes")
    print(f"Verified source entries: {source_count}; web entries: {web_count}; complete entries: {complete_count}")


if __name__ == "__main__":
    main()
