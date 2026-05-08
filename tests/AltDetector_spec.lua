--!strict

local AltDetector = require(game:GetService("ServerScriptService").ElectionSystem.Modules.AltDetector)
local Store = require(game:GetService("ServerScriptService").ElectionSystem.Modules.Store)

return function()
	describe("AltDetector", function()
		it("returns a structured result", function()
			local store = Store.new()
			local fakePlayer = { AccountAge = 999, Name = "Tester" }
			local result = AltDetector.detect(store, "123", fakePlayer :: any)
			expect(type(result.flagged)).to.equal("boolean")
			expect(type(result.reason)).to.equal("string")
		end)
	end)
end
