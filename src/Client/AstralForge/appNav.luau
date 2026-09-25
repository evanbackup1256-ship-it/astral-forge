-- appNav.ts
local scaledCost = require(script.Parent.format).scaledCost
local gteFlux = require(script.Parent.format).gteFlux
local Palette = require(script.Parent.theme).Palette
local NavRouteTable = require(script.Parent.navRouteTable)

local function withAccent(route)
	local accent = Palette[route.accentKey]
	if accent == nil then
		accent = Palette.green
	end
	return {
		id = route.id,
		label = route.label,
		eyebrow = route.eyebrow,
		icon = route.icon,
		accent = accent,
	}
end

local PRIMARY_NAV = table.create(#NavRouteTable.PRIMARY_ROUTES)
for index, route in NavRouteTable.PRIMARY_ROUTES do
	PRIMARY_NAV[index] = withAccent(route)
end
local MORE_NAV = table.create(#NavRouteTable.MORE_ROUTES)
for index, route in NavRouteTable.MORE_ROUTES do
	MORE_NAV[index] = withAccent(route)
end
local _array = {}
local _length = #_array
local _pRIMARY_NAVLength = #PRIMARY_NAV
table.move(PRIMARY_NAV, 1, _pRIMARY_NAVLength, _length + 1, _array)
_length += _pRIMARY_NAVLength
table.move(MORE_NAV, 1, #MORE_NAV, _length + 1, _array)
local NAV = _array
local AppHelpers
AppHelpers = {
	isPassiveRequest = function(self, action)
		local _condition = string.sub(action, 1, 3) == "Get"
		if not _condition then
			local _action = action
			_condition = table.find({ "SyncShop", "MeasureLatency", "ReportClientIntegrity", "ReportPerformance" }, _action) ~= nil
		end
		return _condition
	end,
	actionSignature = function(self, action, value)
		local fields = { "Id", "Key", "Index", "Code", "Channel", "Target", "Uid", "ChoiceId", "Slot", "Tier", "Level", "Role", "UserId", "MachineId" }
		-- ▼ ReadonlyArray.filter ▼
		local _newValue = {}
		local _callback = function(f)
			return value[f] ~= nil
		end
		local _length_1 = 0
		for _k, _v in fields do
			if _callback(_v, _k - 1, fields) == true then
				_length_1 += 1
				_newValue[_length_1] = _v
			end
		end
		-- ▲ ReadonlyArray.filter ▲
		-- ▼ ReadonlyArray.map ▼
		local _newValue_1 = table.create(#_newValue)
		local _callback_1 = function(f)
			return `{f}={tostring(value[f])}`
		end
		for _k, _v in _newValue do
			_newValue_1[_k] = _callback_1(_v, _k - 1, _newValue)
		end
		-- ▲ ReadonlyArray.map ▲
		local parts = _newValue_1
		return `{action}:{table.concat(parts, "|")}`
	end,
	pageAccent = function(self, page)
		-- ▼ ReadonlyArray.find ▼
		local _callback = function(e)
			return e.id == page
		end
		local _result
		for _i, _v in NAV do
			if _callback(_v, _i - 1, NAV) == true then
				_result = _v
				break
			end
		end
		-- ▲ ReadonlyArray.find ▲
		local entry = _result
		return if entry then entry.accent else Palette.green
	end,
	pageEntry = function(self, page)
		-- ▼ ReadonlyArray.find ▼
		local _callback = function(e)
			return e.id == page
		end
		local _result
		for _i, _v in NAV do
			if _callback(_v, _i - 1, NAV) == true then
				_result = _v
				break
			end
		end
		-- ▲ ReadonlyArray.find ▲
		local _condition = _result
		if not _condition then
			_condition = NAV[1]
		end
		return _condition
	end,
	boostEffectText = function(self, boost)
		if boost.Multiplier ~= nil and boost.CapacityMultiplier ~= nil then
			return `{boost.Multiplier}x output + {boost.CapacityMultiplier}x vault`
		end
		if boost.Multiplier ~= nil then
			return `{boost.Multiplier}x output`
		end
		if boost.CapacityMultiplier ~= nil then
			return `{boost.CapacityMultiplier}x vault capacity`
		end
		return "Temporary production perk"
	end,
	featureUnlocked = function(self, state, featureId)
		local _unlock = state.FeatureUnlocks
		if _unlock ~= nil then
			_unlock = _unlock[featureId]
		end
		local unlock = _unlock
		local _result = unlock
		if _result ~= nil then
			_result = _result.Unlocked
		end
		return _result ~= false
	end,
	nextUnlock = function(self, state)
		local ids = { "Research", "Mail", "Rewards", "Story", "Missions", "Worlds", "Wheel", "Shop", "StarGrid", "Milestones", "Rebirth", "Trade", "Echoes", "Anomaly", "Command", "Crew", "Lab", "Convergence", "Domain", "Continuum", "Credits" }
		for _, id in ids do
			local _lock = state.FeatureUnlocks
			if _lock ~= nil then
				_lock = _lock[id]
			end
			local lock = _lock
			if lock and not lock.Unlocked then
				return lock
			end
		end
		return nil
	end,
	navUnlocked = function(self, state, pageId, tutorialPage)
		if pageId == "Trade" then
			return true
		end
		local entry = AppHelpers:pageEntry(pageId)
		if entry.disabled then
			return false
		end
		local _lock = state.FeatureUnlocks
		if _lock ~= nil then
			_lock = _lock[pageId]
		end
		local lock = _lock
		local _result = lock
		if _result ~= nil then
			_result = _result.Unlocked
		end
		local unlocked = _result ~= false
		local _result_1 = state.Flags
		if _result_1 ~= nil then
			_result_1 = _result_1.TutorialDone
		end
		local _condition = _result_1 ~= true
		if _condition then
			_condition = tutorialPage == pageId
		end
		local tutorialOverride = _condition
		return unlocked or tutorialOverride
	end,
	filterNav = function(self, entries, state, tutorialPage)
		local visible = {}
		local seen = {}
		for _, entry in entries do
			local id = entry.id
			if seen[id] ~= nil then
				continue
			end
			local _condition = id == "Admin"
			if _condition then
				local _result = state.Admin
				if _result ~= nil then
					_result = _result.Access
				end
				_condition = _result ~= true
			end
			if _condition then
				continue
			end
			local _lock = state.FeatureUnlocks
			if _lock ~= nil then
				_lock = _lock[id]
			end
			local lock = _lock
			local _result = state.Flags
			if _result ~= nil then
				_result = _result.TutorialDone
			end
			local _condition_1 = _result ~= true
			if _condition_1 then
				_condition_1 = tutorialPage == id
			end
			local tutorialOverride = _condition_1
			local unlocked = id == "Trade"
			if not unlocked then
				local _result_1 = lock
				if _result_1 ~= nil then
					_result_1 = _result_1.Unlocked
				end
				unlocked = _result_1 ~= false
				if not unlocked then
					unlocked = tutorialOverride
				end
			end
			if unlocked then
				seen[id] = true
				table.insert(visible, entry)
			end
		end
		return visible
	end,
	visibleNav = function(self, state, tutorialPage)
		local _array_1 = {}
		local _length_1 = #_array_1
		local _pRIMARY_NAVLength_1 = #PRIMARY_NAV
		table.move(PRIMARY_NAV, 1, _pRIMARY_NAVLength_1, _length_1 + 1, _array_1)
		_length_1 += _pRIMARY_NAVLength_1
		table.move(MORE_NAV, 1, #MORE_NAV, _length_1 + 1, _array_1)
		return AppHelpers:filterNav(_array_1, state, tutorialPage)
	end,
	navBadge = function(self, entry, state, chatUnread)
		local id = entry.id
		if id == "Trade" then
			local _result = state.Trade
			if _result ~= nil then
				_result = _result.Invite
			end
			return if _result then 1 else 0
		end
		if id == "Inventory" then
			local _keys = state.Items
			if _keys ~= nil then
				_keys = _keys.Keys
			end
			local keys = _keys
			if not keys then
				return 0
			end
			local count = 0
			for _, value in pairs(keys) do
				if type(value) == "number" and value > 0 then
					count += 1
				end
			end
			return count
		end
		if id == "Chat" then
			return chatUnread
		end
		if id == "Mail" then
			local _result = state.Mailbox
			if _result ~= nil then
				_result = _result.Unread
			end
			local _condition = _result
			if _condition == nil then
				_condition = 0
			end
			return _condition
		end
		if id == "Echoes" then
			local echoes = state.ForgeEchoes
			local _result = echoes
			if _result ~= nil then
				_result = _result.Ready
			end
			if _result == true then
				return 1
			end
			local _result_1 = echoes
			if _result_1 ~= nil then
				_result_1 = _result_1.Choices
				if _result_1 ~= nil then
					_result_1 = #_result_1
				end
			end
			local _condition = _result_1
			if _condition == nil then
				_condition = 0
			end
			local choiceCount = _condition
			return if choiceCount > 0 then 1 else 0
		end
		if id == "Convergence" then
			local _result = state.Convergence
			if _result ~= nil then
				_result = _result.Tiers
			end
			local _condition = _result
			if _condition == nil then
				_condition = {}
			end
			local tiers = _condition
			local count = 0
			for _, tier in tiers do
				if tier.CanClaim then
					count += 1
				end
			end
			return count
		end
		if id == "Story" then
			local claimable = 0
			local unreadTeaser = 0
			local chapters = state.Story or {}
			for _, chapter in chapters do
				if not chapter.Unlocked then
					continue
				end
				if chapter.Read and not chapter.Claimed then
					claimable += 1
				elseif not chapter.Read and unreadTeaser == 0 then
					unreadTeaser = 1
				end
			end
			return claimable + unreadTeaser
		end
		if id == "Command" then
			local cmd = state.Command
			if not cmd then
				return 0
			end
			local count = if #cmd.ClaimableCommanderLevels > 0 then 1 else 0
			for _, directive in cmd.Weekly do
				if not directive.Claimed and directive.Progress >= directive.Target then
					count += 1
				end
			end
			if cmd.ActiveExpedition and cmd.ActiveExpedition.Id ~= "" and os.time() >= cmd.ActiveExpedition.EndsAt then
				count += 1
			end
			return count
		end
		return 0
	end,
	worldWindow = {
		chunk = 5,
		maxMounted = 15,
	},
	formatWorldMultiplier = function(self, value)
		local rounded = math.floor(value * 100 + 0.5) / 100
		if rounded % 1 == 0 then
			return tostring(math.floor(rounded))
		end
		if (rounded * 10) % 1 == 0 then
			return string.format("%.1f", rounded)
		end
		return string.format("%.2f", rounded)
	end,
	worldWindowAround = function(self, currentIdx, total, count)
		if count == nil then
			count = 5
		end
		if total <= 0 then
			return {
				start = 0,
				count = 0,
			}
		end
		local size = math.clamp(count, 1, math.min(total, 15))
		local start = math.clamp(currentIdx - math.floor((size - 1) / 2), 0, math.max(0, total - size))
		return {
			start = start,
			count = size,
		}
	end,
	trimFarLockedUpgrades = function(self, entries)
		local out = {}
		local lockedShown = 0
		for _, entry in entries do
			if entry.unlocked or entry.level > 0 then
				table.insert(out, entry)
			elseif lockedShown < 12 then
				table.insert(out, entry)
				lockedShown += 1
			end
		end
		return out
	end,
	buildUpgradeEntries = function(self, configs, levels, state, _buyAmount, limit)
		local names = {}
		for _, item in configs do
			local _id = item.Id
			local _name = item.Name
			names[_id] = _name
		end
		local entries = {}
		for index = 0, #configs - 1 do
			if limit ~= nil and index >= limit then
				break
			end
			local item = configs[index + 1]
			local _condition = levels[item.Id]
			if _condition == nil then
				_condition = 0
			end
			local level = _condition
			local price = scaledCost(item.BaseCost, item.CostScale, level)
			local maxed = level >= item.MaxLevel
			local lockReason = ""
			local lockShort = ""
			local _condition_1 = item.RequiredZone
			if _condition_1 == nil then
				_condition_1 = 1
			end
			local requiredZone = _condition_1
			local zone = state.Zone
			if type(zone) ~= "number" then
				zone = 0
			end
			if zone < requiredZone then
				lockReason = `Reach World {requiredZone}`
			else
				local _condition_2 = item.RequiredRebirths
				if _condition_2 == nil then
					_condition_2 = 0
				end
				local requiredRebirths = _condition_2
				local rebirths = state.Rebirths
				if type(rebirths) ~= "number" then
					rebirths = 0
				end
				if rebirths < requiredRebirths then
					lockReason = `Complete {requiredRebirths} rebirth{if requiredRebirths == 1 then "" else "s"}`
				elseif item.PreviousId ~= nil then
					local _condition_3 = levels[item.PreviousId]
					if _condition_3 == nil then
						_condition_3 = 0
					end
					local prevLevel = _condition_3
					local _condition_4 = item.PreviousLevel
					if _condition_4 == nil then
						_condition_4 = 1
					end
					local needLevel = _condition_4
					if prevLevel < needLevel then
						local _previousId = item.PreviousId
						local _condition_5 = names[_previousId]
						if _condition_5 == nil then
							_condition_5 = item.PreviousId
						end
						local prevName = _condition_5
						lockReason = `Get {prevName} to level {needLevel}. You have {prevLevel}.`
						lockShort = `Need level {needLevel}`
					end
				end
			end
			local unlocked = lockReason == ""
			local _arg0 = {
				config = item,
				level = level,
				price = price,
				maxed = maxed,
				unlocked = unlocked,
				lockReason = lockReason,
				lockShort = lockShort,
				affordable = unlocked and not maxed and gteFlux(state.Cash, price),
				order = index,
			}
			table.insert(entries, _arg0)
		end
		return entries
	end,
	reserveId = function(self, value)
		if value >= 0.625 then
			return "HIGH"
		end
		if value >= 0.375 then
			return "HALF"
		end
		if value >= 0.125 then
			return "SAFE"
		end
		return "NONE"
	end,
	reserveValue = function(self, id)
		if id == "HIGH" then
			return 0.75
		end
		if id == "HALF" then
			return 0.5
		end
		if id == "SAFE" then
			return 0.25
		end
		return 0
	end,
}
return {
	PRIMARY_NAV = PRIMARY_NAV,
	MORE_NAV = MORE_NAV,
	NAV = NAV,
	AppHelpers = AppHelpers,
}
