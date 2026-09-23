local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientLog = require(script.Parent.log).ClientLog
local _theme = require(script.Parent.theme)
local darken = _theme.darken
local lighten = _theme.lighten
local Palette = _theme.Palette
-- Bridges the vendor HyperText Luau module (ReplicatedStorage.AstralForge.Vendor.HyperText) into
-- React-Lua for player titles. HyperText renders real per-character Instances driven by its own
-- markup tags (<anim=wiggle>, <shake>, <rainbow>, <emitImg>, ...), giving actual positional motion
-- and particle effects instead of the color/stroke-only tricks the previous title renderer used.
-- Follows the same load-with-retry-and-fallback pattern as RichTextHost.tsx/NumberSpinnerHost.tsx:
-- the module is fetched once, cached, and any load failure degrades to a plain static textlabel
-- instead of leaving a title blank.
local TITLE_FX_KINDS = { "wave", "fire", "ice", "glitch", "galaxy", "rainbow", "glow", "neon", "sparkle", "shake", "pulse", "gradient-shift", "holographic", "void", "plasma", "chrome", "ember", "frost", "aurora", "matrix", "static", "bounce-in", "blur-resolve", "shimmer", "toxic", "solar", "ocean", "candy", "voltage", "prism", "phantom" }
local _set = {}
for _, _v in TITLE_FX_KINDS do
	_set[_v] = true
end
local FX_SET = _set
local function parseFx(fx)
	if fx == nil or fx == "" then
		return nil
	end
	local key = string.lower(fx)
	return if FX_SET[key] ~= nil then key else nil
end
-- One accent per kind, used for the reduced-motion/failed-load fallback text and anywhere else
-- in the UI that just needs "the color for this title" (badges, plates) without a live render.
local FX_ACCENT = {
	wave = Palette.cyan,
	fire = Palette.mango,
	ice = Palette.cyan,
	glitch = Palette.pink,
	galaxy = Palette.violet,
	rainbow = Color3.fromRGB(255, 170, 60),
	glow = lighten(Palette.cream, 0.1),
	neon = Palette.mint,
	sparkle = Palette.mango,
	shake = Palette.coral,
	pulse = Palette.violet,
	["gradient-shift"] = Palette.blue,
	holographic = Palette.cyan,
	void = Palette.violet,
	plasma = Palette.pink,
	chrome = Palette.creamSoft,
	ember = Palette.coral,
	frost = Color3.fromRGB(180, 220, 255),
	aurora = Palette.mint,
	matrix = Palette.green,
	static = Palette.cream,
	["bounce-in"] = Palette.mango,
	["blur-resolve"] = Palette.cream,
	shimmer = Palette.creamSoft,
	toxic = Color3.fromRGB(120, 255, 40),
	solar = Palette.mango,
	ocean = Palette.blue,
	candy = Palette.pink,
	voltage = Palette.cyan,
	prism = Palette.pink,
	phantom = Palette.violet,
}
local function titleFxAccent(fx)
	local kind = parseFx(fx)
	return if kind ~= nil then FX_ACCENT[kind] else Palette.creamSoft
end
local function darkTitlePlate(fx)
	return darken(titleFxAccent(fx), 0.82)
end
local function colorTag(color)
	return `{math.round(color.R * 255)},{math.round(color.G * 255)},{math.round(color.B * 255)}`
end
local function safeText(value)
	local cleaned = (string.gsub(value, "<", "("))
	cleaned = (string.gsub(cleaned, ">", ")"))
	return cleaned
