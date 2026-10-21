-- #selene: allow(multiple_statements)

local RunService = game:GetService("RunService")

local Config = require(script.Parent.Parent.Config)

local is_client = RunService:IsClient()

local util = {
	module_cache = {},
	_warned_missing = {},
}

function util.HasProperty(instance, props: { string })
	local has = true

	for _, prop in props do
		local succ, err = pcall(function()
			return instance[prop]
		end)

		if not succ then
			has = false
			break
		end
	end

	return has
end

-- find parent thats visible up to a depth
function util.GuiObjectIsVisible(ui: Instance?, depth: number)
	-- iterative + IsA instead of pcall-probing each ancestor, cheaper in this hot path
	while ui and depth > 0 do
		if not ui:IsA("GuiObject") then
			return true
		end

		if ui.Visible == false then
			return false
		end

		ui = ui.Parent
		depth -= 1
	end

	return true
end

function util.ValidateConfig(config)
	util.Reconcile(config, Config.Defaults) -- merge with defaults

	local font_count = 0
	if config.Font then
		font_count += 1
	end
	if config.FontFace then
		font_count += 1
	end
	if config.CustomFont then
		font_count += 1
	end

	assert(font_count == 0 or font_count == 1, `[FancyText]: You must specify only 1 font, you have {font_count}`)

	if font_count == 0 then
		config.Font = Enum.Font.RobotoCondensed
	end

	if config.FontSize <= 0 then
		warn(`[FancyText]: FontSize must be > 0`)
		config.FontSize = Config.Defaults.FontSize
	end

	if not table.find({ "Left", "Right", "Center" }, config.TextAlign) then
		warn(`[FancyText]: Only Left, Right & Center alignment supported`)
		config.TextAlign = Config.Defaults.TextAlign
	end

	return config
end

function util.Reconcile(a, b)
	for i, v in b do
		if typeof(v) == "table" and a[i] and typeof(a[i]) == "table" then
			util.Reconcile(a[i], b[i])
		elseif a[i] == nil then
			a[i] = v
		end
	end
end

-- get ui scale relative to 1920x1080 (geometric mean of both axis ratios,
-- avoids one crushed axis dominating the scale on aspect ratios far from 16:9)
function util.GetUIScale()
	if not is_client then
		warn(`[FancyText]: Cannot use this function from the Server.`)
		return
	end

	local cam = workspace.CurrentCamera
	if not cam then
		return 1
	end

	local viewport = cam.ViewportSize
	return math.sqrt((viewport.X / 1920) * (viewport.Y / 1080))
end

function util.GetEffectModule(effect_name: string)
	if util.module_cache[effect_name] then
		return util.module_cache[effect_name]
	end

	local m = Config.EffectsFolder:FindFirstChild(effect_name)
	if not m then
		-- warn once per unknown name, not once per tagged character
		if not util._warned_missing[effect_name] then
			util._warned_missing[effect_name] = true
			warn(`[FancyText]: Can't find effect module: {effect_name}`)
		end
		return
	end

	local src = require(m)
	util.module_cache[effect_name] = src

	return src
end

return util
