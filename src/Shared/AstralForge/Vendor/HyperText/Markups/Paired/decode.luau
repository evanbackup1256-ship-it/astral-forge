--!strict

local HttpService = game:GetService("HttpService")

local types = require("../../Internal/Types")
local util = require("../../Internal/Util")
local config = require("../../Internal/Config")

local CIPHER_GLYPHS = "0123456789ABCDEF#%&*+/?@"

local name : "decode" = "decode"
local type_ : "paired" = "paired"
local module : types.dataModule<typeof(name), typeof(type_)> = {
	type = type_,
	name = name,
	
	onPrint = function(
		obj : types.hyperTextClassObject,
		printerData : types.printerDataRowEntry<false>,
		spanData : types.onPrintMarkupSpanData,
		updater : {[string] : (dt : number) -> ()}
	)
		if obj._contentFolder and printerData.markups.decode.value then
			local startTime = os.clock()
			local updaterId = HttpService:GenerateGUID()
			local text = printerData.character.Text
			local charOrder = printerData.index or 1
			local last

			local function formatChar(ch : string) : string
				return (printerData.markups.underline.value and "<u>" or "")
					.. (printerData.markups.strike.value and "<s>" or "")
					.. ch
					.. (printerData.markups.strike.value and "</s>" or "")
					.. (printerData.markups.underline.value and "</u>" or "")
			end

			local function stop()
				updater[updaterId] = nil
				printerData.character.Text = text
			end
			
			updater[updaterId] = function(dt : number)
				debug.profilebegin("Decode Markup")

				local time_ = os.clock()
				local elapsed = time_ - startTime
				local dur = math.max(0.08, printerData.markups.decode.attributes.dur)
				local loop = printerData.markups.decode.attributes.loop

				if loop then
					-- Travelling cipher wave: each character stays readable for ~84% of the cycle
					-- and briefly flashes cipher glyphs as the decode wavefront passes across it.
					local period = math.max(1.35, dur * 7.5)
					local phase = (time_ - charOrder * 0.085) % period
					if phase < dur then
						local freq = printerData.markups.decode.attributes.freq or 14
						if not last or time_ - last >= 1 / math.max(1, freq) then
							last = time_
							local pick = ((math.floor(time_ * freq) + charOrder * 7) % #CIPHER_GLYPHS) + 1
							local ch = string.sub(CIPHER_GLYPHS, pick, pick)
							printerData.character.Text = formatChar(ch)
						end
					elseif printerData.character.Text ~= text then
						printerData.character.Text = text
					end
				else
					local freq = printerData.markups.decode.attributes.freq or 18
					if not last or time_ - last >= 1 / math.max(1, freq) then
						last = time_
						local pick = ((math.floor(time_ * freq) + charOrder * 5) % #CIPHER_GLYPHS) + 1
						local ch = string.sub(CIPHER_GLYPHS, pick, pick)
						printerData.character.Text = formatChar(ch)
					end
					if elapsed >= dur then
						stop()
					end
				end

				debug.profileend()
			end

			local connection = obj.onRenderEnded:Once(function(stopped : boolean?)
				if stopped and not printerData.markups.decode.attributes.loop then
					stop()
				end
			end)
			obj._contentFolder.Destroying:Once(function()
				connection:Disconnect()

				stop()
			end)
		end
	end,
	convert = util.stringToBoolean,
	attributes = {
		freq = {
			convert = util.stringToNumber,
			unrequired = true,
		},
		dur = {
			convert = function(value : string)
				return util.stringToNumber(value, 0)
			end,
		},
		loop = {
			convert = util.stringToBoolean,
		},
	},
	valueAttributes = {},
}

return module
