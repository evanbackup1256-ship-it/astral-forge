--!strict
-- Material-inspired indeterminate / determinate circular boot spinner.
-- Pure GuiObjects (no gif atlas). Dual-ring track + rotating head + progress arc.
-- Safer than AbsoluteSize bombs: fixed offsets only, ClipsDescendants on hosts.

local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local _theme = require(script.Parent.theme)
local Palette = _theme.Palette

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

export type Props = {
	clock: React.Binding<number>,
	progress: React.Binding<number>,
	leaving: React.Binding<number>?,
	ready: boolean?,
	reducedMotion: boolean?,
	size: number?,
}

local function MaterialBootSpinner(props: Props)
	local clock = props.clock
	local progress = props.progress
	local leaving = props.leaving
	local ready = props.ready == true
	local reducedMotion = props.reducedMotion == true
	local diameter = props.size or 72
	local stroke = math.max(3, math.floor(diameter * 0.085))
	local idleLeave = React.useBinding(0)
	local exitBinding = leaving or idleLeave

	local pose = React.joinBindings({
		clock = clock,
		progress = progress,
		leaving = exitBinding,
	}):map(function(values)
		local t = values.clock
		local p = clamp01(values.progress)
		local fade = clamp01(values.leaving)
		local spin = if reducedMotion or ready then t * 90 else t * 220
		local breathe = if reducedMotion then 0 else (math.sin(t * 2.1) + 1) * 0.5
		return {
			spin = spin % 360,
			counter = (-spin * 0.55) % 360,
			progress = p,
			breathe = breathe,
			fade = fade,
			headAlpha = 0.08 + (1 - p) * 0.12 + breathe * 0.06,
		}
	end)

	return React.createElement("frame", {
		Size = UDim2.fromOffset(diameter, diameter),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 520,
	}, React.createElement("frame", {
		-- Track
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Thickness = stroke,
		Color = Palette.lineSoft,
		Transparency = pose:map(function(v)
			return clamp01(0.72 + v.fade)
		end),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})), React.createElement("frame", {
		-- Determinate fill hint (inner glow ring scales with progress)
		Size = pose:map(function(v)
			local s = 0.62 + v.progress * 0.3
			return UDim2.fromScale(s, s)
		end),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.cyan,
		BackgroundTransparency = pose:map(function(v)
			return clamp01(0.88 - v.progress * 0.22 + v.fade)
		end),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		-- Rotating Material head (thick arc approximation via clipped stroke host)
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Rotation = pose:map(function(v)
			return v.spin
		end),
		ZIndex = 3,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Thickness = stroke + 1,
		Color = Palette.cyan,
		Transparency = pose:map(function(v)
			return clamp01(v.headAlpha + v.fade)
		end),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, React.createElement("uigradient", {
		Rotation = 0,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.58, 0.05),
			NumberSequenceKeypoint.new(0.78, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Palette.cyan),
			ColorSequenceKeypoint.new(0.55, Palette.mint),
			ColorSequenceKeypoint.new(1, Palette.cream),
		}),
	}))), React.createElement("frame", {
		-- Counter-rotating soft mint tick (Material dual-tone feel)
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Rotation = pose:map(function(v)
			return v.counter
		end),
		ZIndex = 4,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Thickness = math.max(2, stroke - 1),
		Color = Palette.mint,
		Transparency = pose:map(function(v)
			return clamp01(0.55 + v.fade + (if ready then 0.2 else 0))
		end),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, React.createElement("uigradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.7, 1),
			NumberSequenceKeypoint.new(0.86, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}))), React.createElement("frame", {
		-- Leading cap (Material head)
		Size = UDim2.fromOffset(stroke + 2, stroke + 2),
		Position = pose:map(function(v)
			local rad = math.rad(v.spin - 90)
			local r = diameter * 0.5 - stroke * 0.5
			return UDim2.fromOffset(diameter * 0.5 + math.cos(rad) * r, diameter * 0.5 + math.sin(rad) * r)
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.cream,
		BackgroundTransparency = pose:map(function(v)
			return clamp01(0.05 + v.fade)
		end),
		BorderSizePixel = 0,
		ZIndex = 5,
		Visible = pose:map(function(v)
			return v.fade < 0.96 and not reducedMotion
		end),
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end

return {
	MaterialBootSpinner = MaterialBootSpinner,
}
