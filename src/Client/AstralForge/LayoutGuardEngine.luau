--!nonstrict
-- Temporal constraint checks, reversible repairs and bounded diagnostics.
-- This module deliberately has no service or frame-loop dependencies.
local Engine = {}
local TRACKED_PROPERTIES = {
	"Size",
	"Position",
	"ZIndex",
	"Visible",
	"TextSize",
	"TextWrapped",
	"TextScaled",
	"TextTruncate",
	"CanvasSize",
	"ScrollingEnabled",
}

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function geometry(instance)
	local size, position = instance.AbsoluteSize, instance.AbsolutePosition
	return { width = size.X, height = size.Y, x = position.X, y = position.Y }
end

local function score(instance)
	local rect = geometry(instance)
	if not finite(rect.width) or not finite(rect.height) or not finite(rect.x) or not finite(rect.y) then
		return 1000
	end
	if not instance.Visible then
		return 0
	end
	local penalty = 0
	if instance:IsA("TextLabel") or instance:IsA("TextBox") or instance:IsA("TextButton") then
		if instance.Text ~= "" and not instance.TextFits then
			penalty += 100
		end
	end
	local parent = instance.Parent
	-- Canvas content is allowed outside its window. Engine layouts own position.
	if
		parent
		and parent:IsA("GuiObject")
		and not parent:IsA("ScrollingFrame")
		and not parent:FindFirstChildWhichIsA("UIListLayout")
		and not parent:FindFirstChildWhichIsA("UIGridLayout")
	then
		local bounds = geometry(parent)
		if not finite(bounds.x) or not finite(bounds.y) or not finite(bounds.width) or not finite(bounds.height) then
			return penalty
		end
		penalty += math.max(0, bounds.x - rect.x - 6) + math.max(0, bounds.y - rect.y - 6) + math.max(
			0,
			rect.x + rect.width - bounds.x - bounds.width - 6
		) + math.max(0, rect.y + rect.height - bounds.y - bounds.height - 6)
	end
	return penalty
end

local function mode(instance)
	local cursor = instance
	local observed = false
	while cursor do
		if cursor:GetAttribute("LayoutGuardIgnore") == true or cursor:GetAttribute("LayoutGuardTransient") == true then
			return "off"
		end
		local selected = cursor:GetAttribute("LayoutGuardMode")
		if selected == "off" then
			return "off"
		elseif selected == "observe" then
			observed = true
		end
		cursor = cursor.Parent
	end
	return if observed then "observe" else "repair"
end

