-- The sanctuary HUD: everything on screen while the player walks the world.
--
--   * region banner when you cross into a new part of the map
--   * ore chips (what you've mined)
--   * the Rift Warden bar: countdown while it sleeps, forming progress, then
--     its health while it fights
--   * Strike (F / R2 / the button) while the Warden is up and you're in the
--     Riftmaw; Recall to jump back to the Forge Heart
--   * the navigation menu (when the docks don't fit) and the waystone sheet
--
-- Every rectangle comes from sanctuaryHudPlan, so nothing overlaps at any
-- screen size and nothing sits where the thumbs go on a phone.

local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Audio = require(script.Parent.audio).Audio
local Icon = require(script.Parent.Icon).Icon
local Palette = require(script.Parent.theme).Palette
local Signals = require(script.Parent.sanctuarySignals)
local Controls = require(script.Parent.sanctuaryControls)
local HudPlan = require(script.Parent.sanctuaryHudPlan)
local MotionTokens = require(script.Parent.motionTokens)
local Shared = ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared")
local Layout = require(Shared:WaitForChild("SanctuaryLayout"))
local SanctuaryConfig = require(Shared:WaitForChild("SanctuaryConfig"))

local e = React.createElement

local BOSS = SanctuaryConfig.RiftBoss
local STRIKE_COOLDOWN = BOSS.StrikeCooldown + 0.04
local RECALL_COOLDOWN = 8
local BANNER_SECONDS = 2.8
local FONT_MEDIUM = Font.fromEnum(Enum.Font.BuilderSansMedium)
local FONT_BOLD = Font.fromEnum(Enum.Font.BuilderSansBold)
local FONT_HEAVY = Font.fromEnum(Enum.Font.BuilderSansExtraBold)
local RIFT = Color3.fromRGB(164, 124, 255)
local RIFT_SOFT = Color3.fromRGB(214, 196, 255)
local PANEL = Palette.ink
local PANEL_ALPHA = 0.18

local REGION_LINES = {
	Heart = "The forge altar",
	Emberreach = "Emberite grows here",
	Hollows = "Voidglass grows here",
	Spire = "Starsteel grows here",
	Riftmaw = "Where the Rift Warden wakes",
}

local function rgb(triple): Color3
	return Color3.fromRGB(triple[1], triple[2], triple[3])
end

local ORE_COLORS = {}
for _, ore in SanctuaryConfig.Ore.Types do
	ORE_COLORS[ore.Id] = rgb(ore.Color)
end

local function compact(value: number): string
	value = math.floor(value)
	if value >= 1e6 then
		return string.format("%.1fM", value / 1e6)
	elseif value >= 1e4 then
		return string.format("%.1fK", value / 1e3)
	end
	-- 1,234 style below ten thousand.
	local text = tostring(value)
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	if string.sub(formatted, 1, 1) == "," then
		formatted = string.sub(formatted, 2)
	end
	return formatted
end

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function rectProps(r)
	return UDim2.fromOffset(r.x, r.y), UDim2.fromOffset(r.w, r.h)
end

local function preferGamepad(): boolean
	local preferred = UserInputService.PreferredInput
	return preferred == Enum.PreferredInput.Gamepad or preferred == Enum.PreferredInput.MicroGamepad
end

------------------------------------------------------------------------
-- Hooks
------------------------------------------------------------------------

-- Eases a binding toward `target` over `seconds` on the shared standard curve, starting from
-- `initial` on mount (default: already at the target). Instant when motion
-- is reduced.
local function useEase(target: number, seconds: number, reduced: boolean, initial: number?)
	local start = if reduced or initial == nil then target else initial
	local binding, setBinding = React.useBinding(start)
	local current = React.useRef(start)
	React.useEffect(function()
		local from = current.current
		if reduced or math.abs(from - target) < 1e-3 then
			current.current = target
			setBinding(target)
			return nil
		end
		local started = os.clock()
		local duration = math.max(0.05, seconds * math.abs(target - from))
		local connection: RBXScriptConnection? = nil
		connection = RunService.RenderStepped:Connect(function()
			local k = math.clamp((os.clock() - started) / duration, 0, 1)
			local eased = MotionTokens.EASE.standard(k)
			local value = from + (target - from) * eased
			current.current = value
			setBinding(value)
			if k >= 1 and connection ~= nil then
				connection:Disconnect()
			end
		end)
		return function()
			if connection ~= nil then
				connection:Disconnect()
			end
		end
	end, { target, reduced } :: { any })
	return binding
end

local function findWarden(): Model?
	local worldFolder = Workspace:FindFirstChild("AstralForgeWorld")
	local expanse = worldFolder and worldFolder:FindFirstChild("SanctuaryWorld")
	local model = expanse and expanse:FindFirstChild("RiftWarden")
	if model ~= nil and model:IsA("Model") then
		return model
	end
	return nil
end

type WardenInfo = { phase: string, endsAt: number, health: number, maxHealth: number, name: string }

local function readWarden(model: Model?): WardenInfo
	if model == nil then
		return { phase = "Unknown", endsAt = 0, health = 0, maxHealth = 1, name = BOSS.Name }
	end
	return {
		phase = tostring(model:GetAttribute("Phase") or "Dormant"),
		endsAt = tonumber(model:GetAttribute("EndsAt")) or 0,
		health = tonumber(model:GetAttribute("Health")) or 0,
		maxHealth = math.max(1, tonumber(model:GetAttribute("MaxHealth")) or 1),
		name = tostring(model:GetAttribute("BossName") or BOSS.Name),
	}
end

-- The Warden's replicated state, kept current from its attributes.
local function useWarden(): WardenInfo
	local info, setInfo = React.useState(function()
		return readWarden(findWarden())
	end)
	React.useEffect(function()
		local alive = true
		local model: Model? = nil
		local connection: RBXScriptConnection? = nil
		local function attach()
			if connection ~= nil then
				connection:Disconnect()
				connection = nil
			end
			model = findWarden()
			if model ~= nil then
				connection = model.AttributeChanged:Connect(function()
					setInfo(readWarden(model))
				end)
			end
			setInfo(readWarden(model))
		end
		attach()
		task.spawn(function()
			while alive do
				task.wait(1)
				if alive and (model == nil or model.Parent == nil) then
					attach()
				end
			end
		end)
		return function()
			alive = false
			if connection ~= nil then
				connection:Disconnect()
			end
		end
	end, {})
	return info
end

-- Server time, ticking a few times a second (for countdowns).
local function useServerClock(rate: number): number
	local now, setNow = React.useState(function()
		return Workspace:GetServerTimeNow()
	end)
	React.useEffect(function()
		local alive = true
		task.spawn(function()
			while alive do
				task.wait(rate)
				if alive then
					setNow(Workspace:GetServerTimeNow())
				end
			end
		end)
		return function()
			alive = false
		end
	end, { rate })
	return now
end

-- Is the local player close enough to the Warden to strike?
local function useInArena(): boolean
	local inArena, setInArena = React.useState(false)
	React.useEffect(function()
		local arena = Layout.arena()
		local origin = Layout.ORIGIN
		local center = Vector3.new(origin.X + arena.Center.X, 0, origin.Z + arena.Center.Z)
		local reach = BOSS.StrikeRange - 3
		local last = false
		local elapsed = 0
		local connection = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed < 0.2 then
				return
			end
			elapsed = 0
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local inside = false
			if root ~= nil and root:IsA("BasePart") then
				local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
				inside = (flat - center).Magnitude <= reach
			end
			if inside ~= last then
				last = inside
				setInArena(inside)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	return inArena
end

------------------------------------------------------------------------
-- Small pieces
------------------------------------------------------------------------

local function Panel(props)
	return e("frame", {
		Position = props.position,
		Size = props.size,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = props.color or PANEL,
		BackgroundTransparency = props.transparency or PANEL_ALPHA,
		BorderSizePixel = 0,
		ClipsDescendants = props.clip == true,
		Visible = props.visible ~= false,
		ZIndex = props.zIndex or 50,
	}, e("uicorner", {
		CornerRadius = UDim.new(0, props.radius or 10),
	}), e("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = props.strokeColor or Palette.white,
		Transparency = props.strokeTransparency or 0.86,
		Thickness = 1,
	}), props.children)
end

local function Label(props)
	return e("textlabel", {
		Position = props.position,
		Size = props.size or UDim2.fromScale(1, 1),
		AnchorPoint = props.anchorPoint,
		BackgroundTransparency = 1,
		Text = props.text,
		TextColor3 = props.color or Palette.cream,
		TextTransparency = props.transparency or 0,
		TextSize = props.textSize or 14,
		FontFace = props.font or FONT_MEDIUM,
		TextXAlignment = props.align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		RichText = false,
		AutoLocalize = true,
		ZIndex = props.zIndex or 51,
	})
end

-- Hover/press state for a button, and the Event handlers that drive it.
local function useButtonFeel()
	local hovered, setHovered = React.useState(false)
	local pressed, setPressed = React.useState(false)
	local events = {
		MouseEnter = function()
			setHovered(true)
		end,
		MouseLeave = function()
			setHovered(false)
			setPressed(false)
		end,
		SelectionGained = function()
			setHovered(true)
		end,
		SelectionLost = function()
			setHovered(false)
		end,
		InputBegan = function(_rbx, input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				setPressed(true)
			end
		end,
		InputEnded = function(_rbx, input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				setPressed(false)
			end
		end,
	}
	return hovered, pressed, events
end

local function IconButton(props)
	local hovered, pressed, events = useButtonFeel()
	local merged = table.clone(events)
	merged.Activated = function()
		Audio:play("click")
		props.onActivate()
	end
	local position, size = rectProps(props.rect)
	return e("textbutton", {
		Position = position,
		Size = size,
		BackgroundColor3 = if pressed then Palette.panelRaised else PANEL,
		BackgroundTransparency = if hovered then 0.06 else PANEL_ALPHA,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		ZIndex = 52,
		Event = merged,
	}, e("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), e("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Palette.white,
		Transparency = if hovered then 0.6 else 0.86,
		Thickness = 1,
	}), e(Icon, {
		kind = props.icon,
		size = math.floor(math.min(props.rect.w, props.rect.h) * 0.46),
		color = Palette.cream,
		spin = false,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	}), props.children)
end

------------------------------------------------------------------------
-- Region banner
------------------------------------------------------------------------

type BannerMessage = { key: number, eyebrow: string, title: string, line: string, accent: Color3 }

local function Banner(props)
	local plan = props.plan
	local message: BannerMessage? = props.message
	local shown = message ~= nil and props.visible
	local amount = useEase(if shown then 1 else 0, if shown then 0.45 else 0.6, props.reducedMotion)
	local last = React.useRef(message)
	if message ~= nil then
		last.current = message
	end
	local current: BannerMessage? = last.current
	if current == nil then
		return nil
	end
	local r = plan.banner
	local titleSize = plan.text.title
	return e("frame", {
		Position = amount:map(function(value)
			return UDim2.fromOffset(r.x, r.y + math.floor((1 - value) * 10))
		end),
		Size = UDim2.fromOffset(r.w, r.h),
		BackgroundTransparency = 1,
		Active = false,
		ZIndex = 50,
	}, e("textlabel", {
		Size = UDim2.new(1, 0, 0, plan.text.label + 4),
		BackgroundTransparency = 1,
		Text = string.upper(current.eyebrow),
		TextColor3 = current.accent,
		TextTransparency = amount:map(function(value)
			return 1 - value
		end),
		TextSize = plan.text.label,
		FontFace = FONT_BOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutoLocalize = true,
		ZIndex = 51,
	}), e("textlabel", {
		Position = UDim2.fromOffset(0, plan.text.label + 6),
		Size = UDim2.new(1, 0, 0, titleSize + 6),
		BackgroundTransparency = 1,
		Text = current.title,
		TextColor3 = Palette.cream,
		TextTransparency = amount:map(function(value)
			return 1 - value
		end),
		TextStrokeColor3 = Palette.void,
		TextStrokeTransparency = amount:map(function(value)
			return 1 - value * 0.55
		end),
		TextSize = titleSize,
		FontFace = FONT_HEAVY,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutoLocalize = true,
		ZIndex = 51,
	}), e("frame", {
		-- A hairline that draws outward from the centre.
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, plan.text.label + titleSize + 16),
		Size = amount:map(function(value)
			return UDim2.fromOffset(math.floor(r.w * 0.36 * value), 1)
		end),
		BackgroundColor3 = current.accent,
		BackgroundTransparency = amount:map(function(value)
			return 1 - value * 0.8
		end),
		BorderSizePixel = 0,
		ZIndex = 51,
	}), current.line ~= "" and e("textlabel", {
		Position = UDim2.fromOffset(0, plan.text.label + titleSize + 22),
		Size = UDim2.new(1, 0, 0, plan.text.body + 6),
		BackgroundTransparency = 1,
		Text = current.line,
		TextColor3 = Palette.creamSoft,
		TextTransparency = amount:map(function(value)
			return 1 - value * 0.9
		end),
		TextSize = plan.text.body,
		FontFace = FONT_MEDIUM,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutoLocalize = true,
		ZIndex = 51,
	}))
end

------------------------------------------------------------------------
-- Ore chips
------------------------------------------------------------------------

local function OreChip(props)
	local bump = useEase(props.bumpKey % 2, 0.18, props.reducedMotion)
	local chip = props.width
	local height = props.height
	local numberSize = props.plan.text.number
	return e("frame", {
		Size = UDim2.fromOffset(chip, height),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = PANEL_ALPHA,
		BorderSizePixel = 0,
		LayoutOrder = props.order,
		ZIndex = 50,
	}, e("uicorner", {
		CornerRadius = UDim.new(0, 9),
	}), e("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = props.color,
		Transparency = 0.7,
		Thickness = 1,
	}), e("frame", {
		-- The ore's colour: a small gem-cut square.
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(8, 8),
		Rotation = 45,
		BackgroundColor3 = props.color,
		BorderSizePixel = 0,
		ZIndex = 51,
	}), e("textlabel", {
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -30, 1, if props.compact then 0 else -math.floor(height * 0.36)),
		BackgroundTransparency = 1,
		Text = compact(props.amount),
		TextColor3 = bump:map(function(value)
			-- A brief brightening when the count changes.
			local pulse = math.sin(math.clamp(value, 0, 1) * math.pi)
			return Palette.cream:Lerp(props.color, pulse * 0.6)
		end),
		TextSize = numberSize,
		FontFace = FONT_BOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = if props.compact then Enum.TextYAlignment.Center else Enum.TextYAlignment.Bottom,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutoLocalize = false,
		ZIndex = 51,
	}), not props.compact and e("textlabel", {
		Position = UDim2.new(0, 24, 1, -math.floor(height * 0.4)),
		Size = UDim2.new(1, -30, 0, math.floor(height * 0.32)),
		BackgroundTransparency = 1,
		Text = props.name,
		TextColor3 = Palette.muted,
		TextSize = props.plan.text.label,
		FontFace = FONT_MEDIUM,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutoLocalize = true,
		ZIndex = 51,
	}))
