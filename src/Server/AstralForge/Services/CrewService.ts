// Crews: small parties inside this server (see Shared/CrewMath for the rules).
// Server-local by design: a crew lives as long as two members share the server. Only the
// per-player daily claim record persists (profile.Flags.CrewDay / CrewClaimed).
import { Dict, num, req } from "./LuaInterop";

const HttpService = game.GetService("HttpService");
const Players = game.GetService("Players");
const ReplicatedStorage = game.GetService("ReplicatedStorage");
const TextChatService = game.GetService("TextChatService");
const TextService = game.GetService("TextService");

interface ClaimRecord {
	Day: number;
	Claimed: unknown;
}

interface CrewMathApi {
	MAX_MEMBERS: number;
	MIN_CONTRIBUTION: number;
	INVITE_SECONDS: number;
	GOAL_TIERS: Array<{ Target: number; Stardust: number }>;
	dayOf: (this: void, now: number) => number;
	normalizeRecord: (this: void, day: unknown, claimed: unknown, today: number) => ClaimRecord;
	isClaimed: (this: void, record: ClaimRecord, index: number) => boolean;
	multiplier: (this: void, members: number) => number;
	cleanName: (this: void, raw: unknown) => string | undefined;
	tierReached: (this: void, pooled: number) => number;
	canClaim: (
		this: void,
		record: ClaimRecord,
		tier: number,
		pooled: number,
		contribution: number,
	) => LuaTuple<[boolean, string | undefined]>;
	markClaimed: (this: void, record: ClaimRecord, tier: number) => ClaimRecord;
}

interface ChatRulesApi {
	crewChannel: (this: void, id: string) => string;
	allows: (this: void, policy: number, isFriend: boolean) => boolean;
}

interface CrewData {
	Get(player: Player): Dict | undefined;
	AtomicUpdate(
		player: Player,
		transform: (profile: Dict) => unknown,
		flag?: boolean,
		label?: string,
	): LuaTuple<[boolean, unknown]>;
}

const shared = ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared");
const CrewMath = req<CrewMathApi>(shared.WaitForChild("CrewMath"));
const ChatRules = req<ChatRulesApi>(shared.WaitForChild("ChatRules"));

interface Crew {
	Id: string;
	Name: string;
	Leader: number;
	Members: number[];
	Day: number;
	Pooled: number;
	Contribution: Map<number, number>;
	Channel?: TextChannel;
}

function fail(message: string) {
	return { ok: false, error: message };
}

const flagsOf = (profile: Dict | undefined): Dict | undefined =>
	profile && typeIs(profile.Flags, "table") ? (profile.Flags as Dict) : undefined;

class CrewService {
	_effect: RemoteEvent;
	_data: CrewData;
	_alive = true;
	_crews = new Map<string, Crew>();
	_memberOf = new Map<number, string>();
	_invites = new Map<number, { FromUserId: number; ExpiresAt: number }>();
	_removing: RBXScriptConnection;

	constructor(effect: RemoteEvent, data: CrewData) {
		this._effect = effect;
		this._data = data;
		this._removing = Players.PlayerRemoving.Connect((player) => {
			this._invites.delete(player.UserId);
			this._leave(player.UserId, "left the server");
		});
	}

	_crewOf(userId: number): Crew | undefined {
		const id = this._memberOf.get(userId);
		return id !== undefined ? this._crews.get(id) : undefined;
	}

	_rollDay(crew: Crew) {
		const today = CrewMath.dayOf(os.time());
		if (crew.Day !== today) {
			crew.Day = today;
			crew.Pooled = 0;
			crew.Contribution = new Map();
		}
	}

