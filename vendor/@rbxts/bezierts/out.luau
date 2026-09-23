-- Compiled with roblox-ts v3.0.0
local TS = _G[script]
local RunService = TS.import(script, TS.getModule(script, "@rbxts", "services")).RunService
local BezierCurve
do
	BezierCurve = setmetatable({}, {
		__tostring = function()
			return "BezierCurve"
		end,
	})
	BezierCurve.__index = BezierCurve
	function BezierCurve.new(...)
		local self = setmetatable({}, BezierCurve)
		return self:constructor(...) or self
	end
	function BezierCurve:constructor(duration, positions)
		self.p2 = nil
		self.p3 = nil
		self.t = 0
		self.duration = 1
		self.position = Vector3.zero
		self.connection = nil
		self.wantToStop = false
		self.p0 = positions.p0
		self.p1 = positions.p1
		self.p2 = positions.p2
		self.p3 = positions.p3
		self.duration = duration
		self.position = positions.p0
	end
	function BezierCurve:play(callback)
		if self.connection then
			return nil
		end
		self.t = 0
		self.connection = RunService.Heartbeat:Connect(function(dt)
			self.t = math.clamp(self.t + dt / self.duration, 0, 1)
			if not self.p2 and not self.p3 then
				local position = BezierCurve:linearBezier(self.t, self.p0, self.p1)
				self.position = position
			end
			if self.p2 and self.p3 then
				local position = BezierCurve:cubicBezier(self.t, self.p0, self.p1, self.p2, self.p3)
				self.position = position
			end
			if self.p2 and not self.p3 then
				local position = BezierCurve:quadraticBezier(self.t, self.p0, self.p1, self.p2)
				self.position = position
			end
			if self.t >= 1 or self.wantToStop then
				local _result = self.connection
				if _result ~= nil then
					_result:Disconnect()
				end
				self.connection = nil
				if self.wantToStop then
					if callback then
						callback(false)
					end
				else
					if callback then
						callback(true)
					end
				end
			end
		end)
	end
	function BezierCurve:stop()
		self.wantToStop = true
	end
	function BezierCurve:quadraticBezier(t, p0, p1, p2)
		local oneMinusT = 1 - t
		local _p0 = p0
		local _arg0 = oneMinusT * oneMinusT
		local _p1 = p1
		local _arg0_1 = 2 * oneMinusT * t
		local _p2 = p2
		local _arg0_2 = t * t
		return _p0 * _arg0 + (_p1 * _arg0_1) + (_p2 * _arg0_2)
	end
	function BezierCurve:linearBezier(t, p0, p1)
		local _p0 = p0
		local _arg0 = 1 - t
		local _p1 = p1
		local _t = t
		return _p0 * _arg0 + (_p1 * _t)
	end
	function BezierCurve:cubicBezier(t, p0, p1, p2, p3)
		local oneMinusT = 1 - t
		local _p0 = p0
		local _arg0 = oneMinusT ^ 3
		local _p1 = p1
		local _arg0_1 = 3 * oneMinusT ^ 2 * t
		local _p2 = p2
		local _arg0_2 = 3 * oneMinusT * t ^ 2
		local _p3 = p3
		local _arg0_3 = t ^ 3
		return _p0 * _arg0 + (_p1 * _arg0_1) + (_p2 * _arg0_2) + (_p3 * _arg0_3)
	end
end
local BezierPositions
do
	BezierPositions = setmetatable({}, {
		__tostring = function()
			return "BezierPositions"
		end,
	})
	BezierPositions.__index = BezierPositions
	function BezierPositions.new(...)
		local self = setmetatable({}, BezierPositions)
		return self:constructor(...) or self
	end
	function BezierPositions:constructor(p0, p1, p2, p3)
		self.p0 = p0
		self.p1 = p1
		self.p2 = p2
		self.p3 = p3
	end
end
return {
	BezierCurve = BezierCurve,
	BezierPositions = BezierPositions,
}
