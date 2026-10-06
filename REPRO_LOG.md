# Astral Forge v2 — Reproduction Log

> Every fix must be reproducible before it is merged. This log records the bug, the repro, the fix, and the regression test.
> Last updated: 2026-10-05

## Template

```
### R-<n>: <Title>
- **System:** <Data stores / Remotes / Replication / Currency / Inventory / Cooldowns / Guild / Ranks / Casino / Bazaar / Astral Forge>
- **Severity:** Critical / High / Medium / Low
- **File:line:** `<path>:<line>`
- **Status:** Reproduced / Fixed / Verified / Regression added

#### Repro steps
1. <step>
2. <step>
3. <step>

#### Expected
<what should happen>

#### Actual
<what happened, including stack trace if applicable>

#### Fix
<what changed>

#### Verification
<test, command, or observation that proves the fix>
```

## Logged reproductions

### R-1: GameConfig nil overwrite for SeasonTiers/Milestones
- **System:** Config / Shared
- **Severity:** Critical
- **File:line:** `src/Shared/AstralForge/Shared/GameConfig.luau:7229`
- **Status:** Fixed, verified

#### Repro steps
1. Load `GameConfigGenerated.luau`; confirm it has no `SeasonTiers` or `Milestones` keys.
2. Run `require(GameConfig).Operations.SeasonTiers` before and after `GameConfigGenerated` adoption.
3. Observe that after adoption the table is `nil`.

#### Expected
Lazy-loaded `SeasonTiers`/`Milestones` tables remain available even if the generated module omits them.

#### Actual
`GameConfig.Operations.SeasonTiers = Generated.SeasonTiers` sets the value to `nil`, causing `attempt to iterate nil` in `CoreServices` state push.

#### Fix
Guard each generated assignment: only adopt the generated section when it is non-nil.

#### Verification
`npm test` passes; `print(GameConfig.Anomalies.Milestones)` returns a table after adoption.

---

### R-2: ForgeTheme.luau untracked breaks client boot
- **System:** Sync / Client
- **Severity:** High
- **File:line:** `src/Client/AstralForge/CoreKit.luau:284`
- **Status:** Fixed, verified

#### Repro steps
1. Run `git ls-files src/Shared/AstralForge/Shared/ForgeTheme.luau`.
2. Confirm the file exists on disk but is not tracked.
3. Simulate a clean clone and Argon build; client fails to require `ReplicatedStorage.AstralForge.Shared.ForgeTheme`.

#### Expected
The required module is tracked so a clean checkout builds successfully.

#### Actual
Module missing on clean checkout; client throws at boot.

#### Fix
`git add src/Shared/AstralForge/Shared/ForgeTheme.luau`.

#### Verification
`argon build default.project.json -x -o "Astral Forge v2.rbxlx"` succeeds; `git status` shows the file tracked.

---

### R-3: AsynchronousActorScheduler drain lock wedge
- **System:** Client runtime
- **Severity:** High
- **File:line:** `src/Client/SharedRuntime/modules/RuntimeKit.luau:983`
- **Status:** Fixed, verified

#### Repro steps
1. Schedule a job whose `complete` callback throws.
2. Observe that `drain` throws before `self.lock:leave("drain")`.
3. Subsequent calls to `schedule()` never execute.

#### Expected
Scheduler continues processing after a callback error.

#### Actual
Lock stays entered; scheduler silently wedges.

#### Fix
Wrap the drain body and callbacks in `pcall`; always call `lock:leave` afterwards.

#### Verification
`npm test`; custom `RuntimeKit` extract passes.

---

### R-4: PlayerScriptsLoader camera not restored on CurrentCamera replacement
- **System:** Client bootstrap
- **Severity:** High
- **File:line:** `src/Client/PlayerScriptsLoader.client.luau:26`
- **Status:** Fixed, verified

#### Repro steps
1. Run `Workspace.CurrentCamera = workspace.CurrentCamera:Clone()` after bootstrap.
2. Observe that the new camera reverts to `Custom` while `PlayerModule` is disabled.

#### Expected
Camera stays `Scriptable` even when Roblox replaces it.

#### Fix
Connect `Workspace:GetPropertyChangedSignal("CurrentCamera")` and re-apply `Scriptable` mode.

