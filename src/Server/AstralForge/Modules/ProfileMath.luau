--!strict
--[=[
	ProfileMath: merged module suite.
	Members (20): ProfileClampMath, SettingsSeal, UnlimitedMoneySeal, PublicPlayerRecord, AutoSalvageSnapshot, ItemLoadoutMath, ItemSalvage, GeneralBoardValue, UtcClockMath, StoryMailSnapshot, VisitSnapshot, VisitorList, RankBracket, Format, ActionFeatureMaps, ActionResponse, CommandActionValidators, ShopGrantEligibility, SocialBoost, TelemetryMath.

	Each member keeps its original source inside its own closure (so every member
	still has its own local-register budget) and is evaluated lazily, exactly once,
	on first access.  Use `require(<this module>)("<Member>")` (or index the returned
	table with the member name) to get a member's exports.
]=]

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("ProfileMath: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("ProfileMath: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

-- ======================================================================
-- Module: ProfileClampMath   (merged from ProfileClampMath.luau, 93 lines)
-- ======================================================================
__defs["ProfileClampMath"] = function()
-- Pure progression-currency clamp helpers. No Roblox services — ServerServices
-- and Lune verify scripts share ClampProgressionNumbers so post-mutate currency
-- / Stats / Continuum sanitizers stay testable without Studio. Economy.Persist
-- is injected so Omega Persist stays with the caller.

local ProfileClampMath = {}

local DEFAULT_MAX = 1e308

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function clampScalar(raw: any, ceiling: number): number
	local value = tonumber(raw)
	if value and finite(value) then
		return math.clamp(value, 0, ceiling)
	end
	return 0
end

-- A persisted currency value is a plain number below ~1e15 and a sign-prefixed
-- scientific-notation string ("-5.000000000000e50") above it. The old guard only
-- tested `type == "number" and < 0`, so a negative Omega-scale balance slipped
-- through the clamp unchanged. Detect negativity in both domains.
local function isNegativePersist(persisted: any): boolean
	if type(persisted) == "number" then
		return persisted < 0
	end
	if type(persisted) == "string" then
		return string.sub(persisted, 1, 1) == "-"
	end
	return false
end

-- Clamp Cash/Vault/RunCash/LifetimeCash via Persist, Cores/Stardust/Rebirths via
-- tonumber, and Stats / Continuum spend bags. Partial profiles (Studio fixtures)
-- must not throw when Stats or Continuum are missing.
function ProfileClampMath.ClampProgressionNumbers(
	profile: any,
	persist: ((any) -> any)?,
	maxSafe: number?
): boolean
	if type(profile) ~= "table" then
		return false
	end
	local ceiling = tonumber(maxSafe) or DEFAULT_MAX
	local persistFn = persist
	if type(persistFn) ~= "function" then
		persistFn = function(value: any): any
			return clampScalar(value, ceiling)
		end
	end

	for _, key in { "Cash", "Vault", "RunCash", "LifetimeCash" } do
		local persisted = persistFn(profile[key])
		if isNegativePersist(persisted) then
			persisted = 0
		end
		profile[key] = persisted
	end
	for _, key in { "Cores", "Stardust", "Rebirths" } do
		profile[key] = clampScalar(profile[key], ceiling)
	end
	if type(profile.Stats) == "table" then
		if profile.Stats.Collected ~= nil then
			local persisted = persistFn(profile.Stats.Collected)
			if isNegativePersist(persisted) then
				persisted = 0
			end
			profile.Stats.Collected = persisted
		end
		for key, raw in profile.Stats do
			if key ~= "Collected" and type(raw) == "number" then
				profile.Stats[key] = if finite(raw) then math.clamp(raw, 0, ceiling) else 0
			end
		end
	end
	if type(profile.Continuum) == "table" then
		local persisted = persistFn(profile.Continuum.TotalFluxSpent)
		if isNegativePersist(persisted) then
			persisted = 0
		end
		profile.Continuum.TotalFluxSpent = persisted
		for _, key in { "TotalStardustSpent" } do
			profile.Continuum[key] = clampScalar(profile.Continuum[key], ceiling)
		end
	end
	return true
end

return table.freeze(ProfileClampMath)
end

-- ======================================================================
-- Module: SettingsSeal   (merged from SettingsSeal.luau, 12 lines)
-- ======================================================================
__defs["SettingsSeal"] = function()
-- Pure settings seal helpers split out of ServerServices.

local SettingsSeal = {}

function SettingsSeal.Apply(profile)
	profile.Settings.SoundEffects = (tonumber(profile.Settings.SoundVolume) or 0) > 0.001
	profile.Settings.UIEffects = (tonumber(profile.Settings.EffectsIntensity) or 0) > 0.001
	profile.Settings.ReducedMotion = (tonumber(profile.Settings.MotionIntensity) or 1) <= 0.03
end

return SettingsSeal
end

-- ======================================================================
-- Module: UnlimitedMoneySeal   (merged from UnlimitedMoneySeal.luau, 14 lines)
-- ======================================================================
__defs["UnlimitedMoneySeal"] = function()
-- Pure unlimited-money seal split out of ServerServices.

local UnlimitedMoneySeal = {}

function UnlimitedMoneySeal.Apply(profile, maxSafeCurrency, Economy)
	if profile.Flags.UnlimitedMoney then
		profile.Cash = maxSafeCurrency
		profile.RunCash = maxSafeCurrency
		profile.LifetimeCash = Economy.Max(profile.LifetimeCash, maxSafeCurrency)
	end
end

return UnlimitedMoneySeal
end

-- ======================================================================
-- Module: PublicPlayerRecord   (merged from PublicPlayerRecord.luau, 46 lines)
-- ======================================================================
__defs["PublicPlayerRecord"] = function()
-- Pure public player mirror record split out of ServerServices.

local PublicPlayerRecord = {}

function PublicPlayerRecord.Build(player: Player, profile, viewer: Player, presence, deps)
	local EnsureItems = deps.EnsureItems
	local itemById = deps.itemById
	local Economy = deps.Economy
	local items = EnsureItems(profile)
	local itemCount = 0
	for _ in items.Inventory do
		itemCount += 1
	end
	local equippedItems = {}
	for _, uid in items.Equipped do
		local instance = items.Inventory[uid]
		local definition = instance and itemById[instance.DefinitionId]
		if definition then
			table.insert(equippedItems, definition.Name)
		end
	end
	local liveEntry = presence and presence[player.UserId]
	return {
		UserId = math.floor(player.UserId),
		Name = player.Name,
		DisplayName = player.DisplayName,
		Zone = profile.Zone,
		CurrentZone = profile.CurrentZone,
		Rebirths = profile.Rebirths,
		Production = Economy.Production(profile),
		LifetimeCash = profile.LifetimeCash,
		Stardust = profile.Stardust,
		Cores = profile.Cores,
		DomainRank = profile.Domain and profile.Domain.Rank or 0,
		PlayTime = profile.Stats and profile.Stats.PlayTime or 0,
		ItemCount = itemCount,
		EquippedItems = equippedItems,
		IsLocal = player == viewer,
		SocialFlags = 0,
		CurrentPage = liveEntry and liveEntry.Page or "Overview",
		PresenceAge = liveEntry and math.max(0, os.time() - liveEntry.UpdatedAt) or -1,
	}
end

return PublicPlayerRecord
end

-- ======================================================================
-- Module: AutoSalvageSnapshot   (merged from AutoSalvageSnapshot.luau, 30 lines)
-- ======================================================================
__defs["AutoSalvageSnapshot"] = function()
-- Pure AutoSalvage / AutoForge snapshot bags split out of ServerServices.

local AutoSalvageSnapshot = {}

function AutoSalvageSnapshot.Normalize(raw)
	if type(raw) == "table" then
		return raw
	end
	return { Enabled = false, KeepNew = true, Rarities = {} }
end

function AutoSalvageSnapshot.Public(raw, copyDictionary)
	local autoSalvage = AutoSalvageSnapshot.Normalize(raw)
	return {
		Enabled = autoSalvage.Enabled == true,
		KeepNew = autoSalvage.KeepNew ~= false,
		Rarities = copyDictionary(type(autoSalvage.Rarities) == "table" and autoSalvage.Rarities or {}),
	}
end

function AutoSalvageSnapshot.DefaultAutoForge()
	return { Enabled = false, MachineId = "StellarCore", Reserve = 0.25, Bought = 0 }
end

function AutoSalvageSnapshot.PublicAutoForge(raw, copyDictionary)
	return copyDictionary(type(raw) == "table" and raw or AutoSalvageSnapshot.DefaultAutoForge())
end

return AutoSalvageSnapshot
end

-- ======================================================================
-- Module: ItemLoadoutMath   (merged from ItemLoadoutMath.luau, 172 lines)
-- ======================================================================
__defs["ItemLoadoutMath"] = function()
-- Pure EquipBest loadout planner. No Roblox services — ServerServices and Lune
-- verify scripts share BuildTargets / PlanEquipBest so socket greedy assignment
-- stays testable without Studio. Catalog ownership gates stay with the caller.

local ItemLoadoutMath = {}

-- True when a relic definition can occupy `target` (Slot + optional Targets list).
function ItemLoadoutMath.IsCompatible(definition: any, target: any): boolean
	if type(definition) ~= "table" or type(target) ~= "table" then
		return false
	end
	if definition.Slot ~= target.Slot then
		return false
	end
	local targets = definition.Targets
	if type(targets) ~= "table" then
		return true
	end
	for _, allowed in targets do
		if allowed == target.TargetId then
			return true
		end
	end
	return false
end

-- Effect power used to rank EquipBest candidates (matches EffectAtLevel formula).
function ItemLoadoutMath.CandidatePower(definition: any, level: any): number
	if type(definition) ~= "table" then
		return 0
	end
	local base = tonumber(definition.BaseEffect) or 0
	local growth = tonumber(definition.LevelGrowth) or 0
	local safeLevel = math.max(1, math.floor(tonumber(level) or 1))
	return base * (1 + growth * math.max(0, safeLevel - 1))
end

-- Open sockets from owned Machines/Research (≥1). Catalog lists are id→def or arrays.
function ItemLoadoutMath.BuildTargets(machinesCatalog: any, researchCatalog: any, machineLevels: any, researchLevels: any): { any }
	local targets = {}
	local machines = if type(machineLevels) == "table" then machineLevels else {}
	local research = if type(researchLevels) == "table" then researchLevels else {}
	if type(machinesCatalog) == "table" then
		for _, machine in machinesCatalog do
			if type(machine) == "table" and type(machine.Id) == "string" then
				if (tonumber(machines[machine.Id]) or 0) >= 1 then
					table.insert(targets, {
						Id = "Machine:" .. machine.Id,
						Slot = "Machine",
						TargetId = machine.Id,
					})
				end
			end
		end
	end
	if type(researchCatalog) == "table" then
		for _, entry in researchCatalog do
			if type(entry) == "table" and type(entry.Id) == "string" then
				if (tonumber(research[entry.Id]) or 0) >= 1 then
					table.insert(targets, {
						Id = "Research:" .. entry.Id,
						Slot = "Research",
						TargetId = entry.Id,
					})
				end
			end
		end
	end
	return targets
end

local function rarityRank(rarities: any, rarity: any): number
	if type(rarities) ~= "table" then
		return 0
	end
	local entry = rarities[rarity]
	if type(entry) == "table" then
		return tonumber(entry.Rank) or 0
	end
	return tonumber(entry) or 0
end

-- Greedy best-fit: scarcest sockets first, strongest compatible relic wins.
-- Returns nextEquipped map, equippedCount, changed vs currentEquipped.
function ItemLoadoutMath.PlanEquipBest(
	targets: any,
	candidates: any,
	rarities: any,
	currentEquipped: any
): ({ [string]: string }, number, number)
	local socketList = if type(targets) == "table" then table.clone(targets) else {}
	local relicList = if type(candidates) == "table" then table.clone(candidates) else {}
	table.sort(relicList, function(a, b)
		local aPower = tonumber(a and a.Power) or 0
		local bPower = tonumber(b and b.Power) or 0
		if aPower ~= bPower then
			return aPower > bPower
		end
		local aRank = rarityRank(rarities, a and a.Definition and a.Definition.Rarity)
		local bRank = rarityRank(rarities, b and b.Definition and b.Definition.Rarity)
		if aRank ~= bRank then
			return aRank > bRank
		end
		local aLevel = tonumber(a and a.Instance and a.Instance.Level) or 0
		local bLevel = tonumber(b and b.Instance and b.Instance.Level) or 0
		if aLevel ~= bLevel then
			return aLevel > bLevel
		end
		return tostring(a and a.Uid) < tostring(b and b.Uid)
	end)

	local function compatibleCount(target): number
		local count = 0
		for _, candidate in relicList do
			if ItemLoadoutMath.IsCompatible(candidate.Definition, target) then
				count += 1
			end
		end
		return count
	end
	table.sort(socketList, function(a, b)
		local aCount = compatibleCount(a)
		local bCount = compatibleCount(b)
		if aCount ~= bCount then
			return aCount < bCount
		end
		return tostring(a.Id) < tostring(b.Id)
	end)

	local nextEquipped: { [string]: string } = {}
	local used = {}
	local equippedCount = 0
	for _, target in socketList do
		for _, candidate in relicList do
			if not used[candidate.Uid] and ItemLoadoutMath.IsCompatible(candidate.Definition, target) then
				nextEquipped[target.Id] = candidate.Uid
				used[candidate.Uid] = true
				equippedCount += 1
				break
			end
		end
	end

	local current = if type(currentEquipped) == "table" then currentEquipped else {}
	local changed = 0
	for target, uid in nextEquipped do
		if current[target] ~= uid then
			changed += 1
		end
	end
	for target in current do
		if not nextEquipped[target] then
			changed += 1
		end
	end
	return nextEquipped, equippedCount, changed
end

-- Aggregated item effect multipliers for client rails.
function ItemLoadoutMath.EffectsPublic(profile, Economy)
	return {
		Production = Economy.ItemEffect(profile, "Production"),
		Capacity = Economy.ItemEffect(profile, "Capacity"),
		Tap = Economy.ItemEffect(profile, "Tap"),
		Critical = Economy.ItemEffect(profile, "Critical"),
		Automation = Economy.ItemEffect(profile, "Automation"),
		Offline = Economy.ItemEffect(profile, "Offline"),
	}
end

return table.freeze(ItemLoadoutMath)
end

-- ======================================================================
-- Module: ItemSalvage   (merged from ItemSalvage.luau, 15 lines)
-- ======================================================================
__defs["ItemSalvage"] = function()
-- Pure item-salvage essence formula. No Roblox services — ServerServices and
-- Lune verify scripts share this so salvage payouts stay testable without
-- Studio. Rarity lookup stays with the caller; pass Rank.

local ItemSalvage = {}

-- Matches prior inline: rank^2 * 8 + max(0, level-1) * rank * 3
function ItemSalvage.Value(level: any, rarityRank: any): number
	local rank = if type(rarityRank) == "number" then rarityRank else 1
	local safeLevel = if type(level) == "number" then level else 1
	return rank * rank * 8 + math.max(0, safeLevel - 1) * rank * 3
end

return table.freeze(ItemSalvage)
end

-- ======================================================================
-- Module: GeneralBoardValue   (merged from GeneralBoardValue.luau, 34 lines)
-- ======================================================================
__defs["GeneralBoardValue"] = function()
-- Pure general leaderboard board-value projection. No Roblox services —
-- ServerServices and Lune verify scripts share this so Flux/Rebirths/PlayTime/
-- Dust/Cores/Domain/Worlds scoring stays testable without Studio. Persist for
-- LifetimeCash is injected (Economy.Persist under Studio).

local GeneralBoardValue = {}

function GeneralBoardValue.Of(profile: any, id: string, persist: (any) -> any): number
	if id == "Flux" then
		return persist(profile.LifetimeCash)
	end
	if id == "Rebirths" then
		return math.max(0, math.floor(tonumber(profile.Rebirths) or 0))
	end
	if id == "PlayTime" then
		return math.max(0, math.floor(tonumber(profile.Stats and profile.Stats.PlayTime) or 0))
	end
	if id == "Dust" then
		return math.max(0, math.floor(tonumber(profile.Stardust) or 0))
	end
	if id == "Cores" then
		return math.max(0, math.floor(tonumber(profile.Cores) or 0))
	end
	if id == "Domain" then
		return math.max(0, math.floor(tonumber(profile.Domain and profile.Domain.Rank) or 0))
	end
	if id == "Worlds" then
		return math.max(1, math.floor(tonumber(profile.Zone) or 1))
	end
	return 0
end

return table.freeze(GeneralBoardValue)
end

-- ======================================================================
-- Module: UtcClockMath   (merged from UtcClockMath.luau, 36 lines)
-- ======================================================================
__defs["UtcClockMath"] = function()
-- Pure UTC day / week / midnight helpers for shop restock clocks and
-- Progression daily/weekly rolls. No Roblox services — ServerServices /
-- ProgressionService and Lune verify scripts share this so day boundaries stay
-- testable without Studio. Pass `now` (unix seconds) for deterministic checks.

local UtcClockMath = {}

UtcClockMath.DAY_SECONDS = 86_400
UtcClockMath.WEEK_SECONDS = UtcClockMath.DAY_SECONDS * 7

function UtcClockMath.Day(now: any): number
	local seconds = tonumber(now) or 0
	return math.floor(seconds / UtcClockMath.DAY_SECONDS)
end

function UtcClockMath.Week(now: any): number
	local seconds = tonumber(now) or 0
	return math.floor(seconds / UtcClockMath.WEEK_SECONDS)
end

function UtcClockMath.NextMidnight(now: any): number
	return (UtcClockMath.Day(now) + 1) * UtcClockMath.DAY_SECONDS
end

-- Seconds remaining until `deadline` (unix). Never negative.
function UtcClockMath.Remaining(deadline: any, now: any): number
	return math.max(0, (tonumber(deadline) or 0) - (tonumber(now) or 0))
end

-- True when the deadline has elapsed (remaining == 0).
function UtcClockMath.IsLive(deadline: any, now: any): boolean
	return UtcClockMath.Remaining(deadline, now) <= 0
end

return table.freeze(UtcClockMath)
end

-- ======================================================================
-- Module: StoryMailSnapshot   (merged from StoryMailSnapshot.luau, 48 lines)
-- ======================================================================
__defs["StoryMailSnapshot"] = function()
-- Pure Story/Mail snapshot builders split out of ServerServices.

local StoryMailSnapshot = {}

function StoryMailSnapshot.BuildStory(profile, storyChapters, ProgressionGate)
	local storyState = {}
	for index, chapter in storyChapters do
		storyState[index] = {
			Id = chapter.Id,
			Unlocked = ProgressionGate.Progress(profile, chapter.Kind) >= chapter.Target,
			Progress = ProgressionGate.Progress(profile, chapter.Kind),
			Target = chapter.Target,
			Read = profile.Story.Read[chapter.Id] == true,
			Claimed = profile.Story.Claimed[chapter.Id] == true,
		}
	end
	return storyState
end

function StoryMailSnapshot.BuildMailbox(profile, mailMessages, ProgressionGate)
	local mailState = {}
	local unreadMail = 0
	for _, message in mailMessages do
		if not profile.Mailbox.Deleted[message.Id] and ProgressionGate.Meets(profile, message.Requirement) then
			local read = profile.Mailbox.Read[message.Id] == true
			if not read then
				unreadMail += 1
			end
			table.insert(mailState, {
				Id = message.Id,
				Read = read,
				Claimed = profile.Mailbox.Claimed[message.Id] == true,
			})
		end
	end
	return mailState, unreadMail
end

-- Client Mailbox rail bag.
function StoryMailSnapshot.MailboxPublic(messages, unread: number)
	return {
		Messages = messages,
		Unread = unread,
	}
end

return StoryMailSnapshot
end

-- ======================================================================
-- Module: VisitSnapshot   (merged from VisitSnapshot.luau, 53 lines)
-- ======================================================================
__defs["VisitSnapshot"] = function()
-- Pure visit snapshot builder split out of ServerServices.

local VisitSnapshot = {}

function VisitSnapshot.Build(player: Player, profile, Economy)
	local production = Economy.Production(profile)
	local machines = {}
	local machineCount = 0
	for id, level in profile.Machines do
		local amount = math.floor(tonumber(level) or 0)
		if amount > 0 then
			machines[id] = amount
			machineCount += 1
		end
	end
	return {
		UserId = player.UserId,
		Name = player.Name,
		DisplayName = player.DisplayName,
		Zone = profile.Zone,
		CurrentZone = profile.CurrentZone,
		Rebirths = profile.Rebirths,
		Production = production,
		Cash = profile.Cash,
		Vault = profile.Vault,
		Capacity = Economy.Capacity(profile, os.time()),
		Cores = profile.Cores,
		Stardust = profile.Stardust,
		LifetimeCash = profile.LifetimeCash,
		Machines = machines,
		MachineKinds = machineCount,
		ServerTime = os.time(),
	}
end

-- Resolve visiting host into a Visit bag. `players` + `getProfile` injected.
function VisitSnapshot.Resolve(hostUserId: number?, players: { Player }, getProfile: (Player) -> any, Economy): any
	if hostUserId == nil then
		return nil
	end
	for _, host in players do
		if host.UserId == hostUserId then
			local hostProfile = getProfile(host)
			if hostProfile then
				return VisitSnapshot.Build(host, hostProfile, Economy)
			end
		end
	end
	return nil
end

return VisitSnapshot
end

-- ======================================================================
-- Module: VisitorList   (merged from VisitorList.luau, 26 lines)
-- ======================================================================
__defs["VisitorList"] = function()
-- Pure visitor roster builder split out of ServerServices.

local VisitorList = {}

function VisitorList.Build(bucket, isPresent)
	local list = {}
	if not bucket then
		return list
	end
	for visitor in bucket do
		if isPresent(visitor) then
			table.insert(list, {
				UserId = visitor.UserId,
				Name = visitor.Name,
				DisplayName = visitor.DisplayName,
			})
		end
	end
	table.sort(list, function(left, right)
		return left.DisplayName < right.DisplayName
	end)
	return list
end

return VisitorList
end

-- ======================================================================
-- Module: RankBracket   (merged from RankBracket.luau, 34 lines)
-- ======================================================================
__defs["RankBracket"] = function()
-- Pure leaderboard climb brackets for rank-ping toasts. No Roblox services —
-- ServerServices and Lune verify scripts share this so bracket crossings stay
-- testable without Studio. Bracket list / unranked sentinel are injected.

local RankBracket = {}

RankBracket.DEFAULT_BRACKETS = { 1, 3, 10, 25 }
RankBracket.UNRANKED = math.huge

function RankBracket.Of(rank: number, brackets: { number }?, unranked: number?): number
	local list = brackets or RankBracket.DEFAULT_BRACKETS
	local fallback = if unranked ~= nil then unranked else RankBracket.UNRANKED
	for _, bracket in list do
		if rank <= bracket then
			return bracket
		end
	end
	return fallback
end

-- Climb toast fires when seeded, rank improved, and bracket tightened.
function RankBracket.ShouldAnnounce(previousRank: number, nextRank: number, brackets: { number }?, unranked: number?): boolean
	local fallback = if unranked ~= nil then unranked else RankBracket.UNRANKED
	local seeded = previousRank > 0
	if not seeded or nextRank >= previousRank then
		return false
	end
	local bracket = RankBracket.Of(nextRank, brackets, fallback)
	local previousBracket = RankBracket.Of(previousRank, brackets, fallback)
	return bracket ~= fallback and bracket < previousBracket
end

return table.freeze(RankBracket)
end

-- ======================================================================
-- Module: Format   (merged from Format.luau, 141 lines)
-- ======================================================================
__defs["Format"] = function()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OmegaMath = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("OmegaMath"))

