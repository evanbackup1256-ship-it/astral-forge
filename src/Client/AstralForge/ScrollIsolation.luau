--!strict
-- Nested rows own their input until the pointer or touch leaves the row.
local Isolation = {}

type ParentLock = {
	owners: number,
	enabled: boolean,
	previousAttribute: any,
	connection: RBXScriptConnection,
}

local parentLocks: { [ScrollingFrame]: ParentLock } = {}

function Isolation.frameAtPosition(playerGui: PlayerGui, pointer: Vector2): ScrollingFrame?
	local candidate: ScrollingFrame? = nil
	local objects = playerGui:GetGuiObjectsAtPosition(math.floor(pointer.X), math.floor(pointer.Y))
	for _, object in objects do
		local cursor: Instance? = object
		while cursor do
			if cursor:IsA("ScrollingFrame") and cursor.Visible then
				-- A page background can precede its nested row in the hit list.
				if candidate == nil or cursor:IsDescendantOf(candidate) then
					candidate = cursor
				end
				break
			end
			cursor = cursor.Parent
		end
	end
	return candidate
end

local function acquire(parent: ScrollingFrame)
	local existing = parentLocks[parent]
	if existing then
		existing.owners += 1
		return
	end
	local enabled = parent.ScrollingEnabled
	local previousAttribute = parent:GetAttribute("AF_ScrollLocked")
	parent:SetAttribute("AF_ScrollLocked", true)
	local connection = parent:GetPropertyChangedSignal("ScrollingEnabled"):Connect(function()
		-- React updates and layout maintenance must respect the active input owner.
		if parent.ScrollingEnabled then
			parent.ScrollingEnabled = false
		end
	end)
	parentLocks[parent] = {
		owners = 1,
		enabled = enabled,
		previousAttribute = previousAttribute,
		connection = connection,
	}
	parent.ScrollingEnabled = false
end

local function releaseParent(parent: ScrollingFrame)
	local lock = parentLocks[parent]
	if lock == nil then
		return
	end
	lock.owners -= 1
	if lock.owners > 0 then
		return
	end
	parentLocks[parent] = nil
	lock.connection:Disconnect()
	if parent.Parent ~= nil then
		parent:SetAttribute("AF_ScrollLocked", lock.previousAttribute)
		parent.ScrollingEnabled = lock.enabled
	end
end

function Isolation.bind(frame: ScrollingFrame): () -> ()
	local inputService = game:GetService("UserInputService")
	local playerGui = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local held: { [ScrollingFrame]: boolean } = {}
	local hovering = false
	local touches: { [InputObject]: boolean } = {}
	local previousCapture = frame:GetAttribute("AF_ScrollCapture")

	local function release()
		for parent in held do
			releaseParent(parent)
		end
		table.clear(held)
	end

	local function refresh()
		if not hovering and next(touches) == nil then
			release()
			return
		end
		local parent = frame.Parent
		while parent do
			if parent:IsA("ScrollingFrame") and not held[parent] then
				held[parent] = true
				acquire(parent)
			end
			parent = parent.Parent
		end
	end

	local function ownsPosition(pointer: Vector2): boolean
		if playerGui == nil then
			return false
		end
		local target = Isolation.frameAtPosition(playerGui, pointer)
		return target == frame or (target ~= nil and target:IsDescendantOf(frame))
	end

	local function updateHover()
		hovering = inputService.MouseEnabled and ownsPosition(inputService:GetMouseLocation())
		refresh()
	end

	local function beginTouch(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			touches[input] = true
			refresh()
		end
	end

	frame:SetAttribute("AF_ScrollCapture", true)
	local connections = {
		game:GetService("RunService").RenderStepped:Connect(updateHover),
		frame.MouseEnter:Connect(updateHover),
		frame.MouseLeave:Connect(updateHover),
		frame.InputBegan:Connect(beginTouch),
		-- Child buttons can receive the initial touch instead of their scrolling parent.
		inputService.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				and ownsPosition(Vector2.new(input.Position.X, input.Position.Y))
			then
				beginTouch(input)
			end
		end),
		inputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				updateHover()
			end
		end),
		inputService.InputEnded:Connect(function(input)
			if touches[input] then
				touches[input] = nil
				refresh()
			end
		end),
	}
	updateHover()
	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		release()
		if frame.Parent ~= nil then
			frame:SetAttribute("AF_ScrollCapture", previousCapture)
		end
	end
end

return Isolation