#### Verification
`npm test` passes; manual Studio repro confirms camera stays Scriptable after replacement.

---

### R-5: VerifyCreatorFollow grants reward without verification
- **System:** Server economy / security
- **Severity:** High
- **File:line:** `src/Server/AstralForge/Services/ServerServices.luau:3369`
- **Status:** Fixed, verified

#### Repro steps
1. Invoke `VerifyCreatorFollow` remote from any client.
2. Observe `SocialRewards.CreatorFollowClaimed = true` and `ProgressionService.ApplyReward` run unconditionally.

#### Expected
Reward only granted when a trusted verification source confirms the follow.

#### Actual
Any client could claim the creator-follow reward once.

#### Fix
Gate reward to `RunService:IsStudio() and ServerConfig.AllowStudioFollowVerification == true`; otherwise reject.

#### Verification
`npm test` session-gate and economy/admin regress guards pass.

---

### R-6: Document.Update mutates cache before DataStore write
- **System:** Data stores
- **Severity:** High
- **File:line:** `src/Server/AstralForge/Modules/Documents/DocumentService/Document.luau:640`
- **Status:** Fixed, verified

#### Repro steps
1. Call `Document:Update` while another server holds the session lock.
2. `UpdateAsync` fails with `SessionLockedError`.
3. Continue mutating the profile; changes never persist.

#### Expected
Cache reflects DataStore state; failed writes leave cache unchanged.

#### Actual
Cache is updated optimistically before persistence, creating a diverged ghost session.

#### Fix
Stage transformed data as `pendingData`; only call `SetCache` after `UpdateAsync` succeeds.

#### Verification
`npm test` profile version guards and data-service residual gates pass.

---

### R-7: Trade settlement non-atomic across two profiles
- **System:** Bazaar / trade
- **Severity:** High
- **File:line:** `src/Server/AstralForge/Modules/TradeSuite.luau`
- **Status:** Fixed, verified

#### Repro steps
1. Start a trade and confirm both sides.
2. Kill the server between host commit and guest commit/revert.
3. Rejoin and inspect both profiles.

#### Expected
Interrupted trade is reconciled on next profile load; no duplication or loss.

#### Actual
Profiles may diverge; faulted state was silently permanent.

#### Fix
Write per-profile `FaultedJournal` on permanent fault; add `TradeRecovery.RecoverFaulted` run during `DataService:Load`.

#### Verification
`npm test` trade settle invariants and settle orchestrate regress gates pass.

---

### R-8: Bazaar lottery state lost on server shutdown
- **System:** Bazaar
- **Severity:** Medium
- **File:line:** `src/Server/AstralForge/Services/BazaarService.luau`
- **Status:** Fixed, verified

#### Repro steps
1. Add tickets to the lottery and do not draw.
2. Shut down the server.
3. Start a new server and check lottery state.

#### Expected
Pot and pending tickets roll over.

#### Actual
State resets to zero; pending entries lost.

#### Fix
Persist lottery pot/tickets/pending to a DataStore key on `BindToClose`; restore on service start.

#### Verification
`npm test` bazaar math guards pass; new `BindToClose` handler logs save attempt.

---

### R-9: Convergence contributions dropped on fast shutdown
- **System:** Economy / convergence
- **Severity:** Medium
- **File:line:** `src/Server/AstralForge/Services/ConvergenceService.luau`
- **Status:** Fixed, verified

#### Repro steps
1. Record many convergence actions quickly.
2. Trigger `BindToClose`.
3. Start a new server.

#### Expected
Pending personal/global contributions are flushed or recovered.

#### Actual
2.5s shutdown budget drops pending data.

#### Fix
`ShutdownFlush()` with 10s budget, stash failed flushes by UserId for rejoin recovery.

#### Verification
`npm test` convergence math extract guards pass.

---

### R-10: MatterRuntime hard-assert aborts server bootstrap
- **System:** Server runtime / sync
- **Severity:** High
- **File:line:** `src/Server/AstralForge/Services/MatterRuntime.luau:11`
- **Status:** Fixed, verified

#### Repro steps
1. Build with `default.project.json` missing the `rbxts_include.node_modules.@rbxts.matter` mapping.
2. Start the server.

#### Expected
Server starts with Matter-dependent systems disabled.