end
-- Per-character reveal stagger applied uniformly on top of every kind below. `interval` is the
-- one HyperText primitive none of the 30 kinds touch internally, so wrapping it around the whole
-- body can never collide with (shadow/override) a kind's own <anim>/<trans> stack — those tags
-- override same-type ancestors when nested, so anything kind-specific has to stay the innermost
-- layer of its own type. The result: titles no longer pop in as a static block and then loop —
-- each character cascades in on its own beat and is already animating (color/shake/particles/
-- gradient, whatever the kind does) from the instant it appears.
local REVEAL_STAGGER = 0.045
-- Each kind is a unique combination of HyperText motion (wiggle / bounce / slide / grow /
-- shake), color treatment (solid, gradient, rainbow, stroke, shadow, mark), and overlay
-- (shiny, fog, decode, transparency tween). Shared "recolor of the same wiggle" setups are
-- banned — NumberRange attrs must be min,max (so rising sparks use velY=-1.2,-.6 not -.6,-1.2).
local function buildKindMarkup(kind, body)
	local accent = FX_ACCENT[kind]
	repeat
		if kind == "wave" then
			return `<anim=wiggle freq=1.05 amp=.38 offset=.18 rot=true loop=true><color={colorTag(Palette.cyan)}>{body}</color></anim>`
		end
		if kind == "ocean" then
			return `<anim=bounce dir=down offset=.22 exp=1.15 loop=true><fog=true color={colorTag(Palette.blue)} rate=.45 chance=40 lifetime=.8,1.4 startSize=.5,.8 endSize=.1,.2 velY=-.15,.2 startTrans=.4,.6 endTrans=1,1><gradient=true colors={colorTag(Palette.blue)};{colorTag(Palette.cyan)};{colorTag(Color3.fromRGB(20, 70, 140))} individual=false moveDir=left moveSpeed=.18 rot=12>{body}</gradient></fog></anim>`
		end
		if kind == "aurora" then
			return `<trans=.08 tweenDur=1.6 tweenFrom=.28 loopTween=true><gradient=true colors={colorTag(Palette.mint)};{colorTag(Palette.cyan)};{colorTag(Palette.violet)};{colorTag(Palette.pink)} individual=false moveDir=right moveSpeed=.22 spacing=.15>{body}</gradient></trans>`
		end
		if kind == "fire" then
			return `<anim=bounce dir=up offset=.2 exp=1.8 loop=true><shiny=true color={colorTag(Color3.fromRGB(255, 190, 70))} rate=.85 chance=55 lifetime=.35,.7 startSize=.28,.42 endSize=0,0 velY=-1.2,-.7 startPosY=.15,.45 rotVel=-40,40><gradient=true colors={colorTag(Color3.fromRGB(255, 70, 16))};{colorTag(Palette.mango)};{colorTag(Color3.fromRGB(255, 230, 110))} individual=true moveDir=right moveSpeed=.4>{body}</gradient></shiny></anim>`
		end
		if kind == "ember" then
			return `<shake=true maxOffset=.012 maxRot=1.2 loop=true freq=3 dur=0><shiny=true color={colorTag(Color3.fromRGB(255, 110, 40))} rate=.35 chance=40 lifetime=.7,1.3 startSize=.18,.28 endSize=0,0 velY=.2,.65 startPosY=-.25,.05 accelY=.15,.4><color={colorTag(Color3.fromRGB(210, 55, 18))}>{body}</color></shiny></shake>`
		end
		if kind == "solar" then
			return `<anim=grow startScale=.86 exp=1.4 loop=true><shiny=true color={colorTag(Color3.fromRGB(255, 240, 160))} rate=.5 chance=30 lifetime=.5,.9 startSize=.35,.5 endSize=.05,.1 velY=-.35,.35 velX=-.4,.4 startPosY=-.15,.15><gradient=true colors={colorTag(Color3.fromRGB(255, 210, 70))};{colorTag(Color3.fromRGB(255, 255, 210))};{colorTag(Palette.mango)} individual=false moveDir=right moveSpeed=.55 rot=90>{body}</gradient></shiny></anim>`
		end
		if kind == "ice" then
			return `<anim=slide dir=down offset=.16 rot=-6 loop=true><stroke=true color={colorTag(Palette.white)} thickness=.055><color={colorTag(Color3.fromRGB(150, 220, 255))}>{body}</color></stroke></anim>`
		end
		if kind == "frost" then
			return `<fog=true color={colorTag(Color3.fromRGB(210, 235, 255))} rate=.3 chance=50 lifetime=1,1.6 startSize=.4,.7 endSize=.15,.25 velY=-.08,.12 startTrans=.35,.55 endTrans=1,1><shiny=true color={colorTag(Palette.white)} rate=.18 chance=22 lifetime=.8,1.3 startSize=.12,.2 endSize=0,0 velY=-.12,.2><stroke=true color={colorTag(Color3.fromRGB(230, 245, 255))} thickness=.03 trans=.25><color={colorTag(Color3.fromRGB(180, 220, 255))}>{body}</color></stroke></shiny></fog>`
		end
		if kind == "glitch" then
			return `<decode=true dur=.16 freq=8 loop=true><shake=true maxOffset=.06 maxRot=3 loop=true freq=7 dur=0><color={colorTag(Palette.pink)}><strike=true>{body}</strike></color></shake></decode>`
		end
		if kind == "static" then
			return `<decode=true dur=.08 freq=14 loop=true><color={colorTag(Palette.cream)}>{body}</color></decode>`
		end
		if kind == "voltage" then
			return `<shake=true maxOffset=.03 maxRot=5 loop=true freq=12 dur=0><stroke=true color={colorTag(Palette.white)} thickness=.035><strokeGradient=true colors={colorTag(Palette.cyan)};{colorTag(Palette.white)};{colorTag(Palette.blue)} moveDir=right moveSpeed=1.1 individual=false><color={colorTag(Palette.cyan)}>{body}</color></strokeGradient></stroke></shake>`
		end
		if kind == "shake" then
			return `<shake=true maxOffset=.07 maxRot=8 loop=true freq=9 dur=0 fade=false><color={colorTag(Palette.coral)}>{body}</color></shake>`
		end
		if kind == "galaxy" then
			return `<anim=wiggle freq=.35 amp=.14 offset=.28 rot=false loop=true><shadow=true color={colorTag(Color3.fromRGB(20, 8, 40))} offset=0,.28 trans=.35><rainbow=true freq=.12 offset=.22>{body}</rainbow></shadow></anim>`
		end
		if kind == "prism" then
			return `<stroke=true color={colorTag(Palette.white)} thickness=.04><strokeGradient=true colors={colorTag(Palette.pink)};{colorTag(Palette.cyan)};{colorTag(Palette.mango)};{colorTag(Palette.violet)} individual=true moveDir=right moveSpeed=.8><rainbow=true freq=.55 offset=.08>{body}</rainbow></strokeGradient></stroke>`
		end
		if kind == "holographic" then
			return `<italic=true><trans=.1 tweenDur=.9 tweenFrom=.32 loopTween=true><gradient=true colors={colorTag(Palette.cyan)};{colorTag(Palette.pink)};{colorTag(Palette.mint)};{colorTag(Palette.white)} individual=true moveDir=left moveSpeed=.95>{body}</gradient></trans></italic>`
		end
		if kind == "gradient-shift" then
			return `<stroke=true color={colorTag(Palette.white)} thickness=.03 trans=.55><gradient=true colors={colorTag(Palette.blue)};{colorTag(Palette.violet)};{colorTag(Palette.pink)};{colorTag(Palette.cyan)} individual=false moveDir=right moveSpeed=.38 spacing=.08>{body}</gradient></stroke>`
		end
		if kind == "candy" then
			return `<anim=bounce dir=up offset=.48 exp=2.1 loop=true><gradient=true colors={colorTag(Palette.pink)};{colorTag(Palette.cream)};{colorTag(Palette.violet)};{colorTag(Palette.mint)} individual=true moveDir=right moveSpeed=.28>{body}</gradient></anim>`
		end
		if kind == "rainbow" then
			return `<stroke=true color={colorTag(Palette.white)} thickness=.03 trans=.6><rainbow=true freq=.7 offset=.16>{body}</rainbow></stroke>`
		end
		if kind == "toxic" then
			return `<fog=true color={colorTag(Color3.fromRGB(90, 255, 40))} rate=.55 chance=45 lifetime=.6,1.1 startSize=.3,.5 endSize=.05,.12 velY=.25,.75 startPosY=-.2,.1 startTrans=.2,.4 endTrans=1,1><shake=true maxOffset=.018 maxRot=.8 loop=true freq=4 dur=0><color={colorTag(Color3.fromRGB(120, 255, 40))}>{body}</color></shake></fog>`
		end
		if kind == "matrix" then
			return `<italic=true><decode=true dur=.28 freq=4 loop=true><color={colorTag(Palette.green)}>{body}</color></decode></italic>`
		end
		if kind == "glow" then
			return `<trans=.04 tweenDur=1.1 tweenFrom=.3 loopTween=true><stroke=true color={colorTag(Color3.fromRGB(255, 236, 190))} thickness=.07 trans=.15><color={colorTag(Color3.fromRGB(255, 244, 210))}>{body}</color></stroke></trans>`
		end
		if kind == "neon" then
			return `<mark=true color={colorTag(Color3.fromRGB(8, 28, 22))} trans=.72><stroke=true color={colorTag(Palette.mint)} thickness=.06><strokeGradient=true colors={colorTag(Palette.mint)};{colorTag(Palette.white)};{colorTag(Palette.cyan)} individual=false moveDir=right moveSpeed=.7><color={colorTag(Palette.mint)}>{body}</color></strokeGradient></stroke></mark>`
		end
		if kind == "sparkle" then
			return `<anim=bounce dir=up offset=.12 exp=1.2 loop=true><shiny=true color={colorTag(Palette.white)} rate=.9 chance=60 lifetime=.4,.75 startSize=.2,.34 endSize=0,0 velY=-.9,-.4 velX=-.5,.5 startPosY=-.2,.2 rotVel=-80,80><color={colorTag(Palette.mango)}>{body}</color></shiny></anim>`
		end
		if kind == "shimmer" then
			return `<trans=.06 tweenDur=1.4 tweenFrom=.22 loopTween=true><gradient=true colors={colorTag(Palette.creamSoft)};{colorTag(Palette.white)};{colorTag(Palette.cream)};{colorTag(Palette.creamSoft)} individual=false moveDir=right moveSpeed=.62 rot=18>{body}</gradient></trans>`
		end
		if kind == "pulse" then
			return `<anim=grow startScale=.78 exp=1.15 loop=true><trans=.05 tweenDur=.9 tweenFrom=.4 loopTween=true><stroke=true color={colorTag(lighten(Palette.violet, 0.3))} thickness=.05><color={colorTag(Palette.violet)}>{body}</color></stroke></trans></anim>`
		end
		if kind == "void" then
			return `<anim=wiggle freq=.28 amp=.2 offset=.32 rot=true loop=true><shadow=true color={colorTag(Color3.fromRGB(8, 0, 16))} offset=.08,.4 trans=.2><stroke=true color={colorTag(Color3.fromRGB(18, 6, 28))} thickness=.08><trans=.12 tweenDur=2 tweenFrom=.45 loopTween=true><color={colorTag(Palette.violet)}>{body}</color></trans></stroke></shadow></anim>`
		end
		if kind == "plasma" then
			return `<shake=true maxOffset=.028 maxRot=2.5 loop=true freq=8 dur=0><shiny=true color={colorTag(Palette.pink)} rate=.7 chance=40 lifetime=.3,.55 startSize=.22,.36 endSize=0,0 velX=-.8,.8 velY=-.5,.5><gradient=true colors={colorTag(Palette.pink)};{colorTag(Palette.violet)};{colorTag(Palette.coral)};{colorTag(Palette.cyan)} individual=true moveDir=right moveSpeed=1.05>{body}</gradient></shiny></shake>`
		end
		if kind == "chrome" then
			return `<shadow=true color={colorTag(Color3.fromRGB(40, 44, 52))} offset=.06,.22 trans=.45><gradient=true colors={colorTag(Palette.muted)};{colorTag(Palette.creamSoft)};{colorTag(Palette.white)};{colorTag(Palette.creamSoft)};{colorTag(Color3.fromRGB(90, 96, 108))} individual=false moveDir=right moveSpeed=.48 rot=90>{body}</gradient></shadow>`
		end
		if kind == "phantom" then
			return `<italic=true><anim=slide dir=up offset=.2 rot=4 loop=true><trans=.18 tweenDur=1.3 tweenFrom=.62 loopTween=true><color={colorTag(Palette.violet)}>{body}</color></trans></anim></italic>`
		end
		if kind == "bounce-in" then
			return `<anim=bounce dir=up offset=.7 exp=1.55><color={colorTag(Palette.mango)}>{body}</color></anim>`
		end
		if kind == "blur-resolve" then
			return `<anim=grow startScale=.4 exp=2.6><decode=true dur=.22 freq=7 loop=false><color={colorTag(Palette.cream)}>{body}</color></decode></anim>`
		end
		return `<color={colorTag(accent)}>{body}</color>`
	until true
