# Astral Forge — Client & UI rewrite (Forge2) plan

Base: user master `0615eaba` (pc/master). Branch `client-rewrite`, worktree `/workspace/af-client2`.
New client root: `src/Client/AstralForge/Forge2/`. The old client stays the default; Forge2 mounts only when
`ReplicatedStorage:GetAttribute("AstralForgeClient2") == true` or the LocalPlayer has that attribute set to true
(set it in Studio / via admin; no save or schema change). Server, remotes, payloads and save shape are untouched.

Rules carried by every port: TS only (no new .luau, no shims); same `request(action, payload)` names/payloads
(typed by `Shared/Data/RemoteRegistry`); every animation/effect kept at full intensity (restyle only);
FancyText titles, MotionFX (ScreenFx) tracks, rainbow UIGradients on the shared `Rainbow` clock, Night Iron /
cast-iron look; few labels, roomy layout; 11-size phone matrix + gamepad + B back layer; never `$className`+`$path`
on one project node; build with `flock /workspace/rbxtsc.lock /workspace/uirev/node_modules/.bin/rbxtsc`,
tests with `flock /workspace/rbxtsc.lock /usr/local/bin/lune run scripts/verify_project.luau`.

---------------------------------------------------------------------------------------------------
## 1. Parity checklist (inventory of src/Client, 233 files / ~106k lines)

### 1a. Boot / runtime (index.client.tsx, ClientRuntime/, Controllers/, BootKit, ReactHosts)
- [ ] ClientRuntime: ScreenGui `AstralForgeStudioUI` (DisplayOrder 80, CoreUISafeInsets), FX ScreenGui
      `AstralForgeFx` (JuiceFx host, 200), shutdown layer (260), VR host portal — **reused as-is by Forge2**
- [ ] Core GUI hiding (Backpack/Health/PlayerList/Emotes/Chat, TopbarEnabled false, orientation Sensor on touch) — reused
- [ ] UI-only workspace/camera setup (configureUiOnlyWorkspace) — reused
- [ ] BootScreen with BOOT_MOTION, StartupFailure, BootFailure bridge attribute, SoftShutdownScreen + Shutdown event/attrs
- [ ] Flamework controllers: UiShell, UiRootRegistry, LayoutGuard (attr-gated), Network, RequestQueue, EffectFeed,
      Presence/Telemetry/Ping — Forge2 keeps NetworkController; RequestQueue semantics re-implemented in Forge2 store
- [ ] ClientRuntime: assetPreloader (deferred config art / far worlds), chat bridge, clientIntegrity probe
- [ ] Audio: Mixer scenes (boot/main), hookGuiClicks, MusicDirector shuffle, volume buses from Settings — reused
- [ ] ButtonMotion.attach, ArtifactPresence, CrewPresence, VRInterface — reused by runtime
- [ ] Locale translator warmup, ReportPerformance, ReportPresence, ReportClientIntegrity, MeasureLatency (antilag)

### 1b. Store / network (CoreKit/clientStore, store/*, MainGame request path)
- [ ] State push: `Reused` section cache, envelope validation (snapshotEnvelopeMath), Revision/SnapshotId ordering
- [ ] Initial `GetState` retry loop, "still connecting" notice after 20 tries, Bridge `Ready` attribute
- [ ] Request path: per-action cooldowns (networkPolicy), optimistic actions + rollback to last accepted snapshot,
      timeout/no-answer notices, late state, friendly failure copy (actionCopy), passive requests silent,
      Guild/LeaveGuild session patches, GRANT_ACTIONS adopt
- [ ] Toast push → notice stack (Tone Info/Success/Warning/Special), Effect push (Collect, Overcharge crit/combo, level
      moments, crate reveals, rebirth ceremony, server events)
- [ ] Session derived notices: daily streak ready, free spin ready, combo readout
- [ ] Settings service: readSetting/isOn/setSettings/resetSection (SetSetting {Values, Label}), optimistic
- [ ] Motion settings context (EffectsIntensity, MotionIntensity, …), accessibility palette (HighContrast, Colorblind),
      text scale (DesktopTextScale/MobileTextScale/FollowRobloxTextSize)

