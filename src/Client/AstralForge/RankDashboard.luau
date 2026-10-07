--!nocheck
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Math = require(game.ReplicatedStorage.AstralForge.Shared.OmegaMath)
local Social = require(game.ReplicatedStorage.AstralForge.Shared.SocialProgression)(Math)
local ui = require(script.Parent.UiCore)("ui")
local theme = require(script.Parent.CoreKit)("theme")
local compact = require(script.Parent.CoreKit)("format").compactNumber
local useViewport = require(script.Parent.MotionKit)("motion").useViewport
local Scaffold = require(script.Parent.LayoutKit)("pageScaffold").PageScaffold
local P = theme.Palette
local BOARD_CATEGORIES = {
	Flux = "Economy",
	Dust = "Economy",
	Cores = "Economy",
	Rebirths = "Prestige",
	Domain = "Prestige",
	PlayTime = "Social",
	Worlds = "Exploration",
	ItemsFound = "Exploration",
	Taps = "Progression",
	AnomalyPulses = "Combat",
	Combat = "Combat",
	OrdersCompleted = "Forge",
	Crafting = "Forge",
	CratesOpened = "Forge",
	ArcadeScore = "Arcade",
	BazaarDeals = "Bazaar",
	Seasonal = "Seasonal",
	Guilds = "Guild",
}
local CATEGORY_ORDER = {
	"Economy",
	"Progression",
	"Exploration",
	"Combat",
	"Forge",
	"Arcade",
	"Bazaar",
	"Seasonal",
	"Prestige",
	"Social",
	"Guild",
}
return function(helpers)
	return function(props)
		local viewport = useViewport()
		local selected, setSelected = React.useState("Flux")
		local category, setCategory = React.useState("All")
		local boardQuery, setBoardQuery = React.useState("")
		local scope, setScope = React.useState("Global")
		local revision, reload = React.useState(0)
		local result, setResult = React.useState({ rows = {}, loading = true, status = "Loading rankings…" })
		local guildBoard = selected == "Guilds"
		local meta = if guildBoard
			then {
				label = "Guild Halls",
				accent = P.violet,
				description = "Guild activity earned by banking and building together.",
			}
			else helpers.metaFor(selected)
		local localId = game.Players.LocalPlayer.UserId
		React.useEffect(function()
			local alive = true
			local pending = false
			local serial = 0
			local timer
			local function refresh()
				if not alive or pending then
					return
				end
				pending = true
				serial += 1
				local request = serial
				setResult(function(previous)
					return { rows = previous.rows, loading = true, status = "Refreshing rankings…" }
				end)
				local function finish(reply)
					if not alive or not pending or serial ~= request then
						return
					end
					pending = false
					serial += 1
					if type(reply) ~= "table" or reply.ok ~= true then
						setResult(function(previous)
							return {
								rows = previous.rows,
								loading = false,
								status = (type(reply) == "table" and (reply.error or reply.message))
									or "Rankings unavailable. Retry below.",
							}
						end)
						return
					end
					local entries = if guildBoard
						then reply.GuildLeaderboard or reply.Leaderboard
						else if scope == "Server"
							then helpers.serverEntries(reply.Players or {}, selected)
							else reply.Leaderboard
					local rows = Social.rank(entries or {}, guildBoard)
					if not guildBoard then
						local eligible = {}
						for _, row in rows do
							if helpers.scoreCounts(selected, row.Value) then
								table.insert(eligible, row)
							end
						end
						rows = eligible
					end
					setResult({
						rows = rows,
						loading = false,
						status = `Updated · {#rows} entries · {if guildBoard
							then "Guild activity"
							else scope .. " board"}`,
					})
				end
				task.delay(12, function()
					finish(nil)
				end)
				local action = if guildBoard
					then "GetGuildLeaderboard"
					elseif scope == "Server" then "GetPlayers"
					else "GetLeaderboard"
				local ok = pcall(props.dispatch, action, { Id = selected }, finish)
				if not ok then
					finish({ ok = false, error = "Rankings connection interrupted." })
				end
			end
			setResult({ rows = {}, loading = true, status = "Loading rankings…" })
			local function tick()
				refresh()
				timer = task.delay(30, tick)
			end
			tick()
			return function()
				alive = false
				serial += 1
				if timer then
					pcall(task.cancel, timer)
				end
			end
		end, { props.dispatch, selected, scope, revision })
		local rows = result.rows
		local own = if guildBoard
			then (props.state.Guild or {}).Activity or 0
			else helpers.ownValue(props.state, selected) or 0
		local personalIndex
		for index, row in rows do
			if
				(guildBoard and row.Id == (props.state.Guild or {}).Id) or (not guildBoard and row.UserId == localId)
			then
				personalIndex = index
				break
			end
		end
		local ahead = personalIndex and rows[personalIndex - 1]
		local gap = ahead and Math.Max(0, Math.Sub(ahead.Value, own))
		local sections = {}
		local function text(value, y, height, size, color)
			return React.createElement(ui.Text, {
				value = value,
				position = UDim2.fromOffset(0, y),
				sizeConstraint = UDim2.new(1, 0, 0, height),
				size = size or 14,
				color = color or P.cream,
				wrap = true,
			})
		end
		local function section(id, height, children, accent)
			table.insert(sections, {
				id = id,
				height = height,
				element = React.createElement(
					ui.Panel,
					{ size = UDim2.fromScale(1, 1), padding = 16, accent = accent or meta.accent },
					children
				),
			})
		end
		section("rank-summary", 200, {
			text("RANKS · YOUR POSITION", 0, 20, 12, meta.accent),
			text(meta.label, 28, 34, 24),
			text(
				if personalIndex
					then `#{personalIndex} in this board · {helpers.formatValue(selected, own)}`
					else `Your score: {helpers.formatValue(selected, own)} · Outside the returned board`,
				72,
				48,
				16
			),
			text(
				if gap
					then `Next position: {compact(gap)} more to match #{personalIndex - 1}. Equal scores use a stable ID order.`
					elseif personalIndex == 1 then "You lead this board. Keep building your record."
					else meta.description,
				128,
				40,
				12,
				P.creamSoft
			),
		})
		local boards = table.clone(helpers.boards)
		table.insert(boards, { id = "Guilds", short = "GUILDS", category = "Guild" })
		local categoryOptions =
			{ { id = "All", label = `ALL · {#boards}`, icon = "Leaderboard", accent = meta.accent } }
		for _, categoryId in CATEGORY_ORDER do
			local count = 0
			for _, board in boards do
				if (board.category or BOARD_CATEGORIES[board.id]) == categoryId then
					count += 1
				end
			end
			if count > 0 then
				table.insert(categoryOptions, {
					id = categoryId,
					label = `{string.upper(categoryId)} · {count}`,
					icon = "Leaderboard",
					accent = meta.accent,
				})
			end
		end
		local visibleBoards = {}
		local needle = string.lower((string.gsub(boardQuery, "^%s*(.-)%s*$", "%1")))
		for _, board in boards do
			local boardCategory = board.category or BOARD_CATEGORIES[board.id] or "Other"
			local matchesCategory = category == "All" or boardCategory == category
			local matchesSearch = needle == ""
				or string.find(
						string.lower(`{board.short} {board.label or board.id} {boardCategory}`),
						needle,
						1,
						true
					)
					~= nil
			if matchesCategory and matchesSearch then
				table.insert(visibleBoards, board)
			end
		end
		local boardTabs = {}
		local columns = if viewport.width < 600 then 2 else 4
		for index, board in visibleBoards do
			boardTabs[index] = React.createElement(ui.Button, {
				text = board.short,
				size = UDim2.new(1 / columns, -6, 0, 48),
				position = UDim2.new(((index - 1) % columns) / columns, 0, 0, math.floor((index - 1) / columns) * 56),
				color = if selected == board.id then board.accent or meta.accent else P.panelSoft,
				onClick = function()
					setSelected(board.id)
					setCategory(board.category or BOARD_CATEGORIES[board.id] or "Other")
				end,
			})
		end
		local categoryColumns = if viewport.width < 600 then 2 else 4
		local categoryTabs = React.createElement(ui.SegmentedTabs, {
			options = categoryOptions,
			value = category,
			onChange = function(nextCategory)
				setCategory(nextCategory)
				for _, board in boards do
					if nextCategory == "All" or (board.category or BOARD_CATEGORIES[board.id]) == nextCategory then
						setSelected(board.id)
						break
					end
				end
			end,
			columns = categoryColumns,
			gap = 6,
			size = UDim2.new(1, 0, 0, math.ceil(#categoryOptions / categoryColumns) * 44),
			accent = meta.accent,
		})
		section("rank-category-groups", math.ceil(#categoryOptions / categoryColumns) * 44 + 18, categoryTabs)
		section(
			"rank-board-search",
			62,
			React.createElement(ui.SearchField, {
				value = boardQuery,
				onChange = setBoardQuery,
				placeholder = "Find a board",
				accent = meta.accent,
				size = UDim2.new(1, 0, 0, 42),
				position = UDim2.fromOffset(0, 0),
				clearButton = true,
			})
		)
		if #visibleBoards > 0 then
			section("rank-boards", math.ceil(#visibleBoards / columns) * 56 + 24, boardTabs)
		else
			section("rank-boards-empty", 68, {
				text("No boards match that search.", 0, 36, 14, P.creamSoft),
			})
		end
		local controls = { text(result.status or "Rankings unavailable.", 0, 42, 12, P.creamSoft) }
		for index, id in { "Global", "Server" } do
			controls[index + 1] = React.createElement(ui.Button, {
				text = string.upper(id),
				position = UDim2.new((index - 1) / 3, 0, 0, 48),
				size = UDim2.new(1 / 3, -6, 0, 48),
				disabled = guildBoard,
				color = if scope == id then meta.accent else P.panelSoft,
				onClick = function()
					setScope(id)
				end,
			})
		end
		controls[4] = React.createElement(ui.Button, {
			text = if result.loading then "LOADING…" else "REFRESH",
			position = UDim2.new(2 / 3, 0, 0, 48),
			size = UDim2.new(1 / 3, -6, 0, 48),
			disabled = result.loading,
			onClick = function()
				reload(function(v)
					return v + 1
				end)
			end,
			color = P.mint,
		})
		section("rank-controls", 128, controls)
		if #rows == 0 then
			section("rank-empty", 136, {
				text(if result.loading then "Finding the current leaders…" else "No entries returned", 0, 40, 20),
				text(
					"Try another category, switch scope, or refresh. Rankings update periodically.",
					48,
					56,
					14,
					P.creamSoft
				),
			})
		end
		for index, row in rows do
			local mine = if guildBoard then row.Id == (props.state.Guild or {}).Id else row.UserId == localId
			local accent = if mine
				then P.mint
				elseif index == 1 then P.mango
				elseif index <= 3 then P.cyan
				else meta.accent
			section(`rank-row-{index}`, 116, {
				text(`#{index} · {row.Name or "Unknown pilot"}{if mine then " · YOU" else ""}`, 0, 38, 17, accent),
				text(
					if guildBoard
						then `[{row.Tag or "…"}] · {compact(row.Value)} activity`
						else helpers.formatValue(selected, row.Value),
					46,
					36,
					16,
					P.creamSoft
				),
			}, accent)
		end
		return React.createElement(
			Scaffold,
			{ sections = sections, gap = 10, tailPad = 80, scrollBarColor = meta.accent, scrollBarThickness = 4 }
		)
	end
end
