--!strict
export type Issue = {
	Kind: string,
	Path: string,
	Owner: string,
	Detail: string,
	FirstSeen: number,
	LastSeen: number,
	Samples: number,
}
local Diagnostics = {}
local CAPACITY = 128
local MAX_PAIR_CHECKS = 256

function Diagnostics.owner(instance: Instance): string
	local ancestor: Instance? = instance
	while ancestor do
		local owner = ancestor:GetAttribute("LayoutOwner")
		if type(owner) == "string" and owner ~= "" then return owner end
		ancestor = ancestor.Parent
	end
	return if instance.Parent then instance.Parent:GetFullName() else instance.Name
end

function Diagnostics.visible(instance: GuiObject): boolean
	local ancestor: Instance? = instance
	local left, top = instance.AbsolutePosition.X, instance.AbsolutePosition.Y
	local right, bottom = left + instance.AbsoluteSize.X, top + instance.AbsoluteSize.Y
	while ancestor do
		if ancestor:GetAttribute("LayoutGuardIgnore") == true then return false end
		if ancestor:IsA("GuiObject") then
			if not ancestor.Visible then return false end
			if ancestor.ClipsDescendants then
				local position, size = ancestor.AbsolutePosition, ancestor.AbsoluteSize
				left, top = math.max(left, position.X), math.max(top, position.Y)
				right, bottom = math.min(right, position.X + size.X), math.min(bottom, position.Y + size.Y)
			end
		elseif ancestor:IsA("LayerCollector") and not ancestor.Enabled then
			return false
		end
		ancestor = ancestor.Parent
	end
	return right > left and bottom > top
end

function Diagnostics.canRecover(instance: Instance, kind: string): boolean
	-- Only the owning component can opt a specific element into recovery.
	return instance:GetAttribute("LayoutGuardRecovery") == kind
end

function Diagnostics.new(clock: () -> number)
	local records: { Issue } = {}
	local keys: { [string]: Issue } = {}
	local cursor = 1
	local total = 0
	local observations = 0
	local epoch = 0
	local checks = 0
	local deadline = 0
	local object = {}

	function object:record(instance: Instance, kind: string, detail: string): boolean
		local path = instance:GetFullName()
		local key = kind .. ":" .. path
		local now = clock()
		observations += 1
		local issue = keys[key]
		if issue then
			issue.LastSeen = now
			issue.Samples += 1
			issue.Detail = detail
			issue.Owner = Diagnostics.owner(instance)
			return false
		end
		issue = {
			Kind = kind, Path = path, Owner = Diagnostics.owner(instance), Detail = detail,
			FirstSeen = now, LastSeen = now, Samples = 1,
		}
		if #records < CAPACITY then
			table.insert(records, issue)
		else
			local previous = records[cursor]
			keys[previous.Kind .. ":" .. previous.Path] = nil
			records[cursor] = issue
			cursor = cursor % CAPACITY + 1
		end
		keys[key] = issue
		total += 1
		return true
	end

	function object:snapshot()
		local copy: { Issue } = {}
		for _, issue in records do table.insert(copy, table.clone(issue)) end
		table.sort(copy, function(a, b) return a.LastSeen > b.LastSeen end)
		return { Epoch = epoch, Total = total, Issues = copy }
	end
	function object:total(): number
		return total
	end
	function object:observations(): number
		return observations
	end

	function object:reset()
		table.clear(records)
		table.clear(keys)
		cursor = 1
		epoch += 1
	end

	function object:beginPairs(endAt: number)
		checks = 0
		deadline = endAt
	end

	function object:pairAllowed(): boolean
		if checks >= MAX_PAIR_CHECKS or clock() >= deadline then return false end
		checks += 1
		return true
	end

	function object:runWork(worker: thread): boolean
		while coroutine.status(worker) ~= "dead" and self:pairAllowed() do
			local ok, reason = coroutine.resume(worker)
			if not ok then error(reason, 0) end
		end
		return coroutine.status(worker) == "dead"
	end

	return object
end
return table.freeze(Diagnostics)
