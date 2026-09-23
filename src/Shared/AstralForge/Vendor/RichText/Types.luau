--!strict

local types = {}

-- used for validating at runtime
types.runtime = {
	animations = {
		SlideFromTop = true,
		SlideFromBottom = true,
		Transparent = true,
		BounceFromTop = true,
		BounceFromBottom = true,
		Wiggle = true,
		None = true,
	},
	effects = {
		Shake = true,
		Rainbow = true,
		Shiny = true,
		Stinky = true,
		None = true
	}
}

export type properties = {
	Color : Color3,
	Font : string,
	Size : number,
	XAlign : Enum.HorizontalAlignment,
	YAlign : Enum.VerticalAlignment,
	TypewriterInterval : number,
	TypewriterSoundId : string?,
	Animation : keyof<typeof(types.runtime.animations)>,
	AnimationDuration : number,
	AnimationLoop : boolean,
	Effect : keyof<typeof(types.runtime.effects)>,
	Weight : Enum.FontWeight,
	Italic : boolean,
	Transparency : number,
	ZIndexOffset : number?,
	EffectZIndexOffset : number?,
}

return types