end

local function OreChips(props)
	local plan = props.plan
	local balances = if type(props.ore) == "table" and type(props.ore.Balances) == "table" then props.ore.Balances else {}
	local counts = React.useRef({})
	local bumps = React.useRef({})
	local children = {
		Layout = e("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, math.max(4, math.floor(plan.gap * 0.6))),
		}),
	}
	for index, ore in SanctuaryConfig.Ore.Types do
		local amount = tonumber(balances[ore.Id]) or 0
		local previous = counts.current[ore.Id]
		if previous ~= nil and amount > previous then
			bumps.current[ore.Id] = (bumps.current[ore.Id] or 0) + 1
		end
		counts.current[ore.Id] = amount
		children[ore.Id] = e(OreChip, {
			order = index,
			name = ore.Name,
			amount = amount,
			color = ORE_COLORS[ore.Id],
			width = plan.oreChip,
			height = plan.ore.h,
			compact = plan.oreCompact,
			plan = plan,
			bumpKey = bumps.current[ore.Id] or 0,
			reducedMotion = props.reducedMotion,
		})
	end
	local position, size = rectProps(plan.ore)
	return e("frame", {
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		Active = false,
		ZIndex = 50,
	}, children)
end

------------------------------------------------------------------------
-- The Warden bar
------------------------------------------------------------------------

