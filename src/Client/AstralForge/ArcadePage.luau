--!strict
-- Purpose: Working score-only arcade controls, persistent-round recovery and history; replaces retired wager UI.
-- Owner: Astral Forge presentation. Dependencies: shared arcade schemas, UiCore/MotionKit/LayoutKit/React. Last-reviewed: 2026-10-05.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReactTypes = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts-js"].React)
local Types = require("@game/ReplicatedStorage/AstralForge/Shared/ArcadeTypes")
local Registry = require("@game/ReplicatedStorage/AstralForge/Shared/RemoteRegistry")
local Config = require("@game/ReplicatedStorage/AstralForge/Shared/ArcadeConfig")
local QuantumBoard = require("@game/ReplicatedStorage/AstralForge/Shared/ArcadeQuantumBoard")
local cardName = require("./ArcadeText").cardName
local Hash = require("@game/ReplicatedStorage/AstralForge/Shared/ProofHash")
local Fair = require("@game/ReplicatedStorage/AstralForge/Shared/FairRandom")(Hash)
local ArcadeViewport = require(script.Parent.ArcadeViewport)
local ui = require(script.Parent.UiCore)("ui")
local motion = require(script.Parent.MotionKit)("motion")
local Palette = require(script.Parent.CoreKit)("theme").Palette
local PageScaffold = require(script.Parent.LayoutKit)("pageScaffold").PageScaffold
local Http = game:GetService("HttpService")
type Element = ReactTypes.ReactElement<{}, string>
type Children = { [string]: Element }
type Dispatch = (string, Registry.TableValue?, ((Types.Reply) -> ())?) -> ()
export type Props = { state: { Arcade: Types.PublicState? }, dispatch: Dispatch, reducedMotion: boolean? }
type Section = { id: string, height: number, element: Element }
type Ref<T> = { current: T }

local function towerCardName(rank: number): string
	return ({ "Ace", "2", "3", "4", "5", "6", "7", "8", "9", "10", "Jack", "Queen", "King" })[rank] or "Card"
end

local function towerTotal(cards: Types.Numbers): number
	local value, aces = 0, 0
	for _, card in cards do
		value += math.min(card, 10)
		if card == 1 then
			aces += 1
		end
	end
	if aces > 0 and value + 10 <= 21 then
		value += 10
	end
	return value
end