local Format = {}

local SUFFIXES = {
	"K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No",
	"Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod",
	"Vg", "UVg", "DVg", "TVg", "QaVg", "QiVg", "SxVg", "SpVg", "OcVg", "NoVg",
	"Tg", "UTg", "DTg", "TTg", "QaTg", "QiTg", "SxTg", "SpTg", "OcTg", "Millinillion",
	"Googol", "Googolchime", "DuoGoogol", "Googolthrong", "Googolchoir", "Googolwell", "Googolcascade", "Googolspire", "Googolmarch", "Googolreign",
	"Googolcourt", "Googolhost", "Googolvast", "Googoldeep", "Googolpeak", "Googolcrown", "Googolheart", "Googolwake", "Googolzenith", "Googolapex",
	"Megaminx", "Gigaminx", "Teraminx", "Petaminx", "Examinx", "Zettaminx", "Yottaminx", "Ronnaminx", "Quettaminx", "Ultraminx",
	"Hyperminx", "Omniminx", "Alphaminx", "Omegaminx", "Prismaminx", "Stellaminx", "Voidminx", "Astraminx", "Infiminx", "Transminx",
	"Skewes", "Moser", "Graham", "TREE", "SSCG", "Loader", "Rayo", "BusyBeaver", "Xi", "Omega",
	"Inaccessible", "Mahlo", "Supercompact", "Huge", "RankIntoRank", "Berkeley", "Reinhardt", "Absolute", "Finality", "Boundless",
	"Apex", "Horizon",
}

