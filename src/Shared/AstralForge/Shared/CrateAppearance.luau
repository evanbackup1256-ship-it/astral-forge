--!strict
-- Purpose: keep default crate models consistent between the shop and opening reveal.
-- Owner: presentation. Dependencies: caller-provided crate definitions.
-- Last-reviewed: 2026-10-06.

export type Definition = { Id: string, ModelId: string? }
local Appearance = {}
local DEFAULT_SKIN = "Classic"

function Appearance.resolve(skinId: string?, crateId: string?, crates: { Definition }): string
	local selected = skinId or DEFAULT_SKIN
	if selected ~= DEFAULT_SKIN then
		return selected
	end
	for _, crate in crates do
		if crate.Id == crateId and crate.ModelId ~= nil and crate.ModelId ~= "" then
			return crate.ModelId
		end
	end
	return DEFAULT_SKIN
end

return table.freeze(Appearance)
