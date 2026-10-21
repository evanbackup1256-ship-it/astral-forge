// Guild documents: create/join/leave, roles, contributions, upgrades and goals.
import { T } from "../../../../Shared/AstralForge/Shared/Locale";
import { Service } from "@flamework/core";
import LeaderboardCodec from "../../Modules/LeaderboardCodec";
import OpsMath from "../../Modules/OpsMath";
import ProfileMath from "../../Modules/ProfileMath";
import StoreAccess from "../../Modules/StoreAccess";
import ServerConfig from "../../ServerConfig";
import GameConfig from "../../../../Shared/AstralForge/Shared/GameConfig";
import OmegaMath from "../../../../Shared/AstralForge/Shared/OmegaMath";
import SocialProgressionFactory from "../../../../Shared/AstralForge/Shared/SocialProgression";
import { Dict, isTable, num } from "../LuaInterop";

const Format = ProfileMath("Format") as { Number(this: void, value: unknown): string };

type Profile = Dict;

interface DataStoreLike {
	GetAsync(key: string): unknown;
	UpdateAsync(key: string, transform: (this: void, old: unknown) => unknown): unknown;
	RemoveAsync(key: string): unknown;
}

interface OrderedStoreLike {
	GetSortedAsync(
		ascending: boolean,
		pageSize: number,
		min?: unknown,
		max?: unknown,
	): { GetCurrentPage(): { key: string; value: number }[] };
	SetAsync(key: string, value: unknown): unknown;
	RemoveAsync(key: string): unknown;
}

interface MemberRec {
	Name?: string;
	Role?: string;
	JoinedAt?: number;
	Contributed?: number;
	[key: string]: unknown;
}

interface GoalTypeDef {
	Id: string;
	Reward?: unknown;
	[key: string]: unknown;
}

interface GuildMathKit {
	FiniteNonNegative(this: void, value: unknown): number;
	UpgradeCost(this: void, definition: unknown, level: number): number;
	UpgradeEffect(this: void, definition: unknown, level: number): number;
	EmptyBonuses(this: void): Record<string, number>;
	BonusesFromUpgrades(this: void, upgrades: unknown, upgradeDefs: unknown): Record<string, number>;
	NormalizeContributionAmount(this: void, amount: unknown): LuaTuple<[number | undefined, string | undefined]>;
	CanAffordBank(this: void, omegaMath: unknown, currency: string, bank: unknown, cost: number): boolean;
	CreditBank(this: void, omegaMath: unknown, currency: string, bank: unknown, amount: number): unknown;
	DebitBank(this: void, omegaMath: unknown, currency: string, bank: unknown, cost: number): unknown;
	AddClamped(this: void, current: unknown, amount: number): number;
}

interface GuildGoalMathKit {
	GoalTypeById(this: void, types: unknown, typeId: string): GoalTypeDef | undefined;
	EnsureGoal(this: void, guild: unknown, now: number, goalConfig: unknown): boolean;
	AdvanceGoal(
		this: void,
		guild: unknown,
		userKey: string,
		metric: string,
		amount: number,
		now: number,
		goalConfig: unknown,
	): void;
	CanClaimGoal(
		this: void,
		goal: unknown,
		userKey: string,
		isMember: boolean,
		minContribution: number,
	): LuaTuple<[boolean, string | undefined]>;
}

interface SocialKit {
	canManage(this: void, actor: unknown, target: unknown, operation?: string): boolean;
	successor(this: void, members: unknown, departing: unknown): string | undefined;
}

interface GuildConfigShape {
	CreateCost: number;
	RenameCost: number;
	RenameCooldownSeconds: number;
	MaxMembers: number;
	Upgrades: Record<string, Dict | undefined>;
	Goal: {
		DurationSeconds: number;
		MinContributionForReward: number;
		Types: GoalTypeDef[];
		[key: string]: unknown;
	};
	[key: string]: unknown;
}

// GameConfig is exported as an untyped Dict; the guild slice is shaped here.
const GuildConfig = GameConfig.Guild as GuildConfigShape;

type Triple = LuaTuple<[boolean, string | undefined, Dict | undefined]>;
type UpdateResult = LuaTuple<[boolean, string | undefined, Dict | undefined]>;
type Transform = (this: void, doc: Dict) => Dict | undefined;

function copy(value: unknown): unknown {
	if (!isTable(value)) return value;
	const result: Dict = {};
	for (const [key, child] of pairs(value)) {
		result[key as string] = copy(child);
	}
	return result;
}

function copyDoc(value: unknown): Dict {
	return copy(value) as Dict;
}

function emptyGuild(): Dict {
	return {
		Id: "",
		Name: "",
		Tag: "",
		Level: 0,
		XP: 0,
		Activity: 0,
		BankCash: 0,
		BankDust: 0,
		Members: {},
		Upgrades: {},
		CreatedAt: 0,
		OwnerUserId: 0,
	};
}

const RunService = game.GetService("RunService");
const HttpService = game.GetService("HttpService");

