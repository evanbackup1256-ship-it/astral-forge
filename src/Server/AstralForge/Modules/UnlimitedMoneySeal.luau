--!strict
-- Pure unlimited-money seal peeled from ServerServices (wave44).

local UnlimitedMoneySeal = {}

function UnlimitedMoneySeal.Apply(profile, maxSafeCurrency, Economy)
	if profile.Flags.UnlimitedMoney then
		profile.Cash = maxSafeCurrency
		profile.RunCash = maxSafeCurrency
		profile.LifetimeCash = Economy.Max(profile.LifetimeCash, maxSafeCurrency)
	end
end

return UnlimitedMoneySeal