end
local function buildMarkup(kind, text, preview)
	local body = safeText(text)
	if preview then
		local accent = FX_ACCENT[kind] or Palette.cream
		-- Visible motion without per-card particle emitters. Full kinds stay on the equipped title.
		return `<interval={REVEAL_STAGGER}><anim=wiggle freq=.7 amp=.22 offset=.1 rot=true loop=true><gradient=true colors={colorTag(accent)};{colorTag(Palette.cream)};{colorTag(accent)} individual=false moveDir=right moveSpeed=.42>{body}</gradient></anim></interval>`
	end
	return `<interval={REVEAL_STAGGER}>{buildKindMarkup(kind, body)}</interval>`
end
local cachedModule
local loadFailed = false
local pendingWarned = false
local TITLE_FONT = "rbxasset://fonts/families/BuilderSans.json"
local function makeTitleMarkups(mod, size, align)
	local markups = mod.newMarkups()
	markups.font.value = TITLE_FONT
	markups.weight.value = Enum.FontWeight.ExtraBold
	markups.size.value = size
	markups.horizontalAlignment.value = if align == Enum.TextXAlignment.Center then Enum.HorizontalAlignment.Center elseif align == Enum.TextXAlignment.Right then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
	markups.verticalAlignment.value = Enum.VerticalAlignment.Center
	markups.scaleDimension.value = "Y"
	return markups
