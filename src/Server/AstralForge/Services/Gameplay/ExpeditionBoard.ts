// Expedition Board (v8 #4): Launch, Claim and Recall for the multi-slot board. Each slot reuses the
// v7 single-expedition rules in Progression (commander level gate, crew-upgrade duration and yield,
// artifact rolls) by running them against that slot, then adds what the relic crew brings back.
// The old LaunchExpedition / ClaimExpedition remotes are aliases for slot 1.
import Board = require("../../../../Shared/AstralForge/Shared/ExpeditionBoard");
import CompanionRelic = require("../../../../Shared/AstralForge/Shared/CompanionRelic");
import GameConfig = require("../../../../Shared/AstralForge/Shared/GameConfig");
import ProgressionModule = require("./Progression");
import * as HotFlags from "../Security/HotFlags";
import { T } from "../../../../Shared/AstralForge/Shared/Locale";
import { Dict, isTable } from "../LuaInterop";

const PAUSE_FLAG = "ExpeditionBoardPaused" as const;

interface ProgressionApi {
	LaunchExpedition(this: void, profile: Dict, id: string): LuaTuple<[boolean, string]>;
	ClaimExpedition(this: void, profile: Dict, random: Random): LuaTuple<[boolean, string, string?, boolean?]>;
	ApplyReward(this: void, profile: Dict, reward: Dict, production?: unknown): string;
}
const Progression = ProgressionModule as unknown as ProgressionApi;

type Result = LuaTuple<[boolean, string, Dict?]>;

const EMPTY_ACTIVE = () => ({ Id: "", StartedAt: 0, EndsAt: 0 });

function itemById(id: unknown): Dict | undefined {
	const items = (GameConfig as unknown as { Items: { Definitions: Dict[] } }).Items;
	for (const definition of items.Definitions) {
		if (definition.Id === id) return definition;
	}
	return undefined;
}

function paused(): boolean {
	return HotFlags.Get(PAUSE_FLAG);
}

function slotIndex(board: ReturnType<typeof Board.ensure>, raw: unknown): number | undefined {
	if (board === undefined || !typeIs(raw, "number") || raw % 1 !== 0) return undefined;
	return raw >= 1 && raw <= board.Slots.size() ? raw : undefined;
}

// crew uids must be owned, distinct, and free (not socketed, not the companion, not on another run)
function checkCrew(profile: Dict, raw: unknown): LuaTuple<[string[] | undefined, string?]> {
	const crew: string[] = [];
	if (raw === undefined) return $tuple(crew, undefined);
	if (!isTable(raw)) return $tuple(undefined, T("ExpeditionBoard.BadCrew"));
	const items = profile.Items as Dict;
	const inventory = items.Inventory as Dict;
	const equipped = items.Equipped as Dict;
	for (const uid of raw as unknown as unknown[]) {
		if (!typeIs(uid, "string") || !isTable(inventory[uid]) || crew.includes(uid)) {
			return $tuple(undefined, T("ExpeditionBoard.BadCrew"));
		}
		for (const [, equippedUid] of pairs(equipped)) {
			if (equippedUid === uid) return $tuple(undefined, T("ExpeditionBoard.CrewBusy"));
		}
		crew.push(uid);
	}
	if (crew.size() > Board.CREW_MAX) return $tuple(undefined, T("ExpeditionBoard.CrewFull", Board.CREW_MAX));
	return $tuple(crew, undefined);
}

function crewMembers(profile: Dict, crew: string[]) {
	const inventory = (profile.Items as Dict).Inventory as Dict;
	const out: { Rarity: string; EffectKind: string; Stars: number }[] = [];
	for (const uid of crew) {
		const instance = inventory[uid] as Dict | undefined;
		const definition = instance !== undefined ? itemById(instance.DefinitionId) : undefined;
		if (instance !== undefined && definition !== undefined) {
			out.push({
				Rarity: definition.Rarity as string,
				EffectKind: definition.EffectKind as string,
				Stars: typeIs(instance.Stars, "number") ? instance.Stars : 0,
			});
		}
	}
	return out;
}

function Launch(profile: Dict, payload: Dict): Result {
	if (paused()) return $tuple(false, T("ExpeditionBoard.Paused"));
	const board = Board.ensure(profile, true);
	const index = slotIndex(board, payload.Slot ?? 1);
	if (board === undefined || index === undefined) return $tuple(false, T("ExpeditionBoard.NoSuchSlot"));
	const slot = board.Slots[index - 1];
	if (slot.Id !== "") return $tuple(false, T("ExpeditionBoard.SlotBusy"));
	if (!typeIs(payload.Id, "string")) return $tuple(false, T("ExpeditionBoard.NoSuchSlot"));
	for (const other of board.Slots) {
		if (other.Id === payload.Id) return $tuple(false, T("ExpeditionBoard.RouteBusy"));
	}
	const [crew, crewProblem] = checkCrew(profile, payload.Crew);
	if (crew === undefined) return $tuple(false, crewProblem ?? T("ExpeditionBoard.BadCrew"));
	// run the v7 launch rules against an empty single slot, then move the result onto the board
	const command = profile.Command as Dict;
	command.ActiveExpedition = EMPTY_ACTIVE();
	const [ok, message] = Progression.LaunchExpedition(profile, payload.Id);
	const launched = command.ActiveExpedition as { Id: string; StartedAt: number; EndsAt: number };
	if (!ok) {
		Board.mirror(profile, board);
		return $tuple(false, message);
	}
	let endsAt = launched.EndsAt;
	const speed = CompanionRelic.traitBonus(profile.Items, "ExpeditionSpeed");
	if (speed > 0) {
		endsAt = launched.StartedAt + math.max(10, math.floor((launched.EndsAt - launched.StartedAt) * (1 - speed)));
	}
	board.Slots[index - 1] = { Id: launched.Id, Crew: crew, StartedAt: launched.StartedAt, EndsAt: endsAt };
	Board.relock(profile, board);
	Board.mirror(profile, board);
	return $tuple(true, message, { Slot: index, EndsAt: endsAt });
}