const GuildMath = OpsMath("GuildMath") as GuildMathKit;
const GuildGoalMath = OpsMath("GuildGoalMath") as GuildGoalMathKit;
const Social = SocialProgressionFactory(
	OmegaMath as unknown as Parameters<typeof SocialProgressionFactory>[0],
) as SocialKit;

const getOrderedStore = StoreAccess.ordered;
const getDataStore = StoreAccess.data;

function normalTag(tag: string): string {
	return string.upper(string.gsub(tag, "%s+", "")[0]);
}

function upgradeCost(definition: unknown, level: number): number {
	return GuildMath.UpgradeCost(definition, level);
}

function goalTypeById(typeId: string): GoalTypeDef | undefined {
	return GuildGoalMath.GoalTypeById(GuildConfig.Goal.Types, typeId);
}

function ensureGoal(guild: unknown, now: number): boolean {
	return GuildGoalMath.EnsureGoal(guild, now, GuildConfig.Goal);
}

function advanceGoal(guild: unknown, userKey: string, metric: string, amount: number, now: number) {
	GuildGoalMath.AdvanceGoal(guild, userKey, metric, amount, now, GuildConfig.Goal);
}

function emptyBonuses(): Record<string, number> {
	return GuildMath.EmptyBonuses();
}

function bonusesFromDocument(guild: unknown): Record<string, number> {
	if (!isTable(guild)) {
		return emptyBonuses();
	}
	return GuildMath.BonusesFromUpgrades(guild.Upgrades, GuildConfig.Upgrades);
}

function members(doc: Dict): Record<string, MemberRec> {
	return doc.Members as Record<string, MemberRec>;
}

function playerName(player: Player): string {
	return player.DisplayName !== "" ? player.DisplayName : player.Name;
}

function guildIdOf(profile: Profile): string {
	const guild = profile.Guild as Dict | undefined;
	return (typeIs(guild, "table") && typeIs(guild.Id, "string") ? guild.Id : "") as string;
}

@Service({ loadOrder: 1 })
export class GuildService {
	private _cache: Record<string, Dict> = {};
	private _cacheExpiry: Record<string, number> = {};
	private _cachePruneAt = 0;
	private _studio: Record<string, Dict> = {};
	private _store = getDataStore(ServerConfig.GuildStoreName as string) as DataStoreLike;
	private _leaderboard = getOrderedStore(ServerConfig.GuildLeaderboardStoreName as string) as OrderedStoreLike;
	private _leaderboardPending: Record<string, number> = {};
	private _leaderboardBusy: Record<string, boolean> = {};
	private _leaderboardCache: Dict[] | undefined = undefined;
	private _leaderboardCacheExpires = 0;
	private _warmQueue: string[] = [];
	private _warmQueued: Record<string, boolean> = {};
	private _warmWorkers = 0;
	private _running = true;
	private _workers = new Map<object, thread>();

	private _spawnWorker(callback: (this: void) => void): thread | undefined {
		if (!this._running) return undefined;
		const token = {};
		const worker = task.defer(() => {
			if (this._running) callback();
			this._workers.delete(token);
		});
		this._workers.set(token, worker);
		return worker;
	}

	private _queueWarmRead(id: string) {
		if (!this._running) return;
		if (this._cache[id] || this._studio[id] || this._warmQueued[id]) return;
		this._warmQueued[id] = true;
		this._warmQueue.push(id);
		while (this._warmWorkers < 2 && this._warmQueue.size() > 0) {
			this._warmWorkers += 1;
			const worker = this._spawnWorker(() => {
				const [ok, err] = pcall(() => {
					while (this._running && this._warmQueue.size() > 0) {
						const nextId = this._warmQueue.shift();
						if (nextId !== undefined) {
							const [readOk, readErr] = pcall(() => {
								this._read(nextId);
							});
							delete this._warmQueued[nextId];
							if (readOk) {
								this._leaderboardCacheExpires = 0;
							} else {
								warn(
									string.format(
										"[WARN] [GUILD] warm read failed for %s — %s",
										tostring(nextId),
										tostring(readErr),
									),
								);
							}
						}
					}
				});
				this._warmWorkers -= 1;
				if (!ok) {
					warn(string.format("[WARN] [GUILD] warm worker crashed — %s", tostring(err)));
				}
			});
			if (worker === undefined) {
				this._warmWorkers -= 1;
			}
		}
	}

	private _queueLeaderboard(id: string, activity: number) {
		if (!this._running) return;
		this._leaderboardPending[id] = LeaderboardCodec.Encode(activity);
		if (this._leaderboardBusy[id]) return;
		this._leaderboardBusy[id] = true;
		const worker = this._spawnWorker(() => {
			let lastWarnAt = 0;
			const [ok, err] = pcall(() => {
				while (this._running && this._leaderboardPending[id] !== undefined) {
					const encoded = this._leaderboardPending[id];
					delete this._leaderboardPending[id];
					const [wrote, writeErr] = pcall(() => {
						this._leaderboard.SetAsync(id, encoded);
					});
					if (!wrote) {
						if (this._leaderboardPending[id] === undefined) {
							this._leaderboardPending[id] = encoded;
						}
						const now = os.clock();
						if (now - lastWarnAt >= 30) {
							lastWarnAt = now;
							warn(
								string.format(
									"[WARN] [GUILD] leaderboard write failed for %s — %s",
									id,
									tostring(writeErr),
								),
							);
						}
						task.wait(8);
					}
				}
			});
			delete this._leaderboardBusy[id];
			if (!ok) {
				warn(
					string.format(
						"[WARN] [GUILD] leaderboard worker crashed for %s — %s",
						tostring(id),
						tostring(err),
					),
				);
			}
		});
		if (worker === undefined) {
			delete this._leaderboardBusy[id];
		}
	}