#### Actual
`assert` fails; `GameService` construction aborts; whole server down.

#### Fix
Wrap require chain in `pcall`; return a frozen no-op MatterRuntime; nil-guard all callers.

#### Verification
`npm test` serverservices extract passes; `argon build` succeeds.

---

### R-11: CasinoKitLoader silently inserts untrusted assets
- **System:** Casino / sync
- **Severity:** Medium
- **File:line:** `src/Server/AstralForge/CasinoKitLoader.luau`
- **Status:** Fixed, verified

#### Repro steps
1. Set `asset_ids.json["Kit"]` to a moderated or arbitrary asset ID.
2. Run `CasinoKitLoader.load()`.

#### Expected
Untrusted/invalid content is rejected and logged.

#### Actual
Anything returned by `InsertService:LoadAsset` is used; failures silent.

#### Fix
Validate root `ClassName` against allowlist; early-return for `assetId <= 0`; log each retry failure.

#### Verification
`npm test` passes; `KitReady=false` startup warning visible.

---

### R-12: GameAntiCheat cash-velocity detection observational only
- **System:** Security / economy
- **Severity:** Medium
- **File:line:** `src/Server/AstralForge/Services/GameAntiCheat.luau`
- **Status:** Fixed, verified

#### Repro steps
1. Forge a cash value exceeding the production ceiling.
2. Observe that the detector logs but does not prevent the credit.

#### Expected
Suspicious credits can be rejected when enforcement is enabled.

#### Actual
Ceiling exceeded but mutation applied anyway.

#### Fix
Add `GameAntiCheat.EnforcementEnabled` flag; return `wouldReject`; callers abort the transaction when enforcement is on.

#### Verification
`npm test` economy/admin regress and AtomicState residual gates pass.

---

### R-13: RemoteFirewall EXEMPT_ACTIONS bypass per-action cooldowns
- **System:** Security / cooldowns
- **Severity:** Medium
- **File:line:** `src/Server/AstralForge/Services/RemoteFirewall.luau:143`
- **Status:** Fixed, verified

#### Repro steps
1. Rapidly invoke `Rebirth`, `ClaimDaily`, or trade actions.
2. Observe they skip the per-action cooldown table in `RemoteFirewall`.
3. Only the generic 8/s token-bucket rate limit applies.

#### Expected
Each action respects a per-action minimum cooldown appropriate to its cost/risk.

#### Actual
Exempt actions can fire at ~8 Hz with no dedicated cooldown.

#### Fix
Add per-action cooldowns for non-spammable exempt actions (`Rebirth`, `ClaimDaily`, `ClaimAllMail`, trade actions); keep `CollectVault`/`Overcharge` exempt only from payload cost, not from rate limits if needed.

#### Verification
`npm test` passes; `argon build default.project.json -x -o "Astral Forge v2.rbxlx"` succeeds.---

### R-14: PulseAnomaly has no server-enforced minimum interval
- **System:** Astral Forge / anomaly
- **Severity:** Medium
- **File:line:** `src/Server/AstralForge/Services/CoreServices.luau:183`
- **Status:** Fixed, verified

#### Repro steps
1. Repeatedly invoke `PulseAnomaly` as fast as the 0.08s firewall cooldown allows.
2. Observe every pulse grants charge regardless of `LastActionAt`.

#### Expected
A server-enforced minimum interval prevents spam-pulsing outside the intended window.

#### Actual
`LastActionAt` is written but never read; charge accrues every 0.08s.

#### Fix
Read `profile.Anomaly.LastActionAt` and reject pulses within the configured minimum interval.

#### Verification
`npm test` passes; `argon build default.project.json -x -o "Astral Forge v2.rbxlx"` succeeds.---

### R-15: Echo Capture can error with empty preferred trait list
- **System:** Astral Forge / echoes
- **Severity:** Medium
- **File:line:** `src/Server/AstralForge/Services/CoreServices.luau:771`
- **Status:** Fixed, verified

#### Repro steps
1. Configure an affinity with no matching traits.
2. Invoke `CaptureEcho`.
3. `random:NextInteger(1, 0)` throws.

#### Expected
Capture falls back gracefully (random trait or explicit failure message).

#### Fix
Guard `NextInteger` lower bound ≤ upper bound; if no preferred trait, pick uniformly from all traits.

