--!strict
-- Pure admin policy: role permissions and dry-run diffs. No Roblox services so it runs under Lune tests.

local AdminPolicy = {}

export type Permission = {
	Categories: { [string]: boolean }?,
	Commands: { [string]: boolean }?,
	Deny: { [string]: boolean }?,
}

local ALL = "*"

AdminPolicy.ROLES = table.freeze({
	Owner = { All = true },
	["Studio Developer"] = { All = true },
	Developer = {
		Categories = { Economy = true, Progress = true, Items = true, Resets = true, Troll = true, Moderation = true },
		Deny = { GlobalBan = true, Unban = true, GrantEverything = true },
	},
	Moderator = {
		Categories = { Moderation = true },
		Commands = { InspectMarket = true, ResetTutorial = true, ShowUpdates = true },
		Deny = { GlobalBan = true },
	},
	Support = {
		Commands = {
			InspectMarket = true,
			ResetTutorial = true,
			ResetSettings = true,
			ShowUpdates = true,
			ResetWheelCooldown = true,
			ResetDailyClaim = true,
			CancelMarketRequest = true,
			Kick = true,
		},
	},
} :: { [string]: any })

function AdminPolicy.Resolve(role: string?): string?
	if type(role) ~= "string" or role == "" then
		return nil
	end
	if AdminPolicy.ROLES[role] ~= nil then
		return role
	end
	-- Unrecognised custom labels get the narrowest staff tier, never full access.
	return "Support"
end

function AdminPolicy.Allows(role: string?, command: string, definition: { [string]: any }?): (boolean, string?)
	local resolved = AdminPolicy.Resolve(role)
	if resolved == nil then
		return false, "Administrative access denied."
	end
	local policy = AdminPolicy.ROLES[resolved]
	if policy.All == true then
		return true, nil
	end
	if policy.Deny and policy.Deny[command] then
		return false, `{resolved} role can't run {command}.`
	end
	if policy.Commands and policy.Commands[command] then
		return true, nil
	end
	local category = definition and definition.Category or ""
	if policy.Categories and (policy.Categories[category] or policy.Categories[ALL]) then
		return true, nil
	end
	return false, `{resolved} role can't run {command}.`
end

function AdminPolicy.DeepCopy<T>(value: T, seen: { [any]: any }?): T
	if type(value) ~= "table" then
		return value
	end
	local visited = seen or {}
	if visited[value] then
		return visited[value]
	end
	local copy = {}
	visited[value] = copy
	for key, child in value :: any do
		copy[AdminPolicy.DeepCopy(key, visited)] = AdminPolicy.DeepCopy(child, visited)
	end
	return copy :: any
end

local function describe(value: any): string
	local kind = type(value)
	if kind == "nil" then
		return "none"
	elseif kind == "number" then
		if value ~= value then
			return "NaN"
		end
		if math.abs(value) >= 1e15 then
			return string.format("%.3e", value)
		end
		if value == math.floor(value) then
			return string.format("%d", value)
		end
		return string.format("%.3f", value)
	elseif kind == "string" then
		return if #value > 24 then string.sub(value, 1, 23) .. "…" else value
	elseif kind == "table" then
		local count = 0
		for _ in value do
			count += 1
		end
		return `{count} entries`
	end
	return tostring(value)
end

local function sortedKeys(left: any, right: any): { any }
	local keys, seen = {}, {}
	for _, source in { left, right } do
		if type(source) == "table" then
			for key in source do
				if not seen[key] then
					seen[key] = true
					table.insert(keys, key)
				end
			end
		end
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

-- Returns readable "Path: before → after" lines plus the total number of changed leaves.
function AdminPolicy.Diff(before: any, after: any, limit: number?): ({ string }, number)
	local maxLines = limit or 12
	local lines: { string } = {}
	local total = 0
	local function walk(path: string, a: any, b: any, depth: number)
		if type(a) == "table" and type(b) == "table" and depth < 6 then
			for _, key in sortedKeys(a, b) do
				walk(if path == "" then tostring(key) else path .. "." .. tostring(key), a[key], b[key], depth + 1)
			end
			return
		end
		if a == b then
			return
		end
		if type(a) == "number" and type(b) == "number" and a ~= a and b ~= b then
			return
		end
		total += 1
		if #lines < maxLines then
			table.insert(lines, `{path}: {describe(a)} → {describe(b)}`)
		end
	end
	walk("", before, after, 0)
	return lines, total
end

return table.freeze(AdminPolicy)
