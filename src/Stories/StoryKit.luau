--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local packages = ReplicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts")
local React = require(packages:WaitForChild("react"))
local ReactRoblox = require(packages:WaitForChild("react-roblox"))
local UILabs = require(packages:WaitForChild("ui-labs"))

local client = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("AstralForge")
local shared = ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared")

local MotionKit = require(client:WaitForChild("MotionKit"))
local CoreKit = require(client:WaitForChild("CoreKit"))
local autoScale = MotionKit("autoScale")
local theme = CoreKit("theme")
local Palette = theme.Palette
local Breakpoints = theme.Breakpoints

local StoryKit = {}
StoryKit.React = React
StoryKit.ReactRoblox = ReactRoblox
StoryKit.UILabs = UILabs
StoryKit.client = client
StoryKit.shared = shared

StoryKit.DEVICES = {
	"Desktop 1920x1080",
	"Laptop 1366x768",
	"Tablet 1024x768",
	"Phone 390x844",
	"Phone landscape 844x390",
	"Small phone 360x640",
	"Small landscape 640x360",
}

function StoryKit.deviceSize(name: string): Vector2
	local w, h = string.match(name or "", "(%d+)x(%d+)")
	if w == nil then
		return Vector2.new(1366, 768)
	end
	return Vector2.new(tonumber(w), tonumber(h))
end

function StoryKit.isPhone(name: string): boolean
	return string.find(name or "", "hone", 1, true) ~= nil or string.find(name or "", "landscape", 1, true) ~= nil
end

local function deviceInsets(name)
	if string.find(name, "landscape", 1, true) then
		return { top = 0, bottom = 12, side = 44 }
	elseif StoryKit.isPhone(name) then
		return { top = 47, bottom = 34, side = 0 }
	end
	return { top = 0, bottom = 0, side = 0 }
end

-- The screen the game's layout code would see on that device, as AutoScale computes it.
function StoryKit.viewportInfo(device: string, keyboardOpen: boolean?)
	local size = StoryKit.deviceSize(device)
	local insets = deviceInsets(device)
	local width, height = size.X, size.Y
	local usable = if keyboardOpen then math.floor(height * 0.55) else height
	return {
		scale = autoScale.computeViewportScale(width, usable),
		width = width,
		height = usable,
		topInset = insets.top,
		bottomInset = if keyboardOpen then 0 else insets.bottom,
		sideInset = insets.side,
		screenWidth = width,
		screenHeight = height,
		keyboardOpen = keyboardOpen == true,
		desktop = not StoryKit.isPhone(device) and width >= 840 and height >= 500,
		tenFoot = false,
		compact = width < Breakpoints.compact,
		tight = width < Breakpoints.tight,
		short = math.min(usable, height) < Breakpoints.short,
	}
end

-- A device screen inside the story canvas: the page lays out at the device's real size and the
-- whole screen is scaled to fit the preview.
local function DeviceFrame(props)
	local hostRef = React.useRef(nil)
	local fit, setFit = React.useState(1)
	local info = StoryKit.viewportInfo(props.device, props.keyboardOpen)
	local size = StoryKit.deviceSize(props.device)
	React.useEffect(function()
		local host = hostRef.current
		if host == nil then
			return nil
		end
		local function sync()
			local avail = host.AbsoluteSize
			if avail.X > 0 and avail.Y > 0 then
				setFit(math.min(1, (avail.X - 16) / size.X, (avail.Y - 16) / size.Y))
			end
		end
		sync()
		local connection = host:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync)
		return function()
			connection:Disconnect()
		end
	end, { size.X, size.Y })
	return React.createElement(
		"frame",
		{
			ref = hostRef,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(8, 6, 12),
			BorderSizePixel = 0,
		},
		React.createElement(
			"frame",
			{
				Name = "DeviceScreen",
				Size = UDim2.fromOffset(size.X, size.Y),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Palette.void,
				BorderSizePixel = 0,
				ClipsDescendants = true,
			},
			React.createElement("uiscale", {
				Scale = fit,
			}),
			React.createElement("uistroke", {
				Color = Palette.lineSoft,
				Thickness = 2,
			}),
			React.createElement(
				autoScale.ViewportScaleContext.Provider,
				{
					value = info,
				},
				React.createElement("frame", {
					Name = "SafeArea",
					Size = UDim2.new(1, -info.sideInset * 2, 1, -(info.topInset + info.bottomInset)),
					Position = UDim2.fromOffset(info.sideInset, info.topInset),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, props.children)
			)
		)
	)
end
StoryKit.DeviceFrame = DeviceFrame

-- Shows a render error inside the story instead of a blank canvas.
local Boundary = React.Component:extend("StoryBoundary")
function Boundary:init()
	self.state = { message = nil }
end
function Boundary.getDerivedStateFromError(err)
	return { message = tostring(err) }
end
function Boundary:render()
	if self.state.message ~= nil then
		return React.createElement("textlabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(40, 12, 18),
			TextColor3 = Color3.fromRGB(255, 200, 200),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Font = Enum.Font.Code,
			TextSize = 14,
			Text = "This story could not render.\n\n"
				.. self.state.message
				.. "\n\nPages that read deep server state need a captured snapshot: see src/Stories/README.md.",
		})
	end
	return self.props.children