#### Verification
`npm test` passes; `argon build default.project.json -x -o "Astral Forge v2.rbxlx"` succeeds.---

### R-16: PendingAnomalyActions can drop actions between snapshot and clear
- **System:** Astral Forge / anomaly / data
- **Severity:** Medium
- **File:line:** `src/Server/AstralForge/Services/ServerServices.luau:4680`
- **Status:** Fixed, verified

#### Repro steps
1. Queue many anomaly charge actions rapidly.
2. Have the production tick skip or run while `IsBusy`.
3. Observe pending actions appended after the snapshot reference are lost on clear.

#### Expected
All pending anomaly actions are eventually applied or explicitly discarded.

#### Fix
Drain pending actions by value/index rather than clearing by table-reference identity, or snapshot before draining.

#### Verification
`npm test` passes; `argon build default.project.json -x -o "Astral Forge v2.rbxlx"` succeeds.---

### R-17: SettingsView crashes on stale activeSection id
- **System:** Client / settings UI
- **Severity:** Low
- **File:line:** `src/Client/AstralForge/pages/PagesSystem.luau:343`
- **Status:** Fixed, verified

#### Repro steps
1. Navigate to a settings section that is later removed from `SECTION_BY_ID`.
2. Render `SettingsView`.

#### Expected
Settings falls back to a valid section or shows empty state.

#### Actual
`SECTION_BY_ID[activeSection].touchOnly` indexes nil and throws.

#### Fix
Nil-check the section lookup before accessing fields.

#### Verification
`npm test` passes; `argon build default.project.json -x -o "Astral Forge v2.rbxlx"` succeeds.---

### R-18: Setting isChanged treats non-numeric defaults as 0
- **System:** Client / settings UI
- **Severity:** Low
- **File:line:** `src/Client/AstralForge/pages/PagesSystem.luau:371`
- **Status:** Fixed, verified

#### Repro steps
1. Define a setting with a non-empty string default.
2. Change the value to another non-zero string.

#### Expected
`isChanged` correctly reflects that the value differs from default.

#### Actual
`tonumber(entry.default) or 0` compares the new string against 0, so the change is hidden.

#### Fix
Compare the raw saved value against the raw default for non-numeric types.

---



---

### R-19: Trade receiver UID collision can overwrite owned relics
- **System:** Inventory / trade
- **Severity:** High
- **File:line:** `src/Server/AstralForge/Modules/TradeSuite.luau:749`
- **Status:** Fixed, verified

#### Repro steps
1. Host owns relic with UID `IT0000001`.
2. Guest owns relic with UID `IT0000001` (different profile, same sequence value).
3. Guest trades that relic to Host.
4. Host receives it under `IT0000001`.

#### Expected
Host receives the traded relic under a fresh UID that does not collide with existing inventory.

#### Actual
Host's existing `IT0000001` is silently overwritten by the received relic (permanent loss).

#### Fix
`TradeExchange.ApplyExchange` now mints a new UID from the receiver's `profile.Items.NextId` and stores `payload.NewUid`; `RevertExchange` removes by `NewUid` when present. `verify_trade.luau` updated to assert re-keying.

#### Verification
`npm test` trade exchange + settle invariants pass.

---

### R-20: Free scratch card whale exploit
- **System:** Casino / economy
- **Severity:** Medium
- **File:line:** `src/Server/AstralForge/Services/CasinoService.luau:154`
- **Status:** Fixed, verified

#### Repro steps
1. Accumulate a very large `profile.Cash`.
2. Scratch the free daily card.
3. Observe payout ceiling uses `profile.Cash * 4`.

#### Expected
Free daily card has a modest, fixed maximum payout.

#### Actual
Whales can win up to 4x their whole balance with no stake.

#### Fix
Introduce `FREE_SCRATCH_BASE = 100` and use it as the cap base for free scratch payouts.

#### Verification
`npm test` casino math guards pass.

---

### R-21: Flip accepts arbitrary op strings on active rounds
- **System:** Casino / input
- **Severity:** Low
- **File:line:** `src/Server/AstralForge/Services/CasinoService.luau:187`
- **Status:** Fixed, verified

#### Repro steps
1. Start a Flip round.
2. Invoke `CasinoPlay` with `Op = "Flop"` (any non-Cashout string).
3. Observe the round flips as if `Op == "Flip"`.

