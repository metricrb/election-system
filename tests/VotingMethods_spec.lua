--!strict

local TestEZ = require(game:GetService("ReplicatedStorage").Packages.TestEZ)
local FPTP = require(game:GetService("ServerScriptService").ElectionSystem.Modules.VotingMethods.FPTP)
local Types = require(game:GetService("ServerScriptService").ElectionSystem.Modules.Types)

return function()
	describe("VotingMethods", function()
		describe("FPTP", function()
			it("should elect candidate with most votes", function()
				local ballots: { Types.Ballot } = {
					{ { candidateId = "candidate_1", rank = 1 } },
					{ { candidateId = "candidate_1", rank = 1 } },
					{ { candidateId = "candidate_2", rank = 1 } },
					{ { candidateId = "candidate_3", rank = 1 } },
				}

				local config: Types.ElectionConfig = {
					countryId = "test",
					votingMethod = "FPTP",
					governmentType = "Presidential",
					seatSystem = "SingleMemberDistrict",
					seats = 1,
					threshold = 0,
					runoffThreshold = 50,
					compulsoryVoting = false,
					electoralCollege = false,
					seatAllocationMethod = "DHondt",
					openAt = 0,
					closeAt = 0,
					eligibility = {
						minGroupRank = { groupId = 0, minRank = 0 },
						minAccountAgeDays = 0,
						bannedGroupIds = {},
						bannedUsernames = {},
					},
					altDetection = {
						enabled = false,
						onDetect = "KickWithScreen",
						heuristic = "age",
						kickDelaySeconds = 5,
						banDuration = -1,
						banReason = "",
						rapidVoteThresholdSeconds = 60,
					},
					parties = {},
					candidates = {
						{ candidateId = "candidate_1", userId = "1", partyId = nil, name = "Candidate 1", bio = "", policyTags = {} },
						{ candidateId = "candidate_2", userId = "2", partyId = nil, name = "Candidate 2", bio = "", policyTags = {} },
						{ candidateId = "candidate_3", userId = "3", partyId = nil, name = "Candidate 3", bio = "", policyTags = {} },
					},
					districts = {},
					cmdr = { adminGroupId = 0, adminMinRank = 255 },
					ui = { placeholderAvatarId = "", accentColour = { r = 0, g = 0, b = 0 }, electionTitle = "" },
				}

				local result = FPTP.calculateWinner(ballots, config)
				expect(result.winner.candidateId).to.equal("candidate_1")
			end)
		end)
	end)
end
