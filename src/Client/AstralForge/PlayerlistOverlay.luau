local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local StarterGui = game:GetService("StarterGui")
local Audio = require(script.Parent.audio).Audio
local Icon = require(script.Parent.Icon).Icon
local _motion = require(script.Parent.motion)
local composePresence = _motion.composePresence
local useEntrance = _motion.useEntrance
local useExitTransition = _motion.useExitTransition
local useViewport = _motion.useViewport
local _theme = require(script.Parent.theme)
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local compactNumber = require(script.Parent.format).compactNumber
local _ui = require(script.Parent.ui)
local Button = _ui.Button
local OverlayPresence = _ui.OverlayPresence
local Text = _ui.Text
local useGamepadAutofocus = _ui.useGamepadAutofocus
local Core = StarterGui
local TEST_BOT_USER_ID = 771133001
local REPORT_REASONS = { "Exploiting", "Harassment", "Trolling", "Spam", "Inappropriate", "Other" }
local function sanitizeRows(raw)
	local rows = {}
	for _, entry in raw do
		local _userId = entry.UserId
		local userId = if type(_userId) == "number" then math.floor(entry.UserId) else tonumber(tostring(entry.UserId))
		if userId == nil or userId == 0 or userId ~= userId then
			continue
		end
		if userId == TEST_BOT_USER_ID then
			continue
		end
		local _object = table.clone(entry)
		setmetatable(_object, nil)
		_object.UserId = userId
		table.insert(rows, _object)
	end
	return rows