local function HealthTrack(props)
	-- The fill follows health quickly; a pale "chip" trails behind it so a
	-- hit reads as a bite taken out of the bar.
	local fraction = math.clamp(props.health / math.max(1, props.maxHealth), 0, 1)
	local fill = useEase(fraction, 0.25, props.reducedMotion)
	local chip = useEase(fraction, 1.1, props.reducedMotion)
	return e("frame", {
		Position = props.position,
		Size = props.size,
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 51,
	}, e("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), e("frame", {
		Size = chip:map(function(value)
			return UDim2.fromScale(math.clamp(value, 0, 1), 1)
		end),
		BackgroundColor3 = RIFT_SOFT,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 52,
	}, e("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), e("frame", {
		Size = fill:map(function(value)
			return UDim2.fromScale(math.clamp(value, 0, 1), 1)
		end),
		BackgroundColor3 = props.color or RIFT,
		BorderSizePixel = 0,
		ZIndex = 53,
	}, e("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), e("uigradient", {
		Color = ColorSequence.new(RIFT_SOFT, props.color or RIFT),
		Rotation = 90,
	})))
end

local function WardenBar(props)
	local plan = props.plan
	local warden: WardenInfo = props.warden
	local now = useServerClock(0.25)
	local phase = warden.phase
	if phase == "Unknown" then
		return nil
	end
	local r = plan.warden
	local position, size = rectProps(r)
	local left = math.max(10, math.floor(r.h * 0.26))
	local labelSize = plan.text.label
	local remaining = warden.endsAt - now
	local title: string
	local right: string
	local track = nil
	if phase == "Active" then
		title = string.upper(warden.name)
		right = if props.inArena then clock(remaining) else `Riftmaw · {clock(remaining)}`
		track = e(HealthTrack, {
			position = UDim2.new(0, left, 1, -left - 6),
			size = UDim2.new(1, -left * 2, 0, 6),
			health = warden.health,
			maxHealth = warden.maxHealth,
			reducedMotion = props.reducedMotion,
		})
	elseif phase == "Forming" then
		title = "THE WARDEN IS FORMING"
		right = clock(remaining)
		local progress = math.clamp(1 - remaining / BOSS.FormingSeconds, 0, 1)
		track = e(HealthTrack, {
			position = UDim2.new(0, left, 1, -left - 4),
			size = UDim2.new(1, -left * 2, 0, 3),
			health = progress,
			maxHealth = 1,
			color = RIFT_SOFT,
			reducedMotion = props.reducedMotion,
		})
	elseif phase == "Defeated" then
		title = "THE WARDEN FALLS"
		right = ""
	elseif phase == "Escaped" then
		title = "THE WARDEN ESCAPED"
		right = ""
	else
		title = "RIFT WARDEN"
		right = `returns in {clock(remaining)}`
	end
	local lively = phase == "Active" or phase == "Forming"
	return e(Panel, {
		position = position,
		size = size,
		radius = 10,
		strokeColor = if lively then RIFT else Palette.white,
		strokeTransparency = if lively then 0.5 else 0.86,
	}, e(Label, {
		position = UDim2.fromOffset(left, if track ~= nil then math.floor(r.h * 0.14) else 0),
		size = UDim2.new(0.62, -left, 0, if track ~= nil then labelSize + 8 else r.h),
		text = title,
		textSize = labelSize,
		font = FONT_BOLD,
		color = if lively then RIFT_SOFT else Palette.creamSoft,
	}), e(Label, {
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -left, 0, if track ~= nil then math.floor(r.h * 0.14) else 0),
		size = UDim2.new(0.38, 0, 0, if track ~= nil then labelSize + 8 else r.h),
		text = right,
		textSize = labelSize,
		font = FONT_MEDIUM,
		color = Palette.muted,
		align = Enum.TextXAlignment.Right,
	}), track)
