#!/usr/bin/env python3
"""Package a Godot 4.3 Web export with one immutable filename set per commit.

Keep all files at the original URL directory and preserve /userfs (IndexedDB).
No service worker, cache deletion or save migration is needed.
"""
import argparse
import hashlib
import json
import pathlib
import re


def package(directory: pathlib.Path, commit: str, ref: str) -> None:
    if not re.fullmatch(r"[a-f0-9]{40}", commit):
        raise ValueError("A full commit SHA is required")
    shell = (directory / "index.html").read_text()
    stem = f"index.{commit}"
    # Rename the executable as well as the script: Godot derives WASM, PCK and
    # audio-worklet URLs from config.executable. Versioning just the script fails.
    files = sorted(p for p in directory.glob("index.*")
                   if not re.match(r"index\.[a-f0-9]{40}\.", p.name))
    if not {"index.js", "index.wasm", "index.pck"} <= {p.name for p in files}:
        raise ValueError("Incomplete Godot Web export")
    for source in files:
        if source.suffix == ".html":
            continue
        target = directory / source.name.replace("index.", stem + ".", 1)
        shell = shell.replace(source.name, target.name)
        source.rename(target)
    # Godot's generated compact JSON contains the executable without an extension.
    shell, count = re.subn(r'"executable"\s*:\s*"index"', f'"executable":"{stem}"', shell)
    if count != 1:
        raise ValueError("Unexpected Godot executable configuration")
    guard = (pathlib.Path(__file__).resolve().parents[1] / "web/release-guard.js").read_text()
    shell = shell.replace("</head>", "<script>\n" + guard + "</script>\n</head>", 1)
    (directory / f"{stem}.html").write_text(shell)
    # This tiny entry may itself be cached: its inline code always fetches the
    # manifest from the network, so it still selects the new release.
    (directory / "index.html").write_text('''<!doctype html>
<html lang="ru"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Little Village Shop</title></head><body>
<p id="notice">Проверяем версию игры…</p>
<script>\n''' + guard + '''
window.villageReleaseReady.catch(error => {
  document.getElementById('notice').textContent = 'Игра не загрузилась. Проверьте соединение и перезагрузите страницу. ' + error.message;
});
</script></body></html>
''')
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
              for p in sorted(directory.glob(f"{stem}.*"))}
    (directory / "build-info.json").write_text(json.dumps({
        "commit": commit, "ref": ref, "entry": f"{stem}.html",
        "godot": "4.3.stable", "thread_support": False, "sha256": hashes,
    }, indent=2) + "\n")
    (directory / ".nojekyll").touch()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("commit")
    parser.add_argument("--ref", default="local")
    args = parser.parse_args()
    package(args.directory, args.commit, args.ref)