	public Destroy() {
		if (!this._running) return;
		this._running = false;
		for (const [, worker] of this._workers) {
			pcall(() => task.cancel(worker));
		}
		this._workers.clear();
		table.clear(this._warmQueue);
		table.clear(this._warmQueued);
		table.clear(this._leaderboardPending);
		table.clear(this._leaderboardBusy);
		this._warmWorkers = 0;
	}

	private _pruneCache() {
		const now = os.clock();
		if (now < this._cachePruneAt) return;
		this._cachePruneAt = now + 30;
		for (const [id, expiresAt] of pairs(this._cacheExpiry)) {
			if (!typeIs(expiresAt, "number") || expiresAt <= now) {
				delete this._cacheExpiry[id];
				delete this._cache[id];
			}
		}
	}

	private _read(id: string): Dict | undefined {
		this._pruneCache();
		if (RunService.IsStudio() && this._studio[id]) {
			return copyDoc(this._studio[id]);
		}
		const cached = this._cache[id];
		if (cached && (this._cacheExpiry[id] ?? 0) > os.clock()) {
			return copyDoc(cached);
		}
		const [ok, result] = pcall(() => {
			return this._store.GetAsync(id);
		});
		if (ok && isTable(result)) {
			this._cache[id] = result;
			this._cacheExpiry[id] = os.clock() + 60;
			return copyDoc(result);
		}

		if (ok && result === undefined && !RunService.IsStudio()) {
			delete this._cache[id];
			delete this._cacheExpiry[id];
			return undefined;
		}
		if (cached) {
			return copyDoc(cached);
		}
		return undefined;
	}

	public _update(id: string, transform: Transform): UpdateResult {
		let updated: Dict | undefined;
		const apply = (current: unknown): unknown => {
			// UpdateAsync can invoke this callback again after a concurrent write.
			// No approval from an earlier attempt may survive a cancelled final attempt.
			updated = undefined;
			let doc = isTable(current) ? (current as Dict) : undefined;
			if (doc === undefined && RunService.IsStudio()) {
				doc = this._studio[id] ?? this._cache[id];
			}
			if (!isTable(doc)) {
				return undefined;
			}
			const nextDoc = transform(copyDoc(doc));
			if (nextDoc === undefined) {
				return undefined;
			}
			updated = nextDoc;
			return nextDoc;
		};
		const [ok, err] = pcall(() => {
			return this._store.UpdateAsync(id, apply);
		});
		if (!ok) {
			if (!RunService.IsStudio()) {
				return $tuple(false, tostring(err), undefined);
			}
			const fallback = this._studio[id] ?? this._cache[id];
			if (isTable(fallback)) {
				updated = transform(copyDoc(fallback));
				if (isTable(updated)) {
					this._studio[id] = updated;
				}
			} else {
				return $tuple(false, tostring(err), undefined);
			}
		}
		if (!isTable(updated)) {
			return $tuple(false, T("GuildService.GuildRequestWasDenied"), undefined);
		}
		this._cache[id] = updated;
		this._cacheExpiry[id] = os.clock() + 60;
		if (RunService.IsStudio()) {
			this._studio[id] = updated;
		}
		this._queueLeaderboard(id, num(updated.Activity) ?? 0);
		return $tuple(true, undefined, copyDoc(updated));
	}

	public _findByTag(tag: string): Dict | undefined {
		this._pruneCache();
		const wanted = normalTag(tag);
		for (const [, doc] of pairs(this._cache)) {
			if (doc.Tag === wanted) return copyDoc(doc);
		}
		for (const [, doc] of pairs(this._studio)) {
			if (doc.Tag === wanted) return copyDoc(doc);
		}

		const [ok, id] = pcall(() => this._store.GetAsync(`tag:${wanted}`));
		if (ok && typeIs(id, "string")) return this._read(id);
		return undefined;
	}