end

------------------------------------------------------------------------
-- Strike and recall
------------------------------------------------------------------------

type Hit = { id: number, text: string, crit: boolean }

local function HitNumber(props)
	local rise = useEase(1, 0.8, false, 0)
	return e("textlabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = rise:map(function(value)
			return UDim2.new(0.5, props.offset, 0, -6 - math.floor(value * 46))
		end),
		Size = UDim2.fromOffset(140, 28),
		BackgroundTransparency = 1,
		Text = props.text,
		TextColor3 = if props.crit then Palette.mango else Palette.cream,
		TextTransparency = rise:map(function(value)
			return math.clamp((value - 0.55) / 0.45, 0, 1)
		end),
		TextStrokeColor3 = Palette.void,
		TextStrokeTransparency = rise:map(function(value)
			return 0.35 + 0.65 * math.clamp((value - 0.55) / 0.45, 0, 1)
		end),
		TextSize = if props.crit then 22 else 17,
		FontFace = FONT_HEAVY,
		AutoLocalize = false,
		ZIndex = 56,
	})
end

local function StrikeButton(props)
	local plan = props.plan
	local r = plan.strike
	local hovered, pressed, events = useButtonFeel()
	local dazed = props.dazedUntil > os.clock()
	local cooldown = props.cooldown
	local position, size = rectProps(r)
	local round = plan.touch
	local ready = not dazed
	local hits = {}
	for _, hit in props.hits do
		hits[`hit{hit.id}`] = e(HitNumber, {
			text = hit.text,
			crit = hit.crit,
			offset = ((hit.id * 37) % 60) - 30,
		})
	end
	return e("textbutton", {
		Position = position,
		Size = size,
		BackgroundColor3 = if dazed then Palette.panel elseif pressed then Color3.fromRGB(92, 64, 170) else Color3.fromRGB(40, 28, 78),
		BackgroundTransparency = if hovered and ready then 0.02 else 0.12,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		ClipsDescendants = false,
		ZIndex = 54,
		Event = {
			MouseEnter = events.MouseEnter,
			MouseLeave = function(rbx)
				events.MouseLeave(rbx)
				props.onHold(false)
			end,
			SelectionGained = events.SelectionGained,
			SelectionLost = events.SelectionLost,
			InputBegan = function(rbx, input)
				events.InputBegan(rbx, input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					props.onHold(true)
				end
			end,
			InputEnded = function(rbx, input)
				events.InputEnded(rbx, input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					props.onHold(false)
				end
			end,
			Activated = function()
				-- Gamepad "A" on a selected button; mouse/touch strike through onHold.
				if preferGamepad() then
					props.onStrike()
				end
			end,
		},
	}, e("uicorner", {
		CornerRadius = if round then UDim.new(1, 0) else UDim.new(0, 12),
	}), e("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = if dazed then Palette.lineSoft else RIFT_SOFT,
		Transparency = if hovered then 0.1 else 0.4,
		Thickness = 1.5,
	}), e("frame", {
		-- The recovery sweep: fills back up across the cooldown.
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = cooldown:map(function(value)
			return UDim2.fromScale(1, math.clamp(value, 0, 1))
		end),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = 55,
	}, e("uicorner", {
		CornerRadius = if round then UDim.new(1, 0) else UDim.new(0, 12),
	})), e("textlabel", {
		Size = if round then UDim2.fromScale(1, 1) else UDim2.new(1, -44, 1, 0),
		Position = if round then UDim2.fromScale(0, 0) else UDim2.fromOffset(16, 0),
		BackgroundTransparency = 1,
		Text = if dazed then "DAZED" else "STRIKE",
		TextColor3 = if dazed then Palette.muted else Palette.cream,
		TextSize = if round then math.clamp(math.floor(r.w * 0.2), 12, 18) else plan.text.body + 1,
		FontFace = FONT_HEAVY,
		TextXAlignment = if round then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
		AutoLocalize = true,
		ZIndex = 56,
	}), not round and e("frame", {
		-- Key cap.
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 56,
	}, e("uicorner", {
		CornerRadius = UDim.new(0, 6),
	}), e("uistroke", {
		Color = Palette.white,
		Transparency = 0.7,
		Thickness = 1,
	}), e(Label, {
		text = if preferGamepad() then "R2" else "F",
		textSize = 13,
		font = FONT_BOLD,
		align = Enum.TextXAlignment.Center,
		zIndex = 57,
	})), props.status ~= "" and e("textlabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -8),
		Size = UDim2.fromOffset(math.max(180, r.w), 20),
		BackgroundTransparency = 1,
		Text = props.status,
		TextColor3 = Palette.creamSoft,
		TextStrokeColor3 = Palette.void,
		TextStrokeTransparency = 0.4,
		TextSize = plan.text.label + 1,
		FontFace = FONT_BOLD,
		AutoLocalize = true,
		ZIndex = 56,
	}), hits)