function Engine.new(clock)
	clock = clock or os.clock
	local records = setmetatable({}, { __mode = "k" })
	local journal = {}
	local cursor = 0
	local metrics = {
		checked = 0,
		deferred = 0,
		observed = 0,
		repaired = 0,
		rolledBack = 0,
		superseded = 0,
		errors = 0,
		frameMs = 0,
	}
	local writing = false
	local deadline = math.huge
	local started = 0
	local api = {}
	local function record(instance, kind, before, after)
		cursor = cursor % 128 + 1
		journal[cursor] = { time = clock(), path = instance:GetFullName(), kind = kind, before = before, after = after }
	end
	local function capture(instance)
		local values = {}
		for _, property in TRACKED_PROPERTIES do
			local ok, value = pcall(function()
				return instance[property]
			end)
			if ok then
				values[property] = value
			end
		end
		return values
	end
	function api.beginFrame(deltaTime, burst)
		started = clock()
		-- A slow frame gets less guard work; resize bursts still obey a CPU ceiling.
		local milliseconds = if deltaTime > 1 / 35 then 0.6 elseif burst then 2 else 1.2
		deadline = started + milliseconds / 1000
	end
	function api.hasBudget()
		return clock() < deadline
	end
	function api.endFrame()
		metrics.frameMs = (clock() - started) * 1000
	end
	function api.isWriting()
		return writing
	end
	function api.invalidate(instance)
		if writing then
			return
		end
		local entry = records[instance]
		if entry then
			entry.stable = 0
			entry.blocked = false
			if entry.transaction then
				entry.transaction = nil
				metrics.superseded += 1
			end
		end
	end
	function api.remove(instance)
		records[instance] = nil
	end
	function api.inspect(instance, repair)
		if instance.Parent == nil or mode(instance) == "off" then
			return "ignored"
		end
		local entry = records[instance]
		if not entry then
			entry = { stable = 0 }
			records[instance] = entry
		end
		local rect = geometry(instance)
		local previous = entry.rect
		local changed = previous == nil
			or math.abs(rect.width - previous.width) > 0.5
			or math.abs(rect.height - previous.height) > 0.5
			or math.abs(rect.x - previous.x) > 0.5
			or math.abs(rect.y - previous.y) > 0.5
		entry.rect = rect
		if changed then
			entry.stable = 0
		else
			entry.stable += 1
		end
		if entry.stable < 1 and finite(rect.width) and finite(rect.height) and finite(rect.x) and finite(rect.y) then
			metrics.deferred += 1
			return "deferred"
		end
		local beforeScore = score(instance)
		if entry.transaction then
			local transaction = entry.transaction
			entry.transaction = nil
			local current = capture(instance)
			for property, expected in transaction.after do
				if current[property] ~= expected then
					metrics.superseded += 1
					return "superseded"
				end
			end
			if beforeScore > transaction.score + 0.5 then
				writing = true
				for property, original in transaction.before do
					pcall(function()
						instance[property] = original
					end)
				end
				writing = false
				entry.blocked = true
				metrics.rolledBack += 1
				record(instance, "rollback", transaction.score, beforeScore)
				return "rollback"
			end
			metrics.repaired += 1
			record(instance, "repair", transaction.score, beforeScore)
		end
		if entry.blocked then
			return "blocked"
		end
		metrics.checked += 1
		if mode(instance) == "observe" then
			if beforeScore > 0 and entry.lastObserved ~= beforeScore then
				entry.lastObserved = beforeScore
				metrics.observed += 1
				record(instance, "observe", beforeScore, beforeScore)
			end
			return "observed"
		end
		local before = capture(instance)
		writing = true
		local ok, problem = pcall(repair, instance)
		writing = false
		local after = capture(instance)
		local edited = false
		for property, value in before do
			if after[property] ~= value then
				edited = true
				break
			end
		end
		if not ok then
			writing = true
			for property, value in before do
				pcall(function()
					instance[property] = value
				end)
			end
			writing = false
			entry.blocked = true
			metrics.errors += 1
			record(instance, "error: " .. tostring(problem), beforeScore, beforeScore)
			return "error"
		end
		if edited then
			entry.transaction = { before = before, after = after, score = beforeScore }
			return "verify"
		end
		return "clean"
	end
	function api.mayRepair(instance)
		local entry = records[instance]
		return entry == nil or (not entry.blocked and not entry.transaction)
	end
	function api.needsVerification(instance)
		local entry = records[instance]
		return entry ~= nil and entry.transaction ~= nil
	end
	function api.repairGroup(group, repair)
		local before = {}
		local editedInstances = {}
		for _, instance in group do
			local target = instance
			-- Stack repairs may move a containing action frame as well as the label.
			for _ = 1, 3 do
				if not target or not target:IsA("GuiObject") then
					break
				end
				before[target] = { values = capture(target), score = score(target) }
				target = target.Parent
			end
		end
		writing = true
		local ok, problem = pcall(repair, group)
		writing = false
		for instance, original in before do
			local after = capture(instance)
			local edited = false
			for property, value in original.values do
				if value ~= after[property] then
					edited = true
					break
				end
			end
			if edited then
				local entry = records[instance] or { stable = 1, rect = geometry(instance) }
				records[instance] = entry
				if ok then
					if entry.transaction == nil then
						entry.transaction = { before = original.values, after = after, score = original.score }
						table.insert(editedInstances, instance)
					end
				else
					writing = true
					for property, value in original.values do
						pcall(function()
							instance[property] = value
						end)
					end
					writing = false
					entry.blocked = true
					metrics.errors += 1
					record(instance, "group error: " .. tostring(problem), original.score, original.score)
				end
			end
		end
		return editedInstances
	end
	function api.diagnostics()
		local history = {}
		for offset = 1, #journal do
			local index = (cursor + offset - 1) % #journal + 1
			table.insert(history, table.clone(journal[index]))
		end
		return { metrics = table.clone(metrics), history = history }
	end
	return api
end

function Engine.pairIterator(list)
	return coroutine.wrap(function()
		local bins = {}
		local work = 0
		local function checkpoint()
			work += 1
			if work >= 16 then
				work = 0
				coroutine.yield(false)
			end
		end
		for _, instance in list do
			local rect = geometry(instance)
			if finite(rect.x) and finite(rect.y) and finite(rect.width) and finite(rect.height) then
				local first = math.floor(rect.y / 160)
				local last = math.floor((rect.y + math.max(0, rect.height) + 6) / 160)
				if last - first <= 16 then
					for row = first, last do
						local bin = bins[row]
						if not bin then
							bin = {}
							bins[row] = bin
						end
						table.insert(bin, instance)
						checkpoint()
					end
				end
			end
			checkpoint()
		end
		for row, bin in bins do
			table.sort(bin, function(a, b)
				return a.AbsolutePosition.X < b.AbsolutePosition.X
			end)
			coroutine.yield(false)
			for index, a in bin do
				local rectA = geometry(a)
				for nextIndex = index + 1, #bin do
					local b = bin[nextIndex]
					local rectB = geometry(b)
					if rectB.x > rectA.x + rectA.width + 6 then
						break
					end
					local startY = math.max(rectA.y, rectB.y)
					local endY = math.min(rectA.y + rectA.height, rectB.y + rectB.height)
					-- Handle a pair in exactly one bin, even when it spans several rows.
					if startY <= endY + 6 and math.floor(startY / 160) == row then
						coroutine.yield({ a, b })
					end
					checkpoint()
				end
				checkpoint()
			end
		end
	end)
end

function Engine.pairGroups(list)
	local groups = {}
	local nextPair = Engine.pairIterator(list)
	while true do
		local pair = nextPair()
		if pair == nil then
			break
		end
		if pair then
			table.insert(groups, pair)
		end
	end
	return groups
end

Engine.score = score
Engine.mode = mode
return Engine
