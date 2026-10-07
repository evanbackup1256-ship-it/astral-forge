"""Validate baked GLB content and normalize Blender mesh datablock suffixes."""
from pathlib import Path
import json
import struct

FOLDER = Path(__file__).resolve().parents[2] / "assets/generated/crates"
path = FOLDER / "CrateKit.glb"
raw = path.read_bytes()
magic, version, total = struct.unpack_from("<III", raw)
assert magic == 0x46546C67 and version == 2 and total == len(raw)
json_length, json_type = struct.unpack_from("<II", raw, 12)
assert json_type == 0x4E4F534A
document = json.loads(raw[20:20 + json_length])
manifest = json.loads((FOLDER / "manifest.json").read_text())
expected = {entry[role] for entry in manifest for role in ("Body", "Lid")}
nodes = [node for node in document["nodes"] if "mesh" in node]
assert len(nodes) == len(document["meshes"]) == 40
assert {node["name"] for node in nodes} == expected
records = []
for node in nodes:
    mesh = document["meshes"][node["mesh"]]
    mesh["name"] = node["name"]
    triangles = 0
    for primitive in mesh["primitives"]:
        assert primitive.get("mode", 4) == 4
        count = document["accessors"][primitive["indices"]]["count"]
        triangles += count // 3
        assert "TEXCOORD_0" in primitive["attributes"]
        material = document["materials"][primitive["material"]]
        assert "baseColorTexture" in material["pbrMetallicRoughness"]
    assert 0 < triangles <= 19500
    records.append({"part": node["name"], "triangles": triangles})
encoded = json.dumps(document, separators=(",", ":")).encode()
encoded += b" " * ((-len(encoded)) % 4)
binary_chunks = raw[20 + json_length:]
size = 12 + 8 + len(encoded) + len(binary_chunks)
path.write_bytes(struct.pack("<III", magic, version, size)
                 + struct.pack("<II", len(encoded), json_type) + encoded + binary_chunks)
(FOLDER / "glb-validation.json").write_text(json.dumps(records, indent=2))
print(f"Validated 40 named, textured mesh parts; maximum triangles: {max(x['triangles'] for x in records)}")
