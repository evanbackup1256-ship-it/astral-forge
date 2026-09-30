"""Upload the generated assets to Roblox with Open Cloud, then update the manifest.

It never runs as part of a build. It needs an Open Cloud key:

    powershell -ExecutionPolicy Bypass -File tools/assetgen/set-key.ps1   (saves it, prompted, once)
    python tools/assetgen/upload.py            # uploads anything whose id is still 0

The key is read from ROBLOX_API_KEY (this process or your saved Windows user
environment). The creator is ROBLOX_GROUP_ID or ROBLOX_CREATOR_ID if set,
otherwise the account Roblox Studio is signed into on this machine.

    python tools/assetgen/upload.py sfx        # just one: sfx | ambience | kit

The game must be owned by the same creator, because the server loads the model
kit with InsertService, which only loads assets its owner owns.

Audio uploads are limited per month (10 unverified, 100 ID-verified); this
uploads two audio files in total. New audio can take a little while to clear
moderation; until it does it plays silent, and the game keeps working.

Prefer Studio? Import AstralForgeKit.glb with the 3D Importer and the two .wav
files with the Asset Manager, then put the ids into assets/asset_ids.json and
run:  python tools/assetgen/build.py --manifest
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "generated")
IDS = os.path.join(ROOT, "assets", "asset_ids.json")
API = "https://apis.roblox.com/assets/v1"

UPLOADS = {
    "sfx": ("SoundSheet", "AstralForgeSFX.wav", "Audio", "audio/wav", "Astral Forge SFX", "Astral Forge interface and sanctuary sound effects."),
    "ambience": ("Ambience", "AstralForgeAmbience.wav", "Audio", "audio/wav", "Astral Forge Ambience", "Astral Forge sanctuary ambient loops."),
    "kit": ("Kit", "AstralForgeKit.glb", "Model", "model/gltf-binary", "Astral Forge Kit", "Astral Forge sanctuary model kit."),
}


def saved(name):
    """A variable from this process, or from the saved Windows user environment
    (so a key saved with set-key.ps1 works without restarting anything)."""
    value = os.environ.get(name)
    if value:
        return value
    try:
        import winreg

        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as key:
            return winreg.QueryValueEx(key, name)[0] or None
    except (ImportError, OSError):
        return None


def studio_user_id():
    """The user id Roblox Studio is signed in with on this machine."""
    path = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "LocalStorage", "appStorage.json")
    try:
        with open(path, "r", encoding="utf-8") as f:
            value = json.load(f).get("UserId")
        return str(int(value)) if value else None
    except (OSError, ValueError, TypeError):
        return None


def creator():
    group = saved("ROBLOX_GROUP_ID")
    if group:
        return {"groupId": str(group)}
    user = saved("ROBLOX_CREATOR_ID") or studio_user_id()
    if user:
        return {"userId": str(user)}
    sys.exit("Set ROBLOX_CREATOR_ID (your user id) or ROBLOX_GROUP_ID.")


def request(method, url, key, body=None, content_type=None):
    last_error = None
    for attempt in range(4):
        req = urllib.request.Request(url, data=body, method=method)
        req.add_header("x-api-key", key)
        if content_type:
            req.add_header("Content-Type", content_type)
        try:
            with urllib.request.urlopen(req, timeout=180) as response:
                return json.loads(response.read() or b"{}")
        except urllib.error.HTTPError as err:
            detail = err.read().decode("utf-8", "replace")
            sys.exit(f"{method} {url} failed: {err.code} {detail}")
        except urllib.error.URLError as err:
            last_error = err
            print(f"  connection dropped ({err}); retry {attempt + 1}/4")
            time.sleep(2 + attempt * 3)
    sys.exit(f"{method} {url} failed: {last_error}")


def upload(key, asset_type, path, mime, name, description):
    meta = {
        "assetType": asset_type,
        "displayName": name,
        "description": description,
        "creationContext": {"creator": creator()},
    }
    boundary = uuid.uuid4().hex
    with open(path, "rb") as f:
        payload = f.read()
    parts = [
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n".encode(),
        json.dumps(meta).encode(),
        f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{os.path.basename(path)}\"\r\nContent-Type: {mime}\r\n\r\n".encode(),
        payload,
        f"\r\n--{boundary}--\r\n".encode(),
    ]
    operation = request("POST", f"{API}/assets", key, b"".join(parts), f"multipart/form-data; boundary={boundary}")
    path_id = operation.get("path") or f"operations/{operation.get('operationId')}"
    # Poll the operation until the asset exists.
    for attempt in range(60):
        status = request("GET", f"{API}/{path_id}", key)
        if status.get("done"):
            if "error" in status:
                sys.exit(f"upload failed: {status['error']}")
            return int(status["response"]["assetId"])
        time.sleep(min(10, 1 + attempt))
    sys.exit(f"timed out waiting for {path_id}; check Creator Hub, then set the id in {IDS}")


def main():
    key = saved("ROBLOX_API_KEY")
    if not key:
        sys.exit("No Open Cloud key yet: run  powershell -ExecutionPolicy Bypass -File tools/assetgen/set-key.ps1")
    print(f"uploading as {creator()}")
    ids = {"SoundSheet": 0, "Ambience": 0, "Kit": 0}
    if os.path.exists(IDS):
        with open(IDS, "r", encoding="utf-8") as f:
            ids.update(json.load(f))
    wanted = sys.argv[1:] or [k for k, spec in UPLOADS.items() if not ids.get(spec[0])]
    for which in wanted:
        field, file_name, asset_type, mime, name, description = UPLOADS[which]
        path = os.path.join(OUT, file_name)
        print(f"uploading {file_name} as {asset_type} ...")
        ids[field] = upload(key, asset_type, path, mime, name, description)
        print(f"  -> {field} = {ids[field]}")
        with open(IDS, "w", encoding="utf-8") as f:
            json.dump(ids, f, indent=2)
    # Rewrite the Luau manifest with the new ids.
    sys.path.insert(0, HERE)
    import build  # noqa: E402

    sys.argv = [sys.argv[0], "--manifest"]
    build.main()


if __name__ == "__main__":
    main()
