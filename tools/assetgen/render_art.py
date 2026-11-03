"""Render the designed art in tools/assetgen/art/ to transparent PNGs in assets/generated/art/.

    python tools/assetgen/render_art.py            render everything in ART_LIST
    python tools/assetgen/render_art.py boot       only names that start with "boot"

Each piece is an HTML page with an inline SVG drawn at its final pixel size; variants of one drawing are the
same page with a query string (warden.html?state=windup). Headless Edge takes the screenshot with a transparent
background, so the PNGs keep their alpha. Nothing here talks to Roblox: upload_art.py does that.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SRC = HERE / "art"
OUT = ROOT / "assets" / "generated" / "art"
EDGE = Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")

# output name -> (page with optional query, width, height)
ART_LIST: dict[str, tuple[str, int, int]] = {
    # loading screen
    "boot-backdrop": ("boot_backdrop.html", 1024, 576),
    "boot-ring-outer": ("boot_rings.html?ring=outer", 1024, 1024),
    "boot-ring-arc": ("boot_rings.html?ring=arc", 1024, 1024),
    "boot-ring-orbit": ("boot_rings.html?ring=orbit", 1024, 1024),
    "boot-core-glow": ("boot_rings.html?ring=glow", 512, 512),
    "boot-shockwave": ("boot_rings.html?ring=shock", 512, 512),
    # the loading screen's clock: dial, movement and hands, each its own layer
    "clock-dial": ("clock.html?part=dial", 1024, 1024),
    "clock-wheel": ("clock.html?part=wheel", 512, 512),
    "clock-pinion": ("clock.html?part=pinion", 512, 512),
    "clock-escape": ("clock.html?part=escape", 512, 512),
    "clock-hour": ("clock.html?part=hour", 1024, 1024),
    "clock-minute": ("clock.html?part=minute", 1024, 1024),
    "clock-second": ("clock.html?part=second", 1024, 1024),
    "clock-cap": ("clock.html?part=cap", 128, 128),
    # the Reaches
    "warden-idle": ("warden.html?state=idle", 1024, 1024),
    "warden-windup": ("warden.html?state=windup", 1024, 1024),
    "warden-down": ("warden.html?state=down", 1024, 1024),
    "ore-emberite": ("ore.html?ore=emberite", 512, 512),
    "ore-voidglass": ("ore.html?ore=voidglass", 512, 512),
    "ore-starsteel": ("ore.html?ore=starsteel", 512, 512),
    "ore-emberite-spent": ("ore.html?ore=emberite&spent=1", 512, 512),
    "ore-voidglass-spent": ("ore.html?ore=voidglass&spent=1", 512, 512),
    "ore-starsteel-spent": ("ore.html?ore=starsteel&spent=1", 512, 512),
    # the Star Foundry
    "foundry-board": ("foundry.html?piece=board", 1024, 1024),
    "foundry-socket": ("foundry.html?piece=socket", 256, 256),
    "foundry-socket-target": ("foundry.html?piece=socket-target", 256, 256),
    "foundry-ember": ("foundry.html?piece=ember", 256, 256),
    "foundry-conduit": ("foundry.html?piece=conduit", 256, 256),
    "foundry-lens": ("foundry.html?piece=lens", 256, 256),
    "foundry-prism": ("foundry.html?piece=prism", 256, 256),
    "foundry-forge-anvil": ("foundry.html?piece=forge-anvil", 256, 256),
    "foundry-strike-anvil": ("foundry.html?piece=strike-anvil", 256, 256),
    "foundry-vault-anvil": ("foundry.html?piece=vault-anvil", 256, 256),
    "foundry-echo-anvil": ("foundry.html?piece=echo-anvil", 256, 256),
    "foundry-lit": ("foundry.html?piece=lit", 256, 256),
    "foundry-beam": ("foundry.html?piece=beam", 512, 32),
    "foundry-spark": ("foundry.html?piece=spark", 64, 64),
    "foundry-arrow": ("foundry.html?piece=arrow", 256, 64),
}


def render(name: str, page: str, width: int, height: int) -> Path | None:
    OUT.mkdir(parents=True, exist_ok=True)
    target = OUT / f"{name}.png"
    url = (SRC / page.split("?")[0]).as_uri() + ("?" + page.split("?", 1)[1] if "?" in page else "")
    if target.exists():
        target.unlink()
    # each render gets its own throwaway profile: headless Edge instances sharing one can block each other,
    # and Edge sometimes lingers after writing the screenshot, so stop it once the file has settled
    profile = Path(tempfile.mkdtemp(prefix="af_edge_"))
    process = subprocess.Popen(
        [
            str(EDGE),
            "--headless=new",
            "--disable-gpu",
            "--hide-scrollbars",
            "--no-first-run",
            f"--user-data-dir={profile}",
            "--force-device-scale-factor=1",
            "--default-background-color=00000000",
            f"--window-size={width},{height}",
            f"--screenshot={target}",
            url,
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    last = -1
    for _ in range(240):
        time.sleep(0.25)
        size = target.stat().st_size if target.exists() else 0
        if size > 0 and size == last:
            break
        last = size
        if process.poll() is not None and size > 0:
            break
    subprocess.run(["taskkill", "/F", "/T", "/PID", str(process.pid)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    shutil.rmtree(profile, ignore_errors=True)
    if not target.exists() or target.stat().st_size == 0:
        return None
    return target


def main():
    prefix = sys.argv[1] if len(sys.argv) > 1 else ""
    for name, (page, width, height) in ART_LIST.items():
        if prefix and not name.startswith(prefix):
            continue
        path = None
        # headless Edge now and then exits without writing; a second try nearly always works
        for _attempt in range(3):
            path = render(name, page, width, height)
            if path is not None:
                break
        if path is None:
            sys.exit(f"{name}: Edge produced no image after three tries")
        print(f"{name}: {path.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
