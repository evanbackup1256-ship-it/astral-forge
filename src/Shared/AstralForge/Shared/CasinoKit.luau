--!strict

local KIT_READY = false
if not KIT_READY then
	-- Release guard: replace the placeholder after the casino kit is uploaded.
	warn("[ASTRAL FORGE / RELEASE BLOCKER] Casino/crate kit is not uploaded; KitReady is false.")
end

return table.freeze({
	Id = 0,
	PlaceholderId = 0,
	KitReady = KIT_READY,
})
