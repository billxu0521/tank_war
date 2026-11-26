"""從固定版共用規則與本次地圖來源組出可獨立開啟的 Godot 專案。"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile


def assemble(destination: Path) -> None:
    source = Path(__file__).resolve().parent
    manifest = json.loads((source / "files.json").read_text(encoding="utf-8"))
    destination = destination.resolve()
    if destination.exists():
        raise FileExistsError(f"請指定新的輸出目錄：{destination}")
    base_paths = [name for name, (owner, _) in manifest["files"].items() if owner == "base"]
    with tempfile.TemporaryDirectory(dir=destination.parent) as staging, tempfile.TemporaryFile() as archive:
        subprocess.run(["git", "archive", manifest["base"], "--", *base_paths],
                       cwd=source.parents[3], stdout=archive, check=True)
        archive.seek(0)
        with tarfile.open(fileobj=archive, mode="r:") as baseline:
            for name, (owner, expected) in manifest["files"].items():
                relative = Path(name)
                if relative.is_absolute() or ".." in relative.parts:
                    raise ValueError(name)
                if owner == "base":
                    with baseline.extractfile(name) as entry:
                        data = entry.read()
                elif owner == "source":
                    data = (source / "source" / relative).read_bytes()
                else:
                    raise ValueError(owner)
                if hashlib.sha256(data).hexdigest() != expected:
                    raise ValueError(f"內容與 r014 指紋不同：{name}")
                path = Path(staging) / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
        Path(staging).rename(destination)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path, help="上層目錄已存在的新專案路徑")
    assemble(parser.parse_args().destination)