### 1c. Shell / HUD (UiCore/AppShellChrome, TopBarChrome, NavChrome, MobileShell, WorkspaceChrome, ShellFx)
- [ ] Top bar: currencies (Flux/Cash, Vault, Cores, Stardust) with NumberSpinner counts, level badge + roadmap,
      rebirth quick button, compact mode, FPS/ping readouts (ShowFps/ShowPing)
- [ ] Desktop nav rail with 5 groups (Home, Daily, Progress, Social, System), ready badges, nav popover, MoreDock
- [ ] Phone: MobileHeader, MobileTabBar (pins from SetMobileLayout, MOBILE_TAB_PRIORITY), menu sheet, MobileQuickActions
      (collect/overcharge), DesktopLayoutEditor + MobileControls layout editing
- [ ] BuffStrip / buff island, ComboBadge, GainPop, TradeReturnPill, ReadyBoard pills, QuickFind (search)
- [ ] AmbientLayer / StarField, EffectLayer, ShellFx confetti, screen MotionFX tracks, rainbow shared clock
- [ ] Gamepad: selection regions (nav, page, top, tabs, header), GamepadNavigationService, padSink, B back layer
- [ ] Touch: TouchGestureService, tap-target padding (44px), LargeTouchTargets
- [ ] LayoutGuard diagnostics (attribute-gated)

### 1d. Overlays / popups (UiCore, UiOverlays)
- [ ] ConfirmDialog / ConfirmHost        - [ ] CrateRevealOverlay (B advances)  - [ ] RebirthCeremony (B skips)
- [ ] DomainChamber (tree/confirm/lattice) - [ ] OfflineRewardsOverlay          - [ ] FeedbackOverlay (SubmitFeedback)
- [ ] CreditsOverlay                      - [ ] PlayerlistOverlay (visit/trade/crew/report) - [ ] LevelRoadmapHost
- [ ] LevelMomentHost                     - [ ] ReleaseNotesModal (Open/DismissRelease)     - [ ] TutorialOverlay / onboarding
- [ ] ServerEventHost (EventAct)          - [ ] AdminPrankOverlay / HudPrankStage            - [ ] Tooltip provider
- [ ] notifications (NOTICE_LIFETIME / exit), PurchaseQueue (MarketplaceService prompts), PrizeWheel

### 1e. Pages (31 routes + Credits) — see §3 for the porting order

### 1f. Remote calls by owner (all through `request(action, payload)`; names from Protocol.Actions)
- Shell/HUD: CollectVault, Overcharge, Rebirth, ClaimDaily, ClaimQuest, ClaimExpedition, CompleteTutorial,
  SetTutorialStep, DismissRelease, OpenRelease, TradeViewAway, SetMobileLayout, SetSetting, MarkHintSeen
- Overlays: SubmitFeedback, ReportPlayer, GetPlayers, VisitPlot, LeavePlot, NudgeCrew, CrewInvite, InviteTrade,
  DomainExpansion, DomainLattice, EventAct
- Overview: CollectVault, Overcharge, Rebirth, RebirthAct, ClaimFirstGoal, CompanionAct, ClaimCommunityReward
- Workshop: BuyMachine, SetAutoForge · Research: BuyResearch · StarGrid: SelectSpecialization, BuyGridUpgrade
- Ascension: Ascend, UpgradeSigil · Echoes: EchoAct · Continuum/Foundry/Anomaly: FoundryAct, UpgradeContinuum,
  PulseAnomaly, StabilizeAnomaly, BuyAnomalyProtocol, ActivateAnomalySurge, SetAnomalyChannel, SetAnomalyLoadout,
  ClaimAnomalyMilestone, ClaimAnomalyDirective · Lab: ClaimLabOrder, RouteLabPower, ProgramAct
- Convergence: ClaimConvergenceReward · Worlds: SelectZone, UnlockZone, ConstellationAct
- Missions: ClaimQuest · Milestones: ClaimAchievement · Wheel: SpinWheel · Rewards: ClaimDaily, ClaimTimedReward
- Boosts: ActivateBoost · Bazaar: BazaarPlay, SetMarketFavorite, RequestProcurement, GetState
- Command: BuySignalOffer, ClaimCommanderReward, ClaimWeeklyDirective, ClaimSeasonTier, ClaimSeasonPremium,
  EquipArtifact, UpgradeArtifact, BuyArtifact, EquipTitle, UpgradeCrew, LaunchExpedition, ClaimExpedition
