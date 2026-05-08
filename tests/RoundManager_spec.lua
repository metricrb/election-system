--!strict

local RoundManager = require(game:GetService("ServerScriptService").ElectionSystem.Modules.RoundManager)
local Store = require(game:GetService("ServerScriptService").ElectionSystem.Modules.Store)

return function()
	describe("RoundManager", function()
		it("increments rounds and eliminates candidate", function()
			local store = Store.new()
			expect(RoundManager.initRound(store)).to.equal(1)
			local ballots = { { { candidateId = "a" } }, { { candidateId = "b" } } }
			local updated = RoundManager.eliminateCandidate("a", ballots)
			expect(#updated[1]).to.equal(0)
		end)
	end)
end
