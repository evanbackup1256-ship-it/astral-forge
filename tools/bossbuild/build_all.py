"""Rebuild every boss body in Blender (needs the BlenderMCP addon running), then export the data module.

    python tools/bossbuild/build_all.py [Kind ...]
"""

import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
KINDS = ["Knight", "Warden", "Choir", "Regent", "Seraph", "Rime", "Astraeon"]


def main():
    wanted = sys.argv[1:] or KINDS
    with open(os.path.join(HERE, "build_boss.py"), "r", encoding="utf-8") as handle:
        source = handle.read()
    for kind in wanted:
        path = os.path.join(tempfile.gettempdir(), f"build_{kind}.py")
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(f'KIND_OVERRIDE = "{kind}"\n' + source)
        result = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "assetgen", "blender_rpc.py"), "run", path], capture_output=True, text=True)
        line = next((l for l in result.stdout.replace("\\n", "\n").splitlines() if l.startswith(f"{kind}:")), None)
        print(line or f"{kind}: FAILED\n{result.stdout[-600:]}{result.stderr[-300:]}", flush=True)
    subprocess.run([sys.executable, os.path.join(HERE, "export_bodies.py")], check=True)


if __name__ == "__main__":
    main()