- Expeditions: ExpeditionAct · ForgePath: ClaimForgePathStep · Story: ReadStoryChapter, ClaimStoryChapter
- Mail: ReadMail, ClaimMail, ClaimAllMail, DeleteMail · Chat: ChatGlobal, ChatOpenWhisper
- Crew: GetCrew, CrewInvite, CrewRespond, CrewLeave, CrewKick, CrewRename, CrewClaim, NudgeCrew, VisitPlot, LeavePlot
- Guild (27): GetGuild … UploadGuildLogo, ModerateGuildLogo, GetGuildLogoReview, SendGuildChat, ClaimGuildGoal
- Trade: GetTrade, InviteTrade, RespondTrade, UpdateTradeOffer, SetTradeReady, ConfirmTrade, CancelTrade,
  TradeViewAway, TradeChat, TradeRequest · Leaderboards: GetLeaderboard, GetGuildLeaderboard
- Shop: SyncShop, BuyItemOffer, OpenItemCrate, BuyDailyOffer, BuyCrateSkin, EquipCrateSkin, FuseRelics, RedeemCode,
  VerifyCreatorFollow, StudioGrantProduct, BuySignalOffer
- Inventory: EquipItem {Uid,Target}, UnequipItem {Target}, UpgradeItem {Uid}, SalvageItem {Uid},
  ToggleItemLock {Uid}, BulkSalvageItems, EquipBestItems, SetItemAutoSalvage, EngraveRelic, CraftRelic, FuseRelics
- Settings: SetSetting, ReplayTutorial, OpenRelease, SetProfileStyle, EquipCrateSkin · Admin: GetAdminState, AdminExecute
- Background: GetState, MeasureLatency, ReportPresence, ReportPerformance, ReportClientIntegrity

### 1g. Settings (Shared/SharedData/SettingsSchema, 6 sections, all must keep working)
- Sound: SoundVolume MusicVolume SfxVolume PageMusic NotificationSounds HoverSounds UiVolume(0.9) GameplayVolume
  RewardVolume AmbientVolume SoundVariation
- Graphics: EffectsIntensity MotionIntensity ConfettiEnabled ScreenFlashes BackgroundStars ButtonShimmers RainbowIntensity
  ScreenEffects GlowIntensity ParticleDensity ShimmerIntensity BackgroundDetail AmbientGlow PanelHover PanelEntrances
  AnimatedTitles IconAnimations NumberAnimations OfflineRewardEffects ViewportSpeed ReactorMotion
- Interface: ShowFps ShowPing ShowResourceLabels ShowNextGoal Tooltips CompactTopBar UiDensity ScrollMomentum
- Accessibility: DesktopTextScale FollowRobloxTextSize HighContrast ColorblindMode BoldText ReducedTransparency
  LargeTouchTargets HapticIntensity
- Social: ChatShowGlobal ChatSounds ChatUseProfileAccent WhispersFriendsOnly CrewInvitePolicy
- Phone: MobileTextScale MobileQuick*/MobileDock*/MobileToast* (Visible/Scale/Opacity) MobileQuickReverse
  MobileCompactHeaders MobileAutoHideDock MobileLandscapeCompact MobileKeyboardCompact MobileButtonSpacing

---------------------------------------------------------------------------------------------------
## 2. New architecture (Forge2)

```
src/Client/AstralForge/Forge2/
  index.tsx            mountable root: Forge2App (providers + shell); forge2Enabled() flag
  store/
    store.ts           ONE store: tiny signal store (getState/subscribe/update) + useForge selector hook
    net.ts             bindings to the existing remotes: state/toast/effect/shutdown pushes, GetState boot loop,
                       request(action, payload, onReply) with cooldowns, optimistic rollback, friendly copy
  router/
    routes.ts          route table: id → page component + nav group/label/icon (from NavRoutes / navRouteTable)
    Router.tsx         PageHost: one mounted page, keyed transition (enter rise/fade), error boundary, legacy note
  design/
    tokens.ts          Night Iron tokens: iron/steel/brass/ember surfaces, space/radius/type scales, phone sizing
    Text.tsx           Text (fit + min size) and Title (FancyText) primitives
    Panel.tsx Card.tsx cast-iron surfaces (IronShade child plate + brass lip; rainbow accent on the shared clock)
    Button.tsx Tab.tsx Chip.tsx   pressables: ≥44px hit on touch, hover lift/press dip, gamepad selectable
    Modal.tsx Toast.tsx Tooltip.tsx EmptyState.tsx
  motion/
    motion.ts          one motion API over MotionKit (springs, stagger, change pop, flash, glint) + MotionFX
                       screen tracks + Juice bursts, scaled by EffectsIntensity/MotionIntensity (never reduced
                       below the old defaults)
  input/
    input.ts           input kind hook, gamepad selection regions, useBack (B back layer, shared with old overlays)
  shell/
    Shell.tsx          HUD shell: top bar (currencies), desktop rail / phone tab bar, page host, toast stack
  pages/
    OverviewPage.tsx InventoryPage.tsx   (proof ports; the rest follow §3)
```