end
StoryKit.Boundary = Boundary

-- Game state for stories: a captured snapshot when one exists, otherwise the hand-built fixture.
function StoryKit.state(save: string?)
	local captured = script.Parent:FindFirstChild("StorySnapshot")
	local base
	if captured ~= nil then
		base = require(captured)
	else
		base = require(script.Parent:WaitForChild("StoryFixture")).build(save or "Mid game")
	end
	return table.clone(base)
end

function StoryKit.config()
	return require(shared:WaitForChild("GameConfig"))
end

-- Records what a story dispatches; answers with the chosen outcome.
function StoryKit.dispatcher(outcome: string?, log: { string }?)
	return function(action, payload, callback)
		local line = `dispatch {action}`
		if log ~= nil then
			table.insert(log, line)
		end
		print("[story]", line, payload)
		if callback ~= nil then
			task.delay(0.35, function()
				if outcome == "Fail" then
					callback({ ok = false, error = "Story preview: the server said no." })
				else
					callback({ ok = true, message = "Story preview: done." })
				end
			end)
		end
	end
end

-- Controls every story shares.
function StoryKit.controls(extra: { [string]: any }?)
	local controls = {
		Device = UILabs.Choose(StoryKit.DEVICES, 2),
		ReducedMotion = false,
		Save = UILabs.Choose({ "New player", "Mid game", "Late game" }, 2),
		Dispatch = UILabs.Choose({ "Succeed", "Fail" }, 1),
	}
	for key, value in extra or {} do
		controls[key] = value
	end
	return controls
end

-- A React story rendered on a device screen. render(controls, kit) returns the element to show, where
-- kit carries state, config, dispatch and reducedMotion for the chosen controls.
function StoryKit.story(info: { name: string?, summary: string?, controls: { [string]: any }? }, render)
	return UILabs.CreateReactStory({
		name = info.name,
		summary = info.summary,
		react = React,
		reactRoblox = ReactRoblox,
		controls = StoryKit.controls(info.controls),
	}, function(props)
		local controls = props.controls
		local kit = {
			state = StoryKit.state(controls.Save),
			config = StoryKit.config(),
			dispatch = StoryKit.dispatcher(controls.Dispatch),
			reducedMotion = controls.ReducedMotion == true,
			device = controls.Device,
		}
		return React.createElement(DeviceFrame, {
			device = controls.Device,
			keyboardOpen = controls.KeyboardOpen == true,
		}, React.createElement(Boundary, nil, render(controls, kit)))
	end)
end

-- A page from PageRouter's suites, with the props PageRouter passes.
function StoryKit.page(suite: string, member: string, summary: string?, extraProps: { [string]: any }?)
	return StoryKit.story({ name = member, summary = summary }, function(_controls, kit)
		local pages = client:WaitForChild("pages")
		local component = require(pages:WaitForChild(suite))(member)[member]
		local props = {
			state = kit.state,
			config = kit.config,
			dispatch = kit.dispatch,
			reducedMotion = kit.reducedMotion,
			navigate = function(page)
				print("[story] navigate", page)
			end,
			onCrateReveal = function(session)
				print("[story] crate reveal", session and session.crateName)
			end,
			crateRevealActive = false,
			onPurchasePresentationChange = function() end,
			setVisit = function() end,
			openShop = function() end,
		}
		for key, value in extraProps or {} do
			props[key] = value
		end
		return React.createElement(component, props)
	end)
