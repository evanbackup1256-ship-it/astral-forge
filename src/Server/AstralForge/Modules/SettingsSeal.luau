--!strict
-- Pure settings seal helpers peeled from ServerServices (wave41).

local SettingsSeal = {}

function SettingsSeal.Apply(profile)
	profile.Settings.SoundEffects = (tonumber(profile.Settings.SoundVolume) or 0) > 0.001
	profile.Settings.UIEffects = (tonumber(profile.Settings.EffectsIntensity) or 0) > 0.001
	profile.Settings.ReducedMotion = (tonumber(profile.Settings.MotionIntensity) or 1) <= 0.03
end

return SettingsSeal
