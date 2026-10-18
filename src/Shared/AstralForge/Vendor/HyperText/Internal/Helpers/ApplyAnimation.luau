local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local util = require("../Util")
local types = require("../Types")

local function ensureCharScale(character : GuiObject) : UIScale
	local existing = character:FindFirstChildOfClass("UIScale")
	if existing then
		return existing
	end
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1
	uiScale.Parent = character
	return uiScale
end

return function(
	obj : types.hyperTextClassObject,
	printerData : types.printerDataRowEntry,
	value : keyof<typeof(types.literal.animations)>,
	attrs : types.animAttrs,
	valueAttrs : types.animValueAttrs,
	updater : {[string] : (dt : number) -> ()},
	onClear : boolean,
	name : string
)
	if
		obj._markupIndices
		and obj._contentFolder
	then
		local startTime = os.clock()
		local size = obj:_GetProportionalSize(printerData.markups.size.value)

		if #printerData.containers == 0 then
			obj:_CreateRowEntryContainer(printerData, name)
		end

		if not obj._markupIndices[value] then
			obj._markupIndices[value] = 0
		end
		local charIndex = obj._markupIndices[value]
		obj._markupIndices[value] += 1

		local charScale = ensureCharScale(printerData.character)

		if value == "slide" then
			local updaterId = HttpService:GenerateGUID()
			local parentGui = printerData.character.Parent :: GuiObject
			local absX = math.max(1, parentGui.AbsoluteSize.X)
			local absY = math.max(1, parentGui.AbsoluteSize.Y)
			local dirSign = if valueAttrs.slide.dir == "up" then 1 else -1
			local startPos = Vector2.new(
				(size * valueAttrs.slide.offset * 0.45) / absX,
				(dirSign * size * valueAttrs.slide.offset) / absY
			)
			local startRot = dirSign * valueAttrs.slide.rot
			local reversing = onClear and true or false

			local function stop()
				util.removeEntryFromTransformUpdater(obj, printerData, name)
				charScale.Scale = 1
				updater[updaterId] = nil
			end

			util.addEntryToTransformUpdater(obj, printerData, name)

			updater[updaterId] = function()
				debug.profilebegin("Slide Animation Markup")
				local time_ = os.clock()
				if not onClear and attrs.loop then
					local dur = math.max(0.15, attrs.dur)
					local phase = (time_ / dur) * math.pi * 2 - charIndex * 0.42
					local wave = math.sin(phase)
					local lift = (wave * 0.5 + 0.5)
					printerData.position += Vector2.new(
						startPos.X * math.cos(phase) * 0.55,
						startPos.Y * wave * 0.65
					)
					printerData.rotation += startRot * math.sin(phase) * 0.55
					charScale.Scale = 1 + (1 - lift) * 0.06
				else
					local n = math.clamp((time_ - startTime) / math.max(0.05, attrs.dur), 0, 1)
					local alpha = TweenService:GetValue(
						reversing and 1 - n or n,
						Enum.EasingStyle.Quint,
						Enum.EasingDirection.Out
					)
					printerData.position += startPos:Lerp(Vector2.zero, alpha)
					printerData.rotation += startRot * (1 - alpha)
					if not onClear and n == 1 then
						stop()
					end
				end
				debug.profileend()
			end

			local connection = not onClear and obj.onRenderEnded:Once(function(stopped : boolean?)
				if stopped and not attrs.loop then
					stop()
				end
			end)
			obj._contentFolder.Destroying:Once(function()
				stop()
				if connection then
					connection:Disconnect()
				end
			end)
		elseif value == "bounce" then
			local updaterId = HttpService:GenerateGUID()
			local parentGui = printerData.character.Parent :: GuiObject
			local absY = math.max(1, parentGui.AbsoluteSize.Y)
			local dirSign = if valueAttrs.bounce.dir == "down" then -1 else 1
			local ampY = (dirSign * size * valueAttrs.bounce.offset) / absY
			local exp = math.max(0.5, valueAttrs.bounce.exp)
			local reversing = onClear and true or false

			local function stop()
				util.removeEntryFromTransformUpdater(obj, printerData, name)
				charScale.Scale = 1
				updater[updaterId] = nil
			end

			util.addEntryToTransformUpdater(obj, printerData, name)

			updater[updaterId] = function()
				debug.profilebegin("Bounce Animation Markup")
				local time_ = os.clock()
				if not onClear and attrs.loop then
					local dur = math.max(0.18, attrs.dur)
					local cycle = ((time_ / dur) - charIndex * 0.11) % 1
					local arc = math.abs(math.sin(cycle * math.pi)) ^ (1 / math.clamp(exp, 0.7, 2.4))
					printerData.position += Vector2.new(0, -math.abs(ampY) * arc * 0.75)
					printerData.rotation += math.sin(cycle * math.pi * 2) * 2.2
					charScale.Scale = 1 + (arc - 0.35) * 0.09
				else
					local n = math.clamp((time_ - startTime) / math.max(0.05, attrs.dur), 0, 1)
					local alpha = TweenService:GetValue(
						reversing and 1 - n or n,
						Enum.EasingStyle.Bounce,
						Enum.EasingDirection.Out
					) ^ exp
					printerData.position += Vector2.new(0, ampY * (1 - alpha))
					if not onClear and n == 1 then
						stop()
					end
				end
				debug.profileend()
			end

			local connection = not onClear and obj.onRenderEnded:Once(function(stopped : boolean?)
				if stopped and not attrs.loop then
					stop()
				end
			end)
			obj._contentFolder.Destroying:Once(function()
				stop()
				if connection then
					connection:Disconnect()
				end
			end)
		elseif value == "wiggle" then
			local updaterId = HttpService:GenerateGUID()

			local function stop()
				util.removeEntryFromTransformUpdater(obj, printerData, name)
				charScale.Scale = 1
				updater[updaterId] = nil
			end

			util.addEntryToTransformUpdater(obj, printerData, name)

			updater[updaterId] = function()
				debug.profilebegin("Wiggle Animation Markup")
				local time_ = os.clock()
				local elapsed = time_ - startTime
				if onClear or attrs.loop or attrs.dur ~= 0 then
					local wiggle = valueAttrs.wiggle
					local x = (time_ * wiggle.freq * math.pi * 2)
						- (math.pi * 2 * wiggle.offset * charIndex)
					local fade = not onClear and attrs.loop
						and 1
						or math.clamp(1 - elapsed / math.max(0.05, attrs.dur), 0, 1)
					if onClear then
						fade = 1 - fade
					end
					local parentGui = printerData.character.Parent :: GuiObject
					local absY = math.max(1, parentGui.AbsoluteSize.Y)
					local absX = math.max(1, parentGui.AbsoluteSize.X)
					local charH = printerData.character.AbsoluteSize.Y
					local waveY = (math.sin(x) + 0.2 * math.sin(x * 2 + 0.6)) * fade * wiggle.amp * charH
					local waveX = math.cos(x) * fade * wiggle.amp * charH * 0.16
					local pos = Vector2.new(waveX / absX, waveY / absY)
					local n = math.clamp(elapsed / math.max(0.05, attrs.dur), 0, 1)
					if onClear then
						n = 1 - n
					end
					printerData.position += pos:Lerp(
						(onClear or not attrs.loop) and Vector2.zero or pos,
						n
					)
					charScale.Scale = 1 + math.sin(x) * 0.055 * fade
					if wiggle.rot then
						local phaseStep = math.pi * 2 * wiggle.offset
						local slopeY = math.cos(x) * phaseStep * fade * wiggle.amp * charH
						printerData.rotation += math.deg(math.atan2(slopeY, math.max(1, printerData.constructionDataRowEntry.width)))
					end
				end
				if elapsed >= attrs.dur and not onClear and not attrs.loop then
					stop()
				end
				debug.profileend()
			end

			local connection = not onClear and obj.onRenderEnded:Once(function(stopped : boolean?)
				if stopped and not attrs.loop then
					stop()
				end
			end)
			obj._contentFolder.Destroying:Once(function()
				stop()
				if connection then
					connection:Disconnect()
				end
			end)
		elseif value == "grow" then
			local updaterId = HttpService:GenerateGUID()
			local reversing = onClear and true or false

			local function stop()
				util.removeEntryFromTransformUpdater(obj, printerData, name)
				charScale.Scale = 1
				updater[updaterId] = nil
			end

			util.addEntryToTransformUpdater(obj, printerData, name)

			updater[updaterId] = function()
				debug.profilebegin("Grow Animation Markup")
				local time_ = os.clock()
				if not onClear and attrs.loop then
					local dur = math.max(0.25, attrs.dur)
					local phase = (time_ / dur) * math.pi * 2 - charIndex * 0.36
					local wave = math.sin(phase) * 0.5 + 0.5
					local shaped = wave ^ math.clamp(valueAttrs.grow.exp * 0.65, 0.6, 2.2)
					local minS = math.clamp(valueAttrs.grow.startScale, 0.78, 0.96)
					local scale = minS + (1.08 - minS) * shaped
					charScale.Scale = scale
					printerData.position += Vector2.new(0, -(scale - 1) * 0.45)
					printerData.rotation += math.cos(phase) * 1.8
				else
					local n = math.clamp((time_ - startTime) / math.max(0.05, attrs.dur), 0, 1)
					n = reversing and 1 - n or n
					local landingPoint = 0.4
					local t = n / landingPoint - 1
					local overshoot = 1.70158
					local alpha = 1 + (overshoot + 1) * t ^ 3 + overshoot * t ^ 2
					if n > landingPoint then
						local t2 = (n - landingPoint) / (1 - landingPoint)
						alpha = 1 - math.sin(t2 * math.pi * 3) * 0.09 * ((1 - t2) ^ 2)
					end
					local scale = valueAttrs.grow.startScale
						+ (1 - valueAttrs.grow.startScale) * (alpha ^ math.clamp(valueAttrs.grow.exp, 0.5, 4))
					charScale.Scale = math.clamp(scale, 0.05, 1.5)
					if not onClear and n == 1 then
						stop()
					end
				end
				debug.profileend()
			end

			local connection = not onClear and obj.onRenderEnded:Once(function(stopped : boolean?)
				if stopped and not attrs.loop then
					stop()
				end
			end)
			obj._contentFolder.Destroying:Once(function()
				stop()
				if connection then
					connection:Disconnect()
				end
			end)
		elseif value == "orbit" then
			local updaterId = HttpService:GenerateGUID()
			local orbit = valueAttrs.orbit

			local function stop()
				util.removeEntryFromTransformUpdater(obj, printerData, name)
				charScale.Scale = 1
				updater[updaterId] = nil
			end

			util.addEntryToTransformUpdater(obj, printerData, name)

			updater[updaterId] = function()
				debug.profilebegin("Orbit Animation Markup")
				local time_ = os.clock()
				local phase = time_ * orbit.freq * math.pi * 2 - charIndex * orbit.offset * math.pi * 2
				local parentGui = printerData.character.Parent :: GuiObject
				local absX = math.max(1, parentGui.AbsoluteSize.X)
				local absY = math.max(1, parentGui.AbsoluteSize.Y)
				local charH = printerData.character.AbsoluteSize.Y
				local dx = math.cos(phase) * orbit.amp * charH * 0.55
				local dy = math.sin(phase * 2) * orbit.amp * charH * 0.75
				printerData.position += Vector2.new(dx / absX, dy / absY)
				charScale.Scale = 1 + math.sin(phase) * 0.065
				if orbit.rot then
					printerData.rotation += math.cos(phase) * 7.5
				end
				debug.profileend()
			end

			obj._contentFolder.Destroying:Once(stop)
		elseif value == "pendulum" then
			local updaterId = HttpService:GenerateGUID()
			local pend = valueAttrs.pendulum

			local function stop()
				util.removeEntryFromTransformUpdater(obj, printerData, name)
				charScale.Scale = 1
				updater[updaterId] = nil
			end

			util.addEntryToTransformUpdater(obj, printerData, name)

			updater[updaterId] = function()
				debug.profilebegin("Pendulum Animation Markup")
				local time_ = os.clock()
				local phase = time_ * pend.freq * math.pi * 2 - charIndex * pend.offset * math.pi * 2
				local swing = math.sin(phase)
				local parentGui = printerData.character.Parent :: GuiObject
				local absX = math.max(1, parentGui.AbsoluteSize.X)
				local absY = math.max(1, parentGui.AbsoluteSize.Y)
				local charH = printerData.character.AbsoluteSize.Y
				local dx = swing * pend.amp * charH * 0.45
				local dy = (1 - math.cos(swing * 0.85)) * pend.amp * charH * 1.1
				printerData.position += Vector2.new(dx / absX, dy / absY)
				printerData.rotation += swing * pend.rot
				charScale.Scale = 1 + (1 - math.abs(swing)) * 0.05
				debug.profileend()
			end

			obj._contentFolder.Destroying:Once(stop)
		elseif value == "spiral" then
			local updaterId = HttpService:GenerateGUID()
			local sp = valueAttrs.spiral

			local function stop()
				util.removeEntryFromTransformUpdater(obj, printerData, name)
				charScale.Scale = 1
				updater[updaterId] = nil
			end

			util.addEntryToTransformUpdater(obj, printerData, name)

			updater[updaterId] = function()
				debug.profilebegin("Spiral Animation Markup")
				local time_ = os.clock()
				local phase = time_ * sp.freq * math.pi * 2 - charIndex * sp.offset * math.pi * 2
				local envelope = 0.55 + 0.45 * math.sin(phase * 0.5)
				local parentGui = printerData.character.Parent :: GuiObject
				local absX = math.max(1, parentGui.AbsoluteSize.X)
				local absY = math.max(1, parentGui.AbsoluteSize.Y)
				local charH = printerData.character.AbsoluteSize.Y
				local dx = math.cos(phase) * sp.amp * charH * envelope * 0.55
				local dy = math.sin(phase) * sp.amp * charH * envelope * 0.75
				printerData.position += Vector2.new(dx / absX, dy / absY)
				printerData.rotation += math.sin(phase) * sp.rot * envelope
				charScale.Scale = 1 + math.cos(phase) * 0.075 * envelope
				debug.profileend()
			end

			obj._contentFolder.Destroying:Once(stop)
		elseif value == "pulsewave" then
			local updaterId = HttpService:GenerateGUID()
			local pw = valueAttrs.pulsewave

			local function stop()
				util.removeEntryFromTransformUpdater(obj, printerData, name)
				charScale.Scale = 1
				updater[updaterId] = nil
			end

			util.addEntryToTransformUpdater(obj, printerData, name)

			updater[updaterId] = function()
				debug.profilebegin("Pulsewave Animation Markup")
				local time_ = os.clock()
				local wavePhase = (time_ * pw.freq - charIndex * pw.offset) % 1
				local crest = math.exp(-((wavePhase - 0.25) / 0.16) ^ 2)
				local parentGui = printerData.character.Parent :: GuiObject
				local absY = math.max(1, parentGui.AbsoluteSize.Y)
				local charH = printerData.character.AbsoluteSize.Y
				local dy = -crest * pw.amp * charH
				printerData.position += Vector2.new(0, dy / absY)
				printerData.rotation += math.sin((wavePhase - 0.25) * math.pi * 2) * crest * pw.rot
				charScale.Scale = 1 + crest * 0.16
				debug.profileend()
			end

			obj._contentFolder.Destroying:Once(stop)
		end
	end
end