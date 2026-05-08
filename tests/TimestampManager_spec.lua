--!strict

local TimestampManager = require(game:GetService("ServerScriptService").ElectionSystem.Modules.TimestampManager)

return function()
	describe("TimestampManager", function()
		it("returns a valid phase", function()
			local manager = TimestampManager.new()
			local phase = manager:getPhase()
			expect(phase == "Scheduled" or phase == "Open" or phase == "ResultsOut" or phase == "Closed" or phase == "Coalition" or phase == "Formed").to.equal(true)
		end)
	end)
end
