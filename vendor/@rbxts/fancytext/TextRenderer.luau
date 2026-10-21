local TextLayoutManager = require(script.Parent.TextLayoutManager)
local TextCharacter = require(script.Parent.TextCharacter)
local IconCharacter = require(script.Parent.IconCharacter)
local EffectParser = require(script.Parent.EffectParser)
local Util = require(script.Parent.Dependencies.Util)

local RESIZE_DEBOUNCE_TIME = 0.2 -- seconds to wait after the last resize before re-laying out

local TextRenderer = {}
TextRenderer.__index = TextRenderer

function TextRenderer.new(container, config, text, trove)
	local self = setmetatable({}, TextRenderer)

	self._container = container
	self._config = config
	self._text = text
	self._trove = trove

	-- own sub-trove per layout pass, so a resize can Clean() without touching self._trove
	self._render_trove = trove:Extend()

	self._characters = {}
	self._effect_args = {}
	self._global_char_index = 0

	-- flat list rebuilt per layout; Update() only walks this, so effect-less chars cost nothing
	self._update_list = {}

	self:_Init()

	return self
end

function TextRenderer:_Init()
	for c in string.gmatch(self._text, ".") do
		table.insert(self._characters, TextCharacter.new(c, self._config, self._container))
	end

	if self._config.Scale then
		local inner = self._trove:Add(Instance.new("Frame"))
		inner.Size = UDim2.fromScale(1, 1)
		inner.BackgroundTransparency = 1
		inner.Parent = self._container

		local scale = self._trove:Add(Instance.new("UIScale"))
		scale.Scale = Util.GetUIScale()
		scale.Parent = inner

		self._render_container = inner
		self._ui_scale = scale
	end

	local parser = EffectParser.new(self._characters)

	parser:RegisterTagCallback("icon", function(args, is_opening)
		if #args == 0 then
			warn("[FancyText]: <icon> tag requires an icon name argument")
			return nil
		end

		local icon_name = args[1]
		local y_offset = tonumber(args[2])
		return { IconCharacter.new(icon_name, self._config, self._container, y_offset) }
	end)

	parser:Parse()

	-- only chars that survived parsing need resolving; see TextCharacter:Resolve
	for _, char_obj in self._characters do
		if char_obj.Resolve then
			char_obj:Resolve()
		end
	end
end

function TextRenderer:Render()
	-- wait for container to have valid size if using alignment
	self._trove:Add(task.spawn(function()
		if
			(self._config.TextAlign and (self._config.TextAlign == "Center" or self._config.TextAlign == "Right"))
			or (
				self._config.VerticalAlign
				and (self._config.VerticalAlign == "Center" or self._config.VerticalAlign == "Bottom")
			)
		then
			while self._container.AbsoluteSize.X == 0 and self._container.AbsoluteSize.Y == 0 do
				self._container:GetPropertyChangedSignal("AbsoluteSize"):Wait()
			end
		end

		self:_Layout()
		self:_ListenForResize()
	end))
end

-- re-wraps and repositions/recreates all characters; safe to call repeatedly
function TextRenderer:_Layout()
	local ui_scale = self._config.Scale and Util.GetUIScale() or 1
	local container_size = self._container.AbsoluteSize

	-- skip if nothing changed, avoids AutomaticSize feedback loops from recreating instances
	if self._last_layout_size == container_size and self._last_layout_scale == ui_scale then
		return
	end
	self._last_layout_size = container_size
	self._last_layout_scale = ui_scale

	self._render_trove:Clean()
	self._effect_args = {}
	self._global_char_index = 0
	table.clear(self._update_list)

	-- precompute character index once per layout instead of searching in _FlushLine
	self._char_index = {}
	for i, char_obj in self._characters do
		self._char_index[char_obj] = i
	end

	if self._ui_scale then
		self._ui_scale.Scale = ui_scale
		-- compensates UIScale>1 inflating AutomaticSize ancestors (pushed text off-center >1080p)
		self._render_container.Size = UDim2.fromScale(1 / ui_scale, 1 / ui_scale)
	end

	-- queued here, run after vertical offset below so Inits see final positions
	self._pending_inits = {}

	local layout_mgr =
		TextLayoutManager.new(self._characters, self._container, self._config.CustomFont ~= nil, ui_scale)

	local total_height = layout_mgr:Init(function(...)
		self:_FlushLine(...)
	end)

	-- Calculate and apply vertical offset
	local vertical_offset = 0
	if self._config.VerticalAlign == "Center" then
		local container_height = self._config.Scale and (self._container.AbsoluteSize.Y / ui_scale)
			or self._container.AbsoluteSize.Y
		vertical_offset = math.max(0, (container_height - total_height) / 2)
	elseif self._config.VerticalAlign == "Bottom" then
		local container_height = self._config.Scale and (self._container.AbsoluteSize.Y / ui_scale)
			or self._container.AbsoluteSize.Y
		vertical_offset = math.max(0, container_height - total_height)
	end

	-- Apply vertical offset (before effect Inits run, so they see final positions)
	if vertical_offset > 0 then
		for _, char_obj in self._characters do
			local instance = char_obj:GetInstance()
			if instance then
				instance.Position = instance.Position + UDim2.fromOffset(0, vertical_offset)
			end
		end
	end

	-- Now run the effect Inits queued by _FlushLine
	for _, pending in self._pending_inits do
		local effect_module = pending.effect_module
		local char_inst = pending.char_inst

		if effect_module.Init then
			local effect_name = pending.effect_name
			if not self._effect_args[effect_name] then
				self._effect_args[effect_name] = {}
			end

			self._effect_args[effect_name][char_inst] = effect_module.Init(
				char_inst,
				pending.global_index,
				self._render_trove,
				pending.char_obj:GetEffectParams(effect_name)
			)
		end

		if effect_module.Update then
			table.insert(self._update_list, {
				instance = char_inst,
				char_obj = pending.char_obj,
				effect_name = pending.effect_name,
				update = effect_module.Update,
				index = self._char_index[pending.char_obj],
			})
		end
	end
