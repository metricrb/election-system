--!strict

--[[
	@class Settings
	@within ElectionSystem

	Master election configuration file. Edit this once to configure your election.
	This is the ONLY file a developer needs to modify to set up an election.
]]

local Types = require(script.Parent.shared.Types)

local Settings: Types.ElectionConfig = {

	-- ELECTION METADATA
	countryId = "nation",
	votingMethod = "FPTP",
	governmentType = "Presidential",
	seatSystem = "SingleMemberDistrict",
	seats = 1,
	threshold = 0,
	runoffThreshold = 50,
	compulsoryVoting = false,
	electoralCollege = false,
	seatAllocationMethod = "DHondt",

	-- TIMESTAMPS (Unix)
	openAt = 0,
	closeAt = 0,

	-- ELIGIBILITY
	eligibility = {
		minGroupRank = { groupId = 0, minRank = 0 },
		minAccountAgeDays = 0,
		bannedGroupIds = {},
		bannedUsernames = {},
	},

	-- ALT DETECTION
	altDetection = {
		enabled = false,
		onDetect = "KickWithScreen",
		heuristic = "age",
		kickDelaySeconds = 5,
		banDuration = -1,
		banReason = "Election fraud: alternative account detected.",
		rapidVoteThresholdSeconds = 60,
	},

	-- PARTIES
	parties = {
		{
			partyId = "party_a",
			name = "Example Party",
			decalId = 0,
			colour = { r = 220, g = 36, b = 36 },
			description = "",
		},
	},

	-- CANDIDATES
	candidates = {
		{
			candidateId = "candidate_1",
			userId = "0",
			partyId = "party_a",
			name = "",
			bio = "",
			policyTags = {},
		},
	},

	-- DISTRICTS (optional)
	districts = {},

	-- CMDR ADMIN
	cmdr = {
		adminGroupId = 0,
		adminMinRank = 255,
	},

	-- UI
	ui = {
		placeholderAvatarId = "rbxassetid://0",
		accentColour = { r = 50, g = 100, b = 200 },
		electionTitle = "General Election",
	},
}

return Settings
