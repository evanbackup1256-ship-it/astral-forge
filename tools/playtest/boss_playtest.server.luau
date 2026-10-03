--!nocheck
-- Boss playtest harness. Run it on the SERVER of a Studio play session (for example through the
-- Roblox Studio MCP `execute_luau` with datamodel_type Server) once the game has loaded (~30s).
-- It is not part of the game and is not synced: it lives here so every playtest runs the same way.
--
-- What it does, one boss at a time:
--   * starts that boss's demo (workspace attribute RiftBossDemo), which holds the boss at full health
--     and plays every attack and every ultimate in turn, with a pause between
--   * keeps the first player alive and standing in the arena, so every attack has a target
--   * records each move as it starts, every server warning or error, the slowest frame, and how many
--     instances the workspace gained (a leak shows as a number that never comes back down)
--
-- Read the result with:  _G.__pt.run.<Kind>  and  _G.__pt.logs
-- Keep calls short (poll, do not sleep for a minute inside one call): long calls time out.

local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")
local player = game.Players:GetPlayers()[1]

player:LoadCharacter()
task.wait(1.5)

local S = { logs = {}, run = {}, allDone = false }
_G.__pt = S

LogService.MessageOut:Connect(function(message, kind)
	if (kind == Enum.MessageType.MessageError or kind == Enum.MessageType.MessageWarning) and #S.logs < 200 then
		table.insert(S.logs, { boss = S.current, message = string.sub(message, 1, 260) })
	end
end)

local live = 0
workspace.DescendantAdded:Connect(function()
	live += 1
end)
workspace.DescendantRemoving:Connect(function()
	live -= 1
end)

RunService.Heartbeat:Connect(function(dt)
	local run = S.current and S.run[S.current]
	if run then
		run.frames += 1
		run.seconds += dt
		run.slowest = math.max(run.slowest, dt)
		if dt > 0.1 then
			run.slow += 1
		end
	end
end)

local function warden()
	for _, d in workspace:GetDescendants() do
		if d.Name == "RiftWarden" and d:IsA("Model") then
			return d
		end
	end
	return nil
end

-- Pass the kinds to run, e.g. { "Warden", "Choir", "Regent", "Seraph", "Rime", "Knight", "Astraeon" }.
function _G.__playtestAll(kinds)
	task.spawn(function()
		for _, kind in kinds do
			S.current = kind
			local run = { frames = 0, seconds = 0, slowest = 0, slow = 0, moves = {}, liveStart = live, done = false }
			S.run[kind] = run
			-- A finished demo leaves "demo finished" behind; clear it or the next boss reads it as its own end.
			workspace:SetAttribute("RiftBossDemoNow", nil)
			workspace:SetAttribute("RiftBossDemo", kind)
			local started, last = os.clock(), nil
			while os.clock() - started < 900 do
				local model = warden()
				local character = player.Character
				if model and model.PrimaryPart and character and character:FindFirstChild("HumanoidRootPart") then
					local floorY, anchor = model:GetAttribute("BossFloorY"), model.PrimaryPart.Position
					local root = character.HumanoidRootPart
					local flat = Vector3.new(root.Position.X - anchor.X, 0, root.Position.Z - anchor.Z)
					local phase = model:GetAttribute("Phase")
					if (phase == "Forming" or phase == "Active") and floorY and (flat.Magnitude > 50 or root.Position.Y < floorY - 5) then
						root.CFrame = CFrame.new(anchor.X + 34, floorY + 4, anchor.Z)
					end
					character.Humanoid.MaxHealth = 1e9
					character.Humanoid.Health = 1e9
				end
				local label = workspace:GetAttribute("RiftBossDemoNow")
				if label ~= nil and label ~= last then
					last = label
					table.insert(run.moves, { at = math.floor(os.clock() - started), label = label, live = live })
					if label == "demo finished" then
						run.done = true
						break
					end
				end
				task.wait(0.25)
			end
			run.liveEnd = live
			task.wait(3)
		end
		S.allDone = true
	end)
end
