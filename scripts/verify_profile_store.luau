--!nocheck
-- ProfileStore (rewrite 03): versioned migrations run in order, once, only for older saves, before
-- template defaults; newer schemas are refused; the v5 settings step keeps toggles that were off.
local load = require("./_out_loader")
local Store = load("out/Server/AstralForge/Modules/ProfileStore")
local checks = 0
local function check(cond, msg) checks += 1; assert(cond, msg) end

check(Store.ReadVersion({}, 21) == 0, "missing DataVersion reads as 0")
check(Store.ReadVersion({ DataVersion = 7 }, 21) == 7, "stored version read")
check(not pcall(Store.ReadVersion, { DataVersion = 22 }, 21), "newer schema refused")

local seen = {}
local steps = {
	{ to = 9, name = "nine", run = function(p) table.insert(seen, "nine"); p.Nine = true end },
	{ to = 3, name = "three", run = function(p) table.insert(seen, "three"); p.Three = (p.Nine == nil) end },
	{ to = 12, name = "twelve", run = function() table.insert(seen, "twelve") end },
}
local doc = {}
local applied = Store.Migrate(doc, 2, 10, steps)
check(#applied == 2 and applied[1] == "three" and applied[2] == "nine", "steps run in version order up to target")
check(doc.Three == true and doc.Nine == true, "earlier step ran first")
check(#Store.Migrate({}, 9, 10, steps) == 0, "a save at or past a step's version skips it")
check(#Store.Migrate("junk", 0, 21) == 0, "non-table documents are left alone")

local old = { DataVersion = 4, Settings = { SoundEffects = false, UIEffects = false, ReducedMotion = true } }
check(#Store.Migrate(old, 4, 21) == 1, "v4 save gets the v5 step")
check(old.Settings.SoundVolume == 0 and old.Settings.EffectsIntensity == 0 and old.Settings.MotionIntensity == 0, "off toggles become 0 sliders")
local current = { DataVersion = 21, Settings = { SoundEffects = false, SoundVolume = 0.7 } }
check(#Store.Migrate(current, 21, 21) == 0 and current.Settings.SoundVolume == 0.7, "current saves are not migrated")
check(Store.Stamp({ DataVersion = 4 }, 21).DataVersion == 21, "stamp sets the current version")

-- full DataService path on a v4 save: toggles survive reconcile + sanitize
local H = require("./_server_harness")
local DataService = H.load("Server/AstralForge/Services/DataService")
local clean = DataService.migrateLegacyProfile({ DataVersion = 4, Settings = { SoundEffects = false, UIEffects = true } })
check(clean.DataVersion == 21 or clean.DataVersion >= 21, "normalized profile is current")
check(clean.Settings.SoundVolume == 0 and clean.Settings.SoundEffects == false, "v4 muted save stays muted")
check(clean.Settings.UIEffects == true, "untouched toggle keeps its default")
print(`[TEST] profile store: {checks} checks (version read, ordered versioned migrations, v5 settings step, DataService load path) passed`)
