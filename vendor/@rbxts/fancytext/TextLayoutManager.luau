local TextLayoutManager = {}
TextLayoutManager.__index = TextLayoutManager

function TextLayoutManager.new(chars, container, is_custom: boolean, ui_scale: number?)
	local self = setmetatable({}, TextLayoutManager)

	self._line_width = 0
	self._line_height = 0
	self._line_height_increment = 0
	self._frame_size = container.AbsoluteSize
	self._chars = chars
	self._is_custom = is_custom
	self._current_line = {}
	self._ui_scale = ui_scale or 1
	self._total_height = 0

	return self
end

function TextLayoutManager:Init(flush_callback)
	self._callback = flush_callback

	local i = 1
	while i <= #self._chars do
		local char_obj = self._chars[i]
		local char = char_obj:GetChar()
		local char_size = char_obj:GetSize()

		-- implement actual newline character
		if char == "\n" then
			self:_Flush()
			i += 1
			continue
		end

		-- implement \n (literal backslash + n)
		if char == "\\" and self._chars[i + 1] and self._chars[i + 1]:GetChar() == "n" then
			self:_Flush()
			i += 2
			continue
		end

		-- word wrapping
		if self:_IsStartOfWord(i) then
			local word_size, word_length = self:_GetWordSize(i)

			-- account for UI scaling when checking wrap boundary
			local wrap_width = self._frame_size.X / self._ui_scale

			if self._line_width > 0 and (self._line_width + word_size > wrap_width) then
				self:_Flush()
			end
		end

		table.insert(self._current_line, {
			CharObj = char_obj,
			XPos = self._line_width,
		})

		if self._is_custom then
			local custom_font_data = char_obj:GetCustomFontData()
			if custom_font_data then
				self._line_width += custom_font_data.XAdvance
			else
				-- IconCharacter or other special characters
				self._line_width += char_size.X
			end
		else
			self._line_width += char_size.X
		end

		-- tallest char in line
		self._line_height_increment = math.max(self._line_height_increment, char_size.Y)

		i += 1
	end

	self:_Flush()

	-- return total height for vertical alignment calculations
	return self._total_height
end

function TextLayoutManager:_IsStartOfWord(i): boolean
	if self._line_width == 0 then
		return true
	end

	if i > 1 and self._chars[i - 1] then
		local prev_char = self._chars[i - 1]:GetChar()
		return prev_char == " "
	end

	return false
end

function TextLayoutManager:_GetWordSize(index): (number, number)
	local word_size = 0
	local word_length = 0

	for i = index, #self._chars do
		local char_obj = self._chars[i]
		local char = char_obj:GetChar()

		if char == " " then
			break
		end

		if self._is_custom then
			local custom_font_data = char_obj:GetCustomFontData()
			if custom_font_data then
				word_size += custom_font_data.XAdvance
			else
				-- IconCharacter or other special characters
				word_size += char_obj:GetSize().X
			end
		else
			word_size += char_obj:GetSize().X
		end

		word_length += 1
	end

	return word_size, word_length
end

function TextLayoutManager:_Flush()
	self._callback(self._current_line, self._line_width, self._line_height)

	self._line_height += self._line_height_increment
	self._total_height = self._line_height

	self._current_line = {}
	self._line_width = 0
	self._line_height_increment = 0
end

return TextLayoutManager