- **One store.** All UI reads `useForge(selector)`; there is no second Rodux store. Session snapshot, page,
  toasts, busy actions and shutdown live in one immutable state object. Updates are `store.update(fn)`.
- **Remotes.** `net.ts` is the only file touching `ClientNetwork`; payloads stay exactly as the old client sends
  them, so the current server runs unchanged against Forge2.
- **Router.** `routes.ts` is a plain table; pages are components `(props: PageProps) => Element` with
  `PageProps = { session, config, request, navigate, phone }`. Unported routes show a quiet EmptyState until their
  port lands, so nav/rail parity is visible from day one.
- **Design system.** Every page builds from the primitives only; no page draws raw buttons. Primitives own touch
  padding, gamepad selection, hover/press motion, cast-iron faces and copy fit.
- **Motion system.** Entrances (stagger), hover/press, change pops, flashes, glints, rainbow and MotionFX are
  called through `motion.ts` so intensity is centrally honoured.
- **Input.** `useBack(open, close)` wraps the shared CoreKit back layer (same B stack as legacy overlays reused
  by Forge2). Regions `top`, `nav`, `tabs`, `page` register via selectionRegions.
- **How pages mount.** Shell → Router → `routes[page].component` inside a keyed transition frame; pages fetch
  nothing themselves except through `request`.

---------------------------------------------------------------------------------------------------
## 3. Page list for parallel porting

Wave 0 (done in phase 1): **Overview**, **Inventory**.

Wave 1 — Home/Daily, mostly independent, assign one helper each:
 1. Workshop (BuyMachine, SetAutoForge)            2. Research (BuyResearch)
 3. Missions (ClaimQuest)                            4. Rewards + Daily (ClaimDaily, ClaimTimedReward)
 5. Boosts (ActivateBoost)                          6. Milestones (ClaimAchievement)
 7. Wheel (SpinWheel, PrizeWheel)                   8. Settings (SettingsSchema-driven; + MobileTabPinsEditor, ProfileStylePanel)

Wave 2 — Progress:
 9. Worlds + Constellations (SelectZone, UnlockZone, ConstellationAct)
10. Rebirth panel/chamber + Ascension (Rebirth, RebirthAct, Ascend, UpgradeSigil; keep ceremony + reset warning)
11. StarGrid / Specializations          12. Echoes (EchoAct)
13. Continuum / Foundry / Anomaly (FoundryAct + anomaly actions)       14. Lab + Programs
15. Expeditions (ExpeditionAct)          16. ForgePath (ClaimForgePathStep)
17. Story (Read/ClaimStoryChapter)       18. Convergence

Wave 3 — Social/Commerce (bigger, one helper each):
19. Shop + crates + StoreFront (crate reel/reveal overlay; cast-iron tiles)
20. Bazaar     21. Trade (two-party flow, TradeReturnPill)     22. Command (season, titles, artifacts, crew upgrades)
23. Guild (27 actions)  24. Crew  25. Chat  26. Mail  27. Leaderboards

Wave 4 — System & overlays:
28. Admin   29. Credits   30. Overlays: Confirm, CrateReveal, RebirthCeremony, DomainChamber, OfflineRewards,
    Feedback, Playerlist, LevelRoadmap/LevelMoments, ReleaseNotes, Tutorial, ServerEvents, AdminPrank
31. HUD extras: BuffStrip, ComboBadge, GainPop, ReadyBoard, QuickFind, mobile quick actions + layout editor

Switch-over (after all waves pass): flip the default, keep the attribute as an escape hatch for one release,
then delete the legacy client tree.
