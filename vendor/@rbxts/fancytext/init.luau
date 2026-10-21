local RunService = game:GetService("RunService")

local FRAME_THROTTLE_AMT = 8

local Util = require(script.Dependencies.Util)
local Trove = require(script.Dependencies.Trove)
local TextRenderer = require(script.TextRenderer)
local FromLabel = require(script.FromLabel)

local Config = require(script.Config)
export type Config = Config.Config

local FancyText = {
	ActiveRenderers = {},
	RendererGroups = {},
	UpdateConnection = nil,
	FrameCounter = 0,
	NextGroup = 1,
}

-- Spread updates out through groups
for i = 1, FRAME_THROTTLE_AMT do
	table.insert(FancyText.RendererGroups, {})
end

-- Custom font atlases only carry single-byte glyphs; swap the common
-- typographic unicode for ASCII equivalents before rendering.
local CUSTOM_FONT_SUBSTITUTES = {
	["\u{2018}"] = "'", -- ‘
	["\u{2019}"] = "'", -- ’
	["\u{201C}"] = '"', -- “
	["\u{201D}"] = '"', -- ”
	["\u{2013}"] = "-", -- –
	["\u{2014}"] = "-", -- —
	["\u{2026}"] = "...", -- …
}

function FancyText.MakeText(container: GuiObject, text: string, config: Config?): Trove.Trove
	assert(container and container:IsA("GuiObject"), "[FancyText]: First argument must be a GuiObject.")
	assert(text and type(text) == "string" or text == "", "[FancyText]: Second argument must be a non-empty string.")
	assert(RunService:IsClient(), `[FancyText]: MakeText must only be called from the Client`)

	local succ, valid_config = pcall(function()
		return Util.ValidateConfig(config)
	end)

	if not succ then
		warn(`[FancyText]: Config invalid: {valid_config}`)
		return
	end

	if valid_config.CustomFont then
		for unicode, ascii in CUSTOM_FONT_SUBSTITUTES do
			text = text:gsub(unicode, ascii)
		end
	end

	local trove = Trove.new()

	local text_renderer = TextRenderer.new(container, valid_config, text, trove)
	text_renderer:Render()

	FancyText.ActiveRenderers[text_renderer] = true

	-- Insert our Renderer into the proper RendererGroup to spread out updates
	local idx = FancyText.NextGroup
	FancyText.NextGroup = (FancyText.NextGroup % FRAME_THROTTLE_AMT) + 1
	table.insert(FancyText.RendererGroups[idx], text_renderer)

	-- Update Renderers (spread out over FRAME_THROTTLE_AMT)
	if not FancyText.UpdateConnection then
		FancyText.UpdateConnection = RunService.RenderStepped:Connect(function(dt)
			FancyText.FrameCounter = (FancyText.FrameCounter % FRAME_THROTTLE_AMT) + 1

			for _, renderer in FancyText.RendererGroups[FancyText.FrameCounter] do
				if FancyText.ActiveRenderers[renderer] then
					renderer:Update(dt * FRAME_THROTTLE_AMT)
				end
			end
		end)
	end

	trove:Add(function()
		-- Remove from ActiveRenderers
		FancyText.ActiveRenderers[text_renderer] = nil

		-- Remove from RenderGroup
		for _, group in FancyText.RendererGroups do
			local idx = table.find(group, text_renderer)
			if idx then
				-- swap last element for O(1) removal, table.remove would shift elements
				group[idx] = group[#group]
				group[#group] = nil
				break
			end
		end

		-- If no more Renderers, remove UpdateConnection
		if FancyText.UpdateConnection and not next(FancyText.ActiveRenderers) then
			FancyText.UpdateConnection:Disconnect()
			FancyText.UpdateConnection = nil
		end
	end)

	-- attached to the trove instance so trove:Add(FancyText.MakeText(...)) still works;
	-- a 2nd return value would splat into Add's cleanupMethod argument instead
	function trove:PlayEffect(effect_name: string, params: { string }?, auto_clean: boolean?)
		return text_renderer:PlayEffect(effect_name, params, auto_clean)
	end

	return trove
end

function FancyText.FromLabel(text_label: TextLabel, configs: Config?, prefix: string?): Trove.Trove
	return FromLabel(FancyText.MakeText, text_label, configs, prefix)
end

function FancyText.GetTextLengthWithoutTags(msg: string): number
	return #(string.gsub(msg, "<.->", ""))
end

function FancyText.GetTextWithoutTags(msg: string): string
	return string.gsub(msg, "<.->", "")
end

return FancyText