end

local function RecallButton(props)
	local plan = props.plan
	local r = plan.recall
	local hovered, pressed, events = useButtonFeel()
	local position, size = rectProps(r)
	local square = plan.touch
	local cooling = props.cooling
	return e("textbutton", {
		Position = position,
		Size = size,
		BackgroundColor3 = if pressed then Palette.panelRaised else PANEL,
		BackgroundTransparency = if hovered then 0.06 else PANEL_ALPHA,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		ClipsDescendants = true,
		ZIndex = 52,
		Event = {
			MouseEnter = events.MouseEnter,
			MouseLeave = events.MouseLeave,
			SelectionGained = events.SelectionGained,
			SelectionLost = events.SelectionLost,
			InputBegan = events.InputBegan,
			InputEnded = events.InputEnded,
			Activated = function()
				Audio:play("click")
				props.onRecall()
			end,
		},
	}, e("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), e("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Palette.white,
		Transparency = if hovered then 0.6 else 0.86,
		Thickness = 1,
	}), e("frame", {
		-- Cooldown: drains left to right.
		Size = props.recharge:map(function(value)
			return UDim2.fromScale(math.clamp(value, 0, 1), 1)
		end),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = 52,
	}), e(Icon, {
		kind = "Back",
		size = math.floor(math.min(r.w, r.h) * 0.44),
		color = if cooling then Palette.muted else Palette.cream,
		spin = false,
		position = if square then UDim2.fromScale(0.5, 0.5) else UDim2.new(0, 12, 0.5, 0),
		anchorPoint = if square then Vector2.new(0.5, 0.5) else Vector2.new(0, 0.5),
	}), not square and e(Label, {
		position = UDim2.fromOffset(math.floor(r.h * 0.44) + 20, 0),
		size = UDim2.new(1, -(math.floor(r.h * 0.44) + 26), 1, 0),
		text = "Recall",
		textSize = plan.text.body,
		font = FONT_BOLD,
		color = if cooling then Palette.muted else Palette.cream,
		zIndex = 53,
	}))
end

------------------------------------------------------------------------
-- Sheets
------------------------------------------------------------------------

local function Sheet(props)
	local plan = props.plan
	local r = plan.sheet
	local shown = useEase(1, 0.22, props.reducedMotion, 0)
	local header = math.max(HudPlan.MIN_TAP, plan.sheetRow - 4)
	return e("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 60,
	}, e("textbutton", {
		-- The dim behind the sheet; a tap outside closes it.
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = shown:map(function(value)
			return 1 - value * 0.5
		end),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Selectable = false,
		ZIndex = 60,
		Event = {
			Activated = function()
				props.onClose()
			end,
		},
	}), e("frame", {
		Position = shown:map(function(value)
			return UDim2.fromOffset(r.x, r.y + math.floor((1 - value) * 14))
		end),
		Size = UDim2.fromOffset(r.w, r.h),
		BackgroundColor3 = Palette.night,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Active = true,
		ClipsDescendants = true,
		ZIndex = 61,
	}, e("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), e("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Palette.white,
		Transparency = 0.84,
		Thickness = 1,
	}), e(Label, {
		position = UDim2.fromOffset(18, 0),
		size = UDim2.new(1, -(header + 30), 0, header),
		text = props.title,
		textSize = plan.text.body + 3,
		font = FONT_HEAVY,
		zIndex = 62,
	}), props.subtitle ~= nil and e(Label, {
		position = UDim2.fromOffset(18, header - 10),
		size = UDim2.new(1, -36, 0, plan.text.label + 6),
		text = props.subtitle,
		textSize = plan.text.label,
		color = Palette.muted,
		zIndex = 62,
	}), e(IconButton, {
		rect = { x = r.w - header - 6, y = 6, w = header, h = header - 12 },
		icon = "Close",
		onActivate = props.onClose,
	}), e("frame", {
		Position = UDim2.fromOffset(0, header + (if props.subtitle ~= nil then plan.text.label + 2 else 0)),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = 62,
	}), e("scrollingframe", {
		Position = UDim2.fromOffset(0, header + 1 + (if props.subtitle ~= nil then plan.text.label + 2 else 0)),
		Size = UDim2.new(1, 0, 1, -(header + 1 + (if props.subtitle ~= nil then plan.text.label + 2 else 0))),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Palette.lineSoft,
		ScrollBarImageTransparency = 0.3,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		Selectable = false,
		ZIndex = 62,
	}, e("uipadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
	}), props.children)))
