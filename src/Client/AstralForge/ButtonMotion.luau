--!strict
-- Purpose: give every GuiButton the game's press/hover motion, including hand-built buttons that
-- don't go through ui.Button. Shared Buttons (they carry their own UIScale) are left alone.
-- Owner: UI shell. Dependencies: TweenService, GuiService. Review: 2026-10-08.

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ButtonMotion = {}

local SCALE_NAME = "AF_Motion"
-- in pixels on the button's longest side, so a 40px icon and a 400px row feel the same as ui.Button
local HOVER_PIXELS = 2
local PRESS_PIXELS = 4
local HOVER_IN = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_IN = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SETTLE = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local reducedOverride: boolean? = nil

function ButtonMotion.setReducedMotion(value: boolean?)
	reducedOverride = value
end

local function reduced(): boolean
	if reducedOverride ~= nil then
		return reducedOverride
	end
	local ok, value = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	return ok and value == true
end

local function optedOut(button: GuiButton): boolean
	local node: Instance? = button
	for _ = 1, 4 do
		if node == nil then
			break
		end
		if node:GetAttribute("NoMotion") == true then
			return true
		end
		node = node.Parent
	end
	return false
end

-- ui.Button nests its own UIScale one level down; anything already scaling animates itself
local function ownsMotion(button: GuiButton): boolean
	for _, child in button:GetChildren() do
		if child:IsA("UIScale") and child.Name ~= SCALE_NAME then
			return true
		end
		if child:IsA("GuiObject") then
			for _, grandchild in child:GetChildren() do
				if grandchild:IsA("UIScale") then
					return true
				end
			end
		end
	end
	return false
end

local function eligible(button: GuiButton): boolean
	if not button.Active or optedOut(button) or ownsMotion(button) then
		return false
	end
	local size = button.AbsoluteSize
	if size.X < 8 or size.Y < 8 then
		return false
	end
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
	-- full-screen scrims and dismiss layers must never pulse
	if size.X > viewport.X * 0.6 and size.Y > viewport.Y * 0.6 then
		return false
	end
	return true
end

local function gains(button: GuiButton): (number, number)
	local longest = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y, 1)
	local hover = math.clamp(HOVER_PIXELS / longest, 0.006, 0.05)
	local press = math.clamp(PRESS_PIXELS / longest, 0.012, 0.08)
	return hover, press
end

function ButtonMotion.attach(root: Instance): () -> ()
	local tracked: { [GuiButton]: { RBXScriptConnection } } = {}
	local tweens: { [GuiButton]: Tween } = {}
	local alive = true

	local function scaleOf(button: GuiButton): UIScale
		local scale = button:FindFirstChild(SCALE_NAME)
		if scale and scale:IsA("UIScale") then
			return scale
		end
		local created = Instance.new("UIScale")
		created.Name = SCALE_NAME
		created.Parent = button
		return created
	end

	local function tween(button: GuiButton, goal: number, info: TweenInfo)
		if tweens[button] ~= nil then
			tweens[button]:Cancel()
		end
		local scale = scaleOf(button)
		local nextTween = TweenService:Create(scale, info, { Scale = goal })
		tweens[button] = nextTween
		nextTween:Play()
	end

	local function attachButton(button: GuiButton)
		if tracked[button] then
			return
		end
		local hovered = false
		local pressed = false
		local connections = {}
		local function rest()
			local scale = button:FindFirstChild(SCALE_NAME)
			if scale and scale:IsA("UIScale") then
				tween(button, 1, SETTLE)
			end
		end
		local function enter()
			hovered = true
			if pressed or reduced() or not eligible(button) then
				return
			end
			-- Roblox's default grey tint doesn't match the game's chrome; motion replaces it
			if button.AutoButtonColor then
				button.AutoButtonColor = false
			end
			local hover = gains(button)
			tween(button, 1 + hover, HOVER_IN)
		end
		local function leave()
			hovered = false
			pressed = false
			rest()
		end
		local function down()
			if not eligible(button) then
				return
			end
			pressed = true
			if button.AutoButtonColor then
				button.AutoButtonColor = false
			end
			local _, press = gains(button)
			tween(button, 1 - (if reduced() then press * 0.5 else press), PRESS_IN)
		end
		local function up()
			if not pressed then
				return
			end
			pressed = false
			if reduced() then
				rest()
				return
			end
			local hover = gains(button)
			tween(button, if hovered then 1 + hover else 1, RELEASE)
		end
		table.insert(connections, button.MouseEnter:Connect(enter))
		table.insert(connections, button.SelectionGained:Connect(enter))
		table.insert(connections, button.MouseLeave:Connect(leave))
		table.insert(connections, button.SelectionLost:Connect(leave))
		table.insert(connections, button.InputBegan:Connect(function(input)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
				down()
			end
		end))
		table.insert(connections, button.InputEnded:Connect(function(input)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
				up()
			end
		end))
		table.insert(connections, button:GetPropertyChangedSignal("Active"):Connect(function()
			if not button.Active then
				pressed = false
				rest()
			end
		end))
		table.insert(connections, button.Destroying:Connect(function()
			if tweens[button] ~= nil then
				tweens[button]:Cancel()
				tweens[button] = nil
			end
			local list = tracked[button]
			tracked[button] = nil
			if list then
				for _, connection in list do
					connection:Disconnect()
				end
			end
		end))
		tracked[button] = connections
	end

	local function consider(instance: Instance)
		if instance:IsA("GuiButton") then
			-- React fills children after creation; decide once the subtree exists
			task.defer(function()
				if alive and instance.Parent ~= nil then
					attachButton(instance)
				end
			end)
		end
	end

	for _, descendant in root:GetDescendants() do
		consider(descendant)
	end
	local added = root.DescendantAdded:Connect(consider)

	return function()
		alive = false
		added:Disconnect()
		for button, activeTween in tweens do
			activeTween:Cancel()
			tweens[button] = nil
		end
		for button, connections in tracked do
			for _, connection in connections do
				connection:Disconnect()
			end
			tracked[button] = nil
			local scale = button:FindFirstChild(SCALE_NAME)
			if scale ~= nil then
				scale:Destroy()
			end
		end
	end
end

return table.freeze(ButtonMotion)