	public Create(player: Player, profile: Profile, rawName: string, rawTag: string): Triple {
		if (!typeIs(rawName, "string") || !typeIs(rawTag, "string"))
			return $tuple(false, T("GuildService.GuildNamesMustBe3"), undefined);
		const profileGuild = profile.Guild as Dict | undefined;
		if (isTable(profileGuild) && profileGuild.Id !== "") {
			const existing =
				this.GetCachedPublic(profileGuild.Id as string) ?? this.GetPublic(profileGuild.Id as string);
			if (existing) return $tuple(true, T("GuildService.YouReAlreadyInThis"), existing);
			return $tuple(false, T("GuildService.LeaveYourCurrentGuildFirst"), undefined);
		}
		const name = string.gsub(string.gsub(rawName, "^%s+", "")[0], "%s+$", "")[0];
		const tag = normalTag(rawTag);
		if (name.size() < 3 || name.size() > 28 || string.match(name, "^[%w%s%-_]+$")[0] === undefined)
			return $tuple(false, T("GuildService.GuildNamesMustBe3"), undefined);
		if (tag.size() < 3 || tag.size() > 4 || string.match(tag, "^[A-Z0-9]+$")[0] === undefined)
			return $tuple(false, T("GuildService.GuildTagsMustBe3"), undefined);
		if (OmegaMath.Lt(profile.Cash as never, GuildConfig.CreateCost))
			return $tuple(false, T("GuildService.YouNeedMoreFluxTo"), undefined);
		if (this._findByTag(tag)) return $tuple(false, T("GuildService.ThatGuildTagIsAlready"), undefined);
		const id = HttpService.GenerateGUID(false);
		const doc: Dict = {
			Id: id,
			Name: name,
			Tag: tag,
			Level: 1,
			XP: 0,
			Activity: 0,
			BankCash: 0,
			BankDust: 0,
			Members: {
				[tostring(player.UserId)]: {
					Name: playerName(player),
					Role: "Leader",
					JoinedAt: os.time(),
					Contributed: 0,
				},
			},
			Upgrades: {},
			CreatedAt: os.time(),
			OwnerUserId: player.UserId,
		};
		ensureGoal(doc, os.time());
		let documentCreated = false;
		let tagClaimed = false;
		const [ok, err] = pcall(() => {
			this._store.UpdateAsync(id, (existing) => {
				documentCreated = false;
				if (existing !== undefined) return existing;
				documentCreated = true;
				return doc;
			});
			if (!documentCreated) error("generated guild id already exists");
			this._store.UpdateAsync(`tag:${tag}`, (existing) => {
				tagClaimed = false;
				if (existing === undefined || existing === id) {
					tagClaimed = true;
					return id;
				}
				return existing;
			});
		});
		if (!ok) {
			warn(string.format("[WARN] [GUILD] create failed for %s — %s", player.Name, tostring(err)));
		}
		if (!RunService.IsStudio() && (!ok || !documentCreated || !tagClaimed)) {
			if (documentCreated && !tagClaimed) {
				const [removed, removeErr] = pcall(() => this._store.RemoveAsync(id));
				if (!removed) {
					warn(
						string.format(
							"[WARN] [GUILD] could not roll back guild %s — %s",
							id,
							tostring(removeErr),
						),
					);
				}
			}
			if (!ok) return $tuple(false, T("GuildCommunity.GuildRecordsAreUnavailableTry"), undefined);
			return $tuple(false, T("GuildService.ThatGuildTagIsAlready"), undefined);
		}
		this._cache[id] = doc;
		if (RunService.IsStudio()) this._studio[id] = doc;
		this._cacheExpiry[id] = os.clock() + 60;
		profile.Cash = OmegaMath.Sub(profile.Cash as never, GuildConfig.CreateCost);
		profile.Guild = { Id: id, Role: "Leader", JoinedAt: os.time(), Tag: tag };
		return $tuple(true, T("GuildService.GuildHallChartered"), copyDoc(doc));
	}

