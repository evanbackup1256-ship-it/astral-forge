# Guild System — completion status

Last updated: 2026-10-06

## Implemented (not signed off)

- Protocol actions, firewall schemas/rate limits, read-only classification, client session grants/timeouts, and server `GameService` dispatch for community requests.
- `GuildCommunity` uses a per-guild DataStore document for bounded chat history (200), announcements (50), logo review history (12), mutes, bans, and settings; Studio has an in-memory fallback.
- Chat and announcements pass through `Security.Filter:Apply` before persistence/broadcast. Guild effects are sent only to online members, and join requests check ban records.
- Guild settings are leader-only; announcement management and member moderation are leader/officer-restricted, with officers limited to member targets. Guild logo approval is leader-only and accepts only Roblox asset IDs/URIs. Guild leader approval is an internal review step; Roblox platform moderation remains separate.
- Guild state includes settings and approved logo; scoped read actions provide chat and announcements only to active guild members. The client Guild Community tab offers chat, announcements, settings, logo upload/review, and member moderation controls.

## Verification status

- `argon build default.project.json`: passed after these changes.
- `lune run scripts/verify_project.luau`: playability/layout and prior regression guards pass, then the overall script exits nonzero in `scripts/verify_economy_projection` because `SharedData.luau` requires Roblox `script.Parent`, unavailable in Lune's plain runtime. This is not an overall test pass.
- After the final source repairs, `argon build default.project.json` passes again. A source-presence script verified request routing, filtering, and community UI landmarks; this is not a behavior test.
- Argon `serve` is running as PID 52332 and listening on IPv4/IPv6 port 8000 (HTTP 200).
- No Roblox Studio/live multi-user/DataStore/TextService end-to-end test has been run; guild functionality is not signed off.
- Argon serve process PID 52332 is listening on port 8000 (HTTP 200); the root page response itself does not prove Roblox runtime behavior.

## Remaining master-spec gaps

- Guild actions/UI require end-to-end Roblox Studio, live DataStore and TextService testing plus regression tests before sign-off.
- Multi-server guild chat federation is not implemented.
- Casino bespoke models remain a content deliverable; external Roblox asset/Product/Pass IDs remain blockers.
- Bazaar rebuild, Skill Tree/Ascension, Squad Loadout/Expedition Route planner, and expanded ranks rewrite remain incomplete. “DO THEM ALL” is not complete.