#### Expected
Unknown op is rejected.

#### Actual
Any garbage string advances the round.

#### Fix
Reject `Op` unless it is `"Flip"` or `"Cashout"`.

#### Verification
`npm test` casino math guards pass.

---

### R-22: Guild name lacks TextService filtering
- **System:** Guild / safety
- **Severity:** Medium
- **File:line:** `src/Server/AstralForge/Services/CoreServices.luau:1243`
- **Status:** Fixed, verified

#### Repro steps
1. Call `CreateGuild` with a filtered name.
2. Observe name stored and broadcast raw.

#### Expected
Name is run through `TextService:FilterStringAsync` before persistence/display.

#### Fix
`ServerServices:_guildAction` filters `payload.Name` via `self._security.Filter:Apply` before calling `GuildService:Create`.

#### Verification
`npm test` guild service fixtures pass.

---

### R-23: Guild leaderboard page parameter ignored
- **System:** Guild / UX
- **Severity:** Low
- **File:line:** `src/Server/AstralForge/Services/CoreServices.luau:1577`
- **Status:** Fixed, verified

#### Repro steps
1. Call `GetLeaderboard(1)`.
2. Observe result is always the top 20 guilds.

#### Expected
Page 1 returns guilds ranked 21–40.

#### Fix
Fetch up to 100 entries, slice by `page * 20 + 1 .. page * 20 + 20`, cache only page 0.

#### Verification
`npm test` guild service fixtures pass.




---

### R-24: Bazaar lottery tickets lost on server shutdown
- **System:** Bazaar / lottery
- **Severity:** Medium
- **File:line:** `src/Server/AstralForge/Services/BazaarService.luau:19`
- **Status:** Fixed, verified

#### Repro steps
1. Buy lottery tickets.
2. Shut down the server before the next draw.
3. Restart and inspect `lottery.Tickets`.

#### Expected
Paid tickets survive into the next server instance within the rollover window.

#### Actual
Only `Pot`, `Pending`, and `Bucket` were saved/restored; `Tickets` reset to empty.

#### Fix
Include `lottery.Tickets` in the `saveLotteryRollover` / `loadLotteryRollover` snapshot.

#### Verification
`npm test` bazaar math guards pass.

---

### R-25: Disbanded guild leaves orphan leaderboard row
- **System:** Guild / cleanup
- **Severity:** Low
- **File:line:** `src/Server/AstralForge/Services/CoreServices.luau:1386`
- **Status:** Fixed, verified

#### Repro steps
1. Disband a guild that has leaderboard activity.
2. Fetch `GetLeaderboard(0)`.
3. Observe an "Uncharted Guild" placeholder for the deleted guild.

#### Expected
Disband removes the guild's OrderedDataStore entry.

#### Fix
`Disband` now calls `self._leaderboard:RemoveAsync(guildId)` after releasing the tag.

#### Verification
`npm test` guild service fixtures pass.

---

### R-26: Kicked guild member keeps bonuses until rejoin
- **System:** Guild / membership
- **Severity:** Medium
- **File:line:** `src/Server/AstralForge/Services/CoreServices.luau:1412` / `ServerServices.luau`
- **Status:** Fixed, verified

#### Repro steps
1. Have a guild member receive guild bonuses.
2. Kick them while they are still in the server.
3. Observe their `profile.Guild` and `GuildBonuses`.

#### Expected
Kicked player's profile is cleared and state is pushed so the client stops receiving bonuses.

#### Actual
`profile.Guild` remains populated until the next login.

#### Fix
`GameService:_guildAction` clears the victim's `profile.Guild`/`GuildBonuses` via `AtomicUpdate` and pushes state when the target is in-server.

#### Verification
`npm test` guild service fixtures pass.


## Pending reproductions

The following areas still need explicit repro entries:

- Guild announcement persistence / rate limits
- Guild members-only chat filtering
- Guild logo upload/moderation path
- Ranks retroactive reward edge cases
- Casino provably-fair seed verification
- Bazaar anti-scam / price validation
- Astral Forge state-machine transitions under lag

#### Verification
`npm test` passes; `argon build default.project.json -x -o "Astral Forge v2.rbxlx"` succeeds.