end
local function AvatarThumbnail(_param)
	local userId = _param.userId
	local accent = _param.accent
	local size = _param.size
	local position = _param.position
	local zIndex = _param.zIndex
	return React.createElement("frame", {
		Size = UDim2.fromOffset(size, size),
		Position = position,
		BackgroundColor3 = darken(accent, 0.64),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = zIndex,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 1.5,
		Transparency = 0.2,
	}), React.createElement("imagelabel", {
		Size = UDim2.new(1, -4, 1, -4),
		Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		Image = `rbxthumb://type=AvatarHeadShot&id={math.floor(userId)}&w=150&h=150`,
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = zIndex + 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end
local function PlayerRow(_param)
	local player = _param.player
	local selected = _param.selected
	local onSelect = _param.onSelect
	local layoutOrder = _param.layoutOrder
	local reducedMotion = _param.reducedMotion
	local awayStamp = _param.awayStamp
	local accent = if player.IsLocal then Palette.mint else Palette.cyan
	local peer = Players:GetPlayerByUserId(player.UserId)
	local _result
	if player.IsLocal or awayStamp < 0 then
		_result = false
	else
		local _result_1 = peer
		if _result_1 ~= nil then
			_result_1 = _result_1:GetAttribute("AF_Away")
		end
		_result = _result_1 == true
	end
	local away = _result
	local subtitle = if player.IsLocal then "YOUR PROFILE" elseif away then "AFK" else `WORLD {compactNumber(player.CurrentZone)}  •  {compactNumber(player.Rebirths)} REBIRTHS`
	return React.createElement("frame", {
		Size = UDim2.new(1, -2, 0, 58),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ZIndex = 620,
	}, React.createElement(Button, {
		text = "",
		onClick = onSelect,
		color = if selected then darken(accent, 0.64) else Palette.panel,
		textColor = Palette.cream,
		outline = not selected,
		highlight = selected,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		zIndex = 620,
	}, React.createElement(AvatarThumbnail, {
		userId = player.UserId,
		accent = accent,
		size = 38,
		position = UDim2.fromOffset(10, 10),
		zIndex = 623,
	}), React.createElement(Text, {
		value = if away then `{player.DisplayName}  ·  AFK` else player.DisplayName,
		size = 15,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 12,
		position = UDim2.fromOffset(58, 7),
		sizeConstraint = UDim2.new(1, -118, 0, 21),
		zIndex = 623,
	}), React.createElement(Text, {
		value = subtitle,
		size = 10,
		color = if away then Palette.mango else accent,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(58, 31),
		sizeConstraint = UDim2.new(1, -118, 0, 17),
		zIndex = 623,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.new(1, -22, 0.5, -4),
		BackgroundColor3 = Palette.mint,
		BorderSizePixel = 0,
		ZIndex = 624,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.white,
		Thickness = 1,
		Transparency = 0.58,
	}))))
end
local function PlayerlistOverlay(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local onClose = _param.onClose
	local notify = _param.notify
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local localSummary = React.useMemo(function()
		return {
			UserId = Players.LocalPlayer.UserId,
			Name = Players.LocalPlayer.Name,
			DisplayName = Players.LocalPlayer.DisplayName,
			CurrentZone = state.CurrentZone,
			Rebirths = state.Rebirths,
			Production = 0,
			LifetimeCash = 0,
			IsLocal = true,
		}
	end, { state.CurrentZone, state.Rebirths })
	local localSummaryRef = React.useRef(localSummary)
	localSummaryRef.current = localSummary
	local rows, setRows = React.useState(function()
		return { localSummary }
	end)
	local selectedId, setSelectedId = React.useState(Players.LocalPlayer.UserId)
	local friends, setFriends = React.useState({})
	local blocked, setBlocked = React.useState({})
	local inventoryOpen, setInventoryOpen = React.useState(false)
	local reportOpen, setReportOpen = React.useState(false)
	local reportReason, setReportReason = React.useState("Exploiting")
	local reportBusy, setReportBusy = React.useState(false)
	local inviteBusy, setInviteBusy = React.useState(false)
	local alive = React.useRef(true)
	local _binding = useExitTransition(reducedMotion)
	local exitAmount = _binding[1]
	local exiting = _binding[2]
	local beginExit = _binding[3]
	local enter = useEntrance(reducedMotion)
	local awayTick, setAwayTick = React.useState(0)
	React.useEffect(function()
		local pulse = task.spawn(function()
			while true do
				task.wait(1)
				setAwayTick(function(current)
					return current + 1
				end)
			end
		end)
		return function()
			return task.cancel(pulse)
		end
	end, {})
	React.useEffect(function()
		Audio:play("playerlistOpen")
	end, {})
	React.useEffect(function()
		alive.current = true
		return function()
			alive.current = false
		end
	end, {})
	local refresh = React.useCallback(function()
		return dispatch("GetPlayers", {}, function(response)
			if not alive.current or not response.ok then
				return nil
			end
			local cleaned = sanitizeRows(response.Players or {})
			local nextRows = if #cleaned > 0 then cleaned else { localSummaryRef.current }
			setRows(nextRows)
			setSelectedId(function(current)
				-- ▼ ReadonlyArray.some ▼
				local _result = false
				local _callback = function(row)
					return row.UserId == current
				end
				for _k, _v in nextRows do
					if _callback(_v, _k - 1, nextRows) then
						_result = true
						break
					end
				end
				-- ▲ ReadonlyArray.some ▲
				return if _result then current else nextRows[1].UserId
			end)
		end)
	end, { dispatch })
	local applyLocalRoster = React.useCallback(function()
		local selfRow = localSummaryRef.current
		local nextRows = {}
		table.insert(nextRows, selfRow)
		for _, player in Players:GetPlayers() do
			if player.UserId == selfRow.UserId then
				continue
			end
			local _arg0 = {
				UserId = player.UserId,
				Name = player.Name,
				DisplayName = player.DisplayName,
				CurrentZone = 1,
				Rebirths = 0,
				Production = 0,
				IsLocal = false,
			}
			table.insert(nextRows, _arg0)
		end
		setRows(function(current)
			local byId = {}
			for _, row in current do
				local _userId = row.UserId
				byId[_userId] = row
			end
			-- ▼ ReadonlyArray.map ▼
			local _newValue = table.create(#nextRows)
			local _callback = function(row)
				local _userId = row.UserId
				local known = byId[_userId]
				local _result
				if known ~= nil and not row.IsLocal then
					local _object = table.clone(known)
					setmetatable(_object, nil)
					_object.Name = row.Name
					_object.DisplayName = row.DisplayName
					_result = _object
				else
					_result = row
				end
				return _result
			end
			for _k, _v in nextRows do
				_newValue[_k] = _callback(_v, _k - 1, nextRows)
			end
			-- ▲ ReadonlyArray.map ▲
			return _newValue
		end)
		setSelectedId(function(current)
			-- ▼ ReadonlyArray.some ▼
			local _result = false
			local _callback = function(row)
				return row.UserId == current
			end
			for _k, _v in nextRows do
				if _callback(_v, _k - 1, nextRows) then
					_result = true
					break
				end
			end
			-- ▲ ReadonlyArray.some ▲
			return if _result then current else nextRows[1].UserId
		end)
	end, {})
	React.useEffect(function()
		refresh()
		applyLocalRoster()
		local debounce
		local requestRefresh = function()
			applyLocalRoster()
			if debounce ~= nil then
				task.cancel(debounce)
			end
			debounce = task.delay(0.35, function()
				debounce = nil
				if alive.current then
					refresh()
				end
			end)
		end
		local joined = Players.PlayerAdded:Connect(requestRefresh)
		local left = Players.PlayerRemoving:Connect(requestRefresh)
		local pulse = task.spawn(function()
			while alive.current do
				task.wait(10)
				if alive.current then
					refresh()
				end
			end
		end)
		return function()
			joined:Disconnect()
			left:Disconnect()
			if debounce ~= nil then
				task.cancel(debounce)
			end
			task.cancel(pulse)
		end
	end, { applyLocalRoster, refresh })
	-- ▼ ReadonlyArray.find ▼
	local _callback = function(row)
		return row.UserId == selectedId
	end
	local _result
	for _i, _v in rows do
		if _callback(_v, _i - 1, rows) == true then
			_result = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local _condition = _result
	if _condition == nil then
		_condition = rows[1]
	end
	local selected = _condition
	local _exp = function()
		local _result_1 = selected
		if _result_1 ~= nil then
			_result_1 = _result_1.IsLocal
		end
		if _result_1 then
			setInventoryOpen(false)
		end
	end
	local _result_1 = selected
	if _result_1 ~= nil then
		_result_1 = _result_1.IsLocal
	end
	React.useEffect(_exp, { _result_1 })
	local syncSocial = React.useCallback(function(userId)
		if userId == nil or userId == Players.LocalPlayer.UserId then
			return nil
		end
		local job = task.spawn(function()
			local nextFriends = {}
			local friendOk, isFriend = pcall(function()
				return (Players.LocalPlayer):IsFriendsWithAsync(userId)
			end)
			if friendOk and isFriend == true then
				local _userId = userId
				nextFriends[_userId] = true
			end
			local nextBlocked = {}
			local blockOk, raw = pcall(function()
				return Core:GetCore("GetBlockedUserIds")
			end)
			if blockOk and type(raw) == "table" then
				for _, value in raw do
					if type(value) == "number" then
						local _arg0 = math.floor(value)
						nextBlocked[_arg0] = true
					end
				end
			end
			if not alive.current then
				return nil
			end
			setFriends(nextFriends)
			setBlocked(nextBlocked)
		end)
		return function()
			return task.cancel(job)
		end
	end, {})
	local _exp_1 = function()
		if selected == nil or selected.IsLocal then
			return nil
		end
		local cancel = syncSocial(selected.UserId)
		local function replaceSocial()
			if cancel ~= nil then
				pcall(cancel)
			end
			cancel = syncSocial(selected.UserId)
		end
		local pulse = task.spawn(function()
			while alive.current do
				task.wait(4)
				if not alive.current then
					break
				end
				replaceSocial()
			end
		end)
		local friendship
		pcall(function()
			local localPlayer = Players.LocalPlayer
			friendship = localPlayer.FriendStatusChanged:Connect(function()
				if alive.current then
					replaceSocial()
				end
			end)
		end)
		return function()
			if cancel ~= nil then
				pcall(cancel)
			end
			pcall(task.cancel, pulse)
			local _result_3 = friendship
			if _result_3 ~= nil then
				_result_3:Disconnect()
			end
		end
	end
	local _result_2 = selected
	if _result_2 ~= nil then
		_result_2 = _result_2.IsLocal
	end
	local _result_3 = selected
	if _result_3 ~= nil then
		_result_3 = _result_3.UserId
	end
	React.useEffect(_exp_1, { _result_2, _result_3, syncSocial })
	local close = React.useCallback(function()
		if exiting then
			return nil
		end
		Audio:play("playerlistClose")
		beginExit(onClose)
	end, { beginExit, exiting, onClose })
	local prompt = function(kind)
		if selected == nil or selected.IsLocal then
			return nil
		end
		local player = Players:GetPlayerByUserId(selected.UserId)
		if player == nil then
			notify("Player left", "That player is no longer in this server.")
			return nil
		end
		local _result_4
		if kind == "friend" then
			local _userId = selected.UserId
			_result_4 = (if friends[_userId] ~= nil then "PromptUnfriend" else "PromptSendFriendRequest")
		else
			local _userId = selected.UserId
			_result_4 = (if blocked[_userId] ~= nil then "PromptUnblockPlayer" else "PromptBlockPlayer")
		end
		local key = _result_4
		local ok = pcall(function()
			return Core:SetCore(key, player)
		end)
		if not ok then
			notify("Roblox menu unavailable", "Wait a moment, then try again.")
		else
			Audio:play("playerlistAction")
		end
	end
	local submitReport = function()
		if selected == nil or selected.IsLocal or reportBusy then
			return nil
		end
		setReportBusy(true)
		Audio:play("dangerPress")
		dispatch("ReportPlayer", {
			UserId = selected.UserId,
			userId = selected.UserId,
			Reason = reportReason,
		}, function(response)
			if not alive.current then
				return nil
			end
			setReportBusy(false)
			if not response.ok then
				local _condition_1 = response.error
				if _condition_1 == nil then
					_condition_1 = "Please try again in a moment."
				end
				notify("Couldn't send report", _condition_1)
				return nil
			end
			setReportOpen(false)
			notify("Report sent", "Thanks for helping keep the server clean.")
		end)
	end
	local invite = function()
		if inviteBusy then
			return nil
		end
		setInviteBusy(true)
		Audio:play("invite")
		local checkDone = false
		local worker
		worker = task.defer(function()
			local canCheck, canInvite = pcall(function()
				return SocialService:CanSendGameInviteAsync(Players.LocalPlayer)
			end)
			checkDone = true
			if not alive.current then
				return nil
			end
			local opened = false
			if canCheck and canInvite == true then
				opened = pcall(function()
					return SocialService:PromptGameInvite(Players.LocalPlayer)
				end)
			end
			if not alive.current then
				return nil
			end
			setInviteBusy(false)
			if not opened then
				notify("Invites unavailable", "Roblox could not open the invite panel on this device.")
			end
		end)
		task.delay(8, function()
			if checkDone or not alive.current then
				return nil
			end
			pcall(task.cancel, worker)
			setInviteBusy(false)
			notify("Invites unavailable", "Roblox could not open the invite panel on this device.")
		end)
	end
	local padFocus = useGamepadAutofocus(true)
	local social = state.SocialBoost or {
		FriendCount = 0,
		FriendLimit = 5,
		FriendBonus = 0,
		Premium = false,
		PremiumBonus = 0,
		Multiplier = 1,
	}
	local side = math.max(chrome.sideSafe, viewport.sideInset, 8) + 6
	local top = math.max(viewport.topInset, 36) + 8
	local bottom = math.max(chrome.bottomSafe, viewport.bottomInset, 8) + 8
	local availableHeight = math.max(210, viewport.height - top - bottom)
	local compactWidth = viewport.width < 620
	local shortSurface = availableHeight < 380
	local width = math.max(286, math.min(if compactWidth then viewport.width - side * 2 else 440, viewport.width - side * 2))
	local headerH = 64
	local boostH = if shortSurface then 54 else 68
	local actionH = if selected ~= nil and not selected.IsLocal then (if reportOpen then (if shortSurface then 168 else 188) elseif inventoryOpen then (if shortSurface then 100 else 126) else 62) else 0
	local desiredListH = math.clamp(#rows * 64, 62, if shortSurface then 144 else 316)
	local desiredHeight = headerH + boostH + desiredListH + actionH + 30
	local height = math.min(availableHeight, desiredHeight)
	local listTop = headerH + boostH + 16
	local listH = math.max(54, height - listTop - actionH - 12)
	-- On a short surface the action panel (report form / inventory) cannot share the column
	-- with the player list — the old math parked it at `height - actionH - 8`, which landed it
	-- ON TOP of the list and the friend-boost strip, and its passive background let taps fall
	-- straight through to hidden rows underneath. When it genuinely doesn't fit below the list,
	-- take over the panel body instead and hide the list until the player backs out.
	local actionCovered = shortSurface and actionH > 0 and listTop + listH + 8 + actionH > height + 1
	local actionTop = if actionCovered then headerH + 8 else height - actionH - 8
	local showAmount = composePresence(enter, exitAmount)
	local panelPosition = showAmount:map(function(amount)
		return UDim2.new(1, -(side - math.round((1 - amount) * 18)), 0, top)
	end)
	local friendProgress = math.clamp(social.FriendCount / math.max(1, social.FriendLimit), 0, 1)
	local _exp_2 = React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = showAmount:map(function(amount)
			return 1 - amount * 0.44
		end),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 600,
	})
	local _exp_3 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	})
	local _exp_4 = React.createElement("uistroke", {
		Color = Palette.cyan,
		Thickness = 1.25,
		Transparency = showAmount:map(function(amount)
			return 1 - amount * 0.76
		end),
	})
	local _exp_5 = React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 610,
	})
	local _exp_6 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, headerH),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 611,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(4, 30),
		Position = UDim2.fromOffset(0, 17),
		BackgroundColor3 = Palette.cyan,
		BorderSizePixel = 0,
		ZIndex = 612,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement(Icon, {
		kind = "Pilot",
		color = Palette.cream,
		accent = Palette.cyan,
		size = 30,
		spin = false,
		position = UDim2.fromOffset(14, 17),
	}), React.createElement(Text, {
		value = "PLAYERLIST",
		size = 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(54, 8),
		sizeConstraint = UDim2.new(1, -112, 0, 24),
		zIndex = 613,
	}), React.createElement(Text, {
		value = `{#rows} ONLINE  •  PLAY TOGETHER FOR A PRODUCTION BOOST`,
		size = 10,
		color = Palette.cyan,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(54, 34),
		sizeConstraint = UDim2.new(1, -112, 0, 17),
		zIndex = 613,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(TapTarget, TapTarget),
		Position = UDim2.new(1, -(TapTarget + 7), 0, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 614,
	}, React.createElement(Button, {
		text = "",
		icon = "Close",
		onClick = close,
		color = Palette.ink,
		textColor = Palette.coral,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = exiting,
		zIndex = 614,
	})))
	local _exp_7 = React.createElement("frame", {
		Size = UDim2.new(1, -20, 0, boostH),
		Position = UDim2.fromOffset(10, headerH + 8),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ZIndex = 612,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 9),
	}), React.createElement("uistroke", {
		Color = Palette.mint,
		Thickness = 1,
		Transparency = 0.5,
	}), React.createElement(Text, {
		value = `FRIEND BOOST  {social.FriendCount}/{social.FriendLimit}  •  +{math.floor(social.FriendBonus * 100 + 0.5)}%`,
		size = 11,
		color = Palette.mint,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(10, if shortSurface then 5 else 8),
		sizeConstraint = UDim2.new(0.58, -14, 0, 18),
		zIndex = 613,
	}), not shortSurface and React.createElement(Text, {
		value = if social.Premium then `PREMIUM +{math.floor(social.PremiumBonus * 100 + 0.5)}%` else "PREMIUM BONUS OFF",
		size = 10,
		color = if social.Premium then Palette.mango else Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(10, 30),
		sizeConstraint = UDim2.new(0.58, -14, 0, 16),
		zIndex = 613,
	}), not shortSurface and React.createElement("frame", {
		Size = UDim2.new(0.54, -18, 0, 4),
		Position = UDim2.fromOffset(10, 51),
		BackgroundColor3 = Palette.lineSoft,
		BorderSizePixel = 0,
		ZIndex = 613,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = UDim2.new(friendProgress, 0, 1, 0),
		BackgroundColor3 = Palette.mint,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))), React.createElement("frame", {
		Size = UDim2.new(0.4, -7, 0, if shortSurface then 36 else 42),
		Position = UDim2.new(0.6, -1, 0.5, if shortSurface then -18 else -21),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 614,
	}, React.createElement(Button, {
		text = if inviteBusy then "OPENING" else "INVITE FRIENDS",
		icon = "Crew",
		onClick = invite,
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = inviteBusy,
		highlight = true,
		zIndex = 614,
	})))
	local _exp_8 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#rows)
	local _callback_1 = function(row, index)
		local _attributes = {
			key = row.UserId,
			player = row,
		}
		local _exp_9 = row.UserId
		local _result_4 = selected
		if _result_4 ~= nil then
			_result_4 = _result_4.UserId
		end
		_attributes.selected = _exp_9 == _result_4
		_attributes.onSelect = function()
			setSelectedId(row.UserId)
			setInventoryOpen(false)
			setReportOpen(false)
			Audio:play("playerlistSelect")
		end
		_attributes.layoutOrder = index
		_attributes.reducedMotion = reducedMotion
		_attributes.awayStamp = awayTick
		return React.createElement(PlayerRow, _attributes)
	end
	for _k, _v in rows do
		_newValue[_k] = _callback_1(_v, _k - 1, rows)
	end
	-- ▲ ReadonlyArray.map ▲
	local _exp_9 = React.createElement("scrollingframe", {
		Size = UDim2.new(1, -20, 0, listH),
		Position = UDim2.fromOffset(10, listTop),
		CanvasSize = UDim2.new(0, 0, 0, #rows * 64),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = not actionCovered,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Palette.cyan,
		ScrollBarImageTransparency = 0.32,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ClipsDescendants = true,
		Active = true,
		Selectable = false,
		ZIndex = 619,
	}, _exp_8, _newValue)
	local _condition_1 = selected ~= nil and not selected.IsLocal and actionH > 0
	if _condition_1 then
		local _exp_10 = React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 9),
		})
		local _exp_11 = React.createElement("uistroke", {
			Color = Palette.cyan,
			Thickness = 1,
			Transparency = 0.56,
		})
		local _result_4
		if reportOpen then
			local _exp_12 = React.createElement(Text, {
				value = `REPORT {string.upper(selected.DisplayName)}`,
				size = 12,
				color = Palette.coral,
				weight = Enum.FontWeight.Heavy,
				fit = true,
				minSize = 9,
				position = UDim2.fromOffset(10, 7),
				sizeConstraint = UDim2.new(1, -20, 0, 18),
				zIndex = 632,
			})
			local _exp_13 = React.createElement("uigridlayout", {
				CellSize = if shortSurface then UDim2.new(1 / 3, -4, 0, 28) else UDim2.new(0.5, -3, 0, 30),
				CellPadding = UDim2.new(0, 6, 0, 6),
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
			-- ▼ ReadonlyArray.map ▼
			local _newValue_1 = table.create(#REPORT_REASONS)
			local _callback_2 = function(reason)
				return React.createElement(Button, {
					key = reason,
					text = string.upper(reason),
					onClick = function()
						setReportReason(reason)
						Audio:play("tabSwitch")
					end,
					color = if reportReason == reason then Palette.coral else Palette.panelSoft,
					textColor = if reportReason == reason then Palette.ink else Palette.creamSoft,
					outline = reportReason ~= reason,
					size = UDim2.fromScale(1, 1),
					reducedMotion = reducedMotion,
					zIndex = 633,
				})
			end
			for _k, _v in REPORT_REASONS do
				_newValue_1[_k] = _callback_2(_v, _k - 1, REPORT_REASONS)
			end
			-- ▲ ReadonlyArray.map ▲
			_result_4 = React.createElement(React.Fragment, nil, _exp_12, React.createElement("frame", {
				Size = UDim2.new(1, -16, 0, if shortSurface then 62 else 108),
				Position = UDim2.fromOffset(8, 26),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 632,
			}, _exp_13, _newValue_1), React.createElement("frame", {
				Size = UDim2.new(1, -16, 0, 36),
				Position = UDim2.new(0, 8, 1, -42),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 633,
			}, React.createElement("frame", {
				Size = UDim2.new(0.4, -4, 1, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, React.createElement(Button, {
				text = "BACK",
				icon = "Back",
				onClick = function()
					Audio:play("playerlistSelect")
					setReportOpen(false)
				end,
				color = Palette.panelSoft,
				textColor = Palette.creamSoft,
				outline = true,
				size = UDim2.fromScale(1, 1),
				reducedMotion = reducedMotion,
				disabled = reportBusy,
				zIndex = 633,
			})), React.createElement("frame", {
				Size = UDim2.new(0.6, -4, 1, 0),
				Position = UDim2.new(0.4, 4, 0, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, React.createElement(Button, {
				text = if reportBusy then "SENDING..." else "SEND REPORT",
				icon = "Admin",
				onClick = submitReport,
				color = Palette.coral,
				textColor = Palette.ink,
				size = UDim2.fromScale(1, 1),
				reducedMotion = reducedMotion,
				disabled = reportBusy,
				highlight = true,
				zIndex = 633,
			}))))
		else
			local _result_5
			if inventoryOpen then
				_result_5 = React.createElement(React.Fragment, nil, React.createElement(Text, {
					value = `{selected.DisplayName}'S RELICS`,
					size = 12,
					color = Palette.violet,
					weight = Enum.FontWeight.Heavy,
					fit = true,
					minSize = 9,
					position = UDim2.fromOffset(10, 7),
					sizeConstraint = UDim2.new(1, -82, 0, 18),
					zIndex = 632,
				}), React.createElement(Text, {
					value = if #(selected.EquippedItems or {}) > 0 then table.concat((selected.EquippedItems or {}), ", ") else "No relics equipped.",
					size = 10,
					color = Palette.creamSoft,
					wrap = true,
					position = UDim2.fromOffset(10, 28),
					sizeConstraint = UDim2.new(1, -20, 0, if shortSurface then 30 else 46),
					zIndex = 632,
				}), React.createElement("frame", {
					Size = UDim2.new(1, -16, 0, 36),
					Position = UDim2.new(0, 8, 1, -42),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 633,
				}, React.createElement(Button, {
					text = "BACK TO PLAYER",
					icon = "Back",
					onClick = function()
						Audio:play("playerlistSelect")
						setInventoryOpen(false)
					end,
					color = Palette.panelSoft,
					textColor = Palette.creamSoft,
					outline = true,
					size = UDim2.fromScale(1, 1),
					reducedMotion = reducedMotion,
					zIndex = 633,
				})))
			else
				local _exp_12 = React.createElement(Text, {
					value = `@{selected.Name}  •  WORLD {compactNumber(selected.CurrentZone)}  •  {compactNumber(selected.Rebirths)} REBIRTHS`,
					size = 10,
					color = Palette.cyan,
					weight = Enum.FontWeight.Bold,
					fit = true,
					minSize = 9,
					position = UDim2.fromOffset(10, 5),
					sizeConstraint = UDim2.new(1, -46, 0, 16),
					zIndex = 632,
				})
				local _exp_13 = React.createElement("frame", {
					Size = UDim2.fromOffset(28, 20),
					Position = UDim2.new(1, -36, 0, 4),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 634,
				}, React.createElement(Button, {
					text = "",
					icon = "Admin",
					onClick = function()
						Audio:play("dangerPress")
						setReportOpen(true)
					end,
					color = Palette.panelSoft,
					textColor = Palette.coral,
					outline = true,
					size = UDim2.fromScale(1, 1),
					reducedMotion = reducedMotion,
					zIndex = 634,
				}))
				local _attributes = {}
				local _userId = selected.UserId
				_attributes.text = if friends[_userId] ~= nil then "UNFRIEND" else "ADD FRIEND"
				_attributes.icon = "Crew"
				_attributes.onClick = function()
					return prompt("friend")
				end
				_attributes.color = Palette.blue
				_attributes.textColor = Palette.ink
				_attributes.size = UDim2.fromScale(1, 1)
				_attributes.reducedMotion = reducedMotion
				_attributes.zIndex = 633
				local _exp_14 = React.createElement("frame", {
					Size = UDim2.new(1 / 3, -7, 0, 36),
					Position = UDim2.fromOffset(8, 22),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 633,
				}, React.createElement(Button, _attributes))
				local _attributes_1 = {}
				local _userId_1 = selected.UserId
				_attributes_1.text = if blocked[_userId_1] ~= nil then "UNBLOCK" else "BLOCK"
				_attributes_1.icon = "Close"
				_attributes_1.onClick = function()
					return prompt("block")
				end
				_attributes_1.color = Palette.coral
				_attributes_1.textColor = Palette.ink
				_attributes_1.size = UDim2.fromScale(1, 1)
				_attributes_1.reducedMotion = reducedMotion
				_attributes_1.zIndex = 633
				_result_5 = React.createElement(React.Fragment, nil, _exp_12, _exp_13, _exp_14, React.createElement("frame", {
					Size = UDim2.new(1 / 3, -7, 0, 36),
					Position = UDim2.new(1 / 3, 4, 0, 22),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 633,
				}, React.createElement(Button, _attributes_1)), React.createElement("frame", {
					Size = UDim2.new(1 / 3, -7, 0, 36),
					Position = UDim2.new(2 / 3, 3, 0, 22),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 633,
				}, React.createElement(Button, {
					text = "RELICS",
					icon = "Inventory",
					onClick = function()
						Audio:play("playerlistAction")
						setInventoryOpen(true)
					end,
					color = Palette.violet,
					textColor = Palette.cream,
					size = UDim2.fromScale(1, 1),
					reducedMotion = reducedMotion,
					zIndex = 633,
				})))
			end
			_result_4 = _result_5
		end
		_condition_1 = React.createElement("frame", {
			Size = UDim2.new(1, -20, 0, if actionCovered then math.max(actionH, height - headerH - 16) else actionH),
			Position = UDim2.fromOffset(10, actionTop),
			BackgroundColor3 = Palette.panelRaised,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 630,
		}, _exp_10, _exp_11, _result_4)
	end
	return React.createElement(OverlayPresence, {
		amount = showAmount,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 600,
		Visible = showAmount:map(function(amount)
			return amount > 0.003
		end),
	}, _exp_2, React.createElement("frame", {
		ref = padFocus,
		Size = UDim2.fromOffset(width, height),
		Position = panelPosition,
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = showAmount:map(function(amount)
			return 1 - amount
		end),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 610,
		Visible = showAmount:map(function(amount)
			return amount > 0.005
		end),
	}, _exp_3, _exp_4, _exp_5, _exp_6, _exp_7, _exp_9, _condition_1)))
end
return {
	PlayerlistOverlay = PlayerlistOverlay,
}
