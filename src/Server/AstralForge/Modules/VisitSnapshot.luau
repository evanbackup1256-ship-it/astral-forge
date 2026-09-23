--!strict
-- Pure visit snapshot builder peeled from ServerServices (wave40).

local VisitSnapshot = {}

function VisitSnapshot.Build(player: Player, profile, Economy)
	local production = Economy.Production(profile)
	local machines = {}
	local machineCount = 0
	for id, level in profile.Machines do
		local amount = math.floor(tonumber(level) or 0)
		if amount > 0 then
			machines[id] = amount
			machineCount += 1
		end
	end
	return {
		UserId = player.UserId,
		Name = player.Name,
		DisplayName = player.DisplayName,
		Zone = profile.Zone,
		CurrentZone = profile.CurrentZone,
		Rebirths = profile.Rebirths,
		Production = production,
		Cash = profile.Cash,
		Vault = profile.Vault,
		Capacity = Economy.Capacity(profile, os.time()),
		Cores = profile.Cores,
		Stardust = profile.Stardust,
		LifetimeCash = profile.LifetimeCash,
		Machines = machines,
		MachineKinds = machineCount,
		ServerTime = os.time(),
	}
end

return VisitSnapshot
