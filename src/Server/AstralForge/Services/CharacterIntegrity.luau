--!strict

return function(loadService: (string) -> any)
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local Workspace = game:GetService("Workspace")

	local ModuleLog = require(script.Parent.Parent:WaitForChild("ModuleLog"))
	local RemoteFirewall = loadService("RemoteFirewall")

	type PlayerState = {
		Character: Model?,
		LastPosition: Vector3?,
		LastSafeCFrame: CFrame?,
		LastAt: number,
		Score: number,
		SpeedBursts: number,
		BarrierCrossings: number,
		FlightBursts: number,
		Corrections: number,
		FirstSuspiciousAt: number,
		LastMitigationAt: number,
		EnforcementStarted: boolean,
		Raycast: RaycastParams?,
		LastGroundedAt: number,
	}

	local CharacterIntegrity = {}
	CharacterIntegrity.__index = CharacterIntegrity

	local SAMPLE_SECONDS = 0.2
	local MIN_BARRIER_DISTANCE = 6
	local CORRECTION_SCORE = 7
	local SERVER_GRACE_ATTRIBUTE = "AF_MovementGraceUntil"

	local function newState(): PlayerState
		return {
			Character = nil,
			LastPosition = nil,
			LastSafeCFrame = nil,
			LastAt = 0,
			Score = 0,
			SpeedBursts = 0,
			BarrierCrossings = 0,
			FlightBursts = 0,
			Corrections = 0,
			FirstSuspiciousAt = 0,
			LastMitigationAt = -math.huge,
			EnforcementStarted = false,
			Raycast = nil,
			LastGroundedAt = 0,
		}
	end

	local function resetCharacter(state: PlayerState, character: Model, root: BasePart, now: number): ()
		local raycast = RaycastParams.new()
		raycast.FilterType = Enum.RaycastFilterType.Exclude
		raycast.FilterDescendantsInstances = { character }
		raycast.IgnoreWater = false

		state.Character = character
		state.LastPosition = root.Position
		state.LastSafeCFrame = root.CFrame
		state.LastAt = now
		state.Score = 0
		state.SpeedBursts = 0
		state.BarrierCrossings = 0
		state.FlightBursts = 0
		state.Corrections = 0
		state.FirstSuspiciousAt = 0
		state.LastMitigationAt = -math.huge
		state.EnforcementStarted = false
		state.Raycast = raycast
		state.LastGroundedAt = now
	end

	local function movementExempt(character: Model, humanoid: Humanoid): boolean
		local graceUntil = character:GetAttribute(SERVER_GRACE_ATTRIBUTE)
		if type(graceUntil) == "number" and Workspace:GetServerTimeNow() < graceUntil then
			return true
		end
		local state = humanoid:GetState()
		return humanoid.Health <= 0
			or humanoid.SeatPart ~= nil
			or state == Enum.HumanoidStateType.Seated
			or state == Enum.HumanoidStateType.Swimming
			or state == Enum.HumanoidStateType.Climbing
	end

	local function crossedBarrier(
		params: RaycastParams,
		from: Vector3,
		to: Vector3
	): boolean
		local delta = to - from
		local horizontal = Vector3.new(delta.X, 0, delta.Z)
		if horizontal.Magnitude < MIN_BARRIER_DISTANCE then
			return false
		end
		local result = Workspace:Raycast(from, horizontal, params)
		if not result or not result.Instance:IsA("BasePart") or not result.Instance.CanCollide then
			return false
		end
		return result.Distance + 3.5 < horizontal.Magnitude
	end

	local function airbornePlatformMotion(params: RaycastParams, root: BasePart, humanoid: Humanoid): boolean
		if not humanoid.PlatformStand then
			return false
		end
		local grounded = Workspace:Raycast(root.Position, Vector3.new(0, -8, 0), params) ~= nil
		return not grounded and root.AssemblyLinearVelocity.Magnitude > 18
	end

	local function shouldEnforce(state: PlayerState, now: number): boolean
		if state.EnforcementStarted or state.FirstSuspiciousAt <= 0 or now - state.FirstSuspiciousAt < 12 then
			return false
		end
		local repeatedTraversal = state.BarrierCrossings >= 3
		local repeatedFlight = state.FlightBursts >= 8
		return state.SpeedBursts >= 12
			and state.Corrections >= 2
			and (repeatedTraversal or repeatedFlight)
	end

	local function correctMotion(player: Player, state: PlayerState, root: BasePart, now: number): boolean
		local safeCFrame = state.LastSafeCFrame
		if not safeCFrame or now - state.LastMitigationAt < 1.5 then
			return false
		end
		state.LastMitigationAt = now
		state.Corrections += 1
		local character = state.Character
		if character then
			character:SetAttribute(SERVER_GRACE_ATTRIBUTE, Workspace:GetServerTimeNow() + 1.25)
		end
		root.CFrame = safeCFrame
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		state.LastPosition = safeCFrame.Position
		state.Score *= 0.55
		player:SetAttribute("AF_ServerMotionCorrections", state.Corrections)
		ModuleLog.Every(
			string.format("motion-correct:%d", player.UserId),
			4,
			"Security",
			string.format("%s motion corrected | score %.1f", player.Name, state.Score)
		)
		return true
	end

	function CharacterIntegrity.new()
		local self = setmetatable({}, CharacterIntegrity)
		self._players = {} :: { [Player]: PlayerState }
		self._workers = {}
		self._alive = true
		self._heartbeat = nil :: RBXScriptConnection?
		self._playerRemoving = nil :: RBXScriptConnection?
		self._accumulator = 0
		return self
	end

	function CharacterIntegrity:_enforce(player: Player, evidence): ()
		if not self._alive then return end
		local token = {}
		local worker = task.defer(function()
			if self._alive then
				RemoteFirewall.EnforceConfirmedBan(player, evidence)
			end
			self._workers[token] = nil
		end)
		self._workers[token] = worker
	end

	function CharacterIntegrity:_state(player: Player): PlayerState
		local state = self._players[player]
		if not state then
			state = newState()
			self._players[player] = state
		end
		return state
	end

	function CharacterIntegrity:_observe(player: Player, now: number): ()
		local character = player.Character
		if not character then
			return
		end
		local rootInstance = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not rootInstance or not rootInstance:IsA("BasePart") or not humanoid then
			return
		end
		local root: BasePart = rootInstance
		local state = self:_state(player)
		if state.Character ~= character or not state.Raycast then
			resetCharacter(state, character, root, now)
			return
		end

		local lastPosition = state.LastPosition
		local elapsed = now - state.LastAt
		state.LastAt = now

		-- Anti-Void & Floor Fall-Through Recovery Guard
		if root.Position.Y < -60 then
			correctMotion(player, state, root, now)
			return
		end

		if not lastPosition or elapsed <= 0 or elapsed > 1 or movementExempt(character, humanoid) then
			state.LastPosition = root.Position
			state.LastSafeCFrame = root.CFrame
			state.Score = math.max(0, state.Score - 1)
			return
		end

		local delta = root.Position - lastPosition
		local horizontalDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
		local horizontalSpeed = horizontalDistance / math.max(0.05, elapsed)
		local allowedSpeed = math.max(110, humanoid.WalkSpeed * 4 + 35)
		local grounded = Workspace:Raycast(root.Position, Vector3.new(0, -3, 0), state.Raycast :: RaycastParams) ~= nil
		if grounded then
			state.LastGroundedAt = now
		end
		local airborneGrace = now - state.LastGroundedAt < 0.4
		local fallingSlowly = root.AssemblyLinearVelocity.Y < -20 and horizontalSpeed < allowedSpeed * 0.8
		local speedFlag = (not airborneGrace or fallingSlowly) and (horizontalSpeed > allowedSpeed or root.AssemblyLinearVelocity.Magnitude > 275)
		local barrierFlag = crossedBarrier(state.Raycast :: RaycastParams, lastPosition, root.Position)
		local flightFlag = not airborneGrace and airbornePlatformMotion(state.Raycast :: RaycastParams, root, humanoid)

		if speedFlag or barrierFlag or flightFlag then
			if state.FirstSuspiciousAt <= 0 then
				state.FirstSuspiciousAt = now
			end
			if speedFlag then
				state.SpeedBursts += 1
				state.Score += 1.5
			end
			if barrierFlag then
				state.BarrierCrossings += 1
				state.Score += 5
			end
			if flightFlag then
				state.FlightBursts += 1
				state.Score += 2
			end
			player:SetAttribute("AF_ServerMotionScore", math.floor(state.Score))
			player:SetAttribute("AF_ServerMotionCorrections", state.Corrections)

			local corrected = false
			if shouldEnforce(state, now) then
				state.EnforcementStarted = true
				if RunService:IsStudio() then
					ModuleLog.Every(
						string.format("motion-confirmed:%d", player.UserId),
						30,
						"Security",
						string.format("%s reached confirmed motion threshold (Studio: no enforcement)", player.Name)
					)
				else
					self:_enforce(player, {
						ServerConfirmed = true,
						CorroboratedSignals = 2,
						Rule = if state.BarrierCrossings >= 3
							then "character-speed-and-barrier-v1"
							else "character-speed-and-flight-v1",
					})
				end
			elseif state.Score >= CORRECTION_SCORE then
				corrected = correctMotion(player, state, root, now)
			end
			if not corrected then

				state.LastPosition = root.Position
			end
		else
			state.Score = math.max(0, state.Score - elapsed * 1.5)
			state.LastPosition = root.Position
			state.LastSafeCFrame = root.CFrame
		end
	end

	function CharacterIntegrity:GrantMovementGrace(player: Player, seconds: number?): ()
		local character = player.Character
		if not character then
			return
		end
		character:SetAttribute(
			SERVER_GRACE_ATTRIBUTE,
			Workspace:GetServerTimeNow() + math.clamp(seconds or 2, 0.1, 30)
		)
	end

	function CharacterIntegrity:Start(): ()
		if self._heartbeat then
			return
		end
		if Players.CharacterAutoLoads == false then
			self._alive = true
			self._playerRemoving = Players.PlayerRemoving:Connect(function(player)
				self._players[player] = nil
			end)
			return
		end
		self._alive = true
		self._playerRemoving = Players.PlayerRemoving:Connect(function(player)
			self._players[player] = nil
		end)
		self._heartbeat = RunService.Heartbeat:Connect(function(deltaTime)
			self._accumulator += deltaTime
			if self._accumulator < SAMPLE_SECONDS then
				return
			end
			self._accumulator %= SAMPLE_SECONDS
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				self:_observe(player, now)
			end
		end)
	end

	function CharacterIntegrity:Destroy(): ()
		self._alive = false
		if self._heartbeat then
			self._heartbeat:Disconnect()
			self._heartbeat = nil
		end
		if self._playerRemoving then
			self._playerRemoving:Disconnect()
			self._playerRemoving = nil
		end
		for token, worker in self._workers do
			pcall(task.cancel, worker)
			self._workers[token] = nil
		end
		table.clear(self._players)
	end

	return CharacterIntegrity
end
