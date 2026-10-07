--!strict
-- Purpose: Explicit arcade request, persisted-round and public-view shapes; no currency fields exist.
-- Owner: Astral Forge arcade. Dependencies: none. Last-reviewed: 2026-10-05.
export type GameId =
	"Slots"
	| "Blackjack"
	| "Roulette"
	| "Poker"
	| "Crash"
	| "Dice"
	| "CoinFlip"
	| "Keno"
	| "Mines"
	| "Plinko"
export type Numbers = { number }
export type Selection = number | string
export type Request = {
	RequestId: string,
	Game: GameId,
	Action: string,
	Commitment: string?,
	ClientSeed: string?,
	Nonce: number?,
	RoundId: string?,
	Version: number?,
	Choice: Selection?,
	Picks: Numbers?,
	Risk: number?,
}
export type Proof = { Algorithm: string, Commitment: string, ClientSeed: string, Nonce: number, Domain: string }
export type Reveal = Proof & { ServerSeed: string }
export type Move = { Action: string, Choice: Selection?, Picks: Numbers, At: number }
export type Round = {
	Id: string,
	Game: GameId,
	Version: number,
	StartedAt: number,
	ExpiresAt: number,
	ServerSeed: string,
	ClientSeed: string,
	Nonce: number,
	Commitment: string,
	Numbers: Numbers,
	PlayerCards: Numbers,
	DealerCards: Numbers,
	Revealed: Numbers,
	Cursor: number,
	Risk: number,
	Choice: Selection?,
	Score: number,
	Finished: boolean,
	Label: string,
	Moves: { Move },
	Draws: number,
}
export type PublicRound = {
	Id: string,
	Game: GameId,
	Version: number,
	StartedAt: number,
	ExpiresAt: number,
	PlayerCards: Numbers,
	DealerCards: Numbers,
	Revealed: Numbers,
	Risk: number,
	Score: number,
	Finished: boolean,
	Label: string,
	Choice: Selection?,
	Proof: Proof,
}
export type FinishedRound = PublicRound & { Reveal: Reveal, Numbers: Numbers, Moves: { Move }, Draws: number }
export type GameStats = { Played: number, BestScore: number, TotalScore: number }
export type Statistics = { Played: number, TotalScore: number, ByGame: { [string]: GameStats } }
export type PublicState = {
	Schema: number,
	Nonce: number,
	Commitment: string,
	Active: PublicRound?,
	History: { FinishedRound },
	Stats: Statistics,
	BreakUntil: number,
}
export type Reply = {
	ok: boolean,
	message: string?,
	error: string?,
	Round: PublicRound?,
	Result: FinishedRound?,
	Replayed: boolean?,
	Arcade: PublicState?,
}
export type Receipt = { Id: string, Fingerprint: string, Reply: Reply }
export type State = {
	Schema: number,
	Nonce: number,
	ServerSeed: string,
	Commitment: string,
	Active: Round?,
	History: { FinishedRound },
	Receipts: { Receipt },
	Stats: Statistics,
	SessionRounds: number,
	BreakUntil: number,
	LastStartAt: number,
}
export type Stream = { integer: (number, number) -> number, unit: () -> number, drawCount: () -> number }
export type Dependencies = { newSeed: () -> string, newId: () -> string, now: () -> number }
export type Profile = { Arcade: State? }
export type GameDefinition = { Id: GameId, Name: string, Description: string, Mode: string, Accent: string }
return table.freeze({})