end
local function resolveModuleScript(node)
	if node:IsA("ModuleScript") then
		return node
	end
	local initChild = node:FindFirstChild("init")
	if initChild ~= nil and initChild:IsA("ModuleScript") then
		return initChild
	end
	return nil
end
local function loadHyperTextModule()
	if cachedModule ~= nil then
		return cachedModule
	end
	if loadFailed then
		return nil
	end
	local astral = ReplicatedStorage:FindFirstChild("AstralForge")
	local _vendor = astral
	if _vendor ~= nil then
		_vendor = _vendor:FindFirstChild("Vendor")
	end
	local vendor = _vendor
	local _node = vendor
	if _node ~= nil then
		_node = _node:FindFirstChild("HyperText")
	end
	local node = _node
	if node == nil then
		return nil
	end
	local moduleScript = resolveModuleScript(node)
	if moduleScript == nil then
		ClientLog:warn("hypertext", `HyperText is a {node.ClassName}, not a ModuleScript`)
		loadFailed = true
		return nil
	end
	local ok, result = pcall(function()
		return require(moduleScript)
	end)
	local _condition = not ok or result == nil
	if not _condition then
		local _new = result.new
		_condition = type(_new) == "function" ~= true
	end
	if _condition then
		ClientLog:warn("hypertext", `couldn't load HyperText: {tostring(result)}`)
		loadFailed = true
		return nil
	end
	cachedModule = result
	pendingWarned = false
	return cachedModule
