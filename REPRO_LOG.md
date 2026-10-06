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

## Pending reproductions

The following areas still need explicit repro entries:

- Guild announcement persistence / rate limits
- Guild members-only chat filtering
- Guild logo upload/moderation path
- Ranks retroactive reward edge cases
- Casino provably-fair seed verification
- Bazaar anti-scam / price validation
- Astral Forge state-machine transitions under lag
