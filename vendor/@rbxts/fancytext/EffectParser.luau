local EffectParser = {}
EffectParser.__index = EffectParser

function EffectParser.new(characters: { string })
	return setmetatable({
		_characters = characters,
		_active_effects = {},
		_building_effect = false,
		-- collected as a table + concat instead of repeated string ..= (quadratic)
		_current_effect = {},
		_tag_callbacks = {},
	}, EffectParser)
end

function EffectParser:RegisterTagCallback(tag_name, callback)
	self._tag_callbacks[tag_name] = callback
end

function EffectParser:Parse()
	local valid_characters = {}

	for i, char_obj in ipairs(self._characters) do
		local char = char_obj:GetChar()
		if char == "<" then
			self._building_effect = true
			table.clear(self._current_effect)
			continue
		elseif char == ">" then
			if not self._building_effect then
				warn("[FancyText]: Found closing '>' without an opening '<'")
				continue
			end

			self._building_effect = false

			-- parse effect name and parameters
			local parts = string.split(table.concat(self._current_effect), " ")
			local effect_name = parts[1]
			local params = {}
			for j = 2, #parts do
				table.insert(params, parts[j])
			end

			-- check if this is a tag callback (like icon)
			local callback = self._tag_callbacks[effect_name]
			if callback then
				local inserted_chars = callback(params, #params > 0)
				if inserted_chars then
					for _, inserted_char in ipairs(inserted_chars) do
						-- apply currently active effects to inserted characters
						for active_effect_name, active_params in self._active_effects do
							if active_params then
								inserted_char:AddEffect(active_effect_name, active_params)
							end
						end
						table.insert(valid_characters, inserted_char)
					end
				end
			else
				-- store effect with params (empty table if no params)
				local existing = self._active_effects[effect_name]
				if existing then
					self._active_effects[effect_name] = nil -- toggle off
				else
					self._active_effects[effect_name] = params -- store params
				end
			end

			table.clear(self._current_effect)
			continue
		elseif self._building_effect then
			table.insert(self._current_effect, char)
			continue
		end

		table.insert(valid_characters, char_obj)

		for effect_name, params in self._active_effects do
			if not params then
				continue
			end

			char_obj:AddEffect(effect_name, params)
		end
	end

	-- hacky way to get rid of <> chars, etc.
	table.clear(self._characters)

	for i, char_obj in ipairs(valid_characters) do
		self._characters[i] = char_obj
	end
end

return EffectParser
