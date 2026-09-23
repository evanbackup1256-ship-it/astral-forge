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
		if type(persisted) == "number" and persisted < 0 then
			persisted = 0
		end
		profile[key] = persisted
	end
	for _, key in { "Cores", "Stardust", "Rebirths" } do
		profile[key] = clampScalar(profile[key], ceiling)
	end
	if type(profile.Stats) == "table" then
		if profile.Stats.Collected ~= nil then
			profile.Stats.Collected = persistFn(profile.Stats.Collected)
		end
		for key, raw in profile.Stats do
			if key ~= "Collected" and type(raw) == "number" then
				profile.Stats[key] = if finite(raw) then math.clamp(raw, 0, ceiling) else 0
			end
		end
	end
	if type(profile.Continuum) == "table" then
		profile.Continuum.TotalFluxSpent = persistFn(profile.Continuum.TotalFluxSpent)
		for _, key in { "TotalStardustSpent" } do
			profile.Continuum[key] = clampScalar(profile.Continuum[key], ceiling)
		end
	end
	return true
end

return table.freeze(ProfileClampMath)
