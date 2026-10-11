--!nonstrict
-- Crewmates in the world: a small "CREW" tag above each crewmate's head so you can find them.
-- Client-only and driven by CrewStore; at most three tags (a full crew minus you).
local Players = game:GetService("Players")
local CrewStore = require(script.Parent.CrewStore)

local CrewPresence = {}

local TAG_NAME = "AF_CrewTag"

local function tagFor(head: BasePart, name: string): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = TAG_NAME
	gui.Adornee = head
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Size = UDim2.fromOffset(150, 28)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5.4, 0)
	gui.ResetOnSpawn = false
	local pill = Instance.new("TextLabel")
	pill.Size = UDim2.fromScale(1, 1)
	pill.BackgroundColor3 = Color3.fromRGB(28, 70, 52)
	pill.BackgroundTransparency = 0.15
	pill.TextColor3 = Color3.fromRGB(150, 255, 200)
	pill.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
	pill.TextSize = 14
	pill.Text = "CREW · " .. name
	pill.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = pill
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(110, 240, 170)
	stroke.Transparency = 0.3
	stroke.Parent = pill
	return gui
end

function CrewPresence.attach()
	local folder = Instance.new("Folder")
	folder.Name = "AF_CrewTags"
	folder.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local watched = {} -- userId -> { connection, gui }
	local function clear(userId)
		local entry = watched[userId]
		if entry then
			if entry.connection then entry.connection:Disconnect() end
			if entry.gui then entry.gui:Destroy() end
			watched[userId] = nil
		end
	end
	local function place(userId, player)
		local entry = watched[userId]
		if entry.gui then entry.gui:Destroy(); entry.gui = nil end
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			entry.gui = tagFor(head, player.DisplayName)
			entry.gui.Parent = folder
		end
	end
	local function sync(state)
		local wanted = {}
		local crew = state.crew
		if crew then
			for _, member in crew.Members or {} do
				if member.UserId ~= Players.LocalPlayer.UserId then wanted[member.UserId] = true end
			end
		end
		for userId in watched do
			if not wanted[userId] then clear(userId) end
		end
		for userId in wanted do
			local player = Players:GetPlayerByUserId(userId)
			if player and watched[userId] == nil then
				watched[userId] = {}
				watched[userId].connection = player.CharacterAdded:Connect(function()
					task.wait(0.5) -- the head appears a moment after the character
					if watched[userId] then place(userId, player) end
				end)
				place(userId, player)
			end
		end
	end
	local unsubscribe = CrewStore.subscribe(sync)
	sync(CrewStore.get())
	return function()
		unsubscribe()
		for userId in watched do clear(userId) end
		folder:Destroy()
	end
end

return CrewPresence