	_snapshot(crew: Crew, viewer: number): Dict {
		this._rollDay(crew);
		const members: Dict[] = [];
		for (const userId of crew.Members) {
			const player = Players.GetPlayerByUserId(userId);
			members.push({
				UserId: userId,
				Name: player ? player.Name : tostring(userId),
				DisplayName: player ? player.DisplayName : tostring(userId),
				Leader: userId === crew.Leader,
				Collects: crew.Contribution.get(userId) ?? 0,
				Zone: player ? player.GetAttribute("CurrentZone") : undefined,
			});
		}
		const viewerPlayer = Players.GetPlayerByUserId(viewer);
		const profile = viewerPlayer ? this._data.Get(viewerPlayer) : undefined;
		const flags = flagsOf(profile);
		const record = CrewMath.normalizeRecord(flags && flags.CrewDay, flags && flags.CrewClaimed, crew.Day);
		const tiers: Dict[] = [];
		CrewMath.GOAL_TIERS.forEach((tier, i) => {
			tiers[i] = { Target: tier.Target, Stardust: tier.Stardust, Claimed: CrewMath.isClaimed(record, i + 1) };
		});
		return {
			Id: crew.Id,
			Name: crew.Name,
			Leader: crew.Leader,
			Members: members,
			Max: CrewMath.MAX_MEMBERS,
			Bonus: CrewMath.multiplier(crew.Members.size()) - 1,
			Pooled: crew.Pooled,
			Tiers: tiers,
			MinContribution: CrewMath.MIN_CONTRIBUTION,
			Channel: ChatRules.crewChannel(crew.Id),
		};
	}

	_push(crew: Crew) {
		for (const userId of crew.Members) {
			const player = Players.GetPlayerByUserId(userId);
			if (player) {
				this._effect.FireClient(player, { Type: "CrewState", Crew: this._snapshot(crew, userId) });
			}
		}
	}

	_notify(userId: number, payload: unknown) {
		const player = Players.GetPlayerByUserId(userId);
		if (player) {
			this._effect.FireClient(player, payload);
		}
	}

	// Private crew chat: a TextChannel whose only sources are the members.
	_openChannel(crew: Crew) {
		const channels = TextChatService.FindFirstChild("TextChannels");
		if (channels === undefined) {
			return;
		}
		const channel = new Instance("TextChannel");
		channel.Name = ChatRules.crewChannel(crew.Id);
		channel.Parent = channels;
		crew.Channel = channel;
		for (const userId of crew.Members) {
			task.spawn(() => {
				pcall(() => channel.AddUserAsync(userId));
			});
		}
	}

	_dropFromChannel(crew: Crew, userId: number) {
		const channel = crew.Channel;
		if (channel === undefined) {
			return;
		}
		for (const source of channel.GetChildren()) {
			if (source.IsA("TextSource") && source.UserId === userId) {
				source.Destroy();
			}
		}
	}

	_disband(crew: Crew, reason: string) {
		for (const userId of crew.Members) {
			this._memberOf.delete(userId);
			this._notify(userId, { Type: "CrewState", Crew: undefined, Reason: reason });
		}
		if (crew.Channel) {
			crew.Channel.Destroy();
		}
		this._crews.delete(crew.Id);
	}

	_leave(userId: number, reason: string) {
		const crew = this._crewOf(userId);
		if (crew === undefined) {
			return;
		}
		const index = crew.Members.indexOf(userId);
		if (index !== -1) {
			crew.Members.remove(index);
		}
		this._memberOf.delete(userId);
		this._dropFromChannel(crew, userId);
		this._notify(userId, { Type: "CrewState", Crew: undefined, Reason: reason });
		if (crew.Members.size() < 2) {
			this._disband(crew, "Your crew disbanded.");
			return;
		}
		if (crew.Leader === userId) {
			crew.Leader = crew.Members[0]; // the longest-standing member leads next
		}
		this._push(crew);
	}

	_filterName(player: Player, raw: unknown): string | undefined {
		const name = CrewMath.cleanName(raw);
		if (name === undefined) {
			return undefined;
		}
		const [ok, filtered] = pcall(() =>
			TextService.FilterStringAsync(name, player.UserId, Enum.TextFilterContext.PublicChat).GetNonChatStringForBroadcastAsync(),
		);
		return ok && typeIs(filtered, "string") && filtered !== "" ? filtered : undefined;
	}

	_create(player: Player, name?: string): Crew {
		const crew: Crew = {
			Id: HttpService.GenerateGUID(false).sub(1, 8),
			Name: name ?? `${player.DisplayName}'s crew`,
			Leader: player.UserId,
			Members: [player.UserId],
			Day: CrewMath.dayOf(os.time()),
			Pooled: 0,
			Contribution: new Map(),
			Channel: undefined,
		};
		this._crews.set(crew.Id, crew);
		this._memberOf.set(player.UserId, crew.Id);
		this._openChannel(crew);
		return crew;
	}

