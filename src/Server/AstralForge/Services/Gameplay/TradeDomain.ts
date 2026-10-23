// Trade actions (invite, respond, offer, ready, confirm, chat, cancel), moved out of GameService (todo500 #1).
// Remote names and payloads are unchanged: GameService._tradeAction delegates here.
import { T } from "../../../../Shared/AstralForge/Shared/Locale";
import { Dict, isTable, num, truthy } from "../LuaInterop";
import { RemoteFirewall } from "../Security/RemoteFirewall";
import * as HotFlags from "../Security/HotFlags";
import * as TradeEngine from "../../Modules/TradeEngine";
import * as K from "../GameKits";

type Fn = (this: void, ...args: unknown[]) => unknown;
type Method = (this: object, ...args: unknown[]) => unknown;
type Kit = Record<string, Fn>;
type Svc = Record<string, Method>;
type Profile = Dict;
type Response = Dict;

const Players = game.GetService("Players");
const ReplicatedStorage = game.GetService("ReplicatedStorage");

function orElse<A, U>(value: A, fallback: () => U): Exclude<A, undefined | false> | U {
	return truthy(value) ? (value as Exclude<A, undefined | false>) : fallback();
}
const responseError = (message: unknown): Response => K.ActionResponse.Error(message) as Response;
const responseSuccess = (message?: unknown, extra?: unknown): Response => K.ActionResponse.Success(message, extra) as Response;

export interface TradeHost {
	_data: Svc;
	_trades: Svc;
	_pushState(player: Player, force?: boolean): unknown;
	_pushTradePartners(hostId: unknown, guestId: unknown): void;
	_toastPlayer(player: Player, title: unknown, body: unknown, tone?: unknown): unknown;
	_flagTradeInvite(player: Player, targetUserId: unknown): unknown;
}

