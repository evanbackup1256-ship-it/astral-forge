local RunService = game:GetService("RunService")

local FONT_FIELDS = { "Font", "FontFace", "CustomFont" }

local X_ALIGN_MAP = {
	[Enum.TextXAlignment.Left.Name] = "Left",
	[Enum.TextXAlignment.Right.Name] = "Right",
	[Enum.TextXAlignment.Center.Name] = "Center",
}

local function shallow_copy(t)
	local copy = {}
	if t then
		for k, v in t do
			copy[k] = v
		end
	end
	return copy
end

local function derive_config(text_label: TextLabel, user_configs)
	local derived = {}

	derived.TextAlign = X_ALIGN_MAP[text_label.TextXAlignment.Name]
	derived.VerticalAlign = text_label.TextYAlignment.Name -- Top/Center/Bottom match 1:1

	local user_specified_font = false
	if user_configs then
		for _, field in FONT_FIELDS do
			if user_configs[field] ~= nil then
				user_specified_font = true
				break
			end
		end
	end
	if not user_specified_font then
		derived.FontFace = text_label.FontFace
	end

	derived.FontSize = text_label.TextSize
	derived.TextColor = text_label.TextColor3
	derived.ZIndex = text_label.ZIndex
	derived.TextTransparency = text_label.TextTransparency
	derived.TextStrokeTransparency = text_label.TextStrokeTransparency
	derived.TextStrokeColor = text_label.TextStrokeColor3

	local size_constraint = text_label:FindFirstChildOfClass("UITextSizeConstraint")
	if size_constraint then
		derived.TextSizeConstraint = { size_constraint.MinTextSize, size_constraint.MaxTextSize }
	end

	return derived
end

return function(MakeText, text_label: TextLabel, configs: {}?, prefix: string?)
	assert(text_label and text_label:IsA("TextLabel"), "[FancyText]: First argument must be a TextLabel.")
	assert(configs == nil or type(configs) == "table", "[FancyText]: Second argument must be a table or nil.")
	assert(prefix == nil or type(prefix) == "string", "[FancyText]: Third argument must be a string or nil.")
	assert(RunService:IsClient(), "[FancyText]: FromLabel must only be called from the Client")

	local original_text = text_label.Text
	local render_text = (prefix or "") .. original_text
	local original_text_transparency = text_label.TextTransparency
	local original_stroke_transparency = text_label.TextStrokeTransparency

	local derived = derive_config(text_label, configs)
	local merged = shallow_copy(derived)
	if configs then
		for k, v in configs do
			merged[k] = v
		end
	end

	text_label.TextTransparency = 1
	text_label.TextStrokeTransparency = 1

	local trove = MakeText(text_label, render_text, merged)
	if not trove then
		text_label.TextTransparency = original_text_transparency
		text_label.TextStrokeTransparency = original_stroke_transparency
		return
	end

	trove:Add(function()
		text_label.Text = original_text
		text_label.TextTransparency = original_text_transparency
		text_label.TextStrokeTransparency = original_stroke_transparency
	end)

	return trove
end
