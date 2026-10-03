local TS = _G[script]

local t = TS.import(script, TS.getModule(script, "@rbxts", "t").lib.ts).t
return {
	t = t,
}
