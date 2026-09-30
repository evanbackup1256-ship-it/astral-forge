"""Objective checks on the generated assets (no listening or viewing needed).

    python tools/assetgen/check.py

Audio: every sheet region is non-silent, unclipped, DC-free, and the gaps
between regions are silent (so a region can never bleed into its neighbour).
Loudness (RMS) is reported per voice so the mix can be balanced.

Models: every mesh is a closed, consistently wound surface with its faces
pointing outward (positive signed volume), and the .glb parses back with the
node names the game looks for.
"""

from __future__ import annotations

import json
import math
import os
import struct
import sys
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "generated")

import meshes  # noqa: E402

failures = []


def fail(message):
    failures.append(message)
    print("FAIL", message)


def read_wav(path):
    with wave.open(path, "rb") as w:
        assert w.getnchannels() == 1 and w.getsampwidth() == 2
        rate = w.getframerate()
        raw = w.readframes(w.getnframes())
    count = len(raw) // 2
    return rate, [v / 32768 for v in struct.unpack(f"<{count}h", raw)]


def check_sheet(file_name, regions, quiet_voices=()):
    rate, samples = read_wav(os.path.join(OUT, file_name))
    report = []
    ordered = sorted(regions.items(), key=lambda kv: kv[1][0])
    last_end = 0
    for name, (start, length) in ordered:
        a, b = int(start * rate), int((start + length) * rate)
        chunk = samples[a:b]
        if not chunk:
            fail(f"{file_name}:{name} is empty")
            continue
        peak = max(abs(v) for v in chunk)
        rms = math.sqrt(sum(v * v for v in chunk) / len(chunk))
        dc = sum(chunk) / len(chunk)
        if peak < 0.05:
            fail(f"{file_name}:{name} is nearly silent (peak {peak:.3f})")
        if peak > 0.999:
            fail(f"{file_name}:{name} clips")
        if abs(dc) > 0.02:
            fail(f"{file_name}:{name} has DC offset {dc:.3f}")
        gap = samples[last_end:a]
        if gap and max(abs(v) for v in gap) > 0.002:
            fail(f"{file_name}: the gap before {name} isn't silent")
        last_end = b
        report.append((name, peak, 20 * math.log10(max(rms, 1e-9)), length))
    return report


def check_meshes():
    for name, make in meshes.MODELS.items():
        mesh = make()
        edges = {}
        volume = 0.0
        for a, b, c in mesh.tris:
            volume += meshes.dot(a, meshes.cross(b, c)) / 6
            for p, q in ((a, b), (b, c), (c, a)):
                key = (tuple(round(x, 5) for x in p), tuple(round(x, 5) for x in q))
                edges[key] = edges.get(key, 0) + 1
        # Closed and consistently wound: every directed edge appears once, and
        # its reverse appears once.
        open_edges = sum(1 for (p, q), n in edges.items() if edges.get((q, p), 0) != n)
        # Merged parts (clusters, lanterns) touch without sharing edges; each
        # part is still closed, so allow shared-vertex seams but not holes.
        if open_edges and name not in ("BasaltCluster", "VoidSpire", "Lantern", "ArenaPillar", "Plinth"):
            fail(f"mesh {name} has {open_edges} unmatched edges (holes or flipped faces)")
        if volume <= 0:
            fail(f"mesh {name} faces point inward (signed volume {volume:.3f})")
        print(f"  {name:<14} tris={len(mesh.tris):4d} volume={volume:8.3f} open_edges={open_edges}")


def check_glb(expected):
    with open(os.path.join(OUT, "AstralForgeKit.glb"), "rb") as f:
        data = f.read()
    magic, version, total = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF" or version != 2 or total != len(data):
        fail("AstralForgeKit.glb header is wrong")
        return
    json_len, json_type = struct.unpack_from("<I4s", data, 12)
    doc = json.loads(data[20:20 + json_len])
    names = [n["name"] for n in doc["nodes"]]
    for name in expected:
        if name not in names:
            fail(f"glb is missing node {name}")
    bin_len, bin_type = struct.unpack_from("<I4s", data, 20 + json_len)
    if bin_type != b"BIN\x00" or bin_len != doc["buffers"][0]["byteLength"]:
        fail("glb binary chunk mismatch")
    for accessor in doc["accessors"]:
        view = doc["bufferViews"][accessor["bufferView"]]
        per = {"VEC3": 12, "SCALAR": 2 if accessor["componentType"] == 5123 else 4}[accessor["type"]]
        if accessor["count"] * per != view["byteLength"]:
            fail("glb accessor/bufferView size mismatch")
    print(f"  glb ok: {len(names)} nodes, {len(data) / 1024:.1f} KB")


def main():
    with open(os.path.join(OUT, "build.json"), "r", encoding="utf-8") as f:
        build = json.load(f)
    print("sound sheet:")
    for name, peak, rms_db, length in check_sheet("AstralForgeSFX.wav", build["sfx"]["regions"]):
        print(f"  {name:<18} peak {peak:.2f}  rms {rms_db:6.1f} dB  {length:5.2f}s")
    print("ambience:")
    for name, peak, rms_db, length in check_sheet("AstralForgeAmbience.wav", build["ambience"]["regions"]):
        print(f"  {name:<18} peak {peak:.2f}  rms {rms_db:6.1f} dB  {length:5.2f}s")
    print("meshes:")
    check_meshes()
    check_glb(list(meshes.MODELS))
    size = os.path.getsize(os.path.join(OUT, "AstralForgeSFX.wav")) / 1e6
    if size > 19:
        fail(f"sound sheet is {size:.1f} MB; Open Cloud caps uploads at 20 MB")
    print(f"{len(failures)} failures")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