end

-- Turns a live value into Luau source (for capturing a snapshot from a playtest into StorySnapshot).
function StoryKit.serialize(value, indent: string?)
	indent = indent or ""
	local kind = typeof(value)
	if kind == "string" then
		return string.format("%q", value)
	elseif kind == "number" then
		if value ~= value then
			return "0/0"
		elseif value == math.huge then
			return "math.huge"
		elseif value == -math.huge then
			return "-math.huge"
		end
		return tostring(value)
	elseif kind == "boolean" or kind == "nil" then
		return tostring(value)
	elseif kind == "Color3" then
		return string.format(
			"Color3.fromRGB(%d, %d, %d)",
			math.round(value.R * 255),
			math.round(value.G * 255),
			math.round(value.B * 255)
		)
	elseif kind == "Vector3" then
		return string.format("Vector3.new(%s, %s, %s)", value.X, value.Y, value.Z)
	elseif kind == "Vector2" then
		return string.format("Vector2.new(%s, %s)", value.X, value.Y)
	elseif kind == "UDim2" then
		return string.format("UDim2.new(%s, %s, %s, %s)", value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset)
	elseif kind == "EnumItem" then
		return tostring(value)
	elseif kind == "table" then
		local inner = indent .. "\t"
		local parts = {}
		local keys = {}
		for key in value do
			table.insert(keys, key)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		for _, key in keys do
			local keyText = if type(key) == "string" and string.match(key, "^[%a_][%w_]*$")
				then key
				else `[{StoryKit.serialize(key)}]`
			table.insert(parts, `{inner}{keyText} = {StoryKit.serialize(value[key], inner)},`)
		end
		if #parts == 0 then
			return "{}"
		end
		return "{\n" .. table.concat(parts, "\n") .. "\n" .. indent .. "}"
	end
	return "nil"
end

-- Layout problems in a rendered tree: text that doesn't fit, controls under the phone tap size,
-- elements outside the screen, and labels running into solid siblings. Used by the mobile audit.
function StoryKit.audit(root: GuiObject, minTap: number?)
	local issues = {}
	local tap = minTap or 40
	local screen = root.AbsolutePosition
	local screenSize = root.AbsoluteSize
	local scale = 1
	local uiScale = root:FindFirstChildOfClass("UIScale")
	if uiScale ~= nil then
		scale = uiScale.Scale
	end
	local function visible(gui)
		local node = gui
		while node ~= nil and node ~= root do
			if node:IsA("GuiObject") and not node.Visible then
				return false
			end
			node = node.Parent
		end
		return true
	end
	for _, gui in root:GetDescendants() do
		if not gui:IsA("GuiObject") or not visible(gui) then
			continue
		end
		local pos, size = gui.AbsolutePosition, gui.AbsoluteSize
		if size.X < 1 or size.Y < 1 then
			continue
		end
		local name = gui:GetFullName()
		if (gui:IsA("TextLabel") or gui:IsA("TextButton")) and gui.Text ~= "" and not gui.TextFits then
			table.insert(issues, { kind = "text-overflow", path = name, detail = gui.Text })
		end
		if
			gui:IsA("GuiButton")
			and gui.Active
			and (size.X / scale < tap - 0.5 or size.Y / scale < tap - 0.5)
			and gui.BackgroundTransparency < 1
		then
			table.insert(
				issues,
				{ kind = "small-tap", path = name, detail = string.format("%dx%d", size.X / scale, size.Y / scale) }
			)
		end
		if
			pos.X + size.X < screen.X - 1
			or pos.Y + size.Y < screen.Y - 1
			or pos.X > screen.X + screenSize.X + 1
			or pos.Y > screen.Y + screenSize.Y + 1
		then
			continue
		end
		if pos.X < screen.X - 2 or pos.X + size.X > screen.X + screenSize.X + 2 then
			if gui:IsA("TextLabel") or gui:IsA("GuiButton") or gui:IsA("TextBox") then
				table.insert(issues, {
					kind = "offscreen-x",
					path = name,
					detail = string.format(
						"%d..%d of %d",
						(pos.X - screen.X) / scale,
						(pos.X + size.X - screen.X) / scale,
						screenSize.X / scale
					),
				})
			end
		end
	end
	return issues
end

return StoryKit