end

local function MenuTile(props)
	local hovered, pressed, events = useButtonFeel()
	return e("textbutton", {
		BackgroundColor3 = if pressed then Palette.panelRaised else Palette.panel,
		BackgroundTransparency = if hovered then 0 else 0.2,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		LayoutOrder = props.order,
		ZIndex = 63,
		ref = props.buttonRef,
		Event = {
			MouseEnter = events.MouseEnter,
			MouseLeave = events.MouseLeave,
			SelectionGained = events.SelectionGained,
			SelectionLost = events.SelectionLost,
			InputBegan = events.InputBegan,
			InputEnded = events.InputEnded,
			Activated = function()
				Audio:play("click")
				props.onActivate()
			end,
		},
	}, e("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), e("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = if hovered then Palette.cyan else Palette.white,
		Transparency = if hovered then 0.4 else 0.88,
		Thickness = 1,
	}), e(Icon, {
		kind = props.icon,
		size = math.floor(props.cell * 0.3),
		color = Palette.cream,
		spin = false,
		position = UDim2.new(0.5, 0, 0.42, 0),
		anchorPoint = Vector2.new(0.5, 0.5),
	}), e(Label, {
		position = UDim2.new(0, 4, 1, -24),
		size = UDim2.new(1, -8, 0, 18),
		text = props.label,
		textSize = 13,
		font = FONT_BOLD,
		color = Palette.creamSoft,
		align = Enum.TextXAlignment.Center,
		zIndex = 64,
	}))
end

local function MenuSheet(props)
	local plan = props.plan
	local columns = plan.sheetColumns
	local inner = plan.sheet.w - 28
	local pad = 10
	local cell = math.floor((inner - pad * (columns - 1)) / columns)
	local cellH = math.max(HudPlan.MIN_TAP + 20, math.floor(cell * 0.78))
	local firstRef = React.useRef(nil)
	React.useEffect(function()
		if preferGamepad() and firstRef.current ~= nil then
			GuiService.SelectedObject = firstRef.current
		end
		return nil
	end, {})
	local tiles = {
		Grid = e("uigridlayout", {
			CellSize = UDim2.fromOffset(cell, cellH),
			CellPadding = UDim2.fromOffset(pad, pad),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, entry in props.entries do
		tiles[entry.key] = e(MenuTile, {
			order = index,
			icon = entry.icon,
			label = entry.label,
			cell = math.min(cell, cellH),
			buttonRef = if index == 1 then firstRef else nil,
			onActivate = function()
				props.onClose()
				props.onNavigate(entry.pageId)
			end,
		})
	end
	return e(Sheet, {
		plan = plan,
		title = "Leave the sanctuary",
		subtitle = "Pick where to go",
		reducedMotion = props.reducedMotion,
		onClose = props.onClose,
	}, tiles)
end

local function WaystoneRow(props)
	local plan = props.plan
	local hovered, pressed, events = useButtonFeel()
	local here = props.here
	return e("textbutton", {
		Size = UDim2.new(1, 0, 0, plan.sheetRow),
		BackgroundColor3 = if pressed then Palette.panelRaised else Palette.panel,
		BackgroundTransparency = if here then 0.5 elseif hovered then 0 else 0.2,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Selectable = not here,
		Active = not here,
		LayoutOrder = props.order,
		ZIndex = 63,
		ref = props.buttonRef,
		Event = {
			MouseEnter = events.MouseEnter,
			MouseLeave = events.MouseLeave,
			SelectionGained = events.SelectionGained,
			SelectionLost = events.SelectionLost,
			InputBegan = events.InputBegan,
			InputEnded = events.InputEnded,
			Activated = function()
				if not here then
					Audio:play("click")
					props.onTravel()
				end
			end,
		},
	}, e("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), e("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = if hovered and not here then props.accent else Palette.white,
		Transparency = if hovered and not here then 0.35 else 0.88,
		Thickness = 1,
	}), e("frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		Rotation = 45,
		BackgroundColor3 = props.accent,
		BorderSizePixel = 0,
		ZIndex = 64,
	}), e(Label, {
		position = UDim2.new(0, 38, 0, 0),
		size = UDim2.new(1, -120, 0.58, 0),
		text = props.name,
		textSize = plan.text.body + 1,
		font = FONT_BOLD,
		color = if here then Palette.muted else Palette.cream,
		zIndex = 64,
	}), e(Label, {
		position = UDim2.new(0, 38, 0.5, 0),
		size = UDim2.new(1, -120, 0.42, 0),
		text = props.line,
		textSize = plan.text.label,
		color = Palette.muted,
		zIndex = 64,
	}), e(Label, {
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -16, 0, 0),
		size = UDim2.new(0, 90, 1, 0),
		text = if here then "You are here" else props.status,
		textSize = plan.text.label,
		font = FONT_BOLD,
		color = if here then Palette.muted else props.accent,
		align = Enum.TextXAlignment.Right,
		zIndex = 64,
	}))
end

