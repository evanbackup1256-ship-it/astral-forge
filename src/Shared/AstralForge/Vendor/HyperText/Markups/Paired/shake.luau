--!strict

local HttpService = game:GetService("HttpService")

local types = require("../../Internal/Types")
local util = require("../../Internal/Util")
local config = require("../../Internal/Config")

local name : "shake" = "shake"
local type_ : "paired" = "paired"
local applyToImages : true = true
local module : types.dataModule<typeof(name), typeof(type_), typeof(applyToImages)> = {
	type = type_,
	name = name,
	applyToImages = applyToImages,

	onPrint = function(
		obj : types.hyperTextClassObject,
		printerData : types.printerDataRowEntry,
		spanData : types.onPrintMarkupSpanData,
		updater : {[string] : (dt : number) -> ()}
	)
		if 
			printerData.markups.shake.value
			and (
				printerData.markups.shake.attributes.loop
				or printerData.markups.shake.attributes.dur > 0
			)
			and obj._contentFolder
		then
			local updaterId = HttpService:GenerateGUID()
			local startTime = os.clock()
			local seed = (printerData.index or 1) * 1.73
			local last
			local lastPos = Vector2.zero
			local lastRot = 0
			
			if printerData.character.Parent == printerData.row then
				obj:_CreateRowEntryContainer(printerData, name)
			end
			
			local function stop()
				util.removeEntryFromTransformUpdater(
					obj,
					printerData,
					name
				)

				updater[updaterId] = nil
			end
			
			util.addEntryToTransformUpdater(
				obj,
				printerData,
				name
			)

			updater[updaterId] = function()
				debug.profilebegin("Shake Markup")

				local parentGui = printerData.character.Parent :: GuiObject
				local absX = math.max(1, parentGui.AbsoluteSize.X)
				local absY = math.max(1, parentGui.AbsoluteSize.Y)
				local offset = printerData.markups.shake.attributes.maxOffset * absY

				local time_ = os.clock()
				local elapsed = time_ - startTime
				local fade = (printerData.markups.shake.attributes.loop or not printerData.markups.shake.attributes.fade)
					and 1
					or math.clamp(1 - (elapsed / math.max(0.05, printerData.markups.shake.attributes.dur)), 0, 1)

				local freq = printerData.markups.shake.attributes.freq or 16
				if not last or time_ - last >= 1 / math.max(1, freq) then
					last = time_
					local t = time_ * math.max(4, freq * 0.85) + seed
					local nx = math.noise(t, seed, 0.37) * 1.45 + math.sin(t * 2.3) * 0.35
					local ny = math.noise(seed, t, 0.91) * 1.45 + math.cos(t * 2.9) * 0.35
					local nr = math.noise(t * 0.9, 0.53, seed) * 1.5
					local xOffset = math.clamp(nx, -1, 1) * offset
					local yOffset = math.clamp(ny, -1, 1) * offset
					lastPos = Vector2.new(
						(xOffset / absX) * fade,
						(yOffset / absY) * fade
					)
					lastRot = math.clamp(nr, -1, 1) * printerData.markups.shake.attributes.maxRot * fade
				end

				printerData.position += lastPos
				printerData.rotation += lastRot

				if elapsed >= printerData.markups.shake.attributes.dur and not printerData.markups.shake.attributes.loop then
					stop()
				end

				debug.profileend()
			end

			local connection = obj.onRenderEnded:Once(function(stopped : boolean?)
				if stopped and not printerData.markups.shake.attributes.loop then
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
		maxOffset = {
			convert = util.stringToNumber,
		},
		dur = {
			convert = util.stringToNumber,
		},
		loop = {
			convert = util.stringToBoolean,
		},
		maxRot = {
			convert = util.stringToNumber,
		},
		freq = {
			convert = util.stringToNumber,
			unrequired = true,
		},
		fade = {
			convert = util.stringToBoolean,
		}
	},
	valueAttributes = {},
}

return module