local LAST_NAMED_LOG10 = #SUFFIXES * 3

local function formatFromLog10(log10: number): string
	if log10 ~= log10 or log10 <= 0 then
		return "0"
	end
	if log10 < 3 and 10 ^ log10 < 999.5 then
		return string.format("%.0f", 10 ^ log10)
	end
	if log10 >= LAST_NAMED_LOG10 then
		local exponent = math.floor(log10)
		local mantissa = 10 ^ (log10 - exponent)
		return string.format("%.2fe%d", mantissa, exponent)
	end
	local group = math.clamp(math.floor(log10 / 3), 1, #SUFFIXES)
	local scaled = 10 ^ (log10 - group * 3)
	-- Three significant figures are shown, so a value that rounds up to a full thousand has to
	-- move to the next suffix ("1M", never "1000K").
	local shownPrecision = if scaled < 10 then 2 elseif scaled < 100 then 1 else 0
	local rollsOver = (tonumber(string.format("%." .. tostring(shownPrecision) .. "f", scaled)) or 0) >= 1000
	if (scaled >= 1000 or rollsOver) and group < #SUFFIXES then
		group += 1
		scaled /= 1000
	end
	local suffix = SUFFIXES[group]
	local precision = if scaled < 10 then 2 elseif scaled < 100 then 1 else 0
	local formatted = string.format("%." .. tostring(precision) .. "f", scaled)
	formatted = formatted:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
	return formatted .. suffix
end

local function scaleForDisplay(value: number): (number, string)
	local absolute = math.abs(value)
	if absolute ~= absolute or absolute == 0 then
		return 0, ""
	end
	if absolute == math.huge or math.log(absolute) / math.log(10) >= LAST_NAMED_LOG10 then
		return 1, "e308+"
	end
	if absolute < 1000 then
		return value, ""
	end
	local group = math.clamp(math.floor(math.log(absolute) / math.log(1000)), 1, #SUFFIXES)
	local scaled = value / (1000 ^ group)
	if math.abs(scaled) >= 1000 and group < #SUFFIXES then
		group += 1
		scaled /= 1000
	end
	return scaled, SUFFIXES[group]
end

function Format.Number(value: any, decimals: number?): string
	if type(value) == "string" or type(value) == "table" then
		return formatFromLog10(OmegaMath.Log10(value))
	end
	if type(value) ~= "number" or value ~= value then
		return "0"
	end
	if value == math.huge or value == -math.huge then
		return formatFromLog10(OmegaMath.Log10(value))
	end
	if math.abs(value) >= 999.5 then
		local text = formatFromLog10(math.log10(math.abs(value)))
		return if value < 0 then "-" .. text else text
	end
	local scaled, suffix = scaleForDisplay(value)
	if suffix == "" then
		local absolute = math.abs(value)
		local precision = decimals
		if precision == nil then
			precision = absolute < 10 and absolute % 1 ~= 0 and 1 or 0
		end
		local formatted = string.format("%." .. tostring(precision) .. "f", value)
		formatted = formatted:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
		return formatted
	end
	local absolute = math.abs(scaled)
	local precision = decimals
	if precision == nil then
		if absolute < 10 then
			precision = 2
		elseif absolute < 100 then
			precision = 1
		else
			precision = 0
		end
	end
	local formatted = string.format("%." .. tostring(precision) .. "f", scaled)
	formatted = formatted:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
	return formatted .. suffix
end

function Format.Integer(value: number): string
	local rounded = math.floor(value + 0.5)
	local text = tostring(rounded)
	local sign, digits = text:match("^([%-]?)(%d+)$")
	if not digits then
		return text
	end
	local reversed = digits:reverse():gsub("(%d%d%d)", "%1,")
	local result = reversed:reverse():gsub("^,", "")
	return (sign or "") .. result
end

function Format.Duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local remaining = seconds % 60
	if days > 0 then
		return string.format("%dd %02dh", days, hours)
	elseif hours > 0 then
		return string.format("%dh %02dm", hours, minutes)
	elseif minutes > 0 then
		return string.format("%dm %02ds", minutes, remaining)
	end
	return string.format("%ds", remaining)
end

function Format.Percent(value: number, decimals: number?): string
	return string.format("%." .. tostring(decimals or 0) .. "f%%", value * 100)
end

return table.freeze(Format)
end

-- ======================================================================
-- Module: ActionFeatureMaps   (merged from ActionFeatureMaps.luau, 133 lines)
-- ======================================================================
__defs["ActionFeatureMaps"] = function()
-- Pure action → feature / anomaly charge / signal maps for GameService.
-- No Roblox services — ServerServices and Lune verify scripts share this so
-- routing tables stay testable without Studio. Keys match Protocol.Actions.

local ActionFeatureMaps = {}

ActionFeatureMaps.ANOMALY_CHARGE = {
	CollectVault = 8,
	Overcharge = 3,
	BuyMachine = 5,
	BuyResearch = 5,
	BuyGridUpgrade = 6,
	UpgradeContinuum = 18,
	UpgradeArtifact = 6,
	UpgradeCrew = 5,
	UnlockZone = 16,
	Rebirth = 24,
	ClaimQuest = 7,
	ClaimAchievement = 12,
	ClaimDaily = 14,
	ClaimTimedReward = 9,
	SpinWheel = 12,
	ClaimExpedition = 20,
	ClaimCommanderReward = 8,
	ClaimWeeklyDirective = 16,
	ClaimSeasonTier = 12,
	OpenItemCrate = 14,
	UpgradeItem = 7,
	EquipBestItems = 10,
	BulkSalvageItems = 10,
}

ActionFeatureMaps.ANOMALY_SIGNAL = {
	CollectVault = "Collect",
	BuyMachine = "Upgrade",
	BuyResearch = "Upgrade",
	BuyGridUpgrade = "Upgrade",
	UpgradeContinuum = "Upgrade",
	UpgradeItem = "Upgrade",
	EquipBestItems = "Upgrade",
	UpgradeArtifact = "Upgrade",
	UpgradeCrew = "Upgrade",
	ClaimQuest = "Reward",
	ClaimAchievement = "Reward",
	ClaimDaily = "Reward",
	ClaimTimedReward = "Reward",
	ClaimExpedition = "Reward",
	ClaimCommanderReward = "Reward",
	ClaimWeeklyDirective = "Reward",
	ClaimSeasonTier = "Reward",
	ClaimForgePathStep = "Reward",
}

ActionFeatureMaps.FEATURE = {
	VisitPlot = "Crew",
	LeavePlot = "Crew",
	NudgeCrew = "Crew",
	BuyResearch = "Research",
	BuyGridUpgrade = "StarGrid",
	UnlockZone = "Worlds",
	SelectZone = "Worlds",
	Rebirth = "Rebirth",
	DomainExpansion = "Domain",
	UnlockDomainNode = "Domain",
	UpgradeContinuum = "Continuum",
	CaptureEcho = "Echoes",
	ClaimEcho = "Echoes",
	EquipEcho = "Echoes",
	UpgradeEcho = "Echoes",
	DismantleEcho = "Echoes",
	ClaimQuest = "Missions",
	ClaimAchievement = "Milestones",
	SpinWheel = "Wheel",
	ClaimDaily = "Rewards",
	ClaimTimedReward = "Rewards",
	ActivateBoost = "Rewards",
	LaunchExpedition = "Command",
	ClaimExpedition = "Command",
	EquipArtifact = "Command",
	UpgradeArtifact = "Command",
	UpgradeCrew = "Command",
	ClaimCommanderReward = "Command",
	ClaimWeeklyDirective = "Command",
	ClaimSeasonTier = "Command",
	BuySignalOffer = "Command",
	EquipTitle = "Command",
	RedeemCode = "Shop",
	VerifyCreatorFollow = "Shop",
	BuyItemOffer = "Inventory",
	OpenItemCrate = "Inventory",
	EquipItem = "Inventory",
	UnequipItem = "Inventory",
	UpgradeItem = "Inventory",
	SalvageItem = "Inventory",
	BulkSalvageItems = "Inventory",
	EquipBestItems = "Inventory",
	ToggleItemLock = "Inventory",
	SetItemAutoSalvage = "Inventory",
	PulseAnomaly = "Anomaly",
	StabilizeAnomaly = "Anomaly",
	BuyAnomalyProtocol = "Anomaly",
	ActivateAnomalySurge = "Anomaly",
	SetAnomalyChannel = "Anomaly",
	SetAnomalyLoadout = "Anomaly",
	ClaimAnomalyMilestone = "Anomaly",
	ClaimAnomalyDirective = "Anomaly",
	ClaimLabOrder = "Lab",
	RouteLabPower = "Lab",
	ReadStoryChapter = "Story",
	ClaimStoryChapter = "Story",
	ReadMail = "Mail",
	ClaimMail = "Mail",
	ClaimAllMail = "Mail",
	DeleteMail = "Mail",
	GetLeaderboard = "Leaderboards",
	ClaimConvergenceReward = "Convergence",
	BuyOreUpgrade = "Foundry",
	CasinoPlay = "Casino",
}

function ActionFeatureMaps.AnomalyCharge(action: string): number?
	return ActionFeatureMaps.ANOMALY_CHARGE[action]
end

function ActionFeatureMaps.AnomalySignal(action: string): string?
	return ActionFeatureMaps.ANOMALY_SIGNAL[action]
end

function ActionFeatureMaps.FeatureId(action: string): string?
	return ActionFeatureMaps.FEATURE[action]
end

return table.freeze(ActionFeatureMaps)
end

-- ======================================================================
-- Module: ActionResponse   (merged from ActionResponse.luau, 19 lines)
-- ======================================================================
__defs["ActionResponse"] = function()
-- Pure GameService action response builders. No Roblox services —
-- ServerServices and Lune verify scripts share this so ok/error envelopes
-- stay testable without Studio. Preserves prior mutation of `extra` tables.

local ActionResponse = {}

function ActionResponse.Error(message: string): { ok: boolean, error: string }
	return { ok = false, error = message }
end

function ActionResponse.Success(message: string?, extra: any): any
	local response = extra or {}
	response.ok = true
	response.message = message
	return response
end

return table.freeze(ActionResponse)
end

-- ======================================================================
-- Module: CommandActionValidators   (merged from CommandActionValidators.luau, 86 lines)
-- ======================================================================
__defs["CommandActionValidators"] = function()
-- Pure command-action classifiers for the GameService request gate. No Roblox
-- services — ServerServices and Lune verify scripts share this so read-only /
-- high-value-grant / deferred-snapshot sets stay testable without Studio.
-- Action names match Protocol.Actions string values.

local CommandActionValidators = {}

-- Read-only actions skip session CheckGrant (no gen/nonce burn).
CommandActionValidators.READ_ONLY = {
	GetState = true,
	MeasureLatency = true,
	SubmitFeedback = true,
	ReportPlayer = true,
	GetPlayers = true,
	GetPlayerMirror = true,
	VisitPlot = true,
	LeavePlot = true,
	NudgeCrew = true,
	ReportPresence = true,
	GetGuild = true,
	GetGuildLeaderboard = true,
	GetLeaderboard = true,
	GetAdminState = true,
	GetTrade = true,
	TradeViewAway = true,
	ReportClientIntegrity = true,
	ReportPerformance = true,
	EnterSanctuary = true,
	LeaveSanctuary = true,
	SetTutorialStep = true,
	ReplayTutorial = true,
}

-- Grants that also require the request to carry the session's live nonce, not
-- just a matching gen — highest-value actions get the extra check.
CommandActionValidators.HIGH_VALUE_GRANT = {
	SpinWheel = true,
	CasinoPlay = true,
	OpenItemCrate = true,
	CollectVault = true,
	Rebirth = true,
	DomainExpansion = true,
	RedeemCode = true,
	AdminExecute = true,
}

-- Successful mutations that defer the immediate state snapshot push.
CommandActionValidators.DEFERRED_SNAPSHOT = {
	Overcharge = true,
	PulseAnomaly = true,
	RouteLabPower = true,
	SetAutoForge = true,
	SetAnomalyChannel = true,
	SetAnomalyLoadout = true,
	SetSetting = true,
	SetMobileLayout = true,
	SetTutorialStep = true,
	ReplayTutorial = true,
	DismissRelease = true,
	OpenRelease = true,
	ReadStoryChapter = true,
	ReadMail = true,
	ReportPresence = true,
	SelectZone = true,
	-- A strike changes the Warden, not the striker's profile.
	StrikeRiftBoss = true,
	TravelWaystone = true,
}

function CommandActionValidators.IsValidAction(action: any): boolean
	return type(action) == "string" and #action > 0
end

function CommandActionValidators.IsReadOnly(action: string): boolean
	return CommandActionValidators.READ_ONLY[action] == true
end

function CommandActionValidators.RequiresHighValueNonce(action: string): boolean
	return CommandActionValidators.HIGH_VALUE_GRANT[action] == true
end

function CommandActionValidators.IsDeferredSnapshot(action: string): boolean
	return CommandActionValidators.DEFERRED_SNAPSHOT[action] == true
end

return table.freeze(CommandActionValidators)
end

-- ======================================================================
-- Module: ShopGrantEligibility   (merged from ShopGrantEligibility.luau, 160 lines)
-- ======================================================================
__defs["ShopGrantEligibility"] = function()
-- Pure item-shop stock / buy / studio-grant eligibility. No Roblox services —
-- ServerServices and Lune verify scripts share this so offer stock refresh and
-- purchase gates can be tested without Studio. Profile currency mutation and
-- Marketplace receipts stay with the caller; offer lists and clocks are injected.

local ShopGrantEligibility = {}

type OfferLike = {
	Id: string,
	Kind: string?,
	Name: string?,
	Currency: string?,
	Price: number?,
	StockMax: number?,
	DailyRefresh: boolean?,
	DailyRestock: number?,
}

type ShopState = {
	Day: number?,
	Stock: { [string]: number }?,
	Purchased: { [string]: boolean }?,
}

function ShopGrantEligibility.StockMax(offer: OfferLike): number
	local stockMax = offer.StockMax
	if type(stockMax) == "number" and stockMax > 0 then
		return math.floor(stockMax)
	end
	return 1
end

-- Keys-only / missing Inventory bags (Studio fixtures) must count as empty —
-- callers that pass profile.Items.Inventory without Ensure must not throw.
function ShopGrantEligibility.InventoryCount(inventory: any): number
	if type(inventory) ~= "table" then
		return 0
	end
	local count = 0
	for _ in inventory do
		count += 1
	end
	return count
end

function ShopGrantEligibility.RemainingStock(stockValue: any, stockMax: number): number
	local remaining = stockValue
	if type(remaining) ~= "number" then
		remaining = stockMax
	end
	return math.clamp(math.floor(remaining), 0, stockMax)
end

-- Studio-only grant surface (money / wheel / product keys). Callers keep error copy.
function ShopGrantEligibility.StudioGrantAllowed(isStudio: boolean): boolean
	return isStudio == true
end

-- Clamp free-wheel studio grant size (matches GrantStudioWheelSpins).
function ShopGrantEligibility.ClampWheelGrant(amount: any): number
	return math.clamp(math.floor(tonumber(amount) or 100), 1, 500)
end

-- Buy-offer gate without mutating profile. formatShortage builds the currency message.
function ShopGrantEligibility.EvaluateBuy(
	offer: OfferLike,
	remaining: number,
	inventoryCount: number,
	inventoryLimit: number,
	balance: any,
	formatShortage: (need: number, currency: string) -> string
): (boolean, string?)
	if remaining <= 0 then
		if offer.DailyRefresh == true then
			return false, "That daily offer is sold out. Come back after refresh."
		end
		return false, "That market offer is sold out."
	end
	if offer.Kind == "Item" and inventoryCount >= inventoryLimit then
		return false, "Your item inventory is full. Salvage something first."
	end
	local price = tonumber(offer.Price) or 0
	local have = if type(balance) == "number" then balance else nil
	if have == nil or have < price then
		local currency = offer.Currency or "Cash"
		return false, formatShortage(math.max(0, price - (have or 0)), currency)
	end
	if offer.Kind ~= "Key" and offer.Kind ~= "Essence" and offer.Kind ~= "Item" then
		return false, "That market offer is misconfigured."
	end
	return true, nil
end

-- Ensure Stock/Purchased tables exist, clamp values, and daily-refresh when day rolls.
-- Mutates `shop` in place. Returns whether anything changed.
-- Nil shop (Items without Shop nest) is a no-op — callers must ProfileBagMath.EnsureItems first.
function ShopGrantEligibility.EnsureShop(shop: any, offers: { OfferLike }, utcDay: number): boolean
	if type(shop) ~= "table" then
		return false
	end
	if type(shop.Stock) ~= "table" then
		shop.Stock = {}
	end
	if type(shop.Purchased) ~= "table" then
		shop.Purchased = {}
	end
	local stock = shop.Stock :: { [string]: number }
	local purchased = shop.Purchased :: { [string]: boolean }
	local day = math.floor(utcDay)
	local changed = false

	for _, offer in offers do
		local stockMax = ShopGrantEligibility.StockMax(offer)
		local current = stock[offer.Id]
		if type(current) ~= "number" then
			if purchased[offer.Id] == true then
				stock[offer.Id] = 0
			else
				stock[offer.Id] = stockMax
			end
			changed = true
		else
			local clamped = math.clamp(math.floor(current), 0, stockMax)
			if clamped ~= current then
				stock[offer.Id] = clamped
				changed = true
			end
		end
	end

	if shop.Day == day then
		return changed
	end

	shop.Day = day
	shop.Purchased = {}
	purchased = shop.Purchased
	for _, offer in offers do
		local stockMax = ShopGrantEligibility.StockMax(offer)
		if offer.DailyRefresh == true then
			stock[offer.Id] = stockMax
		else
			local restock = type(offer.DailyRestock) == "number" and math.max(0, math.floor(offer.DailyRestock)) or 0
			local current = stock[offer.Id] or 0
			stock[offer.Id] = math.min(stockMax, current + restock)
		end
	end
	return true
end

-- Monetization catalog rail bag.
function ShopGrantEligibility.CatalogPublic(ownedPasses: any, copyDictionary)
	return {
		OwnedPasses = copyDictionary(type(ownedPasses) == "table" and ownedPasses or {}),
		CatalogVersion = 1,
	}
end

return table.freeze(ShopGrantEligibility)
end

-- ======================================================================
-- Module: SocialBoost   (merged from SocialBoost.luau, 83 lines)
-- ======================================================================
__defs["SocialBoost"] = function()
-- Pure social production-boost math. No Roblox services — ServerServices and
-- Lune verify scripts share this so friend/premium multipliers stay testable
-- without Studio. Profile mutation stays with Apply; config knobs are injected.

local SocialBoost = {}

type SocialConfig = {
	MaxBoostedFriends: number,
	FriendProductionPerPlayer: number,
	PremiumProductionBonus: number,
}

type SocialBoostState = {
	FriendCount: number,
	FriendLimit: number,
	FriendBonus: number,
	Premium: boolean,
	PremiumBonus: number,
	Multiplier: number,
}

function SocialBoost.Compute(
	friendCount: number,
	premium: boolean,
	config: SocialConfig
): SocialBoostState
	local friendLimit = config.MaxBoostedFriends
	local count = math.clamp(math.floor(friendCount), 0, friendLimit)
	local friendBonus = count * config.FriendProductionPerPlayer
	local premiumBonus = premium and config.PremiumProductionBonus or 0
	return {
		FriendCount = count,
		FriendLimit = friendLimit,
		FriendBonus = friendBonus,
		Premium = premium,
		PremiumBonus = premiumBonus,
		Multiplier = 1 + friendBonus + premiumBonus,
	}
end

function SocialBoost.Changed(previous: any, nextState: SocialBoostState): boolean
	return type(previous) ~= "table"
		or previous.FriendCount ~= nextState.FriendCount
		or previous.FriendLimit ~= nextState.FriendLimit
		or previous.FriendBonus ~= nextState.FriendBonus
		or previous.Premium ~= nextState.Premium
		or previous.PremiumBonus ~= nextState.PremiumBonus
		or previous.Multiplier ~= nextState.Multiplier
end

-- Mutates profile.SocialBoost; returns whether the bag changed.
function SocialBoost.Apply(profile: any, friendCount: number, premium: boolean, config: SocialConfig): boolean
	local nextState = SocialBoost.Compute(friendCount, premium, config)
	local changed = SocialBoost.Changed(profile.SocialBoost, nextState)
	profile.SocialBoost = nextState
	return changed
end

function SocialBoost.DefaultSnapshot(maxBoostedFriends: number): SocialBoostState
	return {
		FriendCount = 0,
		FriendLimit = maxBoostedFriends,
		FriendBonus = 0,
		Premium = false,
		PremiumBonus = 0,
		Multiplier = 1,
	}
end

function SocialBoost.PublicSnapshot(raw: any, maxBoostedFriends: number, copyDictionary): SocialBoostState
	return copyDictionary(type(raw) == "table" and raw or SocialBoost.DefaultSnapshot(maxBoostedFriends))
end

-- Creator-follow reward rail bag.
function SocialBoost.CreatorRewardsPublic(raw: any, creatorName: string): any
	return {
		CreatorFollowClaimed = type(raw) == "table" and raw.CreatorFollowClaimed == true,
		CreatorName = creatorName,
	}
end

return table.freeze(SocialBoost)
end

-- ======================================================================
-- Module: TelemetryMath   (merged from TelemetryMath.luau, 67 lines)
-- ======================================================================
__defs["TelemetryMath"] = function()
-- Pure ServerServices telemetry pack helpers. No Roblox services — GameService
-- and Lune verify scripts share this so float32 clamp + packed snapshots stay
-- testable without Studio. Settings flags are caller-provided booleans.

local TelemetryMath = {}

TelemetryMath.VERSION = 1
TelemetryMath.BYTES = 30
TelemetryMath.FLOAT_MIN = -3.4e38
TelemetryMath.FLOAT_MAX = 3.4e38

-- Clamp any numeric-ish value into a finite float32 envelope. Non-finite → 0.
function TelemetryMath.Number(value: any, asNumber: ((any) -> number)?): number
	local numeric = if type(asNumber) == "function" then asNumber(value) else tonumber(value)
	if type(numeric) ~= "number" or numeric ~= numeric or numeric == math.huge or numeric == -math.huge then
		return 0
	end
	return math.clamp(numeric, TelemetryMath.FLOAT_MIN, TelemetryMath.FLOAT_MAX)
end

function TelemetryMath.SettingsFlags(settings: any): number
	local flags = 0
	if type(settings) ~= "table" then
		return flags
	end
	if settings.ReducedMotion then
		flags = bit32.bor(flags, 1)
	end
	if settings.UIEffects then
		flags = bit32.bor(flags, 2)
	end
	if settings.SoundEffects then
		flags = bit32.bor(flags, 4)
	end
	if settings.HideOtherPlots then
		flags = bit32.bor(flags, 8)
	end
	return flags
end

function TelemetryMath.Encode(
	revision: any,
	settings: any,
	cash: any,
	vault: any,
	production: any,
	capacity: any,
	cores: any,
	stardust: any,
	asNumber: ((any) -> number)?
): buffer
	local packed = buffer.create(TelemetryMath.BYTES)
	buffer.writeu8(packed, 0, TelemetryMath.VERSION)
	buffer.writeu8(packed, 1, TelemetryMath.SettingsFlags(settings))
	local rev = math.floor(math.max(0, tonumber(revision) or 0)) % 4_294_967_296
	buffer.writeu32(packed, 2, rev)
	buffer.writef32(packed, 6, TelemetryMath.Number(cash, asNumber))
	buffer.writef32(packed, 10, TelemetryMath.Number(vault, asNumber))
	buffer.writef32(packed, 14, TelemetryMath.Number(production, asNumber))
	buffer.writef32(packed, 18, TelemetryMath.Number(capacity, asNumber))
	buffer.writef32(packed, 22, TelemetryMath.Number(cores, asNumber))
	buffer.writef32(packed, 26, TelemetryMath.Number(stardust, asNumber))
	return packed
end

return table.freeze(TelemetryMath)
end

-- ======================================================================
-- Suite entry point
-- ======================================================================
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		return __load(name)
	end,
})