export function tradeAction(svc: TradeHost, itemById: Record<string, Dict>, player: Player, action: string, rawPayload: unknown): Response {
		const payload = rawPayload as Dict;
		const profile = svc._data.Get(player) as Profile | undefined;
		if (!profile) {
			return responseError(T("GameService.ProfileIsStillLoading"));
		}
		// live-ops kill switch: cancelling, chat and leaving still work while trading is paused
		if (
			HotFlags.Get("TradingPaused") &&
			(action === K.Protocol.Actions.InviteTrade ||
				action === K.Protocol.Actions.RespondTrade ||
				action === K.Protocol.Actions.UpdateTradeOffer ||
				action === K.Protocol.Actions.SetTradeReady ||
				action === K.Protocol.Actions.ConfirmTrade)
		) {
			return responseError(T("GameService.TradingIsPausedForMaintenance"));
		}
		const now = os.time();
		if (action === K.Protocol.Actions.GetTrade) {
			return responseSuccess(undefined);
		}
		if (!truthy(svc._trades.Unlocked(profile))) {
			return responseError(T("TradeSuite.TradeFloorUnlocksAfterYour"));
		}
		if (action === K.Protocol.Actions.InviteTrade) {
			const userId = RemoteFirewall.CoerceUserId(payload.UserId) as number | undefined;
			if (userId === undefined) {
				return responseError(T("GameService.ChooseAPlayerToInvite"));
			}
			svc._flagTradeInvite(player, userId);
			if (!truthy(svc._trades.Unlocked(profile))) {
				return responseError(T("TradeSuite.TradeFloorUnlocksAfterYour"));
			}
			const target = userId === -999 ? undefined : Players.GetPlayerByUserId(userId);
			const targetProfile = target ? (svc._data.Get(target) as Profile | undefined) : undefined;
			if (userId !== -999 && targetProfile && !truthy(svc._trades.Unlocked(targetProfile))) {
				return responseError(T("GameService.TheyHaveNotUnlockedTrade"));
			}
			// the target's Social setting decides who may invite them
			const targetSettings = targetProfile ? (targetProfile.Settings as Dict | undefined) : undefined;
			const tradePolicy = targetSettings ? targetSettings.TradeInvitePolicy : undefined;
			if (target && typeIs(tradePolicy, "number") && tradePolicy >= 0.25) {
				const [okFriend, isFriend] = pcall(() => (target as unknown as Svc).IsFriendsWith(player.UserId));
				if (!truthy(K.ChatRules.allows(tradePolicy, okFriend && isFriend === true))) {
					return responseError(
						tradePolicy >= 0.75
							? `${target.DisplayName} isn't taking trade invites.`
							: `${target.DisplayName} only takes trade invites from friends.`,
					);
				}
			}
			const [ok, err] = svc._trades.Invite(player, profile, userId, now) as LuaTuple<[unknown, unknown]>;
			if (!truthy(ok)) {
				return responseError(err);
			}
			if (target) {
				svc._toastPlayer(target, T("Toast.TradeInviteTitle"), T("Toast.TradeInviteBody", player.DisplayName), "Info");
				svc._pushState(target, true);
			}
			svc._pushState(player, true);
			return responseSuccess(userId === -999 ? T("GameService.PracticeTradeOpened") : T("GameService.InviteSent"));
		} else if (action === K.Protocol.Actions.RespondTrade) {
			const accept = payload.Accept === true;
			const [ok, err, session, fromId] = svc._trades.Respond(player, profile, accept, now) as LuaTuple<
				[unknown, unknown, Dict | undefined, number | undefined]
			>;
			if (!truthy(ok)) {
				return responseError(err);
			}
			if (fromId !== undefined) {
				const host = Players.GetPlayerByUserId(fromId);
				if (host) {
					svc._toastPlayer(
						host,
						accept ? T("GameService.TradeOpened") : T("GameService.InviteDeclined"),
						accept ? player.DisplayName + " accepted." : player.DisplayName + " declined.",
						accept ? "Success" : "Info",
					);
					svc._pushState(host, true);
				}
			}
			if (session) {
				svc._pushTradePartners(session.Host, session.Guest);
			}
			return responseSuccess(accept ? T("GameService.TradeOpened2") : T("CrewService.InviteDeclined"));
		} else if (action === K.Protocol.Actions.UpdateTradeOffer) {
			const [ok, err, session] = svc._trades.UpdateOffer(player, profile, payload.Offer, now) as LuaTuple<
				[unknown, unknown, Dict | undefined]
			>;
			if (!truthy(ok)) {
				return responseError(err);
			}
			if (session) {
				svc._pushTradePartners(session.Host, session.Guest);
			}
			return responseSuccess(T("GameService.OfferUpdated"));
		} else if (action === K.Protocol.Actions.SetTradeReady) {
			const [ok, err, session] = svc._trades.SetReady(player, profile, payload.Ready === true, now) as LuaTuple<
				[unknown, unknown, Dict | undefined]
			>;
			if (!truthy(ok)) {
				return responseError(err);
			}
			if (session) {
				svc._pushTradePartners(session.Host, session.Guest);
			}
			return responseSuccess(payload.Ready === true ? T("GameService.YouAreReady") : T("GameService.ReadyCleared"));
		} else if (action === K.Protocol.Actions.ConfirmTrade) {
			const [ok, err, maybeSession] = svc._trades.Confirm(player, now) as LuaTuple<[unknown, unknown, Dict | undefined]>;
			if (!truthy(ok)) {
				return responseError(err);
			}
			const confirmed = maybeSession ? (maybeSession.Confirmed as Record<number, unknown>) : undefined;
			if (maybeSession && confirmed && truthy(confirmed[maybeSession.Host as number]) && truthy(confirmed[maybeSession.Guest as number])) {
				const session = maybeSession;
				if (!truthy(svc._trades.TryBeginSettle(session))) {
					svc._pushTradePartners(session.Host, session.Guest);
					return responseSuccess(T("GameService.TradeIsSettling"));
				}
				const isPractice = session.Guest === -999 || session.Host === -999;
				if (isPractice) {
					// The practice table is a tutorial: it walks through ready and confirm, then
					// closes without moving anything either way (no payout, no loss, no daily count).
					svc._trades.Close(session);
					svc._pushTradePartners(session.Host, session.Guest);
					const practicePlayer = Players.GetPlayerByUserId(session.Host as number);
					if (practicePlayer) {
						svc._toastPlayer(practicePlayer, T("Toast.PracticeCompleteTitle"), T("Toast.PracticeCompleteBody"), "Success");
					}
					return responseSuccess(T("GameService.PracticeTradeCompleteNothingChanged"));
				}
				const host = Players.GetPlayerByUserId(session.Host as number);
				const guest = (
					session.Guest === -999
						? {
								UserId: -999,
								Name: "ForgeAutomaton",
								DisplayName: "Forge Automaton [Practice]",
							}
						: Players.GetPlayerByUserId(session.Guest as number)
				) as Player | undefined;
				const hostProfile = host ? (svc._data.Get(host) as Profile | undefined) : undefined;
				let mockBotProfile: Profile | undefined = undefined;
				if (isPractice) {
					mockBotProfile = {
						Cash: 1e6,
						Stardust: 1e5,
						Cores: 100,
						Command: { Signals: 100 },
						Items: {
							Essence: 100,
							Inventory: {},
							Equipped: {},
							Keys: { Bronze: 10, Silver: 10, Gold: 10, Astral: 10, ForgeCrate: 10 },
						},
						BoostInventory: { Surge: 10, Overdrive: 10, Hyperdrive: 10, VaultSurge: 10 },
						Trade: {
							Day: -1,
							Completed: 0,
							Sent: { Cash: 0, Stardust: 0, Cores: 0, Signals: 0, Essence: 0, Boost: 0, Keys: 0, Items: 0 },
							History: {},
						},
					};
				}
				const guestProfile = session.Guest === -999 ? mockBotProfile : guest ? (svc._data.Get(guest) as Profile | undefined) : undefined;
				if (!host || !guest || !hostProfile || !guestProfile) {
					svc._trades.FailSettle(session, false);
					svc._trades.Cancel(player);
					return responseError(T("GameService.ATraderLeftBeforeThe"));
				}
				// Settle only what both sides agreed to: the escrow locked at TryBeginSettle must still
				// match the live offers (Modules/TradeEngine).
				if (!TradeEngine.Verify(session as never)[0]) {
					svc._trades.FailSettle(session, false);
					svc._pushTradePartners(session.Host, session.Guest);
					return responseError(T("GameService.ThatTradeCouldNotBe"));
				}
				const [plannedValue, planErr] = svc._trades.Plan(session, hostProfile, guestProfile, now) as LuaTuple<[Dict | undefined, unknown]>;
				if (!plannedValue) {
					svc._trades.FailSettle(session, false);
					svc._pushTradePartners(session.Host, session.Guest);
					return responseError(orElse(planErr, () => T("GameService.ThatTradeCouldNotBe")));
				}
				const plan = plannedValue;

				// One side's record of this trade: what it gave and what it got, with item names.
				const tradeHistoryEntry = (
					tradeSession: Dict,
					partner: Player,
					gave: unknown,
					gaveItems: unknown,
					got: unknown,
					gotItems: unknown,
					at: unknown,
				) => {
					const names = (snapshot: unknown) => {
						const list: string[] = [];
						for (const [, instance] of pairs((truthy(snapshot) ? snapshot : {}) as Dict)) {
							const definition = isTable(instance) ? itemById[instance.DefinitionId as string] : undefined;
							list.push(definition ? (definition.Name as string) : "an item");
						}
						return list;
					};
					const amount = (value: unknown) => {
						const number = num(value);
						if (number === undefined) {
							return (
								require(
									ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("OmegaMath") as ModuleScript,
								) as Kit
							).ToString(value);
						}
						for (const step of [
							[1e12, "T"],
							[1e9, "B"],
							[1e6, "M"],
							[1e3, "K"],
						] as Array<[number, string]>) {
							if (math.abs(number) >= step[0]) {
								return "%.1f%s".format(number / step[0], step[1]).gsub("%.0(%a)", "%1")[0];
							}
						}
						return tostring(math.floor(number));
					};
					return {
						Id: tostring(tradeSession.Id),
						At: at,
						PartnerId: partner.UserId,
						Partner: partner.DisplayName,
						Gave: K.TradeHistory.summarize(gave, names(gaveItems), amount),
						Got: K.TradeHistory.summarize(got, names(gotItems), amount),
					};
				};

				// Durability hook: stamp a per-profile fault journal so a faulted trade
				// can be reconciled the next time the affected profile loads.
				const writeTradeJournal = (targetPlayer: Player, side: string, status: string, reason?: unknown) => {
					if (status !== "faulted") {
						return;
					}
					const [journalOk, journalErr] = pcall(() =>
						svc._data.AtomicUpdate(
							targetPlayer,
							(journalProfile: Profile) => {
								const entry = K.TradeRecovery.MakeFaultedEntry(
									session,
									side,
									plan,
									orElse(reason, () => "unknown"),
									now,
								);
								(journalProfile.Trade as Dict).FaultedJournal = entry;
								return { ok: true };
							},
							true,
							"trade-journal-" + side,
						),
					);
					if (!journalOk) {
						K.ModuleLog.Warn("Trade", "Could not write %s fault journal: %s".format(side, tostring(journalErr)));
					}
				};

				const outcome = K.TradeSettle.RunHostGuest(session, {
					plan: plan,
					applyHost: () =>
						svc._data.AtomicUpdate(
							host,
							(hostDraft: Profile) => {
								const applyErr = svc._trades.ApplyExchange(
									hostDraft,
									plan.HostOffer,
									plan.GuestOffer,
									plan.HostItems,
									plan.GuestItems,
									plan.Now,
								);
								if (truthy(applyErr)) {
									return { ok: false, error: applyErr };
								}
								// history commits in the same save as the exchange
								K.TradeHistory.record(
									hostDraft.Trade,
									tradeHistoryEntry(session, guest, plan.HostOffer, plan.HostItems, plan.GuestOffer, plan.GuestItems, plan.Now),
								);
								return { ok: true };
							},
							true,
							"trade-host",
						),
					guestPresent: () => {
						if (isPractice) {
							return true;
						}
						return svc._data.Get(guest) !== undefined;
					},
					applyGuest: () => {
						if (isPractice) {
							// RunHostGuest reads (committed, result); a bare table left committed as the table and failed the guest side.
							return $tuple(true, { ok: true });
						}
						return svc._data.AtomicUpdate(
							guest,
							(guestDraft: Profile) => {
								const applyErr = svc._trades.ApplyExchange(
									guestDraft,
									plan.GuestOffer,
									plan.HostOffer,
									plan.GuestItems,
									plan.HostItems,
									plan.Now,
								);
								if (truthy(applyErr)) {
									return { ok: false, error: applyErr };
								}
								K.TradeHistory.record(
									guestDraft.Trade,
									tradeHistoryEntry(session, host, plan.GuestOffer, plan.GuestItems, plan.HostOffer, plan.HostItems, plan.Now),
								);
								return { ok: true };
							},
							true,
							"trade-guest",
						);
					},
					revertHostOnce: () => {
						const [revertOk, revertResult] = svc._data.AtomicUpdate(
							host,
							(hostDraft: Profile) => {
								const shortfall = svc._trades.RevertExchange(
									hostDraft,
									plan.HostOffer,
									plan.GuestOffer,
									plan.HostItems,
									plan.GuestItems,
									plan.Now,
								);
								if (truthy(shortfall)) {
									// what the host received was already spent; the settle faults and is journaled
									return { ok: false, error: "revert shortfall: " + tostring(shortfall) };
								}
								// a reverted side never happened, so its history entry goes too
								K.TradeHistory.remove(hostDraft.Trade, tostring(session.Id));
								return { ok: true };
							},
							true,
							"trade-revert",
						) as LuaTuple<[unknown, unknown]>;
						return K.TradeSettle.IsCommitOk(revertOk, revertResult);
					},
					writeHostJournal: (status: string, reason?: unknown) => {
						writeTradeJournal(host, "host", status, reason);
					},
					writeGuestJournal: (status: string, reason?: unknown) => {
						writeTradeJournal(guest, "guest", status, reason);
					},
				}) as Dict;
				svc._pushTradePartners(session.Host, session.Guest);
				if (!truthy(outcome.ok)) {
					if (typeIs(outcome.log, "string")) {
						K.ModuleLog.Warn("Trade", outcome.log, { SessionId: session.Id, Host: session.Host, Guest: session.Guest });
					}
					return responseError(orElse(outcome.message, () => T("GameService.ThatTradeCouldNotBe")));
				}
				svc._trades.Close(session);
				svc._toastPlayer(host, T("Toast.TradeCompleteTitle"), T("Toast.TradeCompleteBody"), "Success");
				svc._toastPlayer(guest, T("Toast.TradeCompleteTitle"), T("Toast.TradeCompleteBody"), "Success");
				return responseSuccess(T("GameService.TradeComplete"));
			}
			if (maybeSession) {
				svc._pushTradePartners(maybeSession.Host, maybeSession.Guest);
			}
			return responseSuccess(T("GameService.ConfirmationNoted"));
		} else if (action === K.Protocol.Actions.TradeChat) {
			let text: unknown = undefined;
			if (typeIs(payload.Text, "string") && payload.Text.size() > 0) {
				// free text goes through Roblox's filter for the partner before anyone sees it
				const raw = payload.Text.sub(1, 140);
				const [okFilter, filtered] = K.TradeChatFilter.Apply(
					game.GetService("TextService"),
					raw,
					player.UserId,
					Enum.TextFilterContext.PrivateChat,
				) as LuaTuple<[unknown, unknown]>;
				if (!truthy(okFilter)) {
					return responseError(T("GameService.ThatMessageCouldnTBe"));
				}
				text = filtered;
			}
			const [ok, err, session] = svc._trades.Say(player, text, num(payload.Phrase), now) as LuaTuple<[unknown, unknown, Dict]>;
			if (!truthy(ok)) {
				return responseError(err);
			}
			svc._pushTradePartners(session.Host, session.Guest);
			return responseSuccess();
		} else if (action === K.Protocol.Actions.TradeRequest) {
			const [ok, err, session] = svc._trades.Request(player, payload.Request, now) as LuaTuple<[unknown, unknown, Dict]>;
			if (!truthy(ok)) {
				return responseError(err);
			}
			svc._pushTradePartners(session.Host, session.Guest);
			return responseSuccess(T("GameService.RequestSent"));
		} else if (action === K.Protocol.Actions.TradeViewAway) {
			const away = truthy(payload) ? payload.Away === true : payload;
			const session = svc._trades.SetAway(player, away) as Dict | undefined;
			if (!session) {
				return responseSuccess();
			}
			const otherId = session.Host === player.UserId && truthy(session.Guest) ? session.Guest : session.Host;
			const other = Players.GetPlayerByUserId(otherId as number);
			if (other) {
				if (truthy(payload) && payload.Away === true) {
					svc._toastPlayer(other, "Trade", T("Toast.TradeAwayBody", player.DisplayName), "Info");
				} else {
					svc._toastPlayer(other, "Trade", T("Toast.TradeBackBody", player.DisplayName), "Info");
				}
			}
			return responseSuccess();
		} else if (action === K.Protocol.Actions.CancelTrade) {
			const [session, otherId, cancelErr] = svc._trades.Cancel(player) as LuaTuple<[unknown, number | undefined, unknown]>;
			if (truthy(cancelErr)) {
				return responseError(cancelErr);
			}
			if (otherId !== undefined) {
				const other = Players.GetPlayerByUserId(otherId);
				if (other) {
					svc._toastPlayer(other, T("Toast.TradeCancelledTitle"), T("Toast.TradeCancelledBody", player.DisplayName), "Info");
					svc._pushState(other, true);
				}
			}
			if (truthy(session)) {
				return responseSuccess(T("GameService.TradeCancelled"));
			}
			return responseSuccess(T("GameService.InviteCleared"));
		}
		return responseError(T("GameService.UnknownTradeAction"));
}
