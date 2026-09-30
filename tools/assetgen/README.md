# Astral Forge asset generator

Generates the game's sounds, ambience and 3D model kit from code, with plain
Python 3 (no packages to install).

| File (in `assets/generated/`) | What it is | Upload as |
| --- | --- | --- |
| `AstralForgeSFX.wav` | ~193 sound effects in one sheet (near 1:1 cue voices: UI, forge, sanctuary curtain/ore/rift, Warden, rewards, boot) | Audio |
| `AstralForgeAmbience.wav` | 5 seamless region loops for the sanctuary (cosmic foundry beds) | Audio |
| `AstralForgeKit.glb` | 17 models: crystals, rocks, basalt columns, voidglass spires, obelisk, plinth, lantern, arena pillar, star, the Warden's core, plates, blades and halo, bridge deck | Model |

Until a file is uploaded, the game works exactly as before: the mixer keeps its
original sounds and the builders keep their part-built shapes. Effects (fire,
smoke, embers, motes, shockwaves, shatters, rift tethers) use particle textures
built into every Roblox client, so they work without any upload.

## Rebuild

```
python tools/assetgen/build.py              # everything (~4 minutes)
python tools/assetgen/build.py --only sfx   # or: ambience | kit
python tools/assetgen/check.py              # loudness, clipping, gaps, mesh winding, glb validity
```

`build.py` also rewrites `src/Shared/AstralForge/Shared/AssetManifest.luau`
(sheet regions, loudness, model sizes) and keeps the uploaded ids from
`assets/asset_ids.json`.

## Upload (Open Cloud)

1. Creator Hub -> Open Cloud -> API Keys -> create a key with the **Assets**
   API, **Read** and **Write**.
2. Save it (a hidden prompt; the key is stored in your Windows user
   environment, never in the project):

```
powershell -ExecutionPolicy Bypass -File tools/assetgen/set-key.ps1
```

3. Upload:

```
python tools/assetgen/upload.py
```

The uploader uses the account Roblox Studio is signed into on this machine
(set `ROBLOX_CREATOR_ID`, or `ROBLOX_GROUP_ID` for a group-owned game, to
override).

It uploads whatever still has id 0, writes the ids to `assets/asset_ids.json`
and regenerates the manifest. Sync the place (Rojo/Argon) and the new sounds
and models are live.

Notes:
- Roblox allows 10 audio uploads a month (100 if ID-verified). This uses two.
- New audio plays silently until it clears moderation; nothing breaks meanwhile.
- The game's owner must own the model, because the server loads it with
  `InsertService`.

## Upload (Studio, by hand)

- Asset Manager -> Bulk Import the two `.wav` files.
- Either import `AstralForgeKit.glb` with the 3D Importer and put the resulting
  Model in **ServerStorage**, named `AstralForgeKit` (the server looks there
  first), or upload it as a model and note its id.
- Put the ids in `assets/asset_ids.json`, then run
  `python tools/assetgen/build.py --manifest`.
