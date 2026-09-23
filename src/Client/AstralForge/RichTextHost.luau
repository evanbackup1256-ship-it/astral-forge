local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientLog = require(script.Parent.log).ClientLog
local Palette = require(script.Parent.theme).Palette
-- Bridges the vendor RichText Luau module (ReplicatedStorage.AstralForge.Vendor.RichText) --
-- an imperative class that builds real per-character Instances with typewriter timing, <wait>/
-- <br> markup, and Shiny/Stinky particle effects -- into a React-Lua component. Deliberately kept
-- separate from AnimatedTitle.tsx's 31-effect player-title system: that system's per-glyph color/
-- motion math has no equivalent here (RichText only knows Shake/Rainbow/Shiny/Stinky/None), and
-- swapping it out would mean losing 25+ existing effects for a much smaller vocabulary. This host
-- is for what RichText is actually good at and AnimatedTitle doesn't do at all: scripted narrative
-- text with a real typewriter reveal and inline pacing (Story chapters, Mail bodies, tutorial
-- copy) -- see StoryView.tsx/MailboxView.tsx for the call sites.
--
-- Follows the same load-with-retry-and-fallback pattern as NumberSpinnerHost.tsx: the module is
-- fetched once, cached, and any failure to load (missing replication, wrong instance type, a
-- require() error) degrades to a plain static text label instead of leaving the page blank --
-- this text is often the only content on the page (a story chapter, a mail body), so a silent
-- blank render on a load hiccup would be a much worse failure than briefly-unanimated text.
local cachedModule
local loadFailed = false
local pendingWarned = false
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
local function loadRichTextModule()
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
		_node = _node:FindFirstChild("RichText")
	end
	local node = _node
	if node == nil then
		if not pendingWarned then
			pendingWarned = true
			ClientLog:warnEvery("richtext-root", 15, "richtext", "ReplicatedStorage.AstralForge.Vendor.RichText is not replicated yet")
		end
		return nil
	end
	local moduleScript = resolveModuleScript(node)
	if moduleScript == nil then
		ClientLog:warn("richtext", `RichText is a {node.ClassName}, not a ModuleScript`)
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
		ClientLog:warn("richtext", `couldn't load RichText: {tostring(result)}`)
		loadFailed = true
		return nil
	end
	cachedModule = result
	pendingWarned = false
	return cachedModule
end
-- Plain-text width/height is measured the same way AutoHeightText in ui.tsx does, so the reserved
-- space for the scripted version matches what the fallback would have needed -- switching between
-- them (e.g. reducedMotion toggling mid-session) doesn't jump the layout.
local function ScriptedText(_param)
	local text = _param.text
	local width = _param.width
	local height = _param.height
	local size = _param.size
	if size == nil then
		size = 15
	end
	local color = _param.color
	if color == nil then
		color = Palette.creamSoft
	end
	local weight = _param.weight
	if weight == nil then
		weight = Enum.FontWeight.Medium
	end
	local italic = _param.italic
	if italic == nil then
		italic = false
	end
	local align = _param.align
	if align == nil then
		align = Enum.HorizontalAlignment.Left
	end
	local typewriterInterval = _param.typewriterInterval
	if typewriterInterval == nil then
		typewriterInterval = 0.015
	end
	local typewriterSoundId = _param.typewriterSoundId
	local animation = _param.animation
	if animation == nil then
		animation = "None"
	end
	local animationDuration = _param.animationDuration
	if animationDuration == nil then
		animationDuration = 0.125
	end
	local effect = _param.effect
	if effect == nil then
		effect = "None"
	end
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local position = _param.position
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 1
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local renderKey = _param.renderKey
	local onRenderEnded = _param.onRenderEnded
	local hostRef = React.useRef()
	local richRef = React.useRef()
	local fallbackRef = React.useRef()
	local live, setLive = React.useState(false)
	local destroy = React.useCallback(function()
		local rich = richRef.current
		richRef.current = nil
		if rich ~= nil then
			pcall(function()
				return rich.Destroy()
			end)
		end
		setLive(false)
	end, {})
	React.useEffect(function()
		if reducedMotion or text == "" then
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
			local mod = loadRichTextModule()
			if host == nil or mod == nil then
				if attempts < 50 then
					retryJob = task.delay(0.1, tryMount)
				end
				return nil
			end
			local fallback = fallbackRef.current
			if fallback ~= nil then
				fallback.Visible = false
			end
			local rich = mod.new(host, {
				Color = color,
				Size = size,
				XAlign = align,
				YAlign = Enum.VerticalAlignment.Top,
				TypewriterInterval = typewriterInterval,
				TypewriterSoundId = typewriterSoundId,
				Animation = animation,
				AnimationDuration = animationDuration,
				AnimationLoop = false,
				Effect = effect,
				Weight = weight,
				Italic = italic,
				Transparency = 0,
			})
			richRef.current = rich
			setLive(true)
			if onRenderEnded ~= nil and rich.onRenderEnded ~= nil then
				rich.onRenderEnded.Event:Once(function()
					if not cancelled then
						onRenderEnded()
					end
				end)
			end
			rich.Render(text, false, true, false)
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
	end, { renderKey, reducedMotion, text, destroy })
	local showFallback = reducedMotion or not live or text == ""
	return React.createElement("frame", {
		Size = UDim2.fromOffset(width, height),
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		LayoutOrder = layoutOrder,
		ClipsDescendants = false,
	}, React.createElement("frame", {
		ref = hostRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = zIndex + 1,
	}), showFallback and React.createElement("textlabel", {
		ref = fallbackRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = color,
		TextSize = size,
		FontFace = Font.fromEnum(if weight == Enum.FontWeight.Heavy then Enum.Font.BuilderSansExtraBold elseif weight == Enum.FontWeight.Bold then Enum.Font.BuilderSansBold else Enum.Font.BuilderSansMedium),
		TextXAlignment = if align == Enum.HorizontalAlignment.Center then Enum.TextXAlignment.Center elseif align == Enum.HorizontalAlignment.Right then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		LineHeight = 1.12,
		ZIndex = zIndex,
	}))
end
return {
	ScriptedText = ScriptedText,
}
