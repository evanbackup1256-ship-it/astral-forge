--!strict
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

type Entry = {
	Label: ImageLabel,
	Columns: number,
	Count: number,
	Frame: number,
	Rate: number,
	Size: Vector2,
}
local Playback = {}
local entries: { Entry } = {}
local active: { Entry } = {}
local connection: RBXScriptConnection? = nil
local cursor = 1
local clock = 0
local elapsed = 0
local MAX_LAYERS = 24
local SCAN_BATCH = 64
local SCAN_INTERVAL = 0.15

function Playback.visible(label: ImageLabel): boolean
	if label.Parent == nil or label.ImageTransparency >= 1 then return false end
	local position, size = label.AbsolutePosition, label.AbsoluteSize
	local left, top = position.X, position.Y
	local right, bottom = left + size.X, top + size.Y
	if size.X <= 0 or size.Y <= 0 then return false end
	local ancestor: Instance? = label
	local screen: ScreenGui? = nil
	while ancestor do
		if ancestor:IsA("GuiObject") then
			if not ancestor.Visible then return false end
			if ancestor:IsA("CanvasGroup") and ancestor.GroupTransparency >= 1 then return false end
			if ancestor.ClipsDescendants then
				local p, s = ancestor.AbsolutePosition, ancestor.AbsoluteSize
				left, top = math.max(left, p.X), math.max(top, p.Y)
				right, bottom = math.min(right, p.X + s.X), math.min(bottom, p.Y + s.Y)
			end
		elseif ancestor:IsA("LayerCollector") then
			if not ancestor.Enabled then return false end
			if ancestor:IsA("ScreenGui") then screen = ancestor end
		end
		ancestor = ancestor.Parent
	end
	-- World companions have their own distance/frustum owner.
	if screen == nil or screen.Parent == nil or not screen.Parent:IsA("PlayerGui") then return false end
	local camera = workspace.CurrentCamera
	if camera == nil then return false end
	local viewport = camera.ViewportSize
	return right > math.max(left, 0) and bottom > math.max(top, 0)
		and left < viewport.X and top < viewport.Y
end

local function step(dt: number)
	clock += dt
	elapsed += dt
	if GuiService.ReducedMotionEnabled then
		table.clear(active)
		return
	end
	if elapsed >= SCAN_INTERVAL then
		elapsed %= SCAN_INTERVAL
		for index = #active, 1, -1 do
			if not Playback.visible(active[index].Label) then table.remove(active, index) end
		end
		local checked = math.min(#entries, SCAN_BATCH)
		for _ = 1, checked do
			if cursor > #entries then cursor = 1 end
			local entry = entries[cursor]
			cursor += 1
			if #active < MAX_LAYERS and not table.find(active, entry) and Playback.visible(entry.Label) then
				table.insert(active, entry)
			end
		end
	end
	for _, entry in active do
		if Playback.visible(entry.Label) then
			local frame = math.floor(clock * entry.Rate) % entry.Count
			if frame ~= entry.Frame then
				entry.Frame = frame
				entry.Label.ImageRectOffset = Vector2.new(
					(frame % entry.Columns) * entry.Size.X,
					math.floor(frame / entry.Columns) * entry.Size.Y
				)
			end
		end
	end
end

function Playback.register(label: ImageLabel, columns: number, count: number, size: Vector2, rate: number)
	assert(columns > 0 and columns % 1 == 0 and count > 0 and count % 1 == 0
		and size.X > 0 and size.Y > 0 and size.X < math.huge and size.Y < math.huge
		and rate > 0 and rate < math.huge, "Invalid companion animation")
	local entry: Entry = { Label = label, Columns = columns, Count = count, Size = size, Rate = rate, Frame = -1 }
	table.insert(entries, entry)
	if connection == nil then
		elapsed = SCAN_INTERVAL
		connection = RunService.RenderStepped:Connect(step)
	end
	local released = false
	return {
		setRate = function(nextRate: number)
			assert(nextRate > 0 and nextRate < math.huge, "Invalid companion animation rate")
			entry.Rate = nextRate
		end,
		release = function()
			if released then return end
			released = true
			local index = table.find(entries, entry)
			if index then table.remove(entries, index) end
			local activeIndex = table.find(active, entry)
			if activeIndex then table.remove(active, activeIndex) end
			if #entries == 0 and connection then
				connection:Disconnect()
				connection = nil
				cursor = 1
				clock = 0
				elapsed = 0
			end
		end,
	}
end

function Playback.snapshot()
	return { Registered = #entries, Active = #active, Limit = MAX_LAYERS, Connected = connection ~= nil }
end

return Playback
