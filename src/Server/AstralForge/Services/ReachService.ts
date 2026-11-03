// The Reaches on the server: who has emptied which outcrop (and when it grows back), and the Rift Warden fight
// that everyone in the server shares. Astral Forge is played in its interface, so this is all state and rules,
// no world instances. The Warden's public state is published as attributes on ReplicatedStorage.AstralForgeWarden
// so every client's health bar moves with every strike. Anything that touches a profile goes through the hooks
// GameService attaches (it owns profiles).
import { Service } from "@flamework/core";
import * as Reaches from "../../../Shared/AstralForge/Shared/Reaches";
import OreConfig = require("../../../Shared/AstralForge/Shared/SharedData/OreConfig");

const Players = game.GetService("Players");
const ReplicatedStorage = game.GetService("ReplicatedStorage");
const Workspace = game.GetService("Workspace");

export interface ReachHooks {
	/** undefined while the profile is still loading */
	rebirths: (player: Player) => number | undefined;
	/** credits the ore and returns the amount, or undefined if nothing was credited */
	mine: (player: Player, oreId: string) => number | undefined;
	bossBonus: (player: Player) => number;
	reward: (player: Player, spoils: Reaches.Spoils) => boolean;
	effect: (player: Player, payload: object) => void;
	toast: (player: Player, title: string, body: string, tone: string) => void;
	random: () => number;
}

export interface WardenPublic {
	YourDamage: number;
	YourStrikes: number;
	Fighters: number;
	StunnedUntil: number;
}

export interface Outcome {
	ok: boolean;
	message: string;
	extra?: Record<string, unknown>;
}

@Service({ loadOrder: 2 })
export class ReachService {
	private _hooks?: ReachHooks;
	private _attached = false;
	private _alive = true;
	private _board?: Folder;
	// mining: when each player's view of each outcrop grows back (server os.clock)
	private _regrow = new Map<number, Map<string, number>>();
	// the Warden
	private _state = "Active";
	private _hp = 0;
	private _maxHp = 0;
	private _respawnAt = 0;
	private _nextSlam = 0;
	private _slamFrom = 0;
	private _slamAt = 0;
	private _damage = new Map<number, number>();
	private _strikes = new Map<number, number>();
	private _lastStrikeAt = new Map<number, number>();
	private _nextStrike = new Map<number, number>();
	private _stunnedUntil = new Map<number, number>();

	Attach(hooks: ReachHooks) {
		this._hooks = hooks;
		if (this._attached) {
			return;
		}
		this._attached = true;
		const old = ReplicatedStorage.FindFirstChild("AstralForgeWarden");
		if (old !== undefined) {
			old.Destroy();
		}
		const board = new Instance("Folder");
		board.Name = "AstralForgeWarden";
		board.Parent = ReplicatedStorage;
		this._board = board;
		this._respawn();
		Players.PlayerRemoving.Connect((player) => {
			this._regrow.delete(player.UserId);
			this._nextStrike.delete(player.UserId);
			this._stunnedUntil.delete(player.UserId);
			this._lastStrikeAt.delete(player.UserId);
		});
		task.spawn(() => {
			while (this._alive) {
				task.wait(0.25);
				const [ok, problem] = pcall(() => this._step());
				if (!ok) {
					warn("[Reaches] warden step failed: " + tostring(problem));
				}
			}
		});
	}

	Destroy() {
		this._alive = false;
	}

	// ── state for the client ───────────────────────────────────────────────────

	WardenState(player: Player): WardenPublic {
		let fighters = 0;
		for (const [, strikes] of this._strikes) {
			if (strikes > 0) fighters += 1;
		}
		const stunned = this._stunnedUntil.get(player.UserId) ?? 0;
		return {
			YourDamage: this._damage.get(player.UserId) ?? 0,
			YourStrikes: this._strikes.get(player.UserId) ?? 0,
			Fighters: fighters,
			StunnedUntil: stunned > os.clock() ? Workspace.GetServerTimeNow() + (stunned - os.clock()) : 0,
		};
	}

	/** outcrops this player has emptied, with the server time each one grows back */
	Depleted(player: Player): Record<string, number> {
		const out: Record<string, number> = {};
		const mine = this._regrow.get(player.UserId);
		if (mine === undefined) {
			return out;
		}
		const clock = os.clock();
		const serverNow = Workspace.GetServerTimeNow();
		for (const [id, grownAt] of mine) {
			if (grownAt > clock) {
				out[id] = serverNow + (grownAt - clock);
			}
		}
		return out;
	}

	// ── mining ─────────────────────────────────────────────────────────────────

	Mine(player: Player, rawNode: unknown): Outcome {
		const hooks = this._hooks;
		if (hooks === undefined) {
			return { ok: false, message: "The Reaches aren't ready yet." };
		}
		const [entry] = Reaches.parseNodeId(rawNode);
		if (entry === undefined) {
			return { ok: false, message: "That outcrop doesn't exist." };
		}
		const id = rawNode as string;
		const rebirths = hooks.rebirths(player);
		if (rebirths === undefined) {
			return { ok: false, message: "Your profile is still loading." };
		}
		if (!Reaches.regionOpen(entry, rebirths)) {
			return { ok: false, message: `${entry.Name} opens after ${entry.MinRebirths} rebirth${entry.MinRebirths === 1 ? "" : "s"}.` };
		}
		let mine = this._regrow.get(player.UserId);
		if (mine === undefined) {
			mine = new Map();
			this._regrow.set(player.UserId, mine);
		}
		const clock = os.clock();
		if ((mine.get(id) ?? 0) > clock) {
			return { ok: false, message: "That outcrop is still growing back." };
		}
		const amount = hooks.mine(player, entry.Ore);
		if (amount === undefined) {
			return { ok: false, message: "Nothing came loose. Try again." };
		}
		mine.set(id, clock + OreConfig.Ore.RegrowSeconds);
		return {
			ok: true,
			message: `+${amount} ${entry.Ore}`,
			extra: { Node: id, Ore: entry.Ore, Amount: amount, RegrowAt: Workspace.GetServerTimeNow() + OreConfig.Ore.RegrowSeconds },
		};
	}

