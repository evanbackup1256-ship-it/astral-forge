# Evidence record

## Initial solo Studio session — 2026-10-05

Launch: documented StudioTestService.ExecutePlayModeAsync, using a temporary server watchdog. The temporary script and edit-workspace launch attributes were removed when the test returned. The watchdog ended the test; this is not a feature-completion result.

- AF_BASELINE_DESKTOP_20261005.png: original unmodified Studio capture. Reported client viewport was 991.2 × 635.2; the capture uses Studio's display scaling. Overview page and tutorial were visible. Captured after exact-color palette extraction and before the requested gameplay/layout rebuild.
- STUDIO_BASELINE_CONSOLE_20261005.txt: retrieved console, including historical retained output. New boot lines show server runtime start, temporary Studio save, client UI up, profile load and audio caching. Platform CorePackages timeouts are present and not hidden. This is not a clean-console sign-off.
- Initial read-only GUI inspection found approximately 1,600 PlayerGui descendants. No production DataStore test or multi-client transaction test was performed.

Sources were checksum-synced before launch: ForgeTheme, CoreKit and CoreServices. The 28 palette values were compared to the captured source baseline by verify_forge_theme. A rendered before/after visual comparison is still required.

## Initial gate results

- `lune run REGRESSION_SUITE/run.luau`: exit 0, with the new palette and guild lifecycle cases included.
- `rojo build default.project.json`: exit 0 for this worktree and for the primary checkout after the narrowly scoped palette/lifecycle port.
- `verify_guild_document_lifecycle`: the same extracted server functions in the primary checkout are exercised separately.
- Studio source checksum sync: ForgeTheme, CoreKit and CoreServices matched the manifest immediately before the successful solo baseline session.

These are initial-unit results only. SIGNOFF.md remains unsigned.