function Claim(profile: Dict, payload: Dict, random: Random): Result {
	if (paused()) return $tuple(false, T("ExpeditionBoard.Paused"));
	const board = Board.ensure(profile, true);
	const index = slotIndex(board, payload.Slot ?? 1);
	if (board === undefined || index === undefined) return $tuple(false, T("ExpeditionBoard.NoSuchSlot"));
	const slot = board.Slots[index - 1];
	if (slot.Id === "") return $tuple(false, T("ExpeditionBoard.SlotEmpty"));
	const command = profile.Command as Dict;
	command.ActiveExpedition = { Id: slot.Id, StartedAt: slot.StartedAt, EndsAt: slot.EndsAt };
	const [ok, message, artifactId, artifactNew] = Progression.ClaimExpedition(profile, random);
	const settled = (command.ActiveExpedition as Dict).Id === "";
	if (!ok) {
		if (settled) {
			// the route no longer exists; the v7 rules emptied it, so free the slot and its crew
			board.Slots[index - 1] = Board.emptySlot();
			Board.relock(profile, board);
		}
		Board.mirror(profile, board);
		return $tuple(false, message);
	}
	const members = crewMembers(profile, slot.Crew);
	let text = message;
	let bonus: Dict | undefined;
	if (members.size() > 0 && random.NextNumber() <= Board.bonusChance(members)) {
		const loot = Board.bonusLoot(members, slot.EndsAt - slot.StartedAt);
		const reward: Dict = {};
		if (loot.Cores > 0) reward.Cores = loot.Cores;
		if (loot.Stardust > 0) reward.Stardust = loot.Stardust;
		const parts: string[] = [];
		if (next(reward)[0] !== undefined) parts.push(Progression.ApplyReward(profile, reward));
		if (loot.Essence > 0) {
			// relic essence, the salvage currency, since the crew are relics
			const items = profile.Items as Dict;
			items.Essence = ((items.Essence as number | undefined) ?? 0) + loot.Essence;
			reward.Essence = loot.Essence;
			parts.push(T("ExpeditionBoard.RelicEssence", loot.Essence));
		}
		if (parts.size() > 0) {
			text = T("ExpeditionBoard.CrewBonus", text, parts.join(", "));
			bonus = reward;
		}
	}
	board.Slots[index - 1] = Board.emptySlot();
	Board.relock(profile, board);
	Board.mirror(profile, board);
	return $tuple(true, text, { Slot: index, ArtifactId: artifactId, ArtifactNew: artifactNew, Bonus: bonus });
}

function Recall(profile: Dict, payload: Dict): Result {
	if (paused()) return $tuple(false, T("ExpeditionBoard.Paused"));
	const board = Board.ensure(profile, true);
	const index = slotIndex(board, payload.Slot);
	if (board === undefined || index === undefined) return $tuple(false, T("ExpeditionBoard.NoSuchSlot"));
	if (board.Slots[index - 1].Id === "") return $tuple(false, T("ExpeditionBoard.SlotEmpty"));
	board.Slots[index - 1] = Board.emptySlot();
	Board.relock(profile, board);
	Board.mirror(profile, board);
	return $tuple(true, T("ExpeditionBoard.Recalled"), { Slot: index });
}

function Act(profile: Dict, payload: unknown, random: Random): Result {
	const bag = isTable(payload) ? (payload as Dict) : undefined;
	if (bag === undefined) return $tuple(false, T("ExpeditionBoard.UnknownAction"));
	if (bag.Op === "Launch") return Launch(profile, bag);
	if (bag.Op === "Claim") return Claim(profile, bag, random);
	if (bag.Op === "Recall") return Recall(profile, bag);
	return $tuple(false, T("ExpeditionBoard.UnknownAction"));
}

// What the client draws: every slot with its crew, plus the slot count and crew cap.
function State(profile: Dict) {
	const board = Board.read(profile);
	const slots: Dict[] = [];
	const count = Board.slotCount(profile);
	for (let i = 1; i <= math.max(count, board?.Slots.size() ?? 0); i++) {
		const slot = board?.Slots[i - 1] ?? Board.emptySlot();
		slots.push({ Slot: i, Id: slot.Id, Crew: table.clone(slot.Crew), StartedAt: slot.StartedAt, EndsAt: slot.EndsAt });
	}
	return { Slots: slots, CrewMax: Board.CREW_MAX, Paused: paused() };
}

export = table.freeze({ PAUSE_FLAG, Act, Launch, Claim, Recall, State });
