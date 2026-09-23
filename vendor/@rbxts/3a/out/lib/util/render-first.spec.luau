-- Compiled with roblox-ts v2.2.0
local TS = _G[script]
--/ <reference types="@rbxts/testez/globals" />
local RunService = TS.import(script, TS.getModule(script, "@rbxts", "services")).RunService
local RenderFirst = TS.import(script, script.Parent, "render-first").RenderFirst
return function()
	describe("RenderFirst should", function()
		it("Run callbacks in ascending order", function()
			local thing = 0
			local worked1 = false
			local worked2 = false
			local worked3 = false
			RenderFirst.bindAt(1, function()
				worked1 = thing == 0
				thing = 1
			end)
			RenderFirst.bindAt(4, function()
				worked2 = thing == 1
				thing = 2
			end)
			RenderFirst.bindAt(7, function()
				worked3 = thing == 2
				thing = 3
			end)
			RunService.PreRender:Wait()
			RunService.PostSimulation:Wait()
			expect(worked1)
			expect(worked2)
			expect(worked3)
			expect(thing == 3)
		end)
	end)
end