end

-- debounced re-layout on viewport change; watches ViewportSize, not container
-- AbsoluteSize, to avoid a self-triggering loop from recreating instances
function TextRenderer:_ListenForResize()
	local reflow_pending = false
	local alive = true

	self._trove:Add(function()
		alive = false
	end)

	local function request_reflow()
		if reflow_pending then
			return
		end
		reflow_pending = true

		task.delay(RESIZE_DEBOUNCE_TIME, function()
			reflow_pending = false
			if alive then
				self:_Layout()
			end
		end)
	end

	-- camera can be swapped out, so re-hook ViewportSize each time
	local camera_conn = nil
	local function hook_camera()
		if camera_conn then
			camera_conn:Disconnect()
		end

		local cam = workspace.CurrentCamera
		if cam then
			camera_conn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(request_reflow)
		end
	end

	hook_camera()
	self._trove:Add(function()
		if camera_conn then
			camera_conn:Disconnect()
		end
	end)
	self._trove:Connect(workspace:GetPropertyChangedSignal("CurrentCamera"), hook_camera)
end

function TextRenderer:_FlushLine(chars_to_render, line_width, line_height)
	if #chars_to_render == 0 then
		return
	end

	-- left alignment uses 0 (default)
	local line_start_x = 0

	local container_width = self._config.Scale and (self._container.AbsoluteSize.X / Util.GetUIScale())
		or self._container.AbsoluteSize.X

	if self._config.TextAlign == "Center" then
		line_start_x = (container_width - line_width) / 2
	elseif self._config.TextAlign == "Right" then
		line_start_x = math.max(0, container_width - line_width)
	end

	for i, char_line_data in chars_to_render do
		local char_obj = char_line_data.CharObj
		local x_pos = char_line_data.XPos

		char_obj:CreateInstance(line_start_x, x_pos, line_height, self._render_trove, self._render_container)

		self._global_char_index += 1

		for _, effect_name in char_obj:GetEffects() do
			local effect_module = Util.GetEffectModule(effect_name)
			if not effect_module then
				continue
			end

			table.insert(self._pending_inits, {
				effect_module = effect_module,
				effect_name = effect_name,
				char_obj = char_obj,
				char_inst = char_obj:GetInstance(),
				global_index = self._global_char_index,
			})
		end
	end
end

-- triggers an effect on demand (e.g. a click handler) instead of waiting on a tag delay.
-- auto_clean cleans the whole trove once delay+duration elapses, if the effect reports them.
function TextRenderer:PlayEffect(effect_name: string, params: { string }?, auto_clean: boolean?)
	local effect_module = Util.GetEffectModule(effect_name)
	if not effect_module then
		warn(`[FancyText]: Can't find effect module: {effect_name}`)
		return
	end

	if not self._effect_args[effect_name] then
		self._effect_args[effect_name] = {}
	end

	local max_end_time = 0
	local has_estimate = false

	for i, char_obj in self._characters do
		local char_inst = char_obj:GetInstance()
		if not char_inst then
			continue
		end

		char_obj:AddEffect(effect_name, params or {})

		if effect_module.Init then
			local data = effect_module.Init(char_inst, i, self._render_trove, params or {})
			self._effect_args[effect_name][char_inst] = data

			if type(data) == "table" and type(data.delay) == "number" and type(data.duration) == "number" then
				has_estimate = true
				max_end_time = math.max(max_end_time, data.delay + data.duration)
			end
		end

		if effect_module.Update then
			table.insert(self._update_list, {
				instance = char_inst,
				char_obj = char_obj,
				effect_name = effect_name,
				update = effect_module.Update,
				index = i,
			})
		end
	end

	if auto_clean then
		if has_estimate then
			task.delay(max_end_time, function()
				self._trove:Clean()
			end)
		else
			warn(`[FancyText]: Can't auto-clean - effect '{effect_name}' doesn't report delay/duration`)
		end
	end
end

function TextRenderer:Update(dt)
	if #self._update_list == 0 then
		return
	end

	-- check ancestor visibility once per renderer, not per character per frame
	if not Util.GuiObjectIsVisible(self._container, 10) then
		return
	end

	for _, entry in self._update_list do
		local instance = entry.instance

		if not instance or instance.Visible == false then
			continue
		end

		local args_bucket = self._effect_args[entry.effect_name]
		entry.update(
			instance,
			entry.index,
			dt,
			self._render_trove,
			args_bucket and args_bucket[instance],
			entry.char_obj:GetEffectParams(entry.effect_name)
		)
	end
end

return TextRenderer
