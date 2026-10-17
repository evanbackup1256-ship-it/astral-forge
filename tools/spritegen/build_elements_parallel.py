"""Render native 4K sprites in two processes; only the parent writes/upload manifests.

Run: python tools/spritegen/build_elements_parallel.py --upload
Completed, content-verified assets are reused without redrawing or uploading.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ProcessPoolExecutor, as_completed
import hashlib
import json
import os
from pathlib import Path
import sys
import time

import build_elements_hq as hq
import build_elements as base
import build_elements_ext as ext
from PIL import Image


def verified_hash(path: Path) -> str:
    with Image.open(path) as image:
        if image.size != (4096, 4096) or image.mode != "RGBA":
            raise ValueError(f"{path.name}: expected native 4K RGBA atlas")
        image.verify()
    return hashlib.sha256(path.read_bytes()).hexdigest()


def render(name: str) -> tuple[str, str]:
    print(f"[4K] redrawing {name}", flush=True)
    return name, verified_hash(hq.render(name))

def save_manifest(manifest: dict, destination: Path) -> None:
    temporary = destination.with_suffix(".tmp")
    temporary.write_text(json.dumps(manifest, indent=2) + "\n")
    for attempt in range(12):
        try:
            temporary.replace(destination)
            return
        except PermissionError:
            if attempt == 11:
                raise
            print(f"[4K] manifest locked; retry {attempt + 1}/11", flush=True)
            time.sleep(0.5 * (attempt + 1))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upload", action="store_true")
    parser.add_argument("--recover-rendered", action="store_true",
                        help="Validate and reuse orphaned renders from an interrupted run of this generator")
    parser.add_argument("--workers", type=int, default=max(2, min(3, os.cpu_count() or 2)))
    args = parser.parse_args()
    if args.workers < 1:
        raise ValueError("--workers must be at least 1")
    hq.OUT.mkdir(parents=True, exist_ok=True)
    manifest = json.loads(hq.MANIFEST.read_text()) if hq.MANIFEST.exists() else {}
    generator = hashlib.sha256(
        Path(base.__file__).read_bytes() + Path(ext.__file__).read_bytes()
        + Path(hq.__file__).read_bytes()
    ).hexdigest()
    uploader = None
    key = None
    if args.upload:
        sys.path.insert(0, str(hq.ROOT / "tools" / "assetgen"))
        import upload

        uploader = upload
        key = uploader.saved("ROBLOX_API_KEY")
        if not key:
            raise RuntimeError("No Open Cloud key configured; no assets uploaded")

    def save() -> None:
        save_manifest(manifest, hq.MANIFEST)

    def finish(name: str, digest: str) -> None:
        previous = manifest.get(name, {})
        record = previous if previous.get("sha256") == digest else {}
        record.update(sha256=digest, generator=generator, size=4096, frame=682, count=36)
        manifest[name] = record
        save()
        if uploader is not None and not record.get("assetId"):
            print(f"[4K] uploading {name}", flush=True)
            record["assetId"] = uploader.upload(
                key, "Image", str(hq.OUT / f"{name}.png"), "image/png",
                f"AF Element {name} 4K",
                f"Native 4096x4096 Astral Forge {name} animation atlas, 36 high-detail frames.",
            )
            save()
        print(f"[4K] {name}: verified; {sum(bool(row.get('assetId')) for row in manifest.values())}/57 uploaded", flush=True)

    pending = []
    ready = []
    for name in base.ELEMENTS:
        path = hq.OUT / f"{name}.png"
        record = manifest.get(name, {})
        if args.recover_rendered and not record and path.exists():
            digest = verified_hash(path)
            with Image.open(path) as atlas:
                for index in range(36):
                    x, y = (index % 6) * 682, (index // 6) * 682
                    if atlas.crop((x, y, x + 682, y + 682)).getchannel("A").getbbox() is None:
                        raise ValueError(f"{name}: recovered frame {index} is empty")
            ready.append((name, digest))
            continue
        if path.exists() and record.get("generator") == generator:
            digest = verified_hash(path)
            if digest == record.get("sha256"):
                ready.append((name, digest))
                continue
        pending.append(name)
    # A small bounded pool overlaps rendering with uploads without exhausting shared-machine memory.
    with ProcessPoolExecutor(max_workers=args.workers) as pool:
        futures = {pool.submit(render, name): name for name in pending}
        for name, digest in ready:
            finish(name, digest)
        for future in as_completed(futures):
            name, digest = future.result()
            finish(name, digest)
    print("[4K] all native sheets complete", flush=True)


if __name__ == "__main__":
    main()
