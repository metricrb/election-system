--!strict

local makeConfig = require(script.Parent._helpers)
local methods = {
	"FPTP", "TwoRound", "IRV", "Approval", "Score", "STAR", "STV", "PartyListPR", "MMP", "Parallel", "Condorcet", "Borda", "Cumulative", "Sortition",
}

return function()
	describe("VotingMethods", function()
		for _, methodName in ipairs(methods) do
			it("runs " .. methodName .. " without errors", function()
				local module = require(game:GetService("ServerScriptService").ElectionSystem.Modules.VotingMethods[methodName])
				local config = makeConfig(methodName)
			local ballots = if methodName == "TwoRound" or methodName == "IRV" or methodName == "Condorcet" or methodName == "Borda"
				then
					{
						{
							{ candidateId = "candidate_1", rank = 1 },
							{ candidateId = "candidate_2", rank = 2 },
							{ candidateId = "candidate_3", rank = 3 },
						},
						{
							{ candidateId = "candidate_2", rank = 1 },
							{ candidateId = "candidate_3", rank = 2 },
							{ candidateId = "candidate_1", rank = 3 },
						},
						{
							{ candidateId = "candidate_1", rank = 1 },
							{ candidateId = "candidate_3", rank = 2 },
							{ candidateId = "candidate_2", rank = 3 },
						},
					}
				else {
					{ { candidateId = "candidate_1", rank = 1, score = 5, approved = true } },
					{ { candidateId = "candidate_2", rank = 1, score = 3, approved = true } },
					{ { candidateId = "candidate_1", rank = 1, score = 4, approved = true } },
				}
				local result = module.calculateWinner(ballots, config)
				expect(result).never.to.equal(nil)
				expect(result.winner).never.to.equal(nil)
				local validation = module.validateBallot(ballots[1], config)
				expect(validation.valid).to.equal(true)
			end)
		end
	end)
end
