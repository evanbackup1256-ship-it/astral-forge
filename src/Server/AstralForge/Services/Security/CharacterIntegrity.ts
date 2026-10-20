import { ModuleLogApi, req } from "../LuaInterop";
import { RemoteFirewall } from "./RemoteFirewall";
import { Report } from "./SecurityLedger";

interface PlayerState {
	Character?: Model;
	LastPosition?: Vector3;
	LastSafeCFrame?: CFrame;
	LastAt: number;
	Score: number;
	SpeedBursts: number;
	BarrierCrossings: number;
	FlightBursts: number;
	Corrections: number;
	FirstSuspiciousAt: number;
	LastMitigationAt: number;
	EnforcementStarted: boolean;
	Raycast?: RaycastParams;
	LastGroundedAt: number;
}

export = () => {
	const Players = game.GetService("Players");
	const RunService = game.GetService("RunService");
	const Workspace = game.GetService("Workspace");

	const ModuleLog = req<ModuleLogApi>(script.Parent!.Parent!.Parent!.WaitForChild("ModuleLog"));

	const SAMPLE_SECONDS = 0.2;
	const MIN_BARRIER_DISTANCE = 6;
	const CORRECTION_SCORE = 7;
	const SERVER_GRACE_ATTRIBUTE = "AF_MovementGraceUntil";

	const newState = (): PlayerState => ({
		Character: undefined,
		LastPosition: undefined,
		LastSafeCFrame: undefined,
		LastAt: 0,
		Score: 0,
		SpeedBursts: 0,
		BarrierCrossings: 0,
		FlightBursts: 0,
		Corrections: 0,
		FirstSuspiciousAt: 0,
		LastMitigationAt: -math.huge,
		EnforcementStarted: false,
		Raycast: undefined,
		LastGroundedAt: 0,
	});

	const resetCharacter = (state: PlayerState, character: Model, root: BasePart, now: number): void => {
		const raycast = new RaycastParams();
		raycast.FilterType = Enum.RaycastFilterType.Exclude;
		raycast.FilterDescendantsInstances = [character];
		raycast.IgnoreWater = false;

		state.Character = character;
		state.LastPosition = root.Position;
		state.LastSafeCFrame = root.CFrame;
		state.LastAt = now;
		state.Score = 0;
		state.SpeedBursts = 0;
		state.BarrierCrossings = 0;
		state.FlightBursts = 0;
		state.Corrections = 0;
		state.FirstSuspiciousAt = 0;
		state.LastMitigationAt = -math.huge;
		state.EnforcementStarted = false;
		state.Raycast = raycast;
		state.LastGroundedAt = now;
	};

	const movementExempt = (character: Model, humanoid: Humanoid): boolean => {
		const graceUntil = character.GetAttribute(SERVER_GRACE_ATTRIBUTE);
		if (typeIs(graceUntil, "number") && Workspace.GetServerTimeNow() < graceUntil) {
			return true;
		}
		const state = humanoid.GetState();
		return (
			humanoid.Health <= 0 ||
			humanoid.SeatPart !== undefined ||
			state === Enum.HumanoidStateType.Seated ||
			state === Enum.HumanoidStateType.Swimming ||
			state === Enum.HumanoidStateType.Climbing
		);
	};

	const crossedBarrier = (params: RaycastParams, from: Vector3, to: Vector3): boolean => {
		const delta = to.sub(from);
		const horizontal = new Vector3(delta.X, 0, delta.Z);
		if (horizontal.Magnitude < MIN_BARRIER_DISTANCE) {
			return false;
		}
		const result = Workspace.Raycast(from, horizontal, params);
		if (!result || !result.Instance.IsA("BasePart") || !result.Instance.CanCollide) {
			return false;
		}
		return result.Distance + 3.5 < horizontal.Magnitude;
	};

	const airbornePlatformMotion = (params: RaycastParams, root: BasePart, humanoid: Humanoid): boolean => {
		if (!humanoid.PlatformStand) {
			return false;
		}
		const grounded = Workspace.Raycast(root.Position, new Vector3(0, -8, 0), params) !== undefined;
		return !grounded && root.AssemblyLinearVelocity.Magnitude > 18;
	};

	const shouldEnforce = (state: PlayerState, now: number): boolean => {
		if (state.EnforcementStarted || state.FirstSuspiciousAt <= 0 || now - state.FirstSuspiciousAt < 12) {
			return false;
		}
		const repeatedTraversal = state.BarrierCrossings >= 3;
		const repeatedFlight = state.FlightBursts >= 8;
		return state.SpeedBursts >= 12 && state.Corrections >= 2 && (repeatedTraversal || repeatedFlight);
	};

	const correctMotion = (player: Player, state: PlayerState, root: BasePart, now: number): boolean => {
		const safeCFrame = state.LastSafeCFrame;
		if (!safeCFrame || now - state.LastMitigationAt < 1.5) {
			return false;
		}
		state.LastMitigationAt = now;
		state.Corrections += 1;
		const character = state.Character;
		if (character) {
			character.SetAttribute(SERVER_GRACE_ATTRIBUTE, Workspace.GetServerTimeNow() + 1.25);
		}
		root.CFrame = safeCFrame;
		root.AssemblyLinearVelocity = Vector3.zero;
		root.AssemblyAngularVelocity = Vector3.zero;
		state.LastPosition = safeCFrame.Position;
		state.Score *= 0.55;
		player.SetAttribute("AF_ServerMotionCorrections", state.Corrections);
		// low weight: a rubber-band after packet loss looks the same as one correction
		Report(player, "movement", 1, "position corrected, motion score %.1f".format(state.Score));
		ModuleLog.Every(
			"motion-correct:%d".format(player.UserId),
			4,
			"Security",
			"%s motion corrected | score %.1f".format(player.Name, state.Score),
		);
		return true;
	};

	class CharacterIntegrity {
		_players = new Map<Player, PlayerState>();
		_workers = new Map<object, thread>();
		_alive = true;
		_heartbeat?: RBXScriptConnection = undefined;
		_playerRemoving?: RBXScriptConnection = undefined;
		_accumulator = 0;

		_enforce(player: Player, evidence: unknown): void {
			if (!this._alive) {
				return;
			}
			const token = {};
			const worker = task.defer(() => {
				if (this._alive) {
					RemoteFirewall.EnforceConfirmedBan(player, evidence);
				}
				this._workers.delete(token);
			});
			this._workers.set(token, worker);
		}

		_state(player: Player): PlayerState {
			let state = this._players.get(player);
			if (!state) {
				state = newState();
				this._players.set(player, state);
			}
			return state;
		}

		_observe(player: Player, now: number): void {
			const character = player.Character;
			if (!character) {
				return;
			}
			const rootInstance = character.FindFirstChild("HumanoidRootPart");
			const humanoid = character.FindFirstChildOfClass("Humanoid");
			if (!rootInstance || !rootInstance.IsA("BasePart") || !humanoid) {
				return;
			}
			const root: BasePart = rootInstance;
			const state = this._state(player);
			if (state.Character !== character || !state.Raycast) {
				resetCharacter(state, character, root, now);
				return;
			}
			const raycast = state.Raycast;

			const lastPosition = state.LastPosition;
			const elapsed = now - state.LastAt;
			state.LastAt = now;

			if (root.Position.Y < -60) {
				correctMotion(player, state, root, now);
				return;
			}

			if (!lastPosition || elapsed <= 0 || elapsed > 1 || movementExempt(character, humanoid)) {
				state.LastPosition = root.Position;
				state.LastSafeCFrame = root.CFrame;
				state.Score = math.max(0, state.Score - 1);
				return;
			}

			const delta = root.Position.sub(lastPosition);
			const horizontalDistance = new Vector3(delta.X, 0, delta.Z).Magnitude;
			const horizontalSpeed = horizontalDistance / math.max(0.05, elapsed);
			const allowedSpeed = math.max(110, humanoid.WalkSpeed * 4 + 35);
			const grounded = Workspace.Raycast(root.Position, new Vector3(0, -3, 0), raycast) !== undefined;
			if (grounded) {
				state.LastGroundedAt = now;
			}
			const airborneGrace = now - state.LastGroundedAt < 0.4;
			const fallingSlowly = root.AssemblyLinearVelocity.Y < -20 && horizontalSpeed < allowedSpeed * 0.8;
			const speedFlag =
				(!airborneGrace || fallingSlowly) &&
				(horizontalSpeed > allowedSpeed || root.AssemblyLinearVelocity.Magnitude > 275);
			const barrierFlag = crossedBarrier(raycast, lastPosition, root.Position);
			const flightFlag = !airborneGrace && airbornePlatformMotion(raycast, root, humanoid);

			if (speedFlag || barrierFlag || flightFlag) {
				if (state.FirstSuspiciousAt <= 0) {
					state.FirstSuspiciousAt = now;
				}
				if (speedFlag) {
					state.SpeedBursts += 1;
					state.Score += 1.5;
				}
				if (barrierFlag) {
					state.BarrierCrossings += 1;
					state.Score += 5;
				}
				if (flightFlag) {
					state.FlightBursts += 1;
					state.Score += 2;
				}
				player.SetAttribute("AF_ServerMotionScore", math.floor(state.Score));
				player.SetAttribute("AF_ServerMotionCorrections", state.Corrections);

				let corrected = false;
				if (shouldEnforce(state, now)) {
					state.EnforcementStarted = true;
					if (RunService.IsStudio()) {
						ModuleLog.Every(
							"motion-confirmed:%d".format(player.UserId),
							30,
							"Security",
							"%s reached confirmed motion threshold (Studio: no enforcement)".format(player.Name),
						);
					} else {
						this._enforce(player, {
							ServerConfirmed: true,
							CorroboratedSignals: 2,
							Rule:
								state.BarrierCrossings >= 3
									? "character-speed-and-barrier-v1"
									: "character-speed-and-flight-v1",
						});
					}
				} else if (state.Score >= CORRECTION_SCORE) {
					corrected = correctMotion(player, state, root, now);
				}
				if (!corrected) {
					state.LastPosition = root.Position;
				}
			} else {
				state.Score = math.max(0, state.Score - elapsed * 1.5);
				state.LastPosition = root.Position;
				state.LastSafeCFrame = root.CFrame;
			}
		}

		GrantMovementGrace(player: Player, seconds?: number): void {
			const character = player.Character;
			if (!character) {
				return;
			}
			character.SetAttribute(SERVER_GRACE_ATTRIBUTE, Workspace.GetServerTimeNow() + math.clamp(seconds ?? 2, 0.1, 30));
		}

		Start(): void {
			if (this._heartbeat) {
				return;
			}
			if ((Players.CharacterAutoLoads as boolean) === false) {
				this._alive = true;
				this._playerRemoving = Players.PlayerRemoving.Connect((player) => {
					this._players.delete(player);
				});
				return;
			}
			this._alive = true;
			this._playerRemoving = Players.PlayerRemoving.Connect((player) => {
				this._players.delete(player);
			});
			this._heartbeat = RunService.Heartbeat.Connect((deltaTime) => {
				this._accumulator += deltaTime;
				if (this._accumulator < SAMPLE_SECONDS) {
					return;
				}
				this._accumulator %= SAMPLE_SECONDS;
				const now = os.clock();
				for (const player of Players.GetPlayers()) {
					this._observe(player, now);
				}
			});
		}

		Destroy(): void {
			this._alive = false;
			if (this._heartbeat) {
				this._heartbeat.Disconnect();
				this._heartbeat = undefined;
			}
			if (this._playerRemoving) {
				this._playerRemoving.Disconnect();
				this._playerRemoving = undefined;
			}
			for (const [token, worker] of this._workers) {
				pcall(task.cancel, worker);
				this._workers.delete(token);
			}
			this._players.clear();
		}
	}

	return CharacterIntegrity;
};