local function WaystoneSheet(props)
	local plan = props.plan
	local firstRef = React.useRef(nil)
	local pending, setPending = React.useState(nil)
	local problem, setProblem = React.useState("")
	React.useEffect(function()
		if preferGamepad() and firstRef.current ~= nil then
			GuiService.SelectedObject = firstRef.current
		end
		return nil
	end, {})
	local rows = {
		Layout = e("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	}
	local firstAssigned = false
	for index, stone in Layout.waystones() do
		local region = Layout.region(stone.Region)
		local oreId = region and region.Ore
		local accent = if oreId ~= nil then ORE_COLORS[oreId] elseif stone.Id == "Riftmaw" then RIFT else Palette.mango
		local here = stone.Id == props.from
		local useRef = not here and not firstAssigned
		if useRef then
			firstAssigned = true
		end
		rows[stone.Id] = e(WaystoneRow, {
			order = index,
			plan = plan,
			name = stone.Name,
			line = REGION_LINES[stone.Id] or "",
			accent = accent,
			here = here,
			status = if pending == stone.Id then "Opening…" else "Travel",
			buttonRef = if useRef then firstRef else nil,
			onTravel = function()
				if pending ~= nil then
					return
				end
				setPending(stone.Id)
				setProblem("")
				props.dispatch("TravelWaystone", { To = stone.Id }, function(response)
					setPending(nil)
					if type(response) == "table" and response.ok == true then
						props.onClose()
					elseif type(response) == "table" and type(response.error) == "string" then
						setProblem(response.error)
					end
				end)
			end,
		})
	end
	if problem ~= "" then
		rows.Problem = e(Label, {
			size = UDim2.new(1, 0, 0, 22),
			text = problem,
			textSize = plan.text.label + 1,
			color = Palette.coral,
			zIndex = 64,
		})
	end
	return e(Sheet, {
		plan = plan,
		title = "Waystones",
		subtitle = "Step through to any region",
		reducedMotion = props.reducedMotion,
		onClose = props.onClose,
	}, rows)
end

------------------------------------------------------------------------
-- Key hint (mouse and keyboard)
------------------------------------------------------------------------

local function KeyHint(props)
	local plan = props.plan
	local r = plan.hint
	if r == nil then
		return nil
	end
	local position, size = rectProps(r)
	return e(Label, {
		position = position,
		size = size,
		text = props.text,
		textSize = plan.text.label,
		color = Palette.muted,
		align = Enum.TextXAlignment.Right,
		zIndex = 50,
	})
end

------------------------------------------------------------------------
-- The HUD
------------------------------------------------------------------------

local function SanctuaryHud(props)
	local plan = props.plan
	local reduced = props.reducedMotion == true
	local warden = useWarden()
	local inArena = useInArena()
	local banner, setBanner = React.useState(nil :: BannerMessage?)
	local bannerVisible, setBannerVisible = React.useState(false)
	local bannerSeq = React.useRef(0)
	local region, setRegion = React.useState("Heart")
	local sheet, setSheet = React.useState(nil :: string?)
	local sheetFrom, setSheetFrom = React.useState("Heart")
	local hits, setHits = React.useState({} :: { Hit })
	local hitSeq = React.useRef(0)
	local status, setStatus = React.useState("")
	local statusSeq = React.useRef(0)
	local dazedUntil, setDazedUntil = React.useState(0)
	local lastStrike = React.useRef(0)
	local striking = React.useRef(false)
	local holding = React.useRef(false)
	local recallAt, setRecallAt = React.useState(-math.huge)
	local cooldown, setCooldown = React.useBinding(0)
	local recharge, setRecharge = React.useBinding(0)
	local lastDefeat = React.useRef(0)

	local canStrike = warden.phase == "Active" and inArena

	local function showBanner(eyebrow: string, title: string, line: string, accent: Color3, seconds: number?)
		bannerSeq.current += 1
		local seq = bannerSeq.current
		setBanner({ key = seq, eyebrow = eyebrow, title = title, line = line, accent = accent })
		setBannerVisible(true)
		task.delay(seconds or BANNER_SECONDS, function()
			if bannerSeq.current == seq then
				setBannerVisible(false)
			end
		end)
	end

	local function flashStatus(text: string)
		statusSeq.current += 1
		local seq = statusSeq.current
		setStatus(text)
		task.delay(1.4, function()
			if statusSeq.current == seq then
				setStatus("")
			end
		end)
	end

	local function pushHit(damage: number, crit: boolean)
		hitSeq.current += 1
		local id = hitSeq.current
		setHits(function(current)
			local nextHits = table.clone(current)
			table.insert(nextHits, { id = id, text = if crit then `CRIT {compact(damage)}` else compact(damage), crit = crit })
			while #nextHits > 6 do
				table.remove(nextHits, 1)
			end
			return nextHits
		end)
		task.delay(0.85, function()
			setHits(function(current)
				local kept = {}
				for _, hit in current do
					if hit.id ~= id then
						table.insert(kept, hit)
					end
				end
				return kept
			end)
		end)
	end

	-- One strike attempt, if the cooldown and the Warden allow it.
	local strikeRef = React.useRef(nil :: (() -> ())?)
	local function strike()
		if not canStrike or striking.current then
			return
		end
		local now = os.clock()
		if now < dazedUntil or now - lastStrike.current < STRIKE_COOLDOWN then
			return
		end
		lastStrike.current = now
		striking.current = true
		props.dispatch("StrikeRiftBoss", {}, function(response)
			striking.current = false
			if type(response) ~= "table" then
				return
			end
			if response.ok == true then
				local damage = tonumber(response.Damage) or 0
				local crit = response.Crit == true
				Audio:play(if crit then "wardenCrit" else "wardenStrike")
				pushHit(damage, crit)
				Signals.fire("StrikeLanded", { Damage = damage, Crit = crit })
				if crit then
					Controls.shake(0.35)
				end
			elseif type(response.error) == "string" then
				local lowered = string.lower(response.error)
				if string.find(lowered, "working", 1, true) == nil and string.find(lowered, "too fast", 1, true) == nil and string.find(lowered, "busy", 1, true) == nil then
					flashStatus(response.error)
				end
			end
		end)
	end
	strikeRef.current = strike

	-- Cooldown sweeps for strike and recall, driven while they matter.
	React.useEffect(function()
		local connection = RunService.RenderStepped:Connect(function()
			local now = os.clock()
			local strikeLeft = math.max(0, STRIKE_COOLDOWN - (now - lastStrike.current))
			local dazeLeft = math.max(0, dazedUntil - now)
			if dazeLeft > 0 then
				setCooldown(dazeLeft / BOSS.DazeSeconds)
			else
				setCooldown(strikeLeft / STRIKE_COOLDOWN)
			end
			setRecharge(math.clamp(1 - (now - recallAt) / RECALL_COOLDOWN, 0, 1))
			-- Held button or key: keep striking at the cooldown.
			if holding.current and strikeRef.current ~= nil then
				strikeRef.current()
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { dazedUntil, recallAt } :: { any })

	-- Keys: F / R2 strike (hold to keep striking), Esc / B closes a sheet.
	React.useEffect(function()
		local began = UserInputService.InputBegan:Connect(function(input, processed)
			if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
				if sheet ~= nil then
					setSheet(nil)
				end
				return
			end
			if processed or sheet ~= nil then
				return
			end
			if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2 then
				holding.current = true
				if strikeRef.current ~= nil then
					strikeRef.current()
				end
			end
		end)
		local ended = UserInputService.InputEnded:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2 then
				holding.current = false
			end
		end)
		return function()
			began:Disconnect()
			ended:Disconnect()
			holding.current = false
		end
	end, { sheet })

	-- Movement pauses while a sheet is open.
	React.useEffect(function()
		Controls.setEnabled(sheet == nil)
		return function()
			Controls.setEnabled(true)
		end
	end, { sheet })

	-- Sanctuary events.
	React.useEffect(function()
		local unsubscribe = {
			Signals.on("RegionChanged", function(payload)
				if type(payload) ~= "table" or type(payload.Id) ~= "string" then
					return
				end
				setRegion(payload.Id)
				if payload.Id == "Bridge" then
					return
				end
				local layoutRegion = Layout.region(payload.Id)
				local oreId = layoutRegion and layoutRegion.Ore
				local accent = if oreId ~= nil then ORE_COLORS[oreId] elseif payload.Id == "Riftmaw" then RIFT else Palette.mango
				showBanner(if payload.Id == "Heart" then "The sanctuary" else "Entering", tostring(payload.Name), REGION_LINES[payload.Id] or "", accent)
			end),
			Signals.on("WaystoneOpen", function(payload)
				setSheetFrom(if type(payload) == "table" and type(payload.From) == "string" then payload.From else "Heart")
				setSheet("waystones")
			end),
			Signals.on("RiftBossAwake", function()
				showBanner("The rift opens", "The Rift Warden has woken", "Strike it in the Riftmaw", RIFT, 3.4)
			end),
			Signals.on("RiftBossStagger", function(payload)
				local seconds = if type(payload) == "table" then tonumber(payload.Daze) or BOSS.DazeSeconds else BOSS.DazeSeconds
				setDazedUntil(os.clock() + seconds)
			end),
			Signals.on("RiftBossDefeated", function(payload)
				lastDefeat.current = os.clock()
				local share = if type(payload) == "table" then tonumber(payload.Share) or 0 else 0
				showBanner("Victory", "The Rift Warden falls", `Your share of the fight: {math.floor(share * 100 + 0.5)}%`, Palette.mango, 4)
			end),
			Signals.on("RiftBossFell", function()
				task.delay(0.6, function()
					if os.clock() - lastDefeat.current > 2 then
						showBanner("The rift closes", "The Rift Warden falls", "Strike it next time to share the spoils", RIFT, 3.4)
					end
				end)
			end),
		}
		return function()
			for _, stop in unsubscribe do
				stop()
			end
		end
	end, {})

	-- Stop holding when the Warden can't be struck.
	React.useEffect(function()
		if not canStrike then
			holding.current = false
		end
		return nil
	end, { canStrike })

	local function recall()
		local now = os.clock()
		if now - recallAt < RECALL_COOLDOWN then
			return
		end
		setRecallAt(now)
		props.dispatch("TravelWaystone", { Recall = true }, function(response)
			if type(response) == "table" and response.ok ~= true then
				-- Refused (already home, or cooling on the server): free the button.
				setRecallAt(-math.huge)
			end
		end)
	end

	local hintText = if canStrike
		then "F to strike · Shift to run · Right-drag to look"
		elseif region == "Emberreach" or region == "Hollows" or region == "Spire"
		then "Hold E at a glowing outcrop to mine"
		else "WASD to move · Shift to run · Right-drag to look"

	return e("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,
		ZIndex = 50,
	}, e(Banner, {
		plan = plan,
		message = banner,
		visible = bannerVisible,
		reducedMotion = reduced,
	}), e(OreChips, {
		plan = plan,
		ore = props.ore,
		reducedMotion = reduced,
	}), e(WardenBar, {
		plan = plan,
		warden = warden,
		inArena = inArena,
		reducedMotion = reduced,
	}), plan.menuButton ~= nil and e(IconButton, {
		rect = plan.menuButton,
		icon = "Menu",
		onActivate = function()
			setSheet("menu")
		end,
	}), e(RecallButton, {
		plan = plan,
		cooling = os.clock() - recallAt < RECALL_COOLDOWN,
		recharge = recharge,
		onRecall = recall,
	}), canStrike and e(StrikeButton, {
		plan = plan,
		cooldown = cooldown,
		dazedUntil = dazedUntil,
		hits = hits,
		status = status,
		onStrike = strike,
		onHold = function(held: boolean)
			holding.current = held
			if held then
				strike()
			end
		end,
	}), not plan.touch and e(KeyHint, {
		plan = plan,
		text = hintText,
	}), sheet == "menu" and e(MenuSheet, {
		plan = plan,
		entries = props.entries,
		reducedMotion = reduced,
		onNavigate = props.onNavigate,
		onClose = function()
			setSheet(nil)
		end,
	}), sheet == "waystones" and e(WaystoneSheet, {
		plan = plan,
		from = sheetFrom,
		dispatch = props.dispatch,
		reducedMotion = reduced,
		onClose = function()
			setSheet(nil)
		end,
	}))
end

return {
	SanctuaryHud = SanctuaryHud,
	REGION_LINES = REGION_LINES,
}
