--!strict
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