	Get(player: Player) {
		const crew = this._crewOf(player.UserId);
		let invite = this._invites.get(player.UserId);
		if (invite && invite.ExpiresAt < os.time()) {
			this._invites.delete(player.UserId);
			invite = undefined;
		}
		const from = invite ? Players.GetPlayerByUserId(invite.FromUserId) : undefined;
		return {
			ok: true,
			Crew: crew ? this._snapshot(crew, player.UserId) : undefined,
			Invite: from && invite ? { FromUserId: from.UserId, FromName: from.DisplayName, ExpiresAt: invite.ExpiresAt } : undefined,
		};
	}

	Invite(player: Player, payload: unknown) {
		const targetId = typeIs(payload, "table") ? num((payload as Dict).UserId) : undefined;
		const target = targetId !== undefined ? Players.GetPlayerByUserId(targetId) : undefined;
		if (target === undefined || target === player) {
			return fail("Pick another player in this server.");
		}
		if (this._memberOf.get(target.UserId) !== undefined) {
			return fail(`${target.DisplayName} is already in a crew.`);
		}
		const crew = this._crewOf(player.UserId);
		if (crew && crew.Leader !== player.UserId) {
			return fail("Only the crew leader can invite.");
		}
		if (crew && crew.Members.size() >= CrewMath.MAX_MEMBERS) {
			return fail(`Crews hold ${CrewMath.MAX_MEMBERS} players.`);
		}
		// the target's Social setting decides who may invite them
		const targetProfile = this._data.Get(target);
		const settings = targetProfile && typeIs(targetProfile.Settings, "table") ? (targetProfile.Settings as Dict) : undefined;
		const policy = settings ? settings.CrewInvitePolicy : undefined;
		if (typeIs(policy, "number") && policy >= 0.25) {
			const [okFriend, isFriend] = pcall(() =>
				(target as unknown as { IsFriendsWith(userId: number): boolean }).IsFriendsWith(player.UserId),
			);
			if (!ChatRules.allows(policy, okFriend && isFriend === true)) {
				return fail(
					policy >= 0.75
						? `${target.DisplayName} isn't taking crew invites.`
						: `${target.DisplayName} only takes crew invites from friends.`,
				);
			}
		}
		const existing = this._invites.get(target.UserId);
		if (existing && existing.ExpiresAt > os.time() && existing.FromUserId !== player.UserId) {
			return fail(`${target.DisplayName} already has an invite waiting.`);
		}
		this._invites.set(target.UserId, { FromUserId: player.UserId, ExpiresAt: os.time() + CrewMath.INVITE_SECONDS });
		this._effect.FireClient(target, {
			Type: "CrewInvite",
			FromUserId: player.UserId,
			FromName: player.DisplayName,
			CrewName: crew ? crew.Name : `${player.DisplayName}'s crew`,
			ExpiresAt: os.time() + CrewMath.INVITE_SECONDS,
		});
		return { ok: true, message: `Invite sent to ${target.DisplayName}.` };
	}

	Respond(player: Player, payload: unknown) {
		const invite = this._invites.get(player.UserId);
		this._invites.delete(player.UserId);
		const accept = typeIs(payload, "table") && (payload as Dict).Accept === true;
		if (invite === undefined || invite.ExpiresAt < os.time()) {
			return fail("That invite expired.");
		}
		const inviter = Players.GetPlayerByUserId(invite.FromUserId);
		if (inviter === undefined) {
			return fail("They left the server.");
		}
		if (!accept) {
			this._notify(inviter.UserId, { Type: "CrewNotice", Text: `${player.DisplayName} declined your crew invite.` });
			return { ok: true, message: "Invite declined." };
		}
		if (this._memberOf.get(player.UserId) !== undefined) {
			return fail("Leave your current crew first.");
		}
		let crew = this._crewOf(inviter.UserId);
		if (crew === undefined) {
			crew = this._create(inviter, undefined);
		} else if (crew.Leader !== inviter.UserId) {
			return fail("That invite is no longer valid.");
		}
		if (crew.Members.size() >= CrewMath.MAX_MEMBERS) {
			return fail("That crew is full.");
		}
		crew.Members.push(player.UserId);
		this._memberOf.set(player.UserId, crew.Id);
		const joined = crew;
		if (joined.Channel) {
			task.spawn(() => {
				pcall(() => (joined.Channel as TextChannel).AddUserAsync(player.UserId));
			});
		}
		this._push(crew);
		return { ok: true, message: `You joined ${crew.Name}.` };
	}

