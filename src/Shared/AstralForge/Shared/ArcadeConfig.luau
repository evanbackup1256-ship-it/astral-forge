--!strict
-- Purpose: Documented arcade scoring, pacing, dimensions and supported games; no wagers or payouts.
-- Owner: Astral Forge arcade. Dependencies: ArcadeTypes. Last-reviewed: 2026-10-05.
local Types = require("./ArcadeTypes")
export type Rules = {
	Schema: number,
	HistoryLimit: number,
	ReceiptLimit: number,
	RoundLifetime: number,
	StartCooldown: number,
	SessionRounds: number,
	BreakSeconds: number,
	MaximumScore: number,
	ScoreTotalLimit: number,
	SlotSymbols: number,
	RoulettePockets: number,
	KenoNumbers: number,
	KenoDraws: number,
	MinesCells: number,
	PlinkoRows: number,
	CoinOutcomes: number,
	CrashMinimum: number,
	CrashMaximum: number,
	Games: { Types.GameDefinition },
	PokerScores: { [string]: number },
	PlinkoScores: { number },
}
local config: Rules = {
	Schema = 1, -- Versioned, independent of the game's profile-save schema.
	HistoryLimit = 40, -- Bounded client-visible completed rounds.
	ReceiptLimit = 80, -- Recent action replies; nonce/version fencing protects older replays after eviction.
	RoundLifetime = 180, -- Seconds before unattended card/mine rounds finish with no earned score.
	StartCooldown = 0.5, -- Minimum server-time interval between round starts.
	SessionRounds = 40, -- Offer an enforced short break after this many starts.
	BreakSeconds = 60, -- Server-enforced break interval; no purchased bypass.
	MaximumScore = 1000, -- A single round never exceeds the documented score ceiling.
	ScoreTotalLimit = 9007199254740991, -- Exact integer limit; score is not spendable or transferable.
	SlotSymbols = 6, -- Distinct reel faces.
	RoulettePockets = 37, -- Number-wheel pockets 0–36.
	KenoNumbers = 40,
	KenoDraws = 10, -- Ten distinct numbers drawn from forty.
	MinesCells = 25, -- Five-by-five field; risk selection is 1–12 hidden hazards.
	PlinkoRows = 14, -- Fourteen peg decisions produce fifteen destination bins.
	CoinOutcomes = 200, -- 99 heads, 100 tails and one edge outcome; scores only.
	CrashMinimum = 1,
	CrashMaximum = 10, -- Flight duration in seconds, sampled before the run.
	Games = {
		{
			Id = "Slots",
			Name = "Reel Match",
			Description = "Match the three reel faces. Every spin records its verification details.",
			Mode = "Instant",
			Accent = "mango",
		},
		{
			Id = "Blackjack",
			Name = "Card 21",
			Description = "Hit or stand against the dealer. Get close to 21 without going over.",
			Mode = "Cards",
			Accent = "mint",
		},
		{
			Id = "Roulette",
			Name = "Number Wheel",
			Description = "Choose a pocket and follow the ball around the wheel.",
			Mode = "Instant",
			Accent = "coral",
		},
		{
			Id = "Poker",
			Name = "Five Card Draw",
			Description = "Keep the cards you want, draw replacements, and build a stronger hand.",
			Mode = "Cards",
			Accent = "violet",
		},
		{
			Id = "Crash",
			Name = "Flight Run",
			Description = "Stop your flight before the engine cuts out. Longer safe flights score higher.",
			Mode = "Action",
			Accent = "cyan",
		},
		{
			Id = "Dice",
			Name = "Dice Match",
			Description = "Pick a total and roll the two dice.",
			Mode = "Instant",
			Accent = "blue",
		},
		{
			Id = "CoinFlip",
			Name = "Coin Toss",
			Description = "Pick heads, tails, or the rare edge landing.",
			Mode = "Instant",
			Accent = "brass",
		},
		{
			Id = "Keno",
			Name = "Number Pick",
			Description = "Choose up to ten numbers, then compare them with the draw.",
			Mode = "Instant",
			Accent = "pink",
		},
		{
			Id = "Mines",
			Name = "Field Survey",
			Description = "Reveal clear tiles and stop before finding a hidden hazard.",
			Mode = "Action",
			Accent = "ember",
		},
		{
			Id = "Plinko",
			Name = "Peg Drop",
			Description = "Follow the ball through the peg field to its final bin.",
			Mode = "Instant",
			Accent = "steel",
		},
	},
	PokerScores = {
		RoyalFlush = 1000,
		StraightFlush = 750,
		FourKind = 500,
		FullHouse = 350,
		Flush = 250,
		Straight = 200,
		ThreeKind = 150,
		TwoPair = 100,
		HighPair = 50,
		None = 0,
	},
	PlinkoScores = { 1000, 500, 250, 100, 50, 25, 10, 5, 10, 25, 50, 100, 250, 500, 1000 },
}
for _, definition in config.Games do
	table.freeze(definition)
end
table.freeze(config.Games)
table.freeze(config.PokerScores)
table.freeze(config.PlinkoScores)
return table.freeze(config)
