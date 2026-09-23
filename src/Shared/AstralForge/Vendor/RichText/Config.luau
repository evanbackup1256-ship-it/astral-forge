--!strict

local types = require(script.Parent:WaitForChild("Types"))

local config = {}

-- color shorcuts used for color markup
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

-- ZIndex offset used for gui elements
config.ZINDEX_OFFSET = 1
config.EFFECTZINDEX_OFFSET = 1

-- the size in offset used as a reference for scaling animations or effects proportionally when needed
config.REFERENCE_SIZE = 16

-- the interval between the typewriter sounds when the typewriter interval is less than this value
-- (this is so the sound won't play with every character printed, which sounds unbearable with fast speeds -_-)
config.TYPEWRITER_SFX_INTERVAL = .065

config.TYPEWRITER_SFX_VOLUME = 1

-- fraction of the width of the container
-- any word wider than this value which doesn't fit on the current row will be split instead of fully moved to a new row
config.MAX_WORD_WIDTH_FRACTION = .3

-- the max amount of characters of a render's text displayed for debugging when overflowing
config.DEBUG_OVERFLOW_MAX_TEXT_LENGTH = 40

-- default properties used for all objects (MUST INCLUDE ALL EXISTING PROPERTIES!)
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
	-- slideFromTop & slideFromBottom
	SLIDE_OFFSET_FACTOR = .5, -- fraction of property size to offset the x and y starting position
	SLIDE_ROTATION = 55, -- rotation in deg when starting
	
	-- transparent
	TRANSPARENT_STARTING_VAL = 1, -- the starting transparency
	
	-- bounceFromTop & bounceFromBottom
	BOUNCE_OFFSET_FACTOR = .5, -- fraction of property size to offset the y starting position
	
	-- wiggle
	WIGGLE_OSC_FACTOR = .75, -- multiplier of the sine wave oscillations per second
	WIGGLE_OFFSET_FACTOR = .12, -- fraction of one sine wave oscillation by which each character is offsetted from eachother
	WIGGLE_BASE_AMPLITUDE = 4, -- the base amplitude of the sine wave in offset
}

config.EFFECTS = {
	-- shake
	SHAKE_MAX_OFFSET_FACTOR = .05, -- max possible fraction of property size to offset the x and y starting position
	
	--rainbow
	RAINBOW_CYCLE_FACTOR = .3, -- factor of the hue cycles per second
	
	--shiny
	SHINY_RATE = .375, -- sprite spawn requests per second per character
	SHINY_CHANCE = 25, -- chance in percentage of spawning sprite
	SHINY_MIN_LIFETIME = 1000, -- sprites min possible duration in which it tweens in and out in ms
	SHINY_MAX_LIFETIME = 1600, -- sprites max possible duration in which it tweens in and out in ms
	SHINY_MIN_SIZE = .4, -- min fraction of property size indicating the height and width of sprite in offset at the end of its lifetime
	SHINY_MAX_SIZE = .7, -- max fraction of property size indicating the height and width of sprite in offset at the end of its lifetime
	
	--stinky
	STINKY_COLOR = Color3.fromRGB(0, 143, 0), -- color of the sprite
	STINKY_TRANSPARENCY = .825, -- image transparency of the sprite
	STINKY_RATE = 4, -- sprite spawn requests per second per character
	STINKY_CHANCE = 25, -- chance in percentage of spawning sprite
	STINKY_MIN_LIFETIME = 5000, -- sprites min possible duration in which it tweens in and out in ms
	STINKY_MAX_LIFETIME = 6500, -- sprites max possible duration in which it tweens in and out in ms
	STINKY_MIN_SIZE = 2, -- min fraction of property size indicating the height and width of sprite in offset at the end of its lifetime
	STINKY_MAX_SIZE = 3, -- max fraction of property size indicating the height and width of sprite in offset at the end of its lifetime
	STINKY_MIN_ROTATION = -40, -- sprites min possible rotation at the end of its lifetime
	STINKY_MAX_ROTATION = 40, -- sprites max possible rotation at the end of its lifetime
}

return config