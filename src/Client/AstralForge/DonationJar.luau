--!nonstrict
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local RunService = game:GetService("RunService")
local ui = require(script.Parent.UiCore)("ui")
local P = require(script.Parent.CoreKit)("theme").Palette
local motion = require(script.Parent.MotionKit)("motion")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local h = React.createElement
local Jar = {}
local listeners, seen, seenOrder = {}, {}, {}
local function emit(value)
	for _, listener in table.clone(listeners) do
		listener(value)
	end
end
function Jar.push(payload)
	if type(payload.Key) ~= "string" or seen[payload.Key] then
		return
	end
	seen[payload.Key] = true
	table.insert(seenOrder, payload.Key)
	if #seenOrder > 128 then
		seen[table.remove(seenOrder, 1)] = nil
	end
	emit(payload)
end
local function useDonation()
	local event, setEvent = React.useState(nil)
	React.useEffect(function()
		table.insert(listeners, setEvent)
		return function()
			local at = table.find(listeners, setEvent)
			if at then
				table.remove(listeners, at)
			end
		end
	end, {})
	return event
end
local CasinoViewport = require(script.Parent.CasinoViewport)
local function Visual(props)
	local progress, setProgress = React.useBinding(1)
	local soft = motion.useMotionSettings().soft == true
	React.useEffect(function()
		if props.token == nil or soft then
			setProgress(1)
			return nil
		end

		local started = os.clock()
		setProgress(0)
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local elapsed = math.min(1, (os.clock() - started) / 3.2)
			setProgress(elapsed)
			if elapsed == 1 then
				connection:Disconnect()
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { props.token, soft })

	local effects = {}
	for index = 1, 18 do
		effects["Spark" .. index] = h("frame", {
			Size = UDim2.fromOffset(if index % 3 == 0 then 4 else 2, if index % 3 == 0 then 4 else 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if index % 2 == 0 then P.cyan else P.mango,
			BorderSizePixel = 0,
			BackgroundTransparency = progress:map(function(value)
				return 1 - math.sin(value * math.pi) * 0.8
			end),
			Position = progress:map(function(value)
				local angle = index * math.tau / 18 + value * 0.6
				local distance = 0.12 + value * 0.28
				return UDim2.fromScale(0.5 + math.cos(angle) * distance, 0.48 + math.sin(angle) * distance)
			end),
			ZIndex = 4,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))
	end

	local caption = if type(props.amount) == "number" and props.amount > 0
		then `R${math.floor(props.amount)} · THANK YOU`
		else "THANK YOU"
	return h("frame", {
		Name = "TipJarVisual",
		Size = props.size or UDim2.new(1, 0, 0, 230),
		Position = props.position or UDim2.new(),
		BackgroundTransparency = 1,
	}, {
		Effects = h("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, effects),
		Scene = h(CasinoViewport, { kind = "Jar", token = props.token, size = UDim2.new(1, 0, 1, -30) }),
		Label = h(ui.Text, {
			value = caption,
			size = 16,
			color = P.mango,
			weight = Enum.FontWeight.Heavy,
			position = UDim2.new(0, 0, 1, -30),
			sizeConstraint = UDim2.new(1, 0, 0, 30),
		}),
	})
end
Jar.Visual = Visual
function Jar.Panel(props)
	local donation = useDonation()
	return h(ui.Panel, { size = UDim2.fromScale(1, 1), accent = P.mango, padding = 12, background = P.panelRaised }, {
		Title = h(ui.Text, { value = "Tip Jar", size = 22, color = P.mango, sizeConstraint = UDim2.new(1, 0, 0, 30) }),
		Detail = h(ui.Text, {
			value = "Thanks for supporting Astral Forge. Tips do not include items or bonuses.",
			size = 13,
			color = P.muted,
			wrap = true,
			position = UDim2.fromOffset(0, 36),
			sizeConstraint = UDim2.new(1, 0, 0, 48),
		}),
		Jar = h(
			Visual,
			{
				token = donation and donation.Key,
				amount = donation and donation.Amount,
				position = UDim2.fromOffset(0, 84),
				size = UDim2.new(1, 0, 0, 230),
			}
		),
	})
end
local function Celebration(props)
	local viewport = motion.useViewport()
	local height = math.min(390, math.max(280, viewport.height - 32))
	local visualHeight = height - 140
	local donation = props.donation
	local visible, setVisible = React.useState(true)
	local transition = motion.useExitTransition(false, 0.18, visible)
	local entrance = motion.useFlipperSpring(1, false, 900, 40, 0)
	local show = React.joinBindings({ entrance, transition[1] }):map(function(v)
		return v[1] * v[2]
	end)
	React.useEffect(function()
		if not donation then
			return
		end
		Audio:play("reward")
		local job = task.delay(6, function()
			transition[3](function()
				setVisible(false)
			end)
		end)
		return function()
			pcall(task.cancel, job)
		end
	end, { donation })
	return h(
		ui.OverlayPresence,
		{ amount = show },
		h("frame", {
			Name = "DonationCelebration",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -48, 0, height),
			BackgroundTransparency = 1,
			Visible = show:map(function(v)
				return v > 0.01
			end),
			ZIndex = 800,
		}, {
			Constraint = h("uisizeconstraint", { MaxSize = Vector2.new(360, height) }),
			Panel = h(
				ui.Panel,
				{ size = UDim2.fromScale(1, 1), accent = P.mango, padding = 16, background = P.panelRaised },
				{
					Visual = h(
						Visual,
						{
							token = donation and donation.Key,
							amount = donation and donation.Amount,
							size = UDim2.new(1, 0, 0, visualHeight),
						}
					),
					Title = h(ui.Text, {
						value = "Thanks for the support!",
						size = 20,
						color = P.mango,
						position = UDim2.fromOffset(0, visualHeight + 6),
						sizeConstraint = UDim2.new(1, 0, 0, 40),
						wrap = true,
					}),
					Close = h(ui.Button, {
						text = "Close",
						sound = "close",
						size = UDim2.new(1, 0, 0, 48),
						position = UDim2.fromOffset(0, visualHeight + 44),
						color = P.panelSoft,
						textColor = P.cream,
						onClick = function()
							transition[3](function()
								setVisible(false)
							end)
						end,
					}),
				}
			),
		})
	)
end
function Jar.Overlay()
	local donation = useDonation()
	return if donation then h(Celebration, { key = donation.Key, donation = donation }) else nil
end
return Jar
