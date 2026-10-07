--!strict
-- Purpose: Working score-only arcade controls, persistent-round recovery and history; replaces retired wager UI.
-- Owner: Astral Forge presentation. Dependencies: shared arcade schemas, UiCore/MotionKit/LayoutKit/React. Last-reviewed: 2026-10-05.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReactTypes = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts-js"].React)
local Types = require("@game/ReplicatedStorage/AstralForge/Shared/ArcadeTypes")
local Registry = require("@game/ReplicatedStorage/AstralForge/Shared/RemoteRegistry")
local Config = require("@game/ReplicatedStorage/AstralForge/Shared/ArcadeConfig")
local cardName = require("./ArcadeText").cardName
local Hash = require("@game/ReplicatedStorage/AstralForge/Shared/ProofHash")
local Fair = require("@game/ReplicatedStorage/AstralForge/Shared/FairRandom")(Hash)
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

local function ArcadePage(props: Props): Element
	local data: Types.PublicState?, setData: (Types.PublicState?) -> () = React.useState(props.state.Arcade)
	local gameId: Types.GameId, setGame: (Types.GameId) -> () = React.useState("Slots")
	local choice: string, setChoice: (string) -> () = React.useState("7")
	local seed: string, setSeed: (string) -> () = React.useState(Http:GenerateGUID(false))
	local held: { [number]: boolean }, setHeld: ({ [number]: boolean }) -> () = React.useState({})
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
	local function button(text: string, onClick: () -> (), at: UDim2, size: UDim2, disabled: boolean?): Element
		return React.createElement(
			ui.Button,
			{
				text = text,
				onClick = onClick,
				position = at,
				size = size,
				color = accent,
				textColor = Palette.ink,
				disabled = busy or disabled == true,
				reducedMotion = softMotion,
				sound = "button",
			}
		)
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
						elseif entry.Id == "Keno" then "1, 7, 12, 19, 25"
						elseif entry.Id == "Mines" then "5"
						else "7"
				)
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
			element = React.createElement(
				ui.Text,
				{
					value = "Arcade\nPlay for scores. No currency wagers or payouts.",
					size = 21,
					weight = Enum.FontWeight.Heavy,
					wrap = true,
					sizeConstraint = UDim2.fromScale(1, 1),
				}
			),
		},
		{
			id = "games",
			height = math.ceil(#Config.Games / columns) * 54,
			element = React.createElement("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, tabs),
		},
	}
	local controls: Children = {
		Title = React.createElement(
			ui.Text,
			{
				value = definition.Name,
				size = 24,
				weight = Enum.FontWeight.Heavy,
				sizeConstraint = UDim2.new(1, 0, 0, 32),
			}
		),
		Rules = React.createElement(
			ui.Text,
			{
				value = definition.Description,
				size = 14,
				wrap = true,
				position = UDim2.fromOffset(0, 38),
				sizeConstraint = UDim2.new(1, 0, 0, 46),
			}
		),
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
			controls.Dealer = React.createElement(
				ui.Text,
				{
					value = "Dealer: " .. cardName(active.DealerCards[1]) .. "  ?",
					size = 16,
					position = UDim2.fromOffset(0, 138),
					sizeConstraint = UDim2.new(1, 0, 0, 28),
				}
			)
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
	else
		local needsChoice = selected == "Roulette" or selected == "Dice" or selected == "Keno" or selected == "Mines"
		if needsChoice then
			controls.Input = React.createElement(
				ui.SearchField,
				{
					value = choice,
					onChange = setChoice,
					placeholder = if selected == "Keno"
						then "Numbers separated by commas"
						elseif selected == "Mines" then "Number of hazards (1–12)"
						else "Your number",
					position = UDim2.fromOffset(0, 94),
					size = UDim2.new(1, 0, 0, 48),
					reducedMotion = softMotion,
				}
			)
		end
		controls.Play = button("Play " .. definition.Name, function(): ()
			play("Start", if selected == "Dice" or selected == "Roulette" then tonumber(choice) else nil)
		end, UDim2.fromOffset(0, if needsChoice then 154 else 110), UDim2.new(1, 0, 0, 48), data == nil)
	end
	table.insert(
		sections,
		{
			id = "controls",
			height = height,
			element = React.createElement(
				ui.Panel,
				{ size = UDim2.fromScale(1, 1), padding = 16, accent = accent, reducedMotion = softMotion },
				controls
			),
		}
	)
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
	table.insert(
		sections,
		{
			id = "feedback",
			height = 118,
			element = React.createElement(
				"frame",
				{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 },
				feedback
			),
		}
	)
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
		table.insert(
			sections,
			{
				id = "history",
				height = 210,
				element = React.createElement(
					ui.Panel,
					{ size = UDim2.fromScale(1, 1), padding = 16, accent = accent, reducedMotion = softMotion },
					children
				),
			}
		)
	end
	return React.createElement(PageScaffold, { sections = sections, gap = 16, tailPad = 28, scrollBarColor = accent })
end

return { ArcadePage = ArcadePage }
