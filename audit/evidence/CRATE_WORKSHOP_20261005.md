# Crate overhaul in progress

Connected to existing BlenderMCP using repository RPC client. Original Sanctuary — Art Review preserved. Separate Astral Forge — Crate Workshop has 20 independent body/lid rigs, eight redesigned skins and twelve new skins. Contact sheet inspected and revised for distinct new chassis silhouettes, lid seals and front hardware placement. Sources tools/cratebuild/workshop.py and bake_workshop.py. Actual Blender meshes/procedural materials; not image-generated mockups. Texture bake uses RTX4050 OptiX, 1024px maps, 16 samples and AABB UV packing. First body verified 6300 triangles.

Game catalog has 21 crates, 20 skins, and Stardust key offers for all 12 additions. Skin bonuses are deterministic essence per crate, bounded and ownership validated. Native Studio Edit verified counts and Titan five-open bonus 240. Dedicated fixture and full suite passed before final asset-loader changes. Rojo build passed before those final changes.

Texture bake/export, asset upload, actual viewport review, main-checkout opening/save-load/replay and published verification remain unfinished. Existing kit retained until validated replacement is available. New CrateKit ID intentionally zero pending actual upload; loader requires both meshes for all20 skins. No new model asset uploaded yet.


2026-10-06 update: all40 maps baked/exported/validated, floating legacy-lid ornaments corrected in Blender, model uploaded88755990794383 and exact40 textured references imported in native Studio. See CRATE_RUNTIME_20261006.md for native method tests and still-open runtime texture delivery/device/persistence gaps.
