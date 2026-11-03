# Guild and ranks remake

Guilds now use Overview, Treasury, Upgrades, and Members tabs. The overview combines the shared goal with hall progression: every five installed upgrade levels adds one hall level, with titles at level milestones. Existing bank balances, upgrade levels, memberships, roles, and goal claims remain valid. Hall levels are derived recognition and do not grant additional economy multipliers.

Members can contribute and claim eligible goal rewards. Officers can purchase hall upgrades and remove ordinary members; leaders alone assign roles. The client and server share the permission policy. A departing leader is replaced by an officer first, then the earliest joiner, with numeric user ID breaking ties. Leave, disband, and kick actions require a second matching click within eight seconds and display confirmation labels.

Guild mutations share a synchronous request latch, timeout, server-error feedback, and stale/unmounted response guards. The server rejects stale non-member leave requests instead of reporting a successful leave.

Ranks have a new personal-position summary, score gap to the next position, category selection, global/server scope, readable full-width rows, refresh feedback, and a 30-second refresh interval. Equal scores use stable ID ordering. Omega scores retain their original representation when sorting server players, so values above ordinary floating-point range remain distinguishable. Duplicate identities and invalid scores are discarded; zero-score eligibility rules remain intact.

Validation:

- Full project verification, syntax checks, and Argon build passed.
- Pure fixtures verified every role/target combination, succession ordering, hall progression, Omega ordering, duplicate filtering, and request lifecycle behavior.
- Real GuildService methods ran against memory-only transactions for permission denial, role changes, leader succession, and membership cleanup.
- The actual ranks refresh effect was tested for player/guild request routing, zero-score filtering, timeout retention, late responses, and polling cleanup.
- Studio render checks covered empty guilds and populated boards at four viewport sizes, all four tabs of a 20-member guild at three sizes, and narrow Officer/Member rosters. No page errors or detected text overflow occurred at sampled scroll positions. The guild overview was visually inspected.
- All six changed/new game scripts matched the workspace by byte count and checksum after Argon synchronization.

Studio returned to Edit mode. No real guild memberships were modified for testing, no persistent datastore migration was required, and nothing was published. Physical console and VR testing was not performed in this pass.
