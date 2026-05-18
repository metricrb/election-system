--!strict

--[=[
	@class Settings

	Master election configuration file. Edit this once to configure your election.
	This is the ONLY file a developer needs to modify to set up an election.
]=]

local Types = require(script.Parent.shared.Types)

--[[
	How to use this file:
	1) Replace every example value below with your real election data.
	2) Keep keys unchanged (strict typing depends on exact names).
	3) Times are Unix timestamps in seconds (UTC), not milliseconds.
]]
local Settings: Types.ElectionConfig = {

	-- ELECTION METADATA
	countryId = "nation",
	votingMethod = "FPTP",
	twoRoundStyle = "Classic",
	governmentType = "Presidential",
	seatSystem = "SingleMemberDistrict",
	seats = 1,
	threshold = 0,
	runoffThreshold = 50,
	compulsoryVoting = false,
	electoralCollege = false,
	seatAllocationMethod = "DHondt",

	-- TIMESTAMPS (Unix seconds, UTC)
	openAt = os.time() - 60,
	closeAt = os.time() + 86400,

	clearPlayerVoteOnJoin = false,
	allowVoteReplacement = false,

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
		banReason = "Election fraud: alternative account detected.",
		rapidVoteThresholdSeconds = 60,
	},

	parties = {
		{
			partyId = "party_alpha",
			name = "Alpha Party",
			decalId = 0,
			colour = { r = 50, g = 100, b = 200 },
			description = "Example party A",
		},
		{
			partyId = "party_beta",
			name = "Beta Party",
			decalId = 0,
			colour = { r = 200, g = 80, b = 60 },
			description = "Example party B",
		},
		{
			partyId = "party_indep",
			name = "Independent",
			decalId = 0,
			colour = { r = 95, g = 98, b = 110 },
			description = "",
		},
	},

	candidates = {
		{
			candidateId = "alice_north",
			userId = "0",
			partyId = "party_alpha",
			name = "Alice",
			bio = "Candidate for North District.",
			policyTags = { "constituency:district_north" },
		},
		{
			candidateId = "bob_north",
			userId = "0",
			partyId = "party_beta",
			name = "Bob",
			bio = "Also standing in North District.",
			policyTags = { "constituency:district_north" },
		},
		{
			candidateId = "carol_south",
			userId = "0",
			partyId = "party_alpha",
			name = "Carol",
			bio = "Candidate for South District.",
			policyTags = { "constituency:district_south" },
		},
		{
			candidateId = "dave_south",
			userId = "0",
			partyId = "party_indep",
			name = "Dave",
			bio = "Independent candidate for South District.",
			policyTags = { "constituency:district_south" },
		},
	},

	districts = {
		{ districtId = "district_north", name = "North District", seats = 1 },
		{ districtId = "district_south", name = "South District", seats = 1 },
	},

	registeredVotersByDistrict = {
		district_north = 100,
		district_south = 100,
	},

	globalVoteLedger = {
		enabled = true,
		dataStoreName = "ElectionGlobalVotes",
	},

	cmdr = {
		adminGroupId = 0,
		adminMinRank = 255,
	},

	discord = {
		enabled = false,
		webhookUrl = "",
		botUsername = "ElectionNotifier",
		notifyVoteRecorded = true,
		notifyVoteDenied = true,
		notifyAltFlag = true,
		notifyPhaseChanges = false,
	},

	ui = {
		placeholderAvatarId = "rbxassetid://0",
		accentColour = { r = 50, g = 100, b = 200 },
		electionTitle = "General Election",
	},
}

return Settings
