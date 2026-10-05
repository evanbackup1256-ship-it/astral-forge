--!nocheck
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Math = require(game.ReplicatedStorage.AstralForge.Shared.OmegaMath)
local Model = require(script.Parent.UpgradeModel)(Math)
local createQueue = require(script.Parent.PurchaseQueue)
local ui = require(script.Parent.UiCore)("ui")
local theme = require(script.Parent.CoreKit)("theme")
local format = require(script.Parent.CoreKit)("format")
local Tools = { Model = Model }

function Tools.useBatch(dispatch, action, entries, amount, cash)
	local _, refresh = React.useState(0)
	local queue = React.useMemo(function()
		return createQueue(dispatch, task.delay, function()
			refresh(function(value)
				return value + 1
			end)
		end)
	end, { dispatch, action })
	React.useEffect(function()
		return function()
			queue.cancel()
		end
	end, { queue })
	local orders, remaining = Model.plan(entries, amount, cash)
	return {
		busy = queue.busy,
		status = queue.status,
		count = #orders,
		remaining = remaining,
		start = function()
			return queue.start(action, orders)
		end,
		buy = function(id)
			if queue.busy then
				return
			end
			return dispatch(action, { Id = id, Amount = format.amountPayload(amount) })
		end,
	}
end

function Tools.ResearchControls(props)
	local height = if props.stack then 164 else 96
	return React.createElement(
		ui.Panel,
		{ accent = theme.Palette.cyan, size = UDim2.fromScale(1, 1), clips = false },
		React.createElement(ui.SearchField, {
			value = props.query,
			onChange = props.setQuery,
			placeholder = "Search research and bonuses",
			accent = theme.Palette.cyan,
			reducedMotion = props.reducedMotion,
			position = UDim2.fromOffset(0, 0),
			size = if props.stack then UDim2.new(1, 0, 0, theme.TapTarget) else UDim2.new(1, -220, 0, 36),
			zIndex = 32,
		}),
		React.createElement(ui.Dropdown, {
			options = {
				{ id = "Available", label = "Available" },
				{ id = "Affordable", label = "Can afford" },
				{ id = "Owned", label = "Owned" },
				{ id = "Next", label = "Coming up" },
				{ id = "All", label = "All research" },
			},
			value = props.filter,
			onChange = props.setFilter,
			accent = theme.Palette.cyan,
			reducedMotion = props.reducedMotion,
			position = if props.stack then UDim2.fromOffset(0, theme.TapTarget + 8) else UDim2.new(1, -208, 0, 0),
			size = if props.stack then UDim2.new(1, 0, 0, theme.TapTarget) else UDim2.fromOffset(208, 36),
			zIndex = 44,
		}),
		React.createElement(ui.Text, {
			value = if props.batch.busy or props.batch.status ~= ""
				then props.batch.status
				else `{props.count} results · Batch {props.batch.count} upgrades · Max: shared budget, 50 levels each`,
			size = 11,
			color = theme.Palette.creamSoft,
			fit = true,
			position = UDim2.fromOffset(0, if props.stack then height - 44 else 46),
			sizeConstraint = UDim2.new(1, 0, 0, 20),
		})
	)
end

function Tools.Planner(props)
	local best
	for _, entry in props.entries do
		if
			Model.quote(entry, props.amount, props.cash).ready
			and (best == nil or Model.returnScore(entry) > Model.returnScore(best))
		then
			best = entry
		end
	end
	return React.createElement(
		ui.Panel,
		{ accent = props.accent, size = UDim2.fromScale(1, 1) },
		React.createElement(ui.Text, {
			value = if best then `BEST NEXT-LEVEL RETURN · {best.config.Name}` else "PLAN YOUR NEXT PURCHASE",
			size = 13,
			weight = Enum.FontWeight.Heavy,
			color = theme.Palette.cream,
			fit = true,
			sizeConstraint = UDim2.new(1, 0, 0, 24),
		}),
		React.createElement(ui.Text, {
			value = if props.batch.busy or props.batch.status ~= ""
				then props.batch.status
				elseif props.batch.count > 0 then `Batch: {props.batch.count} upgrades · leaves {format.compactNumber(
					props.batch.remaining
				)} Flux`
				else "No upgrades fit your selected amount. Try a smaller amount or collect your vault.",
			size = 12,
			color = theme.Palette.creamSoft,
			wrap = true,
			position = UDim2.fromOffset(0, 30),
			sizeConstraint = UDim2.new(1, 0, 0, 34),
		}),
		React.createElement(ui.Text, {
			value = "Up to 24 upgrades per batch. Max shares budget, up to 50 levels each. Return compares one next level, excludes bonuses.",
			size = 10,
			color = theme.Palette.muted,
			wrap = true,
			position = UDim2.fromOffset(0, 70),
			sizeConstraint = UDim2.new(1, 0, 0, 28),
		})
	)
end

return Tools
