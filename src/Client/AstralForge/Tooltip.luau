--!strict
-- Tooltips. One bubble for the whole game, drawn on its own top layer so nothing covers it.
--
-- Attach content to any GuiObject (Tooltip.attach, or the useTooltip hook; Button takes a
-- `tooltip` prop and gives icon-only buttons their name). Content is a string, or
-- { title = , body = , hint = , accent = }.
--
-- What keeps it out of the way:
--   * it waits before showing (0.5 s), but once one has just been shown, the next comes quickly,
--     so sweeping along a row reads naturally;
--   * it never covers the thing it describes or the pointer: it tries above, below, right and
--     left, takes the first spot that fits the safe area, and slides along the edge if none does;
--   * it sizes to its text (wrapping at a comfortable width, narrower on phones);
--   * it follows its target if that moves or scrolls, and goes the moment the pointer leaves,
--     the target is pressed, the wheel scrolls or the target disappears;
--   * a target that has been explained a few times waits longer before explaining again;
--   * touch shows it on a long press, gamepads when a button stays selected.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Tooltip = {} :: any

export type Content = string | { title: string?, body: string?, hint: string?, accent: Color3? }

local SHOW_DELAY = 0.5
local WARM_DELAY = 0.08
local WARM_WINDOW = 0.6
local SEEN_SLOWDOWN = 3 -- after this many showings a target waits longer
local SLOW_DELAY = 1.1
local GAP = 8
local EDGE = 10
local LONG_PRESS = 0.45

local theme: any = nil
local function palette(): any
	if theme == nil then
		local ok, kit = pcall(function()
			return require(script.Parent.CoreKit)("theme")
		end)
		theme = if ok then kit.Palette else {}
	end
	return theme
end

local reducedMotion = false
function Tooltip.setReducedMotion(value: boolean)
	reducedMotion = value == true
end
local enabled = true
function Tooltip.setEnabled(value: boolean)
	enabled = value ~= false
	if not enabled then
		Tooltip.hide()
	end
end

-- names for icon-only buttons, by icon concept
local LABELS = {
	Close = "Close", Back = "Back", Settings = "Settings", Menu = "Menu", Search = "Search",
	Refresh = "Refresh", Send = "Send", Chat = "Chat", Mail = "Mail", Inventory = "Inventory",
	Shop = "Shop", Play = "Play", Pause = "Pause", Hide = "Hide", Lock = "Locked", Check = "Done",
	Chevron = "More", Visit = "Visit", Wave = "Wave", Gift = "Gift", Leaderboard = "Ranks",
	Guide = "Guide", Credits = "Credits", Crew = "Crew", Guild = "Guild", Admin = "Admin",
	Rewards = "Rewards", Calendar = "Calendar", Code = "Codes", Travel = "Travel", Loadout = "Loadout",
}
function Tooltip.labelFor(icon: string?): string?
	if type(icon) ~= "string" then
		return nil
	end
	return LABELS[string.match(icon, "^[^.]+") or icon]
end

-- the bubble ------------------------------------------------------------------------------------

local screen: ScreenGui? = nil
local bubble: Frame? = nil
local titleLabel: TextLabel? = nil
local bodyLabel: TextLabel? = nil
local hintLabel: TextLabel? = nil
local stroke: UIStroke? = nil
local scale: UIScale? = nil
local widthCap: UISizeConstraint? = nil

