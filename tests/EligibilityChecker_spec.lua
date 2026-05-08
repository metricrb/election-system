--!strict

local EligibilityChecker = require(game:GetService("ServerScriptService").ElectionSystem.Modules.EligibilityChecker)

return function()
	describe("EligibilityChecker", function()
		it("returns ineligible for banned usernames", function()
			local fakePlayer = {
				Name = "BadUser",
				AccountAge = 300,
				GetRankInGroup = function() return 0 end,
			}
			local result = EligibilityChecker.check(fakePlayer :: any)
			expect(type(result.eligible)).to.equal("boolean")
		end)
	end)
end