	Leave(player: Player) {
		if (this._memberOf.get(player.UserId) === undefined) {
			return fail("You're not in a crew.");
		}
		this._leave(player.UserId, "You left the crew.");
		return { ok: true, message: "You left the crew." };
	}

	Kick(player: Player, payload: unknown) {
		const crew = this._crewOf(player.UserId);
		const targetId = typeIs(payload, "table") ? num((payload as Dict).UserId) : undefined;
		if (crew === undefined || crew.Leader !== player.UserId) {
			return fail("Only the crew leader can remove members.");
		}
		if (targetId === undefined || targetId === player.UserId || !crew.Members.includes(targetId)) {
			return fail("That player isn't in your crew.");
		}
		this._leave(targetId, "You were removed from the crew.");
		return { ok: true, message: "Removed from the crew." };
	}

	Rename(player: Player, payload: unknown) {
		const crew = this._crewOf(player.UserId);
		if (crew === undefined || crew.Leader !== player.UserId) {
			return fail("Only the crew leader can rename the crew.");
		}
		const name = this._filterName(player, typeIs(payload, "table") ? (payload as Dict).Name : undefined);
		if (name === undefined) {
			return fail("Crew names need 2 to 20 characters.");
		}
		crew.Name = name;
		this._push(crew);
		return { ok: true, message: `Crew renamed to ${name}.` };
	}

	RecordCollect(player: Player) {
		const crew = this._crewOf(player.UserId);
		if (crew === undefined) {
			return;
		}
		this._rollDay(crew);
		const before = CrewMath.tierReached(crew.Pooled);
		crew.Pooled += 1;
		crew.Contribution.set(player.UserId, (crew.Contribution.get(player.UserId) ?? 0) + 1);
		const after = CrewMath.tierReached(crew.Pooled);
		if (after > before) {
			for (const userId of crew.Members) {
				this._notify(userId, { Type: "CrewNotice", Text: `Crew goal ${after} reached. Claim it on the Crew page.` });
			}
		}
		this._push(crew);
	}

	Claim(player: Player, payload: unknown) {
		const crew = this._crewOf(player.UserId);
		if (crew === undefined) {
			return fail("Join a crew to share crew goals.");
		}
		this._rollDay(crew);
		const tier = typeIs(payload, "table") ? math.floor(num((payload as Dict).Tier) ?? 0) : 0;
		const pooled = crew.Pooled;
		const contribution = crew.Contribution.get(player.UserId) ?? 0;
		const today = crew.Day;
		const [ok, result] = this._data.AtomicUpdate(
			player,
			(profile) => {
				if (profile.Flags === undefined || profile.Flags === false) {
					profile.Flags = {};
				}
				const flags = profile.Flags as Dict;
				let record = CrewMath.normalizeRecord(flags.CrewDay, flags.CrewClaimed, today);
				const [allowed, reason] = CrewMath.canClaim(record, tier, pooled, contribution);
				if (!allowed) {
					return fail(reason ?? "You can't claim that yet.");
				}
				record = CrewMath.markClaimed(record, tier);
				flags.CrewDay = record.Day;
				flags.CrewClaimed = record.Claimed;
				const reward = (CrewMath.GOAL_TIERS as unknown as Record<number, { Stardust: number }>)[tier].Stardust;
				profile.Stardust = (num(profile.Stardust) ?? 0) + reward;
				return { ok: true, message: `+${reward} stardust from the crew goal.`, Stardust: reward };
			},
			true,
			"crew-claim",
		);
		if (!ok) {
			return fail("Couldn't save that claim. Try again.");
		}
		if (typeIs(result, "table") && (result as Dict).ok !== undefined && (result as Dict).ok !== false) {
			this._push(crew);
		}
		return result;
	}

	Multiplier(player: Player): number {
		const crew = this._crewOf(player.UserId);
		return crew ? CrewMath.multiplier(crew.Members.size()) : 1;
	}

	Shutdown() {
		this._alive = false;
		this._removing.Disconnect();
	}
}

export = table.freeze(CrewService);
