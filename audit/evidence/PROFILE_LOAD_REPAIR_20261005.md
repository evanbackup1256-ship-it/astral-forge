# Main-checkout profile load repair

User log: attachments/684f1f25-8c08-4d26-affe-56edbc317d45/Pasted text.txt.
Studio: Astral Forge 135153679037687, e33f9561-9812-4780-8e81-ca294fa15687, Edit mode.

## Reproduction and changes
The main checkout added a four-field whitelist to DataSanitizeMath.Reconcile. Other legitimate OmegaMath persisted strings were converted using tonumber. Native Studio verified tonumber("1e400") becomes infinity, causing the profile integrity finite-number rejection.
Removed this premature conversion from the main checkout. Existing field-specific sanitizers retain responsibility for numeric validation. No saved profile was edited, reset or written by this repair.
Native Studio assertions passed for nested Collected, Balance and Principal, and Base and BiggestWin strings with exponents 400 through 700.

Bazaar rollover called yielding DataStore APIs during module initialization. Deferred the startup work beyond the module loader boundary. A failed read now returns before removing the saved rollover key. Actual DataStore rollover/concurrency recovery remains untested and requires redesign for cross-server ownership; this is not a durable escrow signoff.

InsertService.LoadAsset(95516912278016) succeeded with 63 descendants. Restored this actual existing kit ID and readiness in main CasinoKit, SharedData and assets/asset_ids.json. This is the existing kit, not the unfinished new ten-model asset set.

## Source provenance
Studio matched the separate main checkout at C:/Users/evanm/OneDrive/Desktop/Astral Forge v2, not the current worktree. Corrections were applied narrowly there and Studio Edit source confirmed synced. Source mismatch remains an integration issue; full worktree overhaul has not been merged into the main checkout.

## Outstanding
Full real-player profile load/rejoin and published-server validation are not confirmed. No Roblox publication performed. Eight legacy commerce IDs remain zero/unavailable; no unrelated product IDs substituted. The game-wide master goal remains incomplete.
