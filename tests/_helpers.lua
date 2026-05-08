--!strict

local Types = require(game:GetService("ServerScriptService").ElectionSystem.Modules.Types)

local function makeConfig(method: Types.VotingMethod): Types.ElectionConfig
	return {
		countryId = "test",
		votingMethod = method,
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
		eligibility = { minGroupRank = { groupId = 0, minRank = 0 }, minAccountAgeDays = 0, bannedGroupIds = {}, bannedUsernames = {} },
		altDetection = { enabled = false, onDetect = "KickWithScreen", heuristic = "age", kickDelaySeconds = 5, banDuration = -1, banReason = "", rapidVoteThresholdSeconds = 60 },
		parties = { { partyId = "party_a", name = "A", decalId = 0, colour = { r = 0, g = 0, b = 0 }, description = "" } },
		candidates = {
			{ candidateId = "candidate_1", userId = "1", partyId = "party_a", name = "A", bio = "", policyTags = {} },
			{ candidateId = "candidate_2", userId = "2", partyId = "party_a", name = "B", bio = "", policyTags = {} },
			{ candidateId = "candidate_3", userId = "3", partyId = "party_a", name = "C", bio = "", policyTags = {} },
		},
		districts = {},
		cmdr = { adminGroupId = 0, adminMinRank = 255 },
		ui = { placeholderAvatarId = "", accentColour = { r = 0, g = 0, b = 0 }, electionTitle = "" },
	}
end

return makeConfig