	public Rename(player: Player, profile: Profile, newName: string, newTag?: string): Triple {
		const guildId = guildIdOf(profile);
		if (guildId === "") return $tuple(false, T("GuildCommunity.YouAreNotInA"), undefined);
		const membership = profile.Guild as Dict;
		if (!isTable(membership) || membership.Role !== "Leader") {
			return $tuple(false, T("GuildService.OnlyTheGuildLeaderCan"), undefined);
		}
		const name = string.gsub(string.gsub(newName, "^%s+", "")[0], "%s+$", "")[0];
		if (name.size() < 3 || name.size() > 28 || string.match(name, "^[%w%s%-_]+$")[0] === undefined) {
			return $tuple(false, T("GuildService.GuildNamesMustBe3"), undefined);
		}
		const changeTag = typeIs(newTag, "string") && newTag.size() > 0;
		const tag = changeTag ? normalTag(newTag as string) : "";
		if (changeTag && (tag.size() < 3 || tag.size() > 4 || string.match(tag, "^[A-Z0-9]+$")[0] === undefined)) {
			return $tuple(false, T("GuildService.GuildTagsMustBe3"), undefined);
		}
		if (OmegaMath.Lt(profile.Cash as never, GuildConfig.RenameCost)) {
			return $tuple(false, T("GuildService.YouNeedMoreFluxTo2"), undefined);
		}
		const guild = this._read(guildId);
		if (!isTable(guild)) return $tuple(false, T("GuildService.GuildRecordsAreUnavailable"), undefined);
		const now = os.time();
		const cooldown = num(guild.LastRenamedAt) ?? 0;
		if (cooldown + GuildConfig.RenameCooldownSeconds > now) {
			return $tuple(false, T("GuildService.TheGuildWasRenamedToo"), undefined);
		}
		const oldName = guild.Name as string;
		const oldTag = guild.Tag as string;
		if (name === oldName && (!changeTag || tag === oldTag)) {
			return $tuple(false, T("GuildService.PickANewNameOr"), undefined);
		}
		if (changeTag) {
			const existing = this._findByTag(tag);
			if (existing && existing.Id !== guildId) {
				return $tuple(false, T("GuildService.ThatGuildTagIsAlready"), undefined);
			}
		}
		const [ok, message, updated] = this._update(guildId, (doc) => {
			if (!isTable(doc)) return undefined;
			const docCooldown = num(doc.LastRenamedAt) ?? 0;
			if (docCooldown + GuildConfig.RenameCooldownSeconds > now) {
				return undefined;
			}
			doc.Name = name;
			doc.LastRenamedAt = now;
			if (changeTag) {
				doc.Tag = tag;
			}
			if (!isTable(doc.AuditLog)) {
				doc.AuditLog = [];
			}
			const auditLog = doc.AuditLog as Dict[];
			const entry: Dict = {
				At: now,
				By: player.UserId,
				Action: "Rename",
				FromName: oldName,
				ToName: name,
				Cost: GuildConfig.RenameCost,
			};
			if (changeTag) {
				entry.FromTag = oldTag;
				entry.ToTag = tag;
			}
			auditLog.unshift(entry);
			if (auditLog.size() > 50) {
				auditLog.pop();
			}
			return doc;
		});
		if (!ok) return $tuple(false, message ?? T("GuildService.CouldNotRenameTheGuild"), undefined);
		if (changeTag) {
			const [released, releaseErr] = pcall(() => {
				if (this._store.GetAsync(`tag:${oldTag}`) === guildId) {
					this._store.RemoveAsync(`tag:${oldTag}`);
				}
			});
			if (!released) {
				warn(
					string.format(
						"[WARN] [GUILD] rename could not release old tag %s — %s",
						oldTag,
						tostring(releaseErr),
					),
				);
			}
			const [claimed, claimErr] = pcall(() => {
				this._store.UpdateAsync(`tag:${tag}`, (existing) => {
					if (existing === undefined || existing === guildId) {
						return guildId;
					}
					return existing;
				});
			});
			if (!claimed) {
				warn(
					string.format(
						"[WARN] [GUILD] rename could not claim new tag %s — %s",
						tag,
						tostring(claimErr),
					),
				);
			}
		}
		profile.Cash = OmegaMath.Sub(profile.Cash as never, GuildConfig.RenameCost);
		membership.Tag = changeTag ? tag : membership.Tag;
		return $tuple(true, T("GuildService.GuildRenamed"), updated);
	}

	public JoinByTag(player: Player, profile: Profile, rawTag: string): Triple {
		if (!typeIs(rawTag, "string")) return $tuple(false, T("GuildService.NoGuildHasThatTag"), undefined);
		const profileGuild = profile.Guild as Dict | undefined;
		if (isTable(profileGuild) && profileGuild.Id !== "") {
			const existing =
				this.GetCachedPublic(profileGuild.Id as string) ?? this.GetPublic(profileGuild.Id as string);
			if (existing) return $tuple(true, T("GuildService.YouReAlreadyInThis"), existing);
			return $tuple(false, T("GuildService.LeaveYourCurrentGuildFirst"), undefined);
		}
		const doc = this._findByTag(rawTag);
		if (!doc) return $tuple(false, T("GuildService.NoGuildHasThatTag"), undefined);
		let blockedFull = false;
		const [ok, message, updated] = this._update(doc.Id as string, (guild) => {
			blockedFull = false;
			const key = tostring(player.UserId);
			const memberList = members(guild);
			if (memberList[key]) return guild;
			let count = 0;
			for (const _ of pairs(memberList)) count += 1;
			if (count >= GuildConfig.MaxMembers) {
				blockedFull = true;
				return undefined;
			}
			memberList[key] = {
				Name: playerName(player),
				Role: "Member",
				JoinedAt: os.time(),
				Contributed: 0,
			};
			return guild;
		});
		if (!ok) {
			if (blockedFull) return $tuple(false, T("GuildService.ThatGuildIsFull"), undefined);
			return $tuple(false, message, undefined);
		}
		const membership = members(updated as Dict)[tostring(player.UserId)];
		if (!membership) return $tuple(false, T("GuildService.ThatGuildIsFull"), undefined);
		const updatedDoc = updated as Dict;
		profile.Guild = {
			Id: updatedDoc.Id,
			Role: membership.Role ?? "Member",
			JoinedAt: os.time(),
			Tag: updatedDoc.Tag,
		};
		return $tuple(true, T("GuildService.JoinedS", updatedDoc.Name), updated);
	}

