--!strict
export type State = { Focus: string, ChangedAt: number, Gain: number, Cost: number }
export type BuildPreview = {
	Id: string, Name: string, Description: string, Gain: string, Cost: string,
	GainMultiplier: number, CostMultiplier: number,
	Production: number | string, Capacity: number | string, Tap: number | string, Offline: number,
}
export type Snapshot = {
	Focus: string, Name: string, Builds: { BuildPreview }, Foundation: { { Name: string, Value: number } },
	Gain: number, Cost: number, Cooldown: number, ReadyAt: number,
	Production: number | string, Capacity: number | string, Tap: number | string, Offline: number,
}
local Specializations = {}
Specializations.Builds = {
	{ Id = "Balanced", Name = "Balanced forge", Description = "Keep your current forge rates. No trade-offs.", Gain = "", Cost = "" },
	{ Id = "Handcraft", Name = "Handcraft", Description = "Work the forge actively. Stronger overcharge, less unattended production.", Gain = "Tap", Cost = "Production" },
	{ Id = "Reserve", Name = "Deep reserves", Description = "Bank larger batches between collections. Sacrifice some tap strength.", Gain = "Capacity", Cost = "Tap" },
	{ Id = "NightShift", Name = "Night shift", Description = "Recover more while away. Trade some tap strength for offline efficiency.", Gain = "Offline", Cost = "Tap" },
}
local gain, cost, cooldown = 1.3, 0.85, 600
function Specializations.Find(id: string)
	for _, build in Specializations.Builds do if build.Id == id then return build end end
	return nil
end
function Specializations.Sanitize(raw: any): State
	local source = if type(raw) == "table" then raw else {}
	local focus = if type(source.Focus) == "string" and Specializations.Find(source.Focus) then source.Focus else "Balanced"
	local at = source.ChangedAt
	local savedGain = if type(source.Gain) == "number" and source.Gain == source.Gain then math.clamp(source.Gain, 1.05, 1.5) else gain
	local savedCost = if type(source.Cost) == "number" and source.Cost == source.Cost then math.clamp(source.Cost, 0.5, 0.95) else cost
	return { Focus = focus, Gain = savedGain, Cost = savedCost, ChangedAt = if type(at) == "number" and at == at and at >= 0 and at < math.huge then math.floor(at) else 0 }
end
function Specializations.Configure(nextGain: any, nextCost: any, nextCooldown: any)
	gain = if type(nextGain) == "number" and nextGain == nextGain then math.clamp(nextGain, 1.05, 1.5) else 1.3
	cost = if type(nextCost) == "number" and nextCost == nextCost then math.clamp(nextCost, 0.5, 0.95) else 0.85
	cooldown = if type(nextCooldown) == "number" and nextCooldown == nextCooldown then math.clamp(math.floor(nextCooldown), 60, 3600) else 600
end
function Specializations.Factor(raw: any, kind: string): number
	local state = Specializations.Sanitize(raw)
	local build = Specializations.Find(state.Focus)
	if build and build.Gain == kind then return state.Gain end
	if build and build.Cost == kind then return state.Cost end
	return 1
end
function Specializations.Policy()
	return { Gain = gain, Cost = cost, Cooldown = cooldown }
end
function Specializations.Select(raw: any, id: any, now: number): (State?, string)
	if type(id) ~= "string" or not Specializations.Find(id) then return nil, "Choose an available forge specialization." end
	local state = Specializations.Sanitize(raw)
	if state.Focus == id then return state, "That build is already equipped." end
	if state.ChangedAt > 0 and now < state.ChangedAt + cooldown then
		return nil, "Your forge can be reconfigured in " .. math.ceil(state.ChangedAt + cooldown - now) .. " seconds."
	end
	return { Focus = id, ChangedAt = now, Gain = gain, Cost = cost }, "Forge specialization equipped. All purchased bonuses are preserved."
end
function Specializations.Snapshot(profile: any, economy: any, now: number, cache: any?, current: any?): Snapshot
	local selected = Specializations.Sanitize(profile.Specialization)
	local policy = Specializations.Policy()
	local production = if current then current.Production else economy.Production(profile, now)
	local capacity = if current then current.Capacity else economy.Capacity(profile, now)
	local tap = economy.TapPower(profile, now)
	local offline = economy.OfflineEfficiency(profile, now)
	local levels = {}
	for id, level in profile.GridUpgrades or {} do table.insert(levels, id .. "=" .. tostring(level)) end
	table.sort(levels)
	local key = table.concat({
		tostring(now), tostring(production), tostring(capacity), tostring(tap), tostring(offline),
		selected.Focus, tostring(selected.ChangedAt), tostring(selected.Gain), tostring(selected.Cost),
		tostring(policy.Gain), tostring(policy.Cost), tostring(policy.Cooldown), table.concat(levels, ","),
	}, ":")
	if cache and cache.SpecializationPreviewKey == key and cache.SpecializationPreview then return cache.SpecializationPreview end
	local builds: { BuildPreview } = {}
	for _, build in Specializations.Builds do
		local preview = table.clone(profile)
		preview.Specialization = if build.Id == selected.Focus then selected else {
			Focus = build.Id, ChangedAt = selected.ChangedAt, Gain = policy.Gain, Cost = policy.Cost,
		}
		local card: BuildPreview = {
			Id = build.Id, Name = build.Name, Description = build.Description, Gain = build.Gain, Cost = build.Cost,
			GainMultiplier = Specializations.Factor(preview.Specialization, build.Gain),
			CostMultiplier = Specializations.Factor(preview.Specialization, build.Cost),
			Production = economy.Production(preview, now), Capacity = economy.Capacity(preview, now),
			Tap = economy.TapPower(preview, now), Offline = economy.OfflineEfficiency(preview, now),
		}
		table.insert(builds, card)
	end
	local foundation: { { Name: string, Value: number } } = {}
	for _, item in {
		{ "GridProduction", "Production" }, { "GridCapacity", "Vault capacity" },
		{ "GridTap", "Overcharge" }, { "GridCritical", "Critical chance" },
		{ "GridAutomation", "Auto-collect" }, { "GridOffline", "Offline efficiency" },
	} do
		local value = economy.GridEffect(profile, item[1])
		if value > 0 then table.insert(foundation, { Name = item[2], Value = value }) end
	end
	local build = Specializations.Find(selected.Focus)
	assert(build, "sanitized specialization must exist")
	local snapshot: Snapshot = {
		Focus = selected.Focus, Name = build.Name, Builds = builds, Foundation = foundation,
		Gain = policy.Gain, Cost = policy.Cost, Cooldown = policy.Cooldown,
		ReadyAt = if selected.ChangedAt > 0 then selected.ChangedAt + policy.Cooldown else 0,
		Production = production, Capacity = capacity, Tap = tap, Offline = offline,
	}
	if cache then cache.SpecializationPreviewKey = key; cache.SpecializationPreview = snapshot end
	return snapshot
end
return table.freeze(Specializations)