end
local function AnimatedTitle(_param)
	local text = _param.text
	local fx = _param.fx
	local size = _param.size
	if size == nil then
		size = 13
	end
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local position = _param.position
	local sizeConstraint = _param.sizeConstraint
	local transparency = _param.transparency
	if transparency == nil then
		transparency = 0
	end
	local align = _param.align
	if align == nil then
		align = Enum.TextXAlignment.Left
	end
	local _inline = _param.inline
	if _inline == nil then
		_inline = false
	end
	local kind = parseFx(fx)
	local width = sizeConstraint or UDim2.new(1, 0, 0, size + 4)
	local pos = position or UDim2.fromOffset(0, 0)
	local accent = if kind ~= nil then FX_ACCENT[kind] else Palette.creamSoft
	local preview = _param.preview == true
	local live = kind ~= nil and not reducedMotion and text ~= ""
	local hostRef = React.useRef()
	local richRef = React.useRef()
	local fallbackRef = React.useRef()
	local mounted, setMounted = React.useState(false)
	local destroy = React.useCallback(function()
		local rich = richRef.current
		richRef.current = nil
		if rich ~= nil then
			pcall(function()
				return rich:Destroy()
			end)
		end
		setMounted(false)
	end, {})
	React.useEffect(function()
		if not live or kind == nil then
			destroy()
			return nil
		end
		local cancelled = false
		local attempts = 0
		local retryJob
		local tryMount
		tryMount = function()
			if cancelled then
				return nil
			end
			attempts += 1
			local host = hostRef.current
			local mod = loadHyperTextModule()
			if host == nil or mod == nil then
				if attempts < 80 then
					retryJob = task.delay(if attempts < 10 then 0.05 else 0.15, tryMount)
				elseif not pendingWarned then
					pendingWarned = true
					ClientLog:warnEvery("hypertext-root", 30, "hypertext", "title renderer is still loading")
				end
				return nil
			end
			local fallback = fallbackRef.current
			local rich = mod.new(host)
			local markups = makeTitleMarkups(mod, size, align)
			local okUpdate = pcall(function()
				return rich:UpdateDefaultMarkups(markups)
			end)
			if not okUpdate then
				pcall(function()
					return rich:Destroy()
				end)
				return nil
			end
			local okRender = pcall(function()
				return rich:Render(buildMarkup(kind, text, preview), false, false, false)
			end)
			if not okRender then
				pcall(function()
					return rich:Destroy()
				end)
				return nil
			end
			if fallback ~= nil then
				fallback.Visible = false
			end
			richRef.current = rich
			setMounted(true)
		end
		local mountJob = task.defer(tryMount)
		return function()
			cancelled = true
			task.cancel(mountJob)
			if retryJob ~= nil then
				task.cancel(retryJob)
			end
			destroy()
		end
		-- eslint-disable-next-line react-hooks/exhaustive-deps
	end, { live, kind, text, size, align, preview, destroy })
	local showFallback = not live or not mounted
	return React.createElement("frame", {
		Size = width,
		Position = pos,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
		ClipsDescendants = true,
	}, React.createElement("frame", {
		ref = hostRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 2,
	}), showFallback and React.createElement("textlabel", {
		ref = fallbackRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = accent,
		TextSize = size,
		TextTransparency = transparency,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		TextXAlignment = align,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextScaled = true,
		ZIndex = 1,
	}, React.createElement("uitextsizeconstraint", {
		MinTextSize = math.max(9, size - 4),
		MaxTextSize = size,
	})))
end
local function AnimatedTitlePreview(_param)
	local text = _param.text
	local fx = _param.fx
	local size = _param.size
	if size == nil then
		size = 15
	end
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local transparency = _param.transparency
	if transparency == nil then
		transparency = 0
	end
	local preview = _param.preview == true
	return React.createElement(AnimatedTitle, {
		text = text,
		fx = fx,
		size = size,
		reducedMotion = reducedMotion,
		transparency = transparency,
		align = Enum.TextXAlignment.Center,
		preview = preview,
	})
end
return {
	parseFx = parseFx,
	titleFxAccent = titleFxAccent,
	darkTitlePlate = darkTitlePlate,
	AnimatedTitle = AnimatedTitle,
	AnimatedTitlePreview = AnimatedTitlePreview,
	TITLE_FX_KINDS = TITLE_FX_KINDS,
}
