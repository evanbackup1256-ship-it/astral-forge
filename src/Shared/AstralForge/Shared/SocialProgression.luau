--!nocheck
-- Shared display progression and permission policy. Existing membership data stays valid.
return function(Math)
	local Social = {}
	local roles = { Leader = 3, Officer = 2, Member = 1 }
	function Social.canManage(actor, target, operation)
		if type(actor) ~= "table" or type(target) ~= "table" then
			return false
		end
		local a, b = roles[actor.Role] or 0, roles[target.Role] or 0
		if operation == "Role" then
			return a == 3 and b > 0 and b < 3
		end
		return a >= 2 and b > 0 and a > b
	end
	function Social.successor(members, departing)
		local candidates = {}
		for id, member in members or {} do
			if id ~= departing then
				table.insert(candidates, { id = id, member = member })
			end
		end
		table.sort(candidates, function(a, b)
			local ar, br = roles[a.member.Role] or 1, roles[b.member.Role] or 1
			if ar ~= br then
				return ar > br
			end
			local aj, bj = tonumber(a.member.JoinedAt) or math.huge, tonumber(b.member.JoinedAt) or math.huge
			if aj ~= bj then
				return aj < bj
			end
			return (tonumber(a.id) or math.huge) < (tonumber(b.id) or math.huge)
		end)
		return candidates[1] and candidates[1].id
	end
	function Social.hall(guild)
		local points = 0
		for _, level in guild.Upgrades or {} do
			if type(level) == "number" and level == level and level > 0 and level < math.huge then
				points += math.floor(level)
			end
		end
		local level = 1 + math.floor(points / 5)
		local title = if level >= 13
			then "Astral Citadel"
			elseif level >= 7 then "Starforge Hall"
			elseif level >= 4 then "United Foundry"
			elseif level >= 2 then "Growing Hall"
			else "New Charter"
		return { Level = level, Points = points, Progress = (points % 5) / 5, Remaining = 5 - points % 5, Title = title }
	end
	function Social.rank(entries, guildBoard)
		local rows, seen = {}, {}
		for _, entry in entries or {} do
			if type(entry) == "table" then
				local id = if guildBoard then entry.Id else tonumber(entry.UserId)
				local value = if guildBoard then entry.Activity else entry.Value
				local parsed = if type(value) == "string" then tonumber(value) else nil
				local valid = (type(value) == "number" and value == value and value >= 0 and value < math.huge)
					or (
						type(value) == "string"
						and parsed ~= nil
						and parsed == parsed
						and parsed >= 0
						and value:match("^[%d%.eE%+%-]+$") ~= nil
						and Math.Gte(value, 0)
					)
				local validId = if guildBoard
					then type(id) == "string" and id ~= ""
					else type(id) == "number" and id == id and id > 0 and id < math.huge and id % 1 == 0
				if validId and not seen[id] and valid then
					seen[id] = true
					local row = table.clone(entry)
					row.UserId = if guildBoard then entry.UserId else id
					row.Value = value
					table.insert(rows, row)
				end
			end
		end
		table.sort(rows, function(a, b)
			local comparison = Math.Compare(a.Value, b.Value)
			if comparison ~= 0 then
				return comparison > 0
			end
			return if guildBoard then a.Id < b.Id else a.UserId < b.UserId
		end)
		return rows
	end
	return Social
end
