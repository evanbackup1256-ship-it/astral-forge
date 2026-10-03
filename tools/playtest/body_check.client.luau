--!nocheck
-- Checks the rebuilt Blender bodies in a running Studio session, one boss after another: loads the body, runs
-- the cloth/wing physics and the clips for several seconds, and reports per boss
--   * how many pieces built, whether anything went NaN, and how far from the boss the farthest piece strayed
--     (an exploded cloth chain would be hundreds of studs away);
--   * how many trails / lights / emitters were mounted on the pieces;
--   * the client frame time while it ran, and any warnings or errors.
--
-- Run it on the CLIENT (Roblox Studio MCP `execute_luau`, datamodel_type Client) of a play session, after the
-- server has put the player in the sanctuary (workspace attribute StudioEnterSanctuary = userId) and the
-- sanctuary world has been started:
--     require(<SanctuaryKit>)("sanctuaryWorld").start()
-- and the server forces each boss (workspace attribute RiftBossForce = kind). This script only does the
-- sampling; drive the forcing from the server side and call `_G.__bodyCheck(kind)` once the boss is up.

local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")

local logs = {}
LogService.MessageOut:Connect(function(message, kind)
	if (kind == Enum.MessageType.MessageError or kind == Enum.MessageType.MessageWarning) and not message:find("did not load") and not message:find("not approved") and #logs < 100 then
		table.insert(logs, string.sub(message, 1, 200))
	end
end)

function _G.__bodyCheck(kind, seconds)
	seconds = seconds or 6
	local fx = workspace:FindFirstChild("SanctuaryClientFx")
	if fx == nil then
		return "no SanctuaryClientFx"
	end
	local pieces = {}
	for _, part in fx:GetChildren() do
		if part:IsA("BasePart") and part.Name:find("^" .. kind .. "_") then
			table.insert(pieces, part)
		end
	end
	if #pieces < 10 then
		return ("%s: only %d pieces built"):format(kind, #pieces)
	end
	local anchor
	for _, d in workspace:GetDescendants() do
		if d.Name == "RiftWarden" and d:IsA("Model") and d.PrimaryPart then
			anchor = d.PrimaryPart.Position
			break
		end
	end
	local bad, farthest, frames, slow = 0, 0, 0, 0
	local worst = 0
	local connection = RunService.RenderStepped:Connect(function(dt)
		frames += 1
		if dt > 0.05 then
			slow += 1
		end
		worst = math.max(worst, dt)
	end)
	local stop = os.clock() + seconds
	while os.clock() < stop do
		for _, part in pieces do
			local p = part.Position
			if p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z then
				bad += 1
			elseif anchor ~= nil then
				farthest = math.max(farthest, (p - anchor).Magnitude)
			end
		end
		task.wait(0.1)
	end
	connection:Disconnect()
	local trails, lights, emitters = 0, 0, 0
	for _, part in pieces do
		for _, child in part:GetChildren() do
			if child:IsA("Trail") then
				trails += 1
			elseif child:IsA("PointLight") then
				lights += 1
			elseif child:IsA("ParticleEmitter") or child:IsA("Fire") then
				emitters += 1
			end
		end
	end
	return ("%s: pieces=%d nan=%d farthest=%.0f studs trails=%d lights=%d emitters=%d frames=%d slow(>50ms)=%d worst=%.0fms logs=%d"):format(kind, #pieces, bad, farthest, trails, lights, emitters, frames, slow, worst * 1000, #logs)
end

function _G.__bodyLogs()
	return table.concat(logs, "\n")
end
return "body check installed"
