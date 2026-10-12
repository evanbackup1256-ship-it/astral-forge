--!nonstrict
-- Crewmates in the world: a small "CREW" tag above each crewmate's head so you can find them.
-- 100% React declarative component driven by CrewStore.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReactRoblox = require(ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["react-roblox"])
local CrewStore = require(script.Parent.CrewStore)

local CrewPresence = {}

local function CrewTag(props: { head: BasePart, name: string })
	return React.createElement("BillboardGui", {
		Name = "AF_CrewTag",
		Adornee = props.head,
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 120,
		Size = UDim2.fromOffset(150, 28),
		StudsOffsetWorldSpace = Vector3.new(0, 5.4, 0),
		ResetOnSpawn = false,
	}, {
		Pill = React.createElement("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(28, 70, 52),
			BackgroundTransparency = 0.15,
			TextColor3 = Color3.fromRGB(150, 255, 200),
			FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
			TextSize = 14,
			Text = "CREW · " .. props.name,
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			Stroke = React.createElement("UIStroke", {
				Color = Color3.fromRGB(110, 240, 170),
				Transparency = 0.3,
			}),
		}),
	})
end

local function CrewPresenceTree()
	local crewState, setCrewState = React.useState(function()
		return CrewStore.get()
	end)
	local heads, setHeads = React.useState({})

	React.useEffect(function()
		return CrewStore.subscribe(function(nextState)
			setCrewState(nextState)
		end)
	end, {})

	React.useEffect(function()
		local alive = true
		local function updateHeads()
			if not alive then
				return
			end
			local members = (crewState and crewState.crew and crewState.crew.Members) or {}
			local nextMap = {}
			for _, member in members do
				local uid = member.UserId
				if uid ~= Players.LocalPlayer.UserId then
					local player = Players:GetPlayerByUserId(uid)
					local char = player and player.Character
					local head = char and char:FindFirstChild("Head")
					if head and head:IsA("BasePart") then
						nextMap[uid] = { head = head, name = player.DisplayName }
					end
				end
			end
			setHeads(nextMap)
		end

		updateHeads()
		local conns = {}
		for _, player in Players:GetPlayers() do
			if player ~= Players.LocalPlayer then
				table.insert(conns, player.CharacterAdded:Connect(function()
					task.wait(0.5)
					updateHeads()
				end))
			end
		end
		table.insert(conns, Players.PlayerAdded:Connect(function(player)
			table.insert(conns, player.CharacterAdded:Connect(function()
				task.wait(0.5)
				updateHeads()
			end))
		end))

		return function()
			alive = false
			for _, c in conns do
				c:Disconnect()
			end
		end
	end, { crewState })

	local elements = {}
	for uid, data in heads do
		elements["CrewTag_" .. tostring(uid)] = React.createElement(CrewTag, {
			head = data.head,
			name = data.name,
		})
	end
	return React.createElement(React.Fragment, nil, elements)
end

function CrewPresence.attach()
	-- BillboardGuis only render from PlayerGui (or the world), never nested inside a ScreenGui,
	-- so the tags get their own folder rather than mounting into the app's screen
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local host = Instance.new("Folder")
	host.Name = "AF_CrewTags"
	host.Parent = playerGui
	local root = ReactRoblox.createRoot(host)
	root:render(React.createElement(CrewPresenceTree))
	return function()
		root:unmount()
		host:Destroy()
	end
end

CrewPresence.Component = CrewPresenceTree
return CrewPresence
