local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local Audio = require(script.Parent.audio).Audio
local MAX_MESSAGES = 120
local MAX_INPUT = 160
local CHANNEL_NAME = "RBXGeneral"
local function readTitleAttrs(player)
	if player == nil then
		return {}
	end
	local titleId = player:GetAttribute("EquippedTitle")
	local titleName = player:GetAttribute("EquippedTitleName")
	local titleFx = player:GetAttribute("EquippedTitleFx")
	return {
		titleId = if type(titleId) == "string" and titleId ~= "" then titleId else nil,
		titleName = if type(titleName) == "string" and titleName ~= "" then titleName else nil,
		titleFx = if type(titleFx) == "string" and titleFx ~= "" then titleFx else nil,
	}
end
local function systemMessage(text)
	return {
		id = `system-{os.clock()}`,
		userId = 0,
		username = "System",
		displayName = "System",
		text = text,
		world = 0,
		localPlayer = false,
		system = true,
	}
end
local function pushTrimmed(current, incoming)
	local _array = {}
	local _length = #_array
	local _currentLength = #current
	table.move(current, 1, _currentLength, _length + 1, _array)
	_length += _currentLength
	_array[_length + 1] = incoming
	local updated = _array
	while #updated > MAX_MESSAGES do
		table.remove(updated, 1)
	end
	return updated
end
local function statusError(status)
	if status == Enum.TextChatMessageStatus.Floodchecked then
		return "Slow down — chat is rate limited."
	end
	if status == Enum.TextChatMessageStatus.MessageTooLong then
		return "Message is too long."
	end
	if status == Enum.TextChatMessageStatus.TextFilterFailed then
		return "Message blocked by Roblox chat filters."
	end
	if status == Enum.TextChatMessageStatus.InvalidPrivacySettings then
		return "Chat is unavailable for this account."
	end
	if status == Enum.TextChatMessageStatus.InvalidTextChannelPermissions then
		return "You cannot send on this channel."
	end
	return "Message not sent."
