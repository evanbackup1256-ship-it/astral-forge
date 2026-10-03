--!strict

local types = require(script.Parent:WaitForChild("Types"))

local config = {}

config.COLOR_SHORTCUTS = {} :: {[string] : Color3}
config.COLOR_SHORTCUTS.white        = Color3.fromRGB(255, 255, 255)
config.COLOR_SHORTCUTS.black        = Color3.fromRGB(0, 0, 0)
config.COLOR_SHORTCUTS.red          = Color3.fromRGB(255, 70, 70)
config.COLOR_SHORTCUTS.darkred      = Color3.fromRGB(150, 0, 0)
config.COLOR_SHORTCUTS.lightred     = Color3.fromRGB(255, 170, 170)
config.COLOR_SHORTCUTS.green        = Color3.fromRGB(70, 255, 70)
config.COLOR_SHORTCUTS.darkgreen    = Color3.fromRGB(0, 120, 0)
config.COLOR_SHORTCUTS.lightgreen   = Color3.fromRGB(170, 255, 170)
config.COLOR_SHORTCUTS.blue         = Color3.fromRGB(70, 130, 255)
config.COLOR_SHORTCUTS.darkblue     = Color3.fromRGB(0, 70, 160)
config.COLOR_SHORTCUTS.lightblue    = Color3.fromRGB(170, 210, 255)
config.COLOR_SHORTCUTS.yellow       = Color3.fromRGB(255, 199, 32)
config.COLOR_SHORTCUTS.darkyellow   = Color3.fromRGB(170, 150, 0)
config.COLOR_SHORTCUTS.lightyellow  = Color3.fromRGB(255, 250, 170)
config.COLOR_SHORTCUTS.orange       = Color3.fromRGB(255, 140, 40)
config.COLOR_SHORTCUTS.darkorange   = Color3.fromRGB(200, 100, 0)
config.COLOR_SHORTCUTS.lightorange  = Color3.fromRGB(255, 200, 140)
config.COLOR_SHORTCUTS.purple       = Color3.fromRGB(170, 70, 255)
config.COLOR_SHORTCUTS.darkpurple   = Color3.fromRGB(100, 0, 180)
config.COLOR_SHORTCUTS.lightpurple  = Color3.fromRGB(220, 180, 255)
config.COLOR_SHORTCUTS.pink         = Color3.fromRGB(255, 100, 200)
config.COLOR_SHORTCUTS.darkpink     = Color3.fromRGB(180, 0, 100)
config.COLOR_SHORTCUTS.lightpink    = Color3.fromRGB(255, 180, 230)
config.COLOR_SHORTCUTS.cyan         = Color3.fromRGB(100, 220, 255)
config.COLOR_SHORTCUTS.darkcyan     = Color3.fromRGB(0, 150, 180)
config.COLOR_SHORTCUTS.lightcyan    = Color3.fromRGB(180, 240, 255)
config.COLOR_SHORTCUTS.gray         = Color3.fromRGB(150, 150, 150)
config.COLOR_SHORTCUTS.darkgray     = Color3.fromRGB(80, 80, 80)
config.COLOR_SHORTCUTS.lightgray    = Color3.fromRGB(220, 220, 220)

config.ZINDEX_OFFSET = 1
config.EFFECTZINDEX_OFFSET = 1

config.REFERENCE_SIZE = 16

config.TYPEWRITER_SFX_INTERVAL = .065

config.TYPEWRITER_SFX_VOLUME = 1

config.MAX_WORD_WIDTH_FRACTION = .3

config.DEBUG_OVERFLOW_MAX_TEXT_LENGTH = 40

config.DEFAULT_PROPERTIES = {
	Color = Color3.new(1, 1, 1),
	Font = "rbxasset://fonts/families/BuilderSans.json",
	Size = 16,
	XAlign = Enum.HorizontalAlignment.Left,
	YAlign = Enum.VerticalAlignment.Top,
	TypewriterInterval = .015,
	TypewriterSoundId = nil,
	Animation = "SlideFromTop",
	AnimationDuration = .125,
	Weight = Enum.FontWeight.Regular,
	Italic = false,
	AnimationLoop = false,
	Transparency = 0,
	Effect = "None",
	ZIndexOffset = 1,
	EffectZIndexOffset = 1,
} :: types.properties

config.ANIMATIONS = {
	SLIDE_OFFSET_FACTOR = .5,
	SLIDE_ROTATION = 55,
	
	TRANSPARENT_STARTING_VAL = 1,
	
	BOUNCE_OFFSET_FACTOR = .5,
	
	WIGGLE_OSC_FACTOR = .75,
	WIGGLE_OFFSET_FACTOR = .12,
	WIGGLE_BASE_AMPLITUDE = 4,
}

config.EFFECTS = {
	SHAKE_MAX_OFFSET_FACTOR = .05,
	
	RAINBOW_CYCLE_FACTOR = .3,
	
	SHINY_RATE = .375,
	SHINY_CHANCE = 25,
	SHINY_MIN_LIFETIME = 1000,
	SHINY_MAX_LIFETIME = 1600,
	SHINY_MIN_SIZE = .4,
	SHINY_MAX_SIZE = .7,
	
	STINKY_COLOR = Color3.fromRGB(0, 143, 0),
	STINKY_TRANSPARENCY = .825,
	STINKY_RATE = 4,
	STINKY_CHANCE = 25,
	STINKY_MIN_LIFETIME = 5000,
	STINKY_MAX_LIFETIME = 6500,
	STINKY_MIN_SIZE = 2,
	STINKY_MAX_SIZE = 3,
	STINKY_MIN_ROTATION = -40,
	STINKY_MAX_ROTATION = 40,
}

return config