	public Leave(player: Player, profile: Profile): Triple {
		const guildId = guildIdOf(profile);
		if (guildId === "") return $tuple(false, T("GuildCommunity.YouAreNotInA"), undefined);
		let blockedLastMember = false;
		const [ok, message] = this._update(guildId, (guild) => {
			blockedLastMember = false;
			const key = tostring(player.UserId);
			const memberList = members(guild);
			const member = memberList[key];
			if (!member) return undefined;
			let otherCount = 0;
			for (const [otherKey] of pairs(memberList)) {
				if (otherKey !== key) otherCount += 1;
			}
			if (otherCount === 0) {
				blockedLastMember = true;
				return undefined;
			}
			if (member.Role === "Leader") {
				const successor = Social.successor(memberList, key);
				if (successor !== undefined) {
					memberList[successor].Role = "Leader";
					guild.OwnerUserId = tonumber(successor) ?? 0;
				}
			}
			delete memberList[key];
			return guild;
		});
		if (!ok) {
			if (blockedLastMember)
				return $tuple(
					false,
					"You're the last member. Disband the guild instead of leaving.",
					undefined,
				);
			return $tuple(false, message, undefined);
		}
		profile.Guild = { Id: "", Role: "", JoinedAt: 0, Tag: "" };
		profile.GuildBonuses = emptyBonuses();
		return $tuple(true, T("GuildService.LeftTheGuild"), emptyGuild());
	}

	public Disband(player: Player, profile: Profile): Triple {
		const guildId = guildIdOf(profile);
		if (guildId === "") return $tuple(false, T("GuildCommunity.YouAreNotInA"), undefined);
		delete this._cache[guildId];
		delete this._cacheExpiry[guildId];
		const guild = this._read(guildId);
		if (!guild) return $tuple(false, T("GuildService.GuildRecordsAreUnavailable"), undefined);
		const key = tostring(player.UserId);
		const member = members(guild)[key];
		if (!member || member.Role !== "Leader")
			return $tuple(false, T("GuildService.OnlyTheGuildLeaderCan2"), undefined);
		let memberCount = 0;
		for (const _ of pairs(members(guild))) memberCount += 1;
		if (memberCount > 1)
			return $tuple(false, T("GuildService.RemoveEveryOtherMemberBefore"), undefined);
		const tag = guild.Tag as string;
		const [removedDoc, removeErr] = pcall(() => this._store.RemoveAsync(guildId));
		if (!removedDoc && !RunService.IsStudio()) {
			warn(string.format("[WARN] [GUILD] disband could not delete %s — %s", guildId, tostring(removeErr)));
			return $tuple(false, T("GuildCommunity.GuildRecordsAreUnavailableTry"), undefined);
		}
		if (removedDoc) {
			const [released, releaseErr] = pcall(() => {
				if (this._store.GetAsync(`tag:${tag}`) === guildId) {
					this._store.RemoveAsync(`tag:${tag}`);
				}
			});
			pcall(() => {
				this._leaderboard.RemoveAsync(guildId);
			});
			if (!released) {
				warn(
					string.format(
						"[WARN] [GUILD] disband deleted %s but the tag %s is still reserved — %s",
						guildId,
						tostring(tag),
						tostring(releaseErr),
					),
				);
				if (!RunService.IsStudio()) {
					return $tuple(false, T("GuildCommunity.GuildRecordsAreUnavailableTry"), undefined);
				}
			}
		}
		delete this._cache[guildId];
		delete this._cacheExpiry[guildId];
		if (RunService.IsStudio()) delete this._studio[guildId];
		profile.Guild = { Id: "", Role: "", JoinedAt: 0, Tag: "" };
		profile.GuildBonuses = emptyBonuses();
		return $tuple(true, T("GuildService.GuildDisbanded"), emptyGuild());
	}

	public Kick(player: Player, profile: Profile, targetUserId: number): Triple {
		const guildId = guildIdOf(profile);
		const [ok, message, updated] = this._update(guildId, (guild) => {
			const memberList = members(guild);
			const actor = memberList[tostring(player.UserId)];
			const target = memberList[tostring(targetUserId)];
			if (player.UserId === targetUserId || !Social.canManage(actor, target, "Kick")) return undefined;
			delete memberList[tostring(targetUserId)];
			return guild;
		});
		return $tuple(ok, ok ? "Member removed." : (message ?? "You cannot remove that member."), updated);
	}

	public SetRole(player: Player, profile: Profile, targetUserId: number, role: string): Triple {
		if (role !== "Officer" && role !== "Member") return $tuple(false, T("GuildService.InvalidGuildRole"), undefined);
		const guildId = guildIdOf(profile);
		const [ok, message, updated] = this._update(guildId, (guild) => {
			const memberList = members(guild);
			const actor = memberList[tostring(player.UserId)];
			const target = memberList[tostring(targetUserId)];
			if (player.UserId === targetUserId || !Social.canManage(actor, target, "Role")) return undefined;
			(target as MemberRec).Role = role;
			return guild;
		});
		return $tuple(ok, ok ? "Role updated." : (message ?? "Only the leader can set roles."), updated);
	}

