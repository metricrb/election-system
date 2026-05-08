--!strict

local Store = require(game:GetService("ServerScriptService").ElectionSystem.Modules.Store)

return function()
	describe("Store", function()
		it("serializes and deserializes vote records", function()
			local store = Store.new()
			store:recordVote("1", { { candidateId = "candidate_1" } }, 1, "district_a")
			local serialized = store:serialize()
			local restored = Store.new()
			restored:deserialize(serialized)
			expect(restored:getVoteRecord("1").districtId).to.equal("district_a")
		end)
	end)
end
