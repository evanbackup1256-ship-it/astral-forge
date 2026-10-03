--!strict

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

__defs["ProfileClampMath"] = function()

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

local function isNegativePersist(persisted: any): boolean
	if type(persisted) == "number" then
		return persisted < 0
	end
	if type(persisted) == "string" then
		return string.sub(persisted, 1, 1) == "-"
	end
	return false
end

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

__defs["SettingsSeal"] = function()

local SettingsSeal = {}

function SettingsSeal.Apply(profile)
	profile.Settings.SoundEffects = (tonumber(profile.Settings.SoundVolume) or 0) > 0.001
	profile.Settings.UIEffects = (tonumber(profile.Settings.EffectsIntensity) or 0) > 0.001
	profile.Settings.ReducedMotion = (tonumber(profile.Settings.MotionIntensity) or 1) <= 0.03
end

return SettingsSeal
end

__defs["UnlimitedMoneySeal"] = function()

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

__defs["PublicPlayerRecord"] = function()

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
		AccountAge = player.AccountAge,
		Premium = Enum ~= nil and player.MembershipType == Enum.MembershipType.Premium,
	}
end

return PublicPlayerRecord
end

__defs["ReportLedger"] = function()

local ReportLedger = {}
ReportLedger.__index = ReportLedger

ReportLedger.REASONS = table.freeze({ "Exploiting", "Scamming", "Harassment", "Trolling", "Spam", "Inappropriate", "Other" })
local REASON_SET = {}
for _, reason in ReportLedger.REASONS do
	REASON_SET[reason] = true
end

ReportLedger.REPEAT_SECONDS = 600
ReportLedger.WINDOW_SECONDS = 3600
ReportLedger.MAX_PER_WINDOW = 6

function ReportLedger.isReason(reason: any): boolean
	return type(reason) == "string" and REASON_SET[reason] == true
end

function ReportLedger.new()
	return setmetatable({
		_sent = {},
		_against = {},
	}, ReportLedger)
end

local function prune(list, now: number, window: number)
	local write = 0
	for _, entry in list do
		if now - entry.at < window then
			write += 1
			list[write] = entry
		end
	end
	for index = #list, write + 1, -1 do
		list[index] = nil
	end
end

function ReportLedger:canReport(reporter: number, target: number, now: number): (boolean, string?)
	local sent = self._sent[reporter]
	if sent == nil then
		return true, nil
	end
	prune(sent, now, ReportLedger.WINDOW_SECONDS)
	for _, entry in sent do
		if entry.target == target and now - entry.at < ReportLedger.REPEAT_SECONDS then
			local minutes = math.max(1, math.ceil((ReportLedger.REPEAT_SECONDS - (now - entry.at)) / 60))
			return false, string.format("You already reported this player. You can report them again in %d min.", minutes)
		end
	end
	if #sent >= ReportLedger.MAX_PER_WINDOW then
		return false, "You've sent a lot of reports this hour. Try again later."
	end
	return true, nil
end

function ReportLedger:record(reporter: number, target: number, reason: string, now: number): (number, number)
	local sent = self._sent[reporter]
	if sent == nil then
		sent = {}
		self._sent[reporter] = sent
	end
	table.insert(sent, { target = target, at = now })
	local against = self._against[target]
	if against == nil then
		against = {}
		self._against[target] = against
	end
	table.insert(against, { reporter = reporter, reason = reason, at = now })
	return self:tally(target, now)
end

function ReportLedger:tally(target: number, now: number): (number, number)
	local against = self._against[target]
	if against == nil then
		return 0, 0
	end
	prune(against, now, ReportLedger.WINDOW_SECONDS)
	local reporters = {}
	local distinct = 0
	for _, entry in against do
		if not reporters[entry.reporter] then
			reporters[entry.reporter] = true
			distinct += 1
		end
	end
	return #against, distinct
end

function ReportLedger:forgetReporter(reporter: number)
	self._sent[reporter] = nil
end

return ReportLedger
end

__defs["AutoSalvageSnapshot"] = function()

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