	public ContributeBank(player: Player, profile: Profile, amount: number, currency: string): Triple {
		const guildId = guildIdOf(profile);
		if (guildId === "") return $tuple(false, T("GuildService.JoinAGuildBeforeContributing"), undefined);
		const [normalized, amountError] = GuildMath.NormalizeContributionAmount(amount);
		if (normalized === undefined) {
			return $tuple(false, amountError ?? T("GuildService.PickAPositiveContributionAmount"), undefined);
		}
		amount = normalized;
		if (currency !== "Cash" && currency !== "Dust") {
			return $tuple(false, T("GuildService.ContributeFluxOrDust"), undefined);
		}
		if (currency === "Cash") {
			if (OmegaMath.Lt(profile.Cash as never, amount)) {
				return $tuple(false, T("GuildService.YouDoNotHaveEnough"), undefined);
			}
		} else {
			if ((num(profile.Stardust) ?? 0) < amount) {
				return $tuple(false, T("GuildService.YouDoNotHaveEnough"), undefined);
			}
		}

		const [ok, message, updated] = this._update(guildId, (guild) => {
			const member = members(guild)[tostring(player.UserId)];
			if (!member) return undefined;
			const bankKey = currency === "Cash" ? "BankCash" : "BankDust";
			guild[bankKey] = GuildMath.CreditBank(OmegaMath, currency, guild[bankKey], amount);
			guild.Activity = GuildMath.AddClamped(guild.Activity, amount);
			member.Contributed = GuildMath.AddClamped(member.Contributed, amount);
			if (member.Name === undefined || member.Name === "") {
				member.Name = playerName(player);
			}
			advanceGoal(
				guild,
				tostring(player.UserId),
				currency === "Cash" ? "ContributeCash" : "ContributeDust",
				amount,
				os.time(),
			);
			return guild;
		});
		if (!ok) return $tuple(false, message ?? T("OpsMath.YouAreNotInThat"), updated);
		if (currency === "Cash") {
			profile.Cash = OmegaMath.Sub(profile.Cash as never, amount);
		} else {
			profile.Stardust = (num(profile.Stardust) ?? 0) - amount;
		}
		return $tuple(true, T("GuildService.ContributionDeposited"), updated);
	}

	public BuyUpgrade(player: Player, profile: Profile, upgradeId: string): Triple {
		const definition = (GuildConfig.Upgrades as Record<string, Dict | undefined>)[upgradeId];
		if (!definition) return $tuple(false, T("GuildService.UnknownGuildUpgrade"), undefined);
		const guildId = guildIdOf(profile);
		if (guildId === "") return $tuple(false, T("GuildService.JoinAGuildFirst"), undefined);
		const guild = this._read(guildId);
		if (!guild) return $tuple(false, T("GuildService.GuildRecordsAreUnavailable"), undefined);
		const member = members(guild)[tostring(player.UserId)];
		if (!member || (member.Role !== "Leader" && member.Role !== "Officer")) {
			return $tuple(false, T("GuildService.OnlyLeadersAndOfficersCan"), undefined);
		}
		const level = num((guild.Upgrades as Dict)[upgradeId]) ?? 0;
		if (level >= (num(definition.MaxLevel) ?? 0)) return $tuple(false, T("GuildService.ThatUpgradeIsAlreadyMaxed"), undefined);
		const cost = upgradeCost(definition, level);
		const bankKey = definition.Currency === "Cash" ? "BankCash" : "BankDust";
		const bank = guild[bankKey] ?? 0;
		if (!GuildMath.CanAffordBank(OmegaMath, definition.Currency as string, bank, cost)) {
			const label = definition.Currency === "Cash" ? "flux" : "dust";
			const have = definition.Currency === "Cash" ? bank : math.floor(num(bank) ?? 0);
			return $tuple(
				false,
				string.format(
					"Need %s %s in the guild bank (have %s). Contribute first.",
					Format.Number(cost),
					label,
					Format.Number(have),
				),
				undefined,
			);
		}
		const [ok, message, updated] = this._update(guildId, (current) => {
			const actor = members(current)[tostring(player.UserId)];
			if (!actor || (actor.Role !== "Leader" && actor.Role !== "Officer")) return undefined;
			const nextLevel = num((current.Upgrades as Dict)[upgradeId]) ?? 0;
			if (nextLevel >= (num(definition.MaxLevel) ?? 0)) return undefined;
			const nextCost = upgradeCost(definition, nextLevel);
			const nextBank = GuildMath.DebitBank(OmegaMath, definition.Currency as string, current[bankKey], nextCost);
			if (nextBank === undefined) return undefined;
			current[bankKey] = nextBank;
			(current.Upgrades as Dict)[upgradeId] = nextLevel + 1;
			current.Activity = GuildMath.AddClamped(current.Activity, nextCost);
			advanceGoal(current, tostring(player.UserId), "Upgrades", 1, os.time());
			return current;
		});
		return $tuple(ok, ok ? "Guild upgrade installed." : (message ?? "Could not buy that upgrade."), updated);
	}