	// ── the Warden ─────────────────────────────────────────────────────────────

	private _publish() {
		const board = this._board;
		if (board === undefined) {
			return;
		}
		const serverNow = Workspace.GetServerTimeNow();
		board.SetAttribute("State", this._state);
		board.SetAttribute("Hp", this._hp);
		board.SetAttribute("MaxHp", this._maxHp);
		board.SetAttribute("RespawnAt", this._respawnAt);
		// the slam window in server time; a client compares it with GetServerTimeNow
		const clock = os.clock();
		board.SetAttribute("SlamFrom", this._slamAt > clock ? serverNow - (clock - this._slamFrom) : 0);
		board.SetAttribute("SlamAt", this._slamAt > clock ? serverNow + (this._slamAt - clock) : 0);
	}

	private _respawn() {
		this._maxHp = Reaches.wardenMaxHp(Players.GetPlayers().size());
		this._hp = this._maxHp;
		this._state = "Active";
		this._respawnAt = 0;
		this._damage.clear();
		this._strikes.clear();
		this._nextSlam = os.clock() + Reaches.WARDEN.SlamEvery;
		this._slamAt = 0;
		this._publish();
	}

	Strike(player: Player): Outcome {
		const hooks = this._hooks;
		if (hooks === undefined || this._state !== "Active") {
			return { ok: false, message: "The Warden isn't here right now." };
		}
		const clock = os.clock();
		const userId = player.UserId;
		// refusals the page explains itself say "slow down", which the client treats as an expected, quiet refusal
		if (clock < (this._nextStrike.get(userId) ?? 0)) {
			return { ok: false, message: "Slow down." };
		}
		this._nextStrike.set(userId, clock + Reaches.WARDEN.StrikeCooldown);
		const stunned = this._stunnedUntil.get(userId) ?? 0;
		if (clock < stunned) {
			return { ok: false, message: "Still stunned, slow down.", extra: { Stunned: true } };
		}
		// striking into the wind-up gets you caught by the slam
		if (this._slamAt > clock) {
			this._stunnedUntil.set(userId, this._slamAt + Reaches.WARDEN.StunSeconds);
			return {
				ok: false,
				message: "Caught by the slam. Slow down and wait it out next time.",
				extra: { Caught: true, StunnedUntil: Workspace.GetServerTimeNow() + (this._slamAt - clock) + Reaches.WARDEN.StunSeconds },
			};
		}
		const [damage, crit] = Reaches.strikeDamage(hooks.bossBonus(player), hooks.random());
		this._damage.set(userId, (this._damage.get(userId) ?? 0) + damage);
		this._strikes.set(userId, (this._strikes.get(userId) ?? 0) + 1);
		this._lastStrikeAt.set(userId, clock);
		this._hp = math.max(0, this._hp - damage);
		this._publish();
		const felled = this._hp <= 0;
		if (felled) {
			task.defer(() => this._fell());
		}
		return { ok: true, message: crit ? "Critical strike!" : "Hit.", extra: { Damage: damage, Crit: crit, Felled: felled } };
	}

	private _fell() {
		const hooks = this._hooks!;
		if (this._state !== "Active") {
			return;
		}
		this._state = "Down";
		this._respawnAt = Workspace.GetServerTimeNow() + Reaches.WARDEN.RespawnSeconds;
		this._slamAt = 0;
		this._publish();
		const shares = Reaches.spoils(this._damage, this._strikes);
		for (const player of Players.GetPlayers()) {
			const share = shares.get(player.UserId);
			if (share !== undefined && hooks.reward(player, share)) {
				hooks.effect(player, { Type: "WardenFelled", Starsteel: share.Starsteel, Stardust: share.Stardust, Top: share.Top });
			} else if (this._damage.has(player.UserId)) {
				hooks.toast(player, "The Rift Warden fell", `It takes ${Reaches.WARDEN.MinStrikes} strikes to share the spoils. It re-forms in two minutes.`, "Info");
			}
		}
		this._damage.clear();
		this._strikes.clear();
		task.delay(Reaches.WARDEN.RespawnSeconds, () => {
			if (this._alive && this._state === "Down") {
				this._respawn();
			}
		});
	}

	private _step() {
		if (this._state !== "Active") {
			return;
		}
		const clock = os.clock();
		if (this._slamAt > 0 && clock >= this._slamAt) {
			this._slamAt = 0;
			this._publish();
		}
		if (clock < this._nextSlam) {
			return;
		}
		// the Warden only winds up while somebody is fighting it
		let fighting = false;
		for (const [, at] of this._lastStrikeAt) {
			if (clock - at < 10) {
				fighting = true;
				break;
			}
		}
		if (!fighting) {
			this._nextSlam = clock + 3;
			return;
		}
		this._nextSlam = clock + Reaches.WARDEN.SlamEvery;
		this._slamFrom = clock;
		this._slamAt = clock + Reaches.WARDEN.SlamWarning;
		this._publish();
	}
}
