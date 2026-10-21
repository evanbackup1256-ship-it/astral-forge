local Config = require(script.Parent.Config)

local IconCharacter = {}
IconCharacter.__index = IconCharacter

function IconCharacter.new(icon_name: string, config, container: GuiObject, y_offset: number?)
	local self = setmetatable({}, IconCharacter)

	self._icon_name = icon_name
	self._config = config
	self._container = container
	self._instance = nil
	self._size = Vector2.new(config.FontSize, config.FontSize) -- square, sized to font size
	self._y_offset = y_offset or 0 -- manual per-icon vertical nudge, e.g. <icon name 8>
	self._effect_params = {} -- store parameters for each effect

	return self
end

function IconCharacter:CreateInstance(line_start_x, x_pos, line_height, trove, render_container)
	if not Config.IconsFolder then
		warn(`[FancyText/IconCharacter]: Can't render <icon {self._icon_name}> - Config.IconsFolder isn't set.`)
		return
	end

	local icon = Config.IconsFolder:FindFirstChild(self._icon_name)
	if not icon then
		warn(`[FancyText/IconCharacter]: Icon '{self._icon_name}' not found in {Config.IconsFolder:GetFullName()}`)
		return
	end

	self._instance = trove:Add(icon:Clone())
	self._instance.Name = "Icon_" .. self._icon_name
	self._instance.BackgroundTransparency = 1
	self._instance.Size = UDim2.fromOffset(self._size.X, self._size.Y)
	self._instance.Position = UDim2.fromOffset(line_start_x + x_pos, line_height + self._y_offset)
	self._instance.ImageColor3 = self._config.TextColor or Color3.new(1, 1, 1)

	self._instance.Parent = render_container or self._container
end

function IconCharacter:GetChar()
	return ""
end

function IconCharacter:GetInstance()
	return self._instance
end

function IconCharacter:GetSize()
	return self._size
end

function IconCharacter:GetCustomFontData()
	return nil
end

function IconCharacter:AddEffect(effect_name, params)
	self._effect_params[effect_name] = params or {}
end

function IconCharacter:GetEffects()
	local effects = {}
	for effect_name, _ in self._effect_params do
		table.insert(effects, effect_name)
	end
	return effects
end

function IconCharacter:GetEffectParams(effect_name)
	return self._effect_params[effect_name]
end

return IconCharacter