	public ClaimGoal(player: Player, profile: Profile): LuaTuple<[boolean, string, Dict | undefined, unknown]> {
		const guildId = guildIdOf(profile);
		if (guildId === "") return $tuple(false, T("GuildService.JoinAGuildFirst"), undefined, undefined);
		const userKey = tostring(player.UserId);
		let failure: string | undefined = undefined;
		let rewardTypeId: string | undefined = undefined;
		const [ok, message, updated] = this._update(guildId, (guild) => {
			failure = undefined;
			rewardTypeId = undefined;
			const now = os.time();
			const repaired = ensureGoal(guild, now);
			const goal = guild.Goal;
			const [canClaim, claimError] = GuildGoalMath.CanClaimGoal(
				goal,
				userKey,
				members(guild)[userKey] !== undefined,
				GuildConfig.Goal.MinContributionForReward,
			);
			if (!canClaim) {
				failure = claimError;
				return repaired ? guild : undefined;
			}
			((goal as Dict).Claimed as Dict)[userKey] = true;
			rewardTypeId = (goal as Dict).TypeId as string;
			return guild;
		});
		if (!ok) return $tuple(false, failure ?? message ?? T("GuildService.CouldNotClaimTheGuild"), undefined, undefined);
		if (failure !== undefined) return $tuple(false, failure, updated, undefined);
		const definition = rewardTypeId !== undefined ? goalTypeById(rewardTypeId) : undefined;
		if (!definition) return $tuple(false, T("GuildService.ThatGuildGoalIsNo"), updated, undefined);
		return $tuple(true, T("GuildService.GuildGoalRewardClaimed"), updated, definition.Reward);
	}

	public GetPublic(guildId: string): Dict | undefined {
		if (guildId === "") return undefined;
		const doc = this._read(guildId);
		if (!doc) return undefined;
		ensureGoal(doc, os.time());
		return doc;
	}

	public GetCachedPublic(guildId: string): Dict | undefined {
		if (guildId === "") return undefined;
		let doc: Dict | undefined =
			this._cache[guildId] ?? (RunService.IsStudio() ? this._studio[guildId] : undefined);
		if (!isTable(doc)) {
			doc = this._read(guildId);
		}
		if (!isTable(doc)) return undefined;
		const result = copyDoc(doc);
		ensureGoal(result, os.time());
		return result;
	}

	public GetLeaderboard(page: number): Dict[] {
		const pageIndex = math.max(0, math.floor(num(page) ?? 0));
		if (pageIndex === 0 && this._leaderboardCache && this._leaderboardCacheExpires > os.clock()) {
			return copy(this._leaderboardCache) as Dict[];
		}
		const entries: Dict[] = [];
		let hasPlaceholders = false;
		const [ok, pages] = pcall(() => this._leaderboard.GetSortedAsync(false, 100, undefined, undefined));
		if (ok && pages) {
			for (const row of pages.GetCurrentPage()) {
				const doc = this._cache[row.key] ?? this._studio[row.key];
				if (doc) {
					entries.push({
						Id: doc.Id,
						Name: doc.Name,
						Tag: doc.Tag,
						Activity: LeaderboardCodec.Decode(row.value),
						Level: doc.Level,
					});
				} else {
					hasPlaceholders = true;
					this._queueWarmRead(row.key);
					entries.push({
						Id: row.key,
						Name: "Uncharted Guild",
						Tag: "...",
						Activity: LeaderboardCodec.Decode(row.value),
						Level: 0,
					});
				}
			}
		}
		if (entries.size() === 0) {
			for (const [, doc] of pairs(this._cache))
				entries.push({ Id: doc.Id, Name: doc.Name, Tag: doc.Tag, Activity: doc.Activity, Level: doc.Level });
			entries.sort((a, b) => (a.Activity as number) > (b.Activity as number));
		}
		const start = pageIndex * 20 + 1;
		const sliced: Dict[] = [];
		for (const i of $range(start, math.min(entries.size(), start + 19))) {
			sliced.push(entries[i - 1]);
		}
		if (pageIndex === 0) {
			this._leaderboardCache = copy(sliced) as Dict[];
			this._leaderboardCacheExpires = os.clock() + (hasPlaceholders ? 3 : 15);
		}
		return copy(sliced) as Dict[];
	}

	public GetBonuses(guildId: string): Record<string, number> {
		return bonusesFromDocument(this.GetPublic(guildId));
	}

	public GetCachedBonuses(guildId: string): Record<string, number> {
		return bonusesFromDocument(this.GetCachedPublic(guildId));
	}

	public ReconcileMembership(profile: Profile, userId: number): boolean {
		const membership = profile.Guild as Dict | undefined;
		const guildId = isTable(membership) ? ((membership.Id as string) ?? "") : "";
		if (guildId === "") {
			profile.GuildBonuses = emptyBonuses();
			return false;
		}
		const guild = this._read(guildId);
		if (!guild) return false;
		const member = members(guild)[tostring(userId)];
		if (!member) {
			profile.Guild = { Id: "", Role: "", JoinedAt: 0, Tag: "" };
			profile.GuildBonuses = emptyBonuses();
			return true;
		}
		const changed = membership!.Role !== member.Role || membership!.Tag !== guild.Tag;
		membership!.Role = member.Role;
		membership!.Tag = guild.Tag;
		profile.GuildBonuses = bonusesFromDocument(guild);
		return changed;
	}
}