local function label(name: string, order: number, weight: Enum.FontWeight, size: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.LayoutOrder = order
	text.BackgroundTransparency = 1
	text.AutomaticSize = Enum.AutomaticSize.XY
	text.Size = UDim2.fromOffset(0, 0)
	text.TextWrapped = true
	text.RichText = false
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", weight)
	text.TextSize = size
	text.ZIndex = 3
	local cap = Instance.new("UISizeConstraint")
	cap.Name = "Cap"
	cap.MaxSize = Vector2.new(280, math.huge)
	cap.Parent = text
	return text
end

local function build()
	if bubble ~= nil and screen ~= nil and screen.Parent ~= nil then
		return
	end
	local P = palette()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AstralForgeTooltips"
	gui.DisplayOrder = 9000
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local frame = Instance.new("Frame")
	frame.Name = "Bubble"
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.Size = UDim2.fromOffset(0, 0)
	frame.BackgroundColor3 = P.ink or Color3.fromRGB(16, 14, 24)
	frame.BackgroundTransparency = 0.06
	frame.BorderSizePixel = 0
	frame.Active = false
	frame.Selectable = false
	frame.Visible = false
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = frame
	local line = Instance.new("UIStroke")
	line.Thickness = 1
	line.Transparency = 0.45
	line.Color = P.lineSoft or Color3.fromRGB(90, 84, 120)
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	line.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 11)
	pad.PaddingRight = UDim.new(0, 11)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 9)
	pad.Parent = frame
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 3)
	list.Parent = frame
	local grow = Instance.new("UIScale")
	grow.Parent = frame
	local title = label("Title", 1, Enum.FontWeight.Bold, 14)
	title.TextColor3 = P.cream or Color3.fromRGB(245, 238, 225)
	title.Parent = frame
	local body = label("Body", 2, Enum.FontWeight.Regular, 13)
	body.TextColor3 = P.creamSoft or Color3.fromRGB(205, 198, 190)
	body.Parent = frame
	local hint = label("Hint", 3, Enum.FontWeight.SemiBold, 11)
	hint.TextColor3 = P.muted or Color3.fromRGB(150, 145, 160)
	hint.Parent = frame
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screen, bubble, titleLabel, bodyLabel, hintLabel, stroke, scale = gui, frame, title, body, hint, line, grow
	widthCap = title:FindFirstChild("Cap") :: UISizeConstraint
end

-- where things are on the tooltip layer (which ignores the top-bar inset)
local function screenRect(target: GuiObject): (Vector2, Vector2)
	local position = target.AbsolutePosition
	local holder = target:FindFirstAncestorWhichIsA("LayerCollector")
	if holder and holder:IsA("ScreenGui") and not holder.IgnoreGuiInset then
		position += (GuiService:GetGuiInset())
	end
	return position, target.AbsoluteSize
end

local function viewport(): Vector2
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

local function overlaps(p: Vector2, s: Vector2, q: Vector2, t: Vector2): boolean
	return p.X < q.X + t.X and q.X < p.X + s.X and p.Y < q.Y + t.Y and q.Y < p.Y + s.Y
end

-- the best spot for a bubble of `size` beside a target, kept clear of the pointer
local function place(targetPos: Vector2, targetSize: Vector2, size: Vector2, pointer: Vector2?, prefer: string?): (Vector2, string)
	local view = viewport()
	local inset = GuiService:GetGuiInset()
	local top = math.max(EDGE, inset.Y + 4)
	local cx = targetPos.X + targetSize.X / 2 - size.X / 2
	local cy = targetPos.Y + targetSize.Y / 2 - size.Y / 2
	local spots = {
		above = Vector2.new(cx, targetPos.Y - GAP - size.Y),
		below = Vector2.new(cx, targetPos.Y + targetSize.Y + GAP),
		right = Vector2.new(targetPos.X + targetSize.X + GAP, cy),
		left = Vector2.new(targetPos.X - GAP - size.X, cy),
	}
	local order = { "above", "below", "right", "left" }
	if prefer and spots[prefer] then
		table.insert(order, 1, prefer)
	end
	local function fits(p: Vector2): boolean
		return p.X >= EDGE and p.Y >= top and p.X + size.X <= view.X - EDGE and p.Y + size.Y <= view.Y - EDGE
	end
	local function clamp(p: Vector2): Vector2
		return Vector2.new(math.clamp(p.X, EDGE, math.max(EDGE, view.X - EDGE - size.X)), math.clamp(p.Y, top, math.max(top, view.Y - EDGE - size.Y)))
	end
	local pointerBox = Vector2.new(22, 26)
	for _, side in order do
		-- the centred spot, or one slid along the edge to stay on screen
		local p = spots[side]
		local slid = if side == "above" or side == "below" then Vector2.new(clamp(p).X, p.Y) else Vector2.new(p.X, clamp(p).Y)
		if fits(slid) and not (pointer and overlaps(slid, size, pointer - Vector2.new(4, 4), pointerBox)) then
			return slid, side
		end
	end
	return clamp(spots[order[1]]), order[1]
