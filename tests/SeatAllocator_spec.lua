--!strict

local SeatAllocator = require(game:GetService("ServerScriptService").ElectionSystem.Modules.SeatAllocator)

return function()
	describe("SeatAllocator", function()
		it("allocates exact seat count", function()
			local seats = SeatAllocator.allocate({ party_a = 1000, party_b = 750, party_c = 250 }, 10)
			local total = 0
			for _, value in pairs(seats) do
				total += value
			end
			expect(total).to.equal(10)
		end)
	end)
end
