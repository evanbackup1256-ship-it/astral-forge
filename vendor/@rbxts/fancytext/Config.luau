export type Config = {
	Font: Enum.Font?,
	FontFace: Font?,
	CustomFont: string?,

	FontSize: number?,
	FontWeight: Enum.FontWeight?,
	FontStyle: Enum.FontStyle?,
	TextColor: Color3?,
	TextAlign: ("Left" | "Right" | "Center")?,
	VerticalAlign: ("Top" | "Center" | "Bottom")?,
	ZIndex: number?,
	TextStrokeTransparency: number?,
	TextTransparency: number?,
	TextStrokeColor: Color3?,

	Scale: boolean?, -- UI scaling relative to 1920x1080
	TextSizeConstraint: { number }?, -- { MinTextSize, MaxTextSize }
}

return {
	Defaults = {
		FontSize = 25,
		FontWeight = Enum.FontWeight.Regular,
		FontStyle = Enum.FontStyle.Normal,
		TextColor = Color3.new(1, 1, 1),
		TextAlign = "Center",
		VerticalAlign = "Top",
		ZIndex = 1,
		TextTransparency = 0,
		TextStrokeTransparency = 1,
		TextStrokeColor = Color3.new(0, 0, 0),
		Scale = true,
	},

	FontsFolder = script.Parent.Fonts,
	EffectsFolder = script.Parent.Effects,
	IconsFolder = nil, -- Set this to your icons folder (e.g., game.ReplicatedStorage.Icons)
}
