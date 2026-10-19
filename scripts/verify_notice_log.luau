-- Recent-alerts log: bounded, deduplicated history surfaced as the Mail "Alerts" filter.
local fs = require("@lune/fs")
local task = require("@lune/task")

local NoticeMath = require("../out/Client/AstralForge/CoreKit/noticeMath")
NoticeMath.ClearLog()

assert(NoticeMath.Record("", "", "Info") == nil, "empty notices are ignored")
local heard = 0
local unsubscribe = NoticeMath.Subscribe(function()
	heard += 1
end)
NoticeMath.Record("Forge ready", "Your build finished.", "Success", 100)
NoticeMath.Record("Forge ready", "Your build finished.", "Success", 101)
local entries = NoticeMath.Entries()
assert(#entries == 1, "consecutive duplicates merge")
assert(entries[1].Count == 2, "merged entry counts repeats")
assert(entries[1].Tone == "Success", "tone kept")
entries[1].Title = "mutated"
assert(NoticeMath.Entries()[1].Title == "Forge ready", "Entries returns copies")

NoticeMath.Record("Other", string.rep("x", 900), "Warning", 102)
local newest = NoticeMath.Entries()[1]
assert(newest.Title == "Other", "newest first")
assert(#newest.Body <= 400, "body truncated")

for i = 1, NoticeMath.LOG_LIMIT + 10 do
	NoticeMath.Record(`Alert {i}`, "", "Info", 200 + i)
end
assert(#NoticeMath.Entries() == NoticeMath.LOG_LIMIT, "log is bounded")

task.wait()
assert(heard > 0, "subscribers notified")
unsubscribe()
local before = heard
NoticeMath.Record("After", "", "Info", 999)
task.wait()
assert(heard == before, "unsubscribe stops notifications")
NoticeMath.ClearLog()
assert(#NoticeMath.Entries() == 0, "clear empties the log")

local ui = fs.readFile("src/Client/AstralForge/UiCore.luau")
assert(string.find(ui, "NoticeMath.Record(normalizedTitle, body, tone)", 1, true), "UiCore records toasts")
local social = fs.readFile("src/Client/AstralForge/pages/PagesSocial.luau")
assert(string.find(social, '{ id = "Alerts", label = "Alerts" }', 1, true), "Mail has Alerts filter")
assert(string.find(social, "NoticeMath.Subscribe", 1, true), "Mail subscribes to the alert log")

print("verify_notice_log OK")