__defs["ItemLoadoutMath"] = function()

local ItemLoadoutMath = {}

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

function ItemLoadoutMath.CandidatePower(definition: any, level: any): number
	if type(definition) ~= "table" then
		return 0
	end
	local base = tonumber(definition.BaseEffect) or 0
	local growth = tonumber(definition.LevelGrowth) or 0
	local safeLevel = math.max(1, math.floor(tonumber(level) or 1))
	return base * (1 + growth * math.max(0, safeLevel - 1))
end

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

__defs["ItemSalvage"] = function()

local ItemSalvage = {}

function ItemSalvage.Value(level: any, rarityRank: any): number
	local rank = if type(rarityRank) == "number" then rarityRank else 1
	local safeLevel = if type(level) == "number" then level else 1
	return rank * rank * 8 + math.max(0, safeLevel - 1) * rank * 3
end

return table.freeze(ItemSalvage)
end

__defs["GeneralBoardValue"] = function()

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

__defs["UtcClockMath"] = function()

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

function UtcClockMath.Remaining(deadline: any, now: any): number
	return math.max(0, (tonumber(deadline) or 0) - (tonumber(now) or 0))
end

function UtcClockMath.IsLive(deadline: any, now: any): boolean
	return UtcClockMath.Remaining(deadline, now) <= 0
end

return table.freeze(UtcClockMath)
end

__defs["StoryMailSnapshot"] = function()

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

function StoryMailSnapshot.MailboxPublic(messages, unread: number)
	return {
		Messages = messages,
		Unread = unread,
	}
end

return StoryMailSnapshot
end

__defs["VisitSnapshot"] = function()

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

__defs["VisitorList"] = function()

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

__defs["RankBracket"] = function()

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

__defs["ActionFeatureMaps"] = function()

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
	BuyDailyOffer = "Shop",
	BuyCrateSkin = "Shop",
	EquipCrateSkin = "Shop",
	FuseRelics = "Inventory",
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
	CasinoPlay = "Casino",
	BazaarPlay = "Bazaar",
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

__defs["ActionResponse"] = function()

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

__defs["CommandActionValidators"] = function()

local CommandActionValidators = {}

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
	SetTutorialStep = true,
	ReplayTutorial = true,
}

CommandActionValidators.HIGH_VALUE_GRANT = {
	SpinWheel = true,
	CasinoPlay = true,
	BazaarPlay = true,
	OpenItemCrate = true,
	CollectVault = true,
	Rebirth = true,
	DomainExpansion = true,
	RedeemCode = true,
	AdminExecute = true,
}

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

__defs["ShopGrantEligibility"] = function()

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

function ShopGrantEligibility.StudioGrantAllowed(isStudio: boolean): boolean
	return isStudio == true
end

function ShopGrantEligibility.ClampWheelGrant(amount: any): number
	return math.clamp(math.floor(tonumber(amount) or 100), 1, 500)
end

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

function ShopGrantEligibility.CatalogPublic(ownedPasses: any, copyDictionary)
	return {
		OwnedPasses = copyDictionary(type(ownedPasses) == "table" and ownedPasses or {}),
		CatalogVersion = 1,
	}
end

return table.freeze(ShopGrantEligibility)
end

__defs["SocialBoost"] = function()

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

function SocialBoost.CreatorRewardsPublic(raw: any, creatorName: string): any
	return {
		CreatorFollowClaimed = type(raw) == "table" and raw.CreatorFollowClaimed == true,
		CreatorName = creatorName,
	}
end

return table.freeze(SocialBoost)
end

__defs["TelemetryMath"] = function()

local TelemetryMath = {}

TelemetryMath.VERSION = 1
TelemetryMath.BYTES = 30
TelemetryMath.FLOAT_MIN = -3.4e38
TelemetryMath.FLOAT_MAX = 3.4e38

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

local __members = {}
for name in __defs do
	table.insert(__members, name)
end
table.sort(__members)
table.freeze(__members)
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		if name == "__members" then
			return __members
		end
		return __load(name)
	end,
})