end

-- showing and hiding ----------------------------------------------------------------------------

type Entry = { target: GuiObject, content: Content, seen: number }
local entries: { [GuiObject]: Entry } = {}
local current: Entry? = nil
local side = "above"
local lastHiddenAt = -math.huge
local pending: thread? = nil
local follow: RBXScriptConnection? = nil
local fade: Tween? = nil

local function normalize(content: Content): { title: string?, body: string?, hint: string?, accent: Color3? }
	if type(content) == "string" then
		return { title = content }
	end
	return content :: any
end

local function stopFollow()
	if follow then
		follow:Disconnect()
		follow = nil
	end
end

function Tooltip.hide()
	if pending then
		pcall(task.cancel, pending)
		pending = nil
	end
	if current == nil then
		return
	end
	current = nil
	lastHiddenAt = os.clock()
	stopFollow()
	local frame = bubble
	if frame == nil then
		return
	end
	if fade then
		fade:Cancel()
	end
	if reducedMotion then
		frame.Visible = false
		return
	end
	fade = TweenService:Create(frame, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	for _, child in frame:GetChildren() do
		if child:IsA("TextLabel") then
			TweenService:Create(child, TweenInfo.new(0.1), { TextTransparency = 1 }):Play()
		end
	end
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(0.1), { Transparency = 1 }):Play()
	end
	local thisFade = fade :: Tween
	thisFade.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed and current == nil and bubble then
			bubble.Visible = false
		end
	end)
	thisFade:Play()
end

local function pointerPosition(): Vector2?
	if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		return UserInputService:GetMouseLocation()
	end
	return nil
end

local function reveal(entry: Entry)
	if not enabled or not entry.target:IsDescendantOf(game) or not entry.target.Visible then
		return
	end
	build()
	local frame, title, body, hint = bubble :: Frame, titleLabel :: TextLabel, bodyLabel :: TextLabel, hintLabel :: TextLabel
	local data = normalize(entry.content)
	local P = palette()
	local view = viewport()
	local width = math.clamp(math.floor(view.X * 0.7), 160, if view.X < 700 then 230 else 280)
	for _, text in { title, body, hint } do
		local cap = text:FindFirstChild("Cap") :: UISizeConstraint
		cap.MaxSize = Vector2.new(width, math.huge)
	end
	title.Text = data.title or ""
	title.Visible = data.title ~= nil and data.title ~= ""
	body.Text = data.body or ""
	body.Visible = data.body ~= nil and data.body ~= ""
	hint.Text = data.hint or ""
	hint.Visible = data.hint ~= nil and data.hint ~= ""
	if not title.Visible and not body.Visible then
		return
	end
	-- a body without a title reads as the main line
	body.TextColor3 = if title.Visible then (P.creamSoft or body.TextColor3) else (P.cream or body.TextColor3)
	if stroke then
		stroke.Color = data.accent or P.lineSoft or stroke.Color
	end
	current = entry
	entry.seen += 1
	if fade then
		fade:Cancel()
	end
	frame.BackgroundTransparency = 0.06
	title.TextTransparency, body.TextTransparency, hint.TextTransparency = 0, 0, 0
	if stroke then
		stroke.Transparency = if data.accent then 0.2 else 0.45
	end
	frame.Visible = true
	local first = true
	local drift = 0
	stopFollow()
	follow = RunService.RenderStepped:Connect(function(dt)
		local live = current
		if live ~= entry or not entry.target:IsDescendantOf(game) or not entry.target.Visible then
			Tooltip.hide()
			return
		end
		local targetPos, targetSize = screenRect(entry.target)
		local spot
		spot, side = place(targetPos, targetSize, frame.AbsoluteSize, pointerPosition(), if first then nil else side)
		-- arrive with a short slide away from the target, then sit still
		if first then
			drift = if reducedMotion then 0 else 1
			first = false
		end
		drift = math.max(0, drift - dt * 9)
		local push = drift * drift * 6
		local away = if side == "above" then Vector2.new(0, push) elseif side == "below" then Vector2.new(0, -push) elseif side == "right" then Vector2.new(-push, 0) else Vector2.new(push, 0)
		frame.Position = UDim2.fromOffset(math.round(spot.X + away.X), math.round(spot.Y + away.Y))
		if scale then
			scale.Scale = 1 - drift * 0.04
		end
	end)