end
local function useGameChat(active, enabled)
	if enabled == nil then
		enabled = true
	end
	local messages, setMessages = React.useState({})
	local unread, setUnread = React.useState(0)
	local connected, setConnected = React.useState(false)
	local channel = React.useRef()
	local activeRef = React.useRef(active)
	local aliveRef = React.useRef(true)
	local sendWorkers = React.useRef({})
	activeRef.current = active
	React.useEffect(function()
		if active then
			setUnread(0)
		end
	end, { active })
	React.useEffect(function()
		if not enabled then
			setConnected(false)
			setUnread(0)
			setMessages({ systemMessage("Chat is disabled in this experience.") })
			return nil
		end
		aliveRef.current = true
		local alive = true
		local connection
		local channelAdded
		local ingest = function(message)
			if not alive or message.TextSource == nil then
				return nil
			end
			if message.Status ~= Enum.TextChatMessageStatus.Success then
				return nil
			end
			local userId = message.TextSource.UserId
			local player = Players:GetPlayerByUserId(userId)
			local localPlayer = userId == Players.LocalPlayer.UserId
			local title = readTitleAttrs(player)
			local _object = {
				id = if message.MessageId ~= "" then message.MessageId else `{userId}-{os.clock()}`,
				userId = userId,
			}
			local _left = "username"
			local _result = player
			if _result ~= nil then
				_result = _result.Name
			end
			local _condition = _result
			if _condition == nil then
				_condition = `Operator{userId}`
			end
			_object[_left] = _condition
			local _left_1 = "displayName"
			local _result_1 = player
			if _result_1 ~= nil then
				_result_1 = _result_1.DisplayName
			end
			local _condition_1 = _result_1
			if _condition_1 == nil then
				_condition_1 = `Operator {userId}`
			end
			_object[_left_1] = _condition_1
			_object.text = message.Text
			local _left_2 = "world"
			local _result_2 = player
			if _result_2 ~= nil then
				_result_2 = _result_2:GetAttribute("CurrentZone")
			end
			_object[_left_2] = if type(_result_2) == "number" then player:GetAttribute("CurrentZone") else 1
			_object.localPlayer = localPlayer
			_object.titleId = title.titleId
			_object.titleName = title.titleName
			_object.titleFx = title.titleFx
			local record = _object
			setMessages(function(current)
				-- ▼ ReadonlyArray.find ▼
				local _callback = function(entry)
					return entry.id == record.id
				end
				local _result_3
				for _i, _v in current do
					if _callback(_v, _i - 1, current) == true then
						_result_3 = _v
						break
					end
				end
				-- ▲ ReadonlyArray.find ▲
				if _result_3 ~= nil then
					return current
				end
				return pushTrimmed(current, record)
			end)
			if not localPlayer then
				Audio:play("chatReceive")
			end
			if not activeRef.current and not localPlayer then
				setUnread(function(current)
					return math.min(99, current + 1)
				end)
			end
		end
		local connectWorker = task.spawn(function()
			local channels = TextChatService:WaitForChild("TextChannels", 30)
			if not alive then
				return nil
			end
			if channels == nil then
				setConnected(false)
				setMessages({ systemMessage("Roblox chat did not start. Rejoin, then check Privacy > Communication if it still fails.") })
				return nil
			end
			local attach = function(candidate)
				if not alive or candidate.Name ~= CHANNEL_NAME or not candidate:IsA("TextChannel") or channel.current == candidate then
					return nil
				end
				local _result = connection
				if _result ~= nil then
					_result:Disconnect()
				end
				channel.current = candidate
				connection = candidate.MessageReceived:Connect(ingest)
				setConnected(true)
				setMessages({ systemMessage("Chat is ready. Roblox filters every message. Type /help for shortcuts.") })
			end
			channelAdded = channels.ChildAdded:Connect(attach)
			local existing = channels:FindFirstChild(CHANNEL_NAME)
			if existing ~= nil then
				attach(existing)
			else
				setConnected(false)
				setMessages({ systemMessage("Chat is connecting. This can take a moment on slower devices.") })
				local general = channels:WaitForChild(CHANNEL_NAME, 30)
				if general ~= nil then
					attach(general)
				elseif alive then
					setMessages({ systemMessage("Roblox chat is unavailable. Rejoin, then check Privacy > Communication if it still fails.") })
				end
			end
		end)
		return function()
			alive = false
			aliveRef.current = false
			pcall(function()
				return task.cancel(connectWorker)
			end)
			for worker in sendWorkers.current do
				pcall(function()
					return task.cancel(worker)
				end)
			end
			table.clear(sendWorkers.current)
			local _result = channelAdded
			if _result ~= nil then
				_result:Disconnect()
			end
			local _result_1 = connection
			if _result_1 ~= nil then
				_result_1:Disconnect()
			end
			channel.current = nil
		end
	end, { enabled })
	local send = React.useCallback(function(raw, done)
		if not enabled then
			local _result = done
			if _result ~= nil then
				_result(false, "Chat is disabled in this experience.")
			end
			return nil
		end
		local forSend = string.sub(raw, 1, MAX_INPUT)
		local trimmed = (string.gsub((string.gsub(forSend, "^%s+", "")), "%s+$", ""))
		if trimmed == "" then
			local _result = done
			if _result ~= nil then
				_result(false, "Type a message first.")
			end
			return nil
		end
		if string.lower(trimmed) == "/clear" then
			setMessages({ systemMessage("Local message history cleared.") })
			local _result = done
			if _result ~= nil then
				_result(true)
			end
			return nil
		end
		if string.lower(trimmed) == "/help" then
			setMessages(function(current)
				return pushTrimmed(current, systemMessage("Shortcuts: /clear removes messages on this device. /help shows this list."))
			end)
			local _result = done
			if _result ~= nil then
				_result(true)
			end
			return nil
		end
		local target = channel.current
		if not target then
			local _result = done
			if _result ~= nil then
				_result(false, "Chat is still connecting.")
			end
			return nil
		end
		Audio:play("chatSend")
		local worker
		worker = task.defer(function()
			local ok, result = pcall(function()
				return target:SendAsync(forSend)
			end)
			if worker ~= nil then
				local _current = sendWorkers.current
				local _worker = worker
				_current[_worker] = nil
			end
			worker = nil
			if not aliveRef.current then
				return nil
			end
			if not ok then
				local _result = done
				if _result ~= nil then
					_result(false, "Roblox could not send this message. Check your chat privacy settings and try again.")
				end
				return nil
			end
			local delivered = result
			if delivered.Status ~= Enum.TextChatMessageStatus.Success then
				local name = tostring(delivered.Status)
				if (string.find(name, "Sending")) == nil and (string.find(name, "Pending")) == nil then
					local _result = done
					if _result ~= nil then
						_result(false, statusError(delivered.Status))
					end
					return nil
				end
			end
			local _result = done
			if _result ~= nil then
				_result(true)
			end
		end)
		local _current = sendWorkers.current
		local _worker = worker
		_current[_worker] = true
	end, { enabled })
	local clear = React.useCallback(function()
		return setMessages({ systemMessage("Local message history cleared.") })
	end, {})
	return {
		messages = messages,
		unread = unread,
		connected = connected,
		send = send,
		clear = clear,
	}
end
return {
	useGameChat = useGameChat,
}
