local textservice = game:GetService("TextService")

local Config = require(script.Parent.Config)

-- cache resolved font modules, avoids FindFirstChild+require per glyph
local font_data_cache = {}

-- GetTextSize is pure per (char, size, font); shared cache avoids re-measuring
local text_size_cache = {}

local function get_custom_char_data(char: string, font_size: number, custom_font: string)
	local font_data = font_data_cache[custom_font]

	if not font_data then
		local font_module = assert(
			Config.FontsFolder:FindFirstChild(custom_font),
			`[FancyText]: Custom Font: {custom_font} doesn't exist or isn't a module.`
		)

		font_data = require(font_module)
		font_data_cache[custom_font] = font_data
	end

	local char_code = string.byte(char)
	local char_data = font_data.Characters[char_code]
	local o_size = font_data.OriginalSize
	local scale = font_size / o_size

	if char == `\\` or char == "\n" or char == "\r" or char == "\t" then
		return nil
	end

	if not char_data then
		-- unknown glyph: fall back to system font instead of erroring
		warn(`[FancyText]: No CharacterData for {char_code} in {custom_font}; falling back to system font.`)
		return nil
	end

	if not o_size then
		error(`[FancyText]: FontData for {custom_font} doesn't have an OriginalSize.`)
	end

	if not font_data.Atlas then
		error(`[FancyText]: FontData for {custom_font} doesn't have an Atlas.`)
	end

	-- font_data.YOffset: optional manual per-font vertical nudge, defaults to 0
	return {
		Atlas = font_data.Atlas,
		UnscaledWidth = char_data.width,
		UnscaledHeight = char_data.height,
		Width = char_data.width * scale,
		Height = char_data.height * scale,
		XAdvance = char_data.xadvance * scale,
		XOffset = char_data.xoffset * scale,
		YOffset = (char_data.yoffset + (font_data.YOffset or 0)) * scale,
		X = char_data.x,
		Y = char_data.y,
	}
end

local TextCharacter = {}
TextCharacter.__index = TextCharacter

function TextCharacter.new(char: string, config, container: GuiObject)
	local self = setmetatable({}, TextCharacter)

	self._effects = {}
	self._effect_params = {} -- store parameters for each effect
	self._char = char
	self._font_size = config.FontSize
	self._config = config
	self._container = container
	self._instance = nil

	self._size = Vector2.new(0, 0)

	return self
end

-- deferred until after tag parsing so tag-only chars (e.g. '<', '>') never need font data
function TextCharacter:Resolve()
	if self._config.CustomFont then
		self._custom_font_data = get_custom_char_data(self._char, self._font_size, self._config.CustomFont)
	end

	-- newlines and other control characters have zero size
	if self._char == "\n" or self._char == "\r" or self._char == "\t" then
		self._size = Vector2.new(0, 0)
		return
	end

	local custom = self:GetCustomFontData()
	if custom then
		self._size = Vector2.new(custom.Width, custom.Height)
	else
		-- GetTextSize only accepts Enum.Font, not FontFace
		local font = self._config.Font or Enum.Font.SourceSans

		-- single glyphs never wrap, so a big fixed bound is safe to cache across renderers
		local cache_key = self._char .. "\1" .. font.Name .. "\1" .. self._font_size
		local cached = text_size_cache[cache_key]
		if not cached then
			cached = textservice:GetTextSize(self._char, self._font_size, font, Vector2.new(100000, 100000))
			text_size_cache[cache_key] = cached
		end
		self._size = cached
	end
end

function TextCharacter:CreateInstance(line_start_x, x_pos, line_height, trove, render_container)
	local custom = self:GetCustomFontData()
	local size = self:GetSize()
	local text_color = self._config.TextColor
	local parent = render_container or self._container

	if custom then
		self._instance = trove:Add(Instance.new("ImageLabel"))
		self._instance.BackgroundTransparency = 1
		self._instance.Name = self._char
		self._instance.Image = custom.Atlas
		self._instance.ImageColor3 = text_color
		self._instance.ZIndex = self._config.ZIndex
		self._instance.Size = UDim2.fromOffset(size.X, size.Y)
		self._instance.ImageRectOffset = Vector2.new(custom.X, custom.Y)
		self._instance.ImageRectSize = Vector2.new(custom.UnscaledWidth, custom.UnscaledHeight)
		self._instance.Position = UDim2.fromOffset(line_start_x + x_pos + custom.XOffset, line_height + custom.YOffset)
		self._instance.Parent = parent
	else
		self._instance = trove:Add(Instance.new("TextLabel"))
		self._instance.BackgroundTransparency = 1
		self._instance.Name = self._char
		self._instance.Text = self._char
		self._instance.TextSize = self._font_size
		self._instance.TextColor3 = text_color
		-- one plain char per label, no markup to parse (EffectParser already handled tags)
		self._instance.RichText = false
		self._instance.ZIndex = self._config.ZIndex
		self._instance.Size = UDim2.fromOffset(size.X, size.Y)
		self._instance.Position = UDim2.fromOffset(line_start_x + x_pos, line_height)
		self._instance.TextStrokeTransparency = self._config.TextStrokeTransparency
		self._instance.TextStrokeColor3 = self._config.TextStrokeColor
		self._instance.TextTransparency = self._config.TextTransparency

		if self._config.Font then
			self._instance.Font = self._config.Font
		elseif self._config.FontFace then
			self._instance.FontFace = self._config.FontFace
		end

		if self._config.TextSizeConstraint then
			local constraint = Instance.new("UITextSizeConstraint")
			constraint.MinTextSize = self._config.TextSizeConstraint[1]
			constraint.MaxTextSize = self._config.TextSizeConstraint[2]
			constraint.Parent = self._instance
		end

		self._instance.Parent = parent
	end
end

function TextCharacter:AddEffect(effect_name, params)
	table.insert(self._effects, effect_name)
	self._effect_params[effect_name] = params or {}
end

function TextCharacter:GetEffects()
	return self._effects
end

function TextCharacter:GetEffectParams(effect_name)
	return self._effect_params[effect_name]
end

function TextCharacter:GetChar()
	return self._char
end

function TextCharacter:GetInstance()
	return self._instance
end

function TextCharacter:GetSize()
	return self._size
end

function TextCharacter:GetCustomFontData()
	return self._custom_font_data
end

return TextCharacter