local function ArcadePage(props: Props): Element
	local data: Types.PublicState?, setData: (Types.PublicState?) -> () = React.useState(props.state.Arcade)
	local gameId: Types.GameId, setGame: (Types.GameId) -> () = React.useState("Slots")
	local choice: string, setChoice: (string) -> () = React.useState("7")
	local seed: string, setSeed: (string) -> () = React.useState(Http:GenerateGUID(false))
	local held: { [number]: boolean }, setHeld: ({ [number]: boolean }) -> () = React.useState({})
	local towerSlots: number, setTowerSlots: (number) -> () = React.useState(3)
	local status: string, setStatus: (string) -> () = React.useState("Loading arcade…")
	local busy: boolean, setBusy: (boolean) -> () = React.useState(false)
	local mounted: Ref<boolean> = React.useRef(true)
	local busyRef: Ref<boolean> = React.useRef(false)
	local attempt: Ref<number> = React.useRef(0)
	local pending: Ref<Registry.TableValue?> = React.useRef(nil)
	local viewport = motion.useViewport()
	local reducedMotion = props.reducedMotion == true
	local softMotion = reducedMotion or motion.useMotionSettings().soft == true
	local active = data and data.Active
	local selected = if active then active.Game else gameId
	local quantumRounds = 0
	if data then
		local quantumStats = data.Stats.ByGame.QuantumRoulette
		if quantumStats then
			quantumRounds = quantumStats.Played
		end
	end
	local quantumBoard = QuantumBoard.of(quantumRounds)
	local definition = Config.Games[1]
	for _, entry in Config.Games do
		if entry.Id == selected then
			definition = entry
		end
	end
	local accent = Palette[definition.Accent] or Palette.cyan
	local function receive(response: Types.Reply): ()
		if response.Arcade then
			setData(response.Arcade)
		end
		setStatus(
			if response.ok
				then response.message or "Ready to play."
				else response.error or "The request could not finish."
		)
	end
	local function refresh(): ()
		props.dispatch("GetArcade", {}, function(response: Types.Reply): ()
			if mounted.current then
				receive(response)
			end
		end)
	end
	React.useEffect(function(): () -> ()
		mounted.current = true
		refresh()
		return function(): ()
			mounted.current = false
			attempt.current += 1
		end
	end, {})
	React.useEffect(function(): ()
		if props.state.Arcade then
			setData(props.state.Arcade)
		end
	end, { props.state.Arcade })
	local function send(payload: Registry.TableValue): ()
		if busyRef.current then
			return
		end
		pending.current = payload
		busyRef.current = true
		setBusy(true)
		setStatus("Confirming your action…")
		attempt.current += 1
		local token = attempt.current
		local function finish(response: Types.Reply): ()
			if not mounted.current or token ~= attempt.current then
				return
			end
			attempt.current += 1
			busyRef.current = false
			setBusy(false)
			if response.ok then
				pending.current = nil
				setHeld({})
			end
			receive(response)
		end
		task.delay(18, function(): ()
			finish({ ok = false, error = "Still waiting for confirmation. Retry keeps the same action ID." })
		end)
		local ok = pcall(props.dispatch, "ArcadePlay", payload, finish)
		if not ok then
			finish({ ok = false, error = "Connection interrupted. Retry your action." })
		end
	end
	local function play(action: string, selectedChoice: Types.Selection?): ()
		if not data then
			refresh()
			return
		end
		local payload: Registry.TableValue = { RequestId = Http:GenerateGUID(false), Game = selected, Action = action }
		if active then
			payload.RoundId = active.Id
			payload.Version = active.Version
		else
			payload.Commitment = data.Commitment
			payload.Nonce = data.Nonce
			payload.ClientSeed = seed
		end
		if selectedChoice ~= nil then
			payload.Choice = selectedChoice
		end
		if selected == "Keno" and action == "Start" then
			local picks: Registry.TableValue = {}
			for entry in choice:gmatch("[^,%s]+") do
				local number = tonumber(entry)
				if not number then
					setStatus("Enter numbers separated by commas.")
					return
				end
				table.insert(picks, number)
			end
			payload.Picks = picks
		elseif selected == "Mines" and action == "Start" then
			payload.Risk = tonumber(choice) or 5
		elseif selected == "Poker" and action == "Draw" then
			local picks: Registry.TableValue = {}
			for index = 1, 5 do
				if held[index] then
					table.insert(picks, index)
				end
			end
			payload.Picks = picks
		end
		send(payload)
	end
	local function button(
		text: string,
		onClick: () -> (),
		at: UDim2,
		size: UDim2,
		disabled: boolean?,
		customColor: Color3?
	): Element
		return React.createElement(ui.Button, {
			text = text,
			onClick = onClick,
			position = at,
			size = size,
			color = customColor or accent,
			textColor = Palette.ink,
			disabled = busy or disabled == true,
			reducedMotion = softMotion,
			sound = "button",
		})
	end
	local tabs: Children = {}
	local columns = if viewport.width < 700 then 2 else 5
	for index, entry in Config.Games do
		tabs[entry.Id] = button(
			entry.Name,
			function(): ()
				setGame(entry.Id)
				setChoice(
					if entry.Id == "Roulette"
						then "12"
						elseif entry.Id == "TableRoulette" then "12"
						elseif entry.Id == "QuantumRoulette" then "1"
						elseif entry.Id == "DiceTable" then "7"
						elseif entry.Id == "Keno" then "1, 7, 12, 19, 25"
						elseif entry.Id == "Mines" then "5"
						else "7"
				)
				if entry.Id == "CardTower" then
					setTowerSlots(3)
				end
				setHeld({})
			end,
			UDim2.new(((index - 1) % columns) / columns, 0, 0, math.floor((index - 1) / columns) * 54),
			UDim2.new(1 / columns, -8, 0, 46),
			active ~= nil
		)
	end
	local sections: { Section } = {
		{
			id = "heading",
			height = 80,
			element = React.createElement(ui.Text, {
				value = "Arcade\nFree rounds. Play for scores; no wagers or payouts.",
				size = 21,
				weight = Enum.FontWeight.Heavy,
				wrap = true,
				sizeConstraint = UDim2.fromScale(1, 1),
			}),
		},
		{
			id = "games",
			height = math.ceil(#Config.Games / columns) * 54,
			element = React.createElement("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, tabs),
		},
		{
			id = "game-scene",
			height = 248,
			element = React.createElement(
				ui.Panel,
				{ size = UDim2.fromScale(1, 1), padding = 14, accent = accent, reducedMotion = softMotion },
				{
					Label = React.createElement(ui.Text, {
						value = definition.Name .. " · 3D preview",
						size = 12,
						weight = Enum.FontWeight.Bold,
						position = UDim2.fromOffset(0, 0),
						sizeConstraint = UDim2.new(1, 0, 0, 24),
					}),
					Scene = React.createElement(ArcadeViewport, {
						kind = selected,
						size = UDim2.new(1, 0, 1, -28),
						position = UDim2.fromOffset(0, 28),
						animate = true,
					}),
				}
			),
		},
	}
	local controls: Children = {
		Title = React.createElement(ui.Text, {
			value = definition.Name,
			size = 24,
			weight = Enum.FontWeight.Heavy,
			sizeConstraint = UDim2.new(1, 0, 0, 32),
		}),
		Rules = React.createElement(ui.Text, {
			value = definition.Description,
			size = 14,
			wrap = true,
			position = UDim2.fromOffset(0, 38),
			sizeConstraint = UDim2.new(1, 0, 0, 46),
		}),
	}
	local height = 240
	if active and (selected == "Blackjack" or selected == "Poker") then
		local hand = ""
		for _, card in active.PlayerCards do
			hand ..= cardName(card) .. "   "
		end
		controls.Hand = React.createElement(
			ui.Text,
			{ value = hand, size = 22, position = UDim2.fromOffset(0, 94), sizeConstraint = UDim2.new(1, 0, 0, 36) }
		)
		if selected == "Blackjack" then
			controls.Dealer = React.createElement(ui.Text, {
				value = "Dealer: " .. cardName(active.DealerCards[1]) .. "  ?",
				size = 16,
				position = UDim2.fromOffset(0, 138),
				sizeConstraint = UDim2.new(1, 0, 0, 28),
			})
			controls.Hit = button("Hit", function(): ()
				play("Hit")
			end, UDim2.fromOffset(0, 180), UDim2.new(0.5, -6, 0, 48))
			controls.Stand = button("Stand", function(): ()
				play("Stand")
			end, UDim2.new(0.5, 6, 0, 180), UDim2.new(0.5, -6, 0, 48))
		else
			for index, card in active.PlayerCards do
				controls["Hold" .. index] = button(
					(if held[index] then "Keep " else "Swap ") .. cardName(card),
					function(): ()
						local nextHeld = table.clone(held)
						nextHeld[index] = not held[index]
						setHeld(nextHeld)
					end,
					UDim2.new((index - 1) / 5, 0, 0, 138),
					UDim2.new(0.2, -4, 0, 48)
				)
			end
			controls.Draw = button("Draw replacements", function(): ()
				play("Draw")
			end, UDim2.fromOffset(0, 198), UDim2.new(1, 0, 0, 48))
			height = 280
		end
	elseif active and selected == "Mines" then
		for tile = 1, Config.MinesCells do
			local revealed = table.find(active.Revealed, tile) ~= nil
			controls["Tile" .. tile] = button(
				if revealed then "Clear" else tostring(tile),
				function(): ()
					play("Reveal", tile)
				end,
				UDim2.new(((tile - 1) % 5) / 5, 0, 0, 94 + math.floor((tile - 1) / 5) * 52),
				UDim2.new(0.2, -6, 0, 46),
				revealed
			)
		end
		controls.Stop = button("Finish survey · " .. tostring(active.Score) .. " points", function(): ()
			play("Stop")
		end, UDim2.fromOffset(0, 366), UDim2.new(1, 0, 0, 48))
		height = 450
	elseif active and selected == "CardTower" and active.Tower then
		local tower = active.Tower
		controls.CurrentCard = React.createElement(ui.Text, {
			value = `Next card: {towerCardName(tower.CurrentCard)}   ·   {tower.Hands} cleared   ·   {active.Score} points`,
			size = 18,
			weight = Enum.FontWeight.Bold,
			position = UDim2.fromOffset(0, 94),
			sizeConstraint = UDim2.new(1, 0, 0, 42),
		})
		for index = 1, tower.Slots do
			local cards = tower.Columns[index]
			local names = {}
			for _, rank in cards do
				table.insert(names, towerCardName(rank))
			end
			local columnText = if #names == 0 then "Empty" else table.concat(names, " · ")
			controls[`Column{index}`] = button(
				`Column {index}   {towerTotal(cards)} / 21\n{columnText}`,
				function(): ()
					play("Place", index)
				end,
				UDim2.new(
					((index - 1) % 2) * 0.5,
					if index % 2 == 1 then 0 else 6,
					0,
					150 + math.floor((index - 1) / 2) * 62
				),
				UDim2.new(0.5, -6, 0, 54),
				not data or busy
			)
		end
		controls.Stop = button("Finish run · " .. tostring(active.Score) .. " points", function(): ()
			play("Stop")
		end, UDim2.fromOffset(0, if tower.Slots == 3 then 216 else 278), UDim2.new(1, 0, 0, 48))
		height = if tower.Slots == 3 then 290 else 352
	elseif active then
		controls.Stop = button("Land flight", function(): ()
			play("Stop")
		end, UDim2.fromOffset(0, 110), UDim2.new(1, 0, 0, 48))
	elseif selected == "CoinFlip" then
		for index, face in { "Heads", "Tails", "Edge" } do
			controls[face] = button(face, function(): ()
				play("Start", face)
			end, UDim2.new((index - 1) / 3, 0, 0, 104), UDim2.new(1 / 3, -8, 0, 48), data == nil)
		end
	elseif selected == "CardTower" then
		controls.SlotsLabel = React.createElement(
			ui.Text,
			{
				value = "Choose your columns",
				size = 14,
				position = UDim2.fromOffset(0, 96),
				sizeConstraint = UDim2.new(1, 0, 0, 24),
			}
		)
		for _, slots in { 3, 4 } do
			controls[`Slots{slots}`] = button(
				tostring(slots) .. (slots == towerSlots and " columns · selected" or " columns"),
				function(): ()
					setTowerSlots(slots)
				end,
				UDim2.new((slots - 3) * 0.5, if slots == 3 then 0 else 6, 0, 126),
				UDim2.new(0.5, -6, 0, 48),
				false
			)
		end
		controls.StartTower = button("Start free tower", function(): ()
			play("Start", towerSlots)
		end, UDim2.fromOffset(0, 182), UDim2.new(1, 0, 0, 48), data == nil)
		height = 244
	elseif selected == "TableRoulette" then
		local red = {
			[1] = true,
			[3] = true,
			[5] = true,
			[7] = true,
			[9] = true,
			[12] = true,
			[14] = true,
			[16] = true,
			[18] = true,
			[19] = true,
			[21] = true,
			[23] = true,
			[25] = true,
			[27] = true,
			[30] = true,
			[32] = true,
			[34] = true,
			[36] = true,
		}
		for pocket = 0, 36 do
			local color = if pocket == 0 then Palette.mint elseif red[pocket] then Palette.coral else Palette.steel
			controls[`Pocket{pocket}`] = button(
				tostring(pocket),
				function(): ()
					setChoice(tostring(pocket))
				end,
				UDim2.new((pocket % 7) / 7, 0, 0, 94 + math.floor(pocket / 7) * 42),
				UDim2.new(1 / 7, -4, 0, 38),
				data == nil,
				if tonumber(choice) == pocket then accent else color
			)
		end
		controls.Spin = button("Spin · pocket " .. choice, function(): ()
			play("Start", tonumber(choice))
		end, UDim2.fromOffset(0, 352), UDim2.new(1, 0, 0, 48), data == nil)
		height = 416
	elseif selected == "QuantumRoulette" then
		controls.BoardInfo = React.createElement(ui.Text, {
			value = `{quantumBoard.Phase}   ·   Gravity Sink: {quantumBoard.Sink}   ·   shifts after {quantumBoard.UntilShift} round(s)`,
			size = 14,
			wrap = true,
			position = UDim2.fromOffset(0, 94),
			sizeConstraint = UDim2.new(1, 0, 0, 36),
		})
		local zoneIndex = 0
		local function zoneButton(startNumber: number, numbers: { number }): ()
			zoneIndex += 1
			local endNumber = numbers[#numbers]
			local containsSink = table.find(numbers, quantumBoard.Sink) ~= nil
			local label = if startNumber == 0
				then (if containsSink then "0 · Gravity Sink" else "0")
				elseif containsSink then `Gravity Sink · {startNumber}–{endNumber}`
				elseif startNumber == endNumber then tostring(startNumber)
				else `{startNumber}–{endNumber}`
			controls[`Zone{startNumber}`] = button(
				label,
				function(): ()
					setChoice(tostring(startNumber))
				end,
				UDim2.new(((zoneIndex - 1) % 3) / 3, 0, 0, 132 + math.floor((zoneIndex - 1) / 3) * 42),
				UDim2.new(1 / 3, -6, 0, 36),
				data == nil,
				if tonumber(choice) == startNumber then accent elseif containsSink then Palette.coral else Palette.violet
			)
		end
		zoneButton(0, { 0 })
		for _, zone in quantumBoard.Zones do
			zoneButton(zone.Start, zone.Numbers)
		end
		local rows = math.ceil(zoneIndex / 3)
		local spinY = 132 + rows * 42 + 8
		controls.Spin = button("Spin · selected zone " .. choice, function(): ()
			play("Start", tonumber(choice))
		end, UDim2.fromOffset(0, spinY), UDim2.new(1, 0, 0, 48), data == nil)
		height = spinY + 64
	elseif selected == "DiceTable" then
		for total = 2, 12 do
			controls[`Total{total}`] = button(
				tostring(total),
				function(): ()
					setChoice(tostring(total))
				end,
				UDim2.new(((total - 2) % 6) / 6, 0, 0, 104 + math.floor((total - 2) / 6) * 48),
				UDim2.new(1 / 6, -5, 0, 42),
				data == nil,
				if tonumber(choice) == total then accent else Palette.coral
			)
		end
		controls.Roll = button("Roll for " .. choice, function(): ()
			play("Start", tonumber(choice))
		end, UDim2.fromOffset(0, 206), UDim2.new(1, 0, 0, 48), data == nil)
		height = 268
	else
		local needsChoice = selected == "Roulette" or selected == "Dice" or selected == "Keno" or selected == "Mines"
		if needsChoice then
			controls.Input = React.createElement(ui.SearchField, {
				value = choice,
				onChange = setChoice,
				placeholder = if selected == "Keno"
					then "Numbers separated by commas"
					elseif selected == "Mines" then "Number of hazards (1–12)"
					else "Your number",
				position = UDim2.fromOffset(0, 94),
				size = UDim2.new(1, 0, 0, 48),
				reducedMotion = softMotion,
			})
		end
		controls.Play = button("Play " .. definition.Name, function(): ()
			play("Start", if selected == "Dice" or selected == "Roulette" then tonumber(choice) else nil)
		end, UDim2.fromOffset(0, if needsChoice then 154 else 110), UDim2.new(1, 0, 0, 48), data == nil)
	end
	table.insert(sections, {
		id = "controls",
		height = height,
		element = React.createElement(
			ui.Panel,
			{ size = UDim2.fromScale(1, 1), padding = 16, accent = accent, reducedMotion = softMotion },
			controls
		),
	})
	local feedback: Children = {
		Status = React.createElement(
			ui.Text,
			{ value = status, size = 14, wrap = true, sizeConstraint = UDim2.new(1, 0, 0, 46) }
		),
		Refresh = button("Refresh arcade", refresh, UDim2.fromOffset(0, 54), UDim2.new(0.5, -6, 0, 48)),
	}
	if pending.current then
		feedback.Retry = button("Retry action", function(): ()
			if pending.current then
				send(pending.current)
			end
		end, UDim2.new(0.5, 6, 0, 54), UDim2.new(0.5, -6, 0, 48))
	end
	table.insert(sections, {
		id = "feedback",
		height = 118,
		element = React.createElement("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, feedback),
	})
	if data then
		local latest = data.History[1]
		local history = "Total score: "
			.. tostring(data.Stats.TotalScore)
			.. "  ·  Rounds: "
			.. tostring(data.Stats.Played)
		for index = 1, math.min(4, #data.History) do
			local row = data.History[index]
			history ..= "\n" .. row.Game .. " · " .. row.Label .. " · " .. tostring(row.Score) .. " points"
		end
		local children: Children = {
			Text = React.createElement(
				ui.Text,
				{ value = history, size = 15, wrap = true, sizeConstraint = UDim2.new(1, 0, 0, 122) }
			),
		}
		if latest then
			children.Verify = button("Check last seed commitment", function(): ()
				setStatus(
					if Fair.verifyCommitment(latest.Reveal)
						then "The revealed seed matches its original commitment."
						else "This round's seed commitment does not match."
				)
			end, UDim2.fromOffset(0, 128), UDim2.new(1, 0, 0, 48))
		end
		table.insert(sections, {
			id = "history",
			height = 210,
			element = React.createElement(
				ui.Panel,
				{ size = UDim2.fromScale(1, 1), padding = 16, accent = accent, reducedMotion = softMotion },
				children
			),
		})
	end
	return React.createElement(PageScaffold, { sections = sections, gap = 16, tailPad = 28, scrollBarColor = accent })
end

return { ArcadePage = ArcadePage }
