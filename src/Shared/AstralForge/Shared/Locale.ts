// Player-facing copy, keyed. English is the source table; every string here is the exact copy the
// game shipped with before routing, so this table changes nothing on screen. Add a key here, then
// call T("Key", ...args) at the use site. Keys are typed, so a missing key is a compile error.
// %s / %d placeholders are filled with string.format, same as the code they replaced.

export const EN = {
	"Save.OpenFailed": "Your save could not be opened safely. Please rejoin in a moment.",
	"Save.VerifyFailed": "Your save could not be verified safely. Please rejoin or contact support.",
	"Save.ChangedWhileLoading": "Your save changed while loading. Please rejoin in a moment.",
	"Save.ActiveElsewhere": "Your data is still active on another server. Please wait a moment and rejoin.",
	"Save.OldServer": "You joined an old server that cannot load your save. Please try a newer server.",
	"Save.LoadFailed": "Your save could not be loaded safely. Please rejoin in a moment.",
	"Shutdown.StudioSaving": "Tempering a fresh test server. Your progress is safe.",
	"Shutdown.Saving": "Securing your forge before the server refreshes.",
	"Shutdown.Teleporting": "Progress saved. Opening a fresh forge now.",
	"Shutdown.Waiting": "Roblox is reconnecting this server. Hold tight.",
	"Kick.Suspicious": "Astral Forge rejected suspicious activity.",
	"Kick.Exploit": "Astral Forge rejected confirmed exploit activity.",
	"Toast.TradeInviteTitle": "Trade invite",
	"Toast.PracticeCompleteTitle": "Practice complete",
	"Toast.PracticeCompleteBody": "That's how a trade settles. Nothing changed hands.",
	"Toast.TradeCompleteTitle": "Trade complete",
	"Toast.TradeCompleteBody": "The exchange is locked in.",
	"Toast.TradeCancelledTitle": "Trade cancelled",
	"Toast.SaveTroubleTitle": "Save trouble",
	"Toast.SaveTroubleBody": "Your progress couldn't save just now. Stay online while we retry.",
	"Toast.PurchaseCompleteTitle": "Purchase complete",
	"Toast.RelicLinkedTitle": "Relic linked",
	"Toast.RelicDetachedTitle": "Relic detached",
	"Toast.LeaderboardClimbTitle": "Leaderboard climb",
	"Toast.VisitEndedTitle": "Visit ended",
	"Toast.VisitEndedBody": "The host left the server.",
	"Toast.TradeClosedTitle": "Trade closed",
	"Toast.TradeClosedBody": "Your partner left the server.",
	"Toast.ReactorReadyTitle": "Reactor ready",
	"Toast.ReactorReadyBody": "Stabilize it for the payout.",
	"Toast.UnlimitedFluxTitle": "Unlimited Flux enabled",
	"Toast.UnlimitedFluxBody": "Your test balance will not decrease.",
	"Toast.FreeSpinsTitle": "Free wheel spins",
	"Toast.VisitorLeftTitle": "Visitor left",
	"Toast.VisitorArrivedTitle": "Someone stopped by",
	"Toast.VisitorLeftBody": "%s headed home.",
	"Toast.VisitorArrivedBody": "%s is checking out your shop.",
	"Toast.TradeInviteBody": "%s wants to trade. Open Trade to accept.",
	"Toast.TradeAwayBody": "%s stepped away from the table.",
	"Toast.TradeBackBody": "%s is back at the table.",
	"Toast.TradeCancelledBody": "%s closed the table.",
	"Toast.LeaderboardClimbBody": "You're #%d in %s now.",
	"Toast.FreeSpinsBody": "%s spins added (%s ready).",
} as const;

export type LocaleKey = keyof typeof EN;

export function T(key: LocaleKey, ...args: Array<string | number>): string {
	const copy: string = EN[key];
	return args.size() > 0 ? string.format(copy, ...args) : copy;
}
