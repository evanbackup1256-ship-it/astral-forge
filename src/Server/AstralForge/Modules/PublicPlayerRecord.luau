--!strict
-- Pure public player mirror record peeled from ServerServices (wave41).

local PublicPlayerRecord = {}

function PublicPlayerRecord.Build(player: Player, profile, viewer: Player, presence, deps)
	local EnsureItems = deps.EnsureItems
	local itemById = deps.itemById
	local Economy = deps.Economy
	local items = EnsureItems(profile)
	local itemCount = 0
	for _ in items.Inventory do
		itemCount += 1
	end
	local equippedItems = {}
	for _, uid in items.Equipped do
		local instance = items.Inventory[uid]
		local definition = instance and itemById[instance.DefinitionId]
		if definition then
			table.insert(equippedItems, definition.Name)
		end
	end
	local liveEntry = presence and presence[player.UserId]
	return {
		UserId = math.floor(player.UserId),
		Name = player.Name,
		DisplayName = player.DisplayName,
		Zone = profile.Zone,
		CurrentZone = profile.CurrentZone,
		Rebirths = profile.Rebirths,
		Production = Economy.Production(profile),
		LifetimeCash = profile.LifetimeCash,
		Stardust = profile.Stardust,
		Cores = profile.Cores,
		DomainRank = profile.Domain and profile.Domain.Rank or 0,
		PlayTime = profile.Stats and profile.Stats.PlayTime or 0,
		ItemCount = itemCount,
		EquippedItems = equippedItems,
		IsLocal = player == viewer,
		SocialFlags = 0,
		CurrentPage = liveEntry and liveEntry.Page or "Overview",
		PresenceAge = liveEntry and math.max(0, os.time() - liveEntry.UpdatedAt) or -1,
	}
end

return PublicPlayerRecord