end

local function schedule(entry: Entry, delay: number)
	if pending then
		pcall(task.cancel, pending)
	end
	pending = task.delay(delay, function()
		pending = nil
		if entries[entry.target] == entry then
			reveal(entry)
		end
	end)
end

local function delayFor(entry: Entry): number
	if os.clock() - lastHiddenAt < WARM_WINDOW then
		return WARM_DELAY
	end
	return if entry.seen >= SEEN_SLOWDOWN then SLOW_DELAY else SHOW_DELAY
end

-- give `target` a tooltip; returns a function that removes it
function Tooltip.attach(target: GuiObject, content: Content?): () -> ()
	if content == nil or content == "" then
		return function() end
	end
	local entry: Entry = { target = target, content = content :: Content, seen = 0 }
	entries[target] = entry
	local connections = {}
	local pressAt = 0
	local function leave()
		if pending and entries[target] == entry then
			pcall(task.cancel, pending)
			pending = nil
		end
		if current == entry then
			Tooltip.hide()
		end
	end
	table.insert(connections, target.MouseEnter:Connect(function()
		if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
			return
		end
		schedule(entry, delayFor(entry))
	end))
	table.insert(connections, target.MouseLeave:Connect(leave))
	table.insert(connections, target.SelectionGained:Connect(function()
		if GuiService.SelectedObject == target then
			schedule(entry, if os.clock() - lastHiddenAt < WARM_WINDOW then 0.25 else 0.7)
		end
	end))
	table.insert(connections, target.SelectionLost:Connect(leave))
	table.insert(connections, target.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Touch then
			pressAt = os.clock()
			schedule(entry, LONG_PRESS)
		elseif kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseButton2 then
			-- pressing means they know what it is; don't pop up over the click
			leave()
		elseif kind == Enum.UserInputType.MouseWheel then
			leave()
		end
	end))
	table.insert(connections, target.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			if current == entry and os.clock() - pressAt >= LONG_PRESS then
				-- leave a long-press tip up long enough to read
				task.delay(1.6, function()
					if current == entry then
						Tooltip.hide()
					end
				end)
			else
				leave()
			end
		end
	end))
	table.insert(connections, target.AncestryChanged:Connect(function()
		if not target:IsDescendantOf(game) then
			leave()
		end
	end))
	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		if entries[target] == entry then
			entries[target] = nil
		end
		leave()
	end
end

-- change what an attached target says (the bubble updates if it is showing)
function Tooltip.update(target: GuiObject, content: Content?)
	local entry = entries[target]
	if entry and content ~= nil then
		entry.content = content
		if current == entry then
			reveal(entry)
		end
	end
end

-- React: useTooltip(ref, content). Content can change every render; the attachment stays.
local React: any = nil
function Tooltip.useTooltip(ref: any, content: Content?)
	if React == nil then
		React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
	end
	local key = if type(content) == "table" then `{content.title or ""}\0{content.body or ""}\0{content.hint or ""}` else content
	local has = content ~= nil and content ~= ""
	React.useEffect(function()
		local target = ref.current
		if not has or target == nil then
			return nil
		end
		return Tooltip.attach(target, content :: Content)
	end, { has })
	React.useEffect(function()
		local target = ref.current
		if has and target ~= nil then
			Tooltip.update(target, content :: Content)
		end
	end, { key })
end

-- the scroll wheel anywhere dismisses (the target may be scrolling away under the pointer)
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel and current ~= nil then
		Tooltip.hide()
	end
end)

Tooltip._place = place
return Tooltip
