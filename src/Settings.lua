--!strict

--[[
	@class Settings
	@within ElectionSystem

	Master election configuration file. Edit this once to configure your election.
	This is the ONLY file a developer needs to modify to set up an election.
]]

local Types = require(script.Parent.shared.Types)

--[[
	How to use this file:
	1) Replace every example value below with your real election data.
	2) Keep keys unchanged (strict typing depends on exact names).
	3) Times are Unix timestamps in seconds (UTC), not milliseconds.
]]
local Settings: Types.ElectionConfig = {

	-- ELECTION METADATA
	countryId = "nation", -- Unique identifier for this election config/profile bucket (example: "uk_2026")
	votingMethod = "FPTP", -- One of: FPTP, TwoRound, IRV, Approval, Score, STAR, STV, PartyListPR, MMP, Parallel, Condorcet, Borda, Cumulative, Sortition
	governmentType = "Presidential", -- One of: Presidential, Parliamentary, SemiPresidential, ConstitutionalMonarchy
	seatSystem = "SingleMemberDistrict", -- One of: SingleMemberDistrict, MultiMemberDistrict, AtLarge, Federal
	seats = 1, -- Number of seats to fill (use >1 for PR/STV/MMP/Parallel style elections)
	threshold = 0, -- Percent threshold for parties/candidates where applicable (example: 5 means 5%)
	runoffThreshold = 50, -- Percent needed to avoid runoff in TwoRound systems
	compulsoryVoting = false, -- If true, your gameplay layer can enforce/track required voting
	electoralCollege = false, -- Toggle if you are modeling an electoral college layer
	seatAllocationMethod = "DHondt", -- One of: DHondt, SainteLague, HareNiemeyer (used in seat allocation flows)

	-- TIMESTAMPS (Unix seconds, UTC)
	openAt = 0, -- Voting start time (example: 1767225600)
	closeAt = 0, -- Voting end time (must be greater than openAt)

	-- ELIGIBILITY
	eligibility = {
		minGroupRank = { groupId = 0, minRank = 0 }, -- Set groupId > 0 to enable; player rank must be >= minRank
		minAccountAgeDays = 0, -- Minimum Roblox account age in days; set 0 to disable
		bannedGroupIds = {}, -- Any membership in these groups blocks voting (example: {123456, 654321})
		bannedUsernames = {}, -- Exact username blocklist, case-insensitive
	},

	-- ALT DETECTION
	altDetection = {
		enabled = false, -- Master toggle for post-vote alt checks
		onDetect = "KickWithScreen", -- One of: KickWithScreen, InvalidateVote
		heuristic = "age", -- One of: age, rapid, both
		kickDelaySeconds = 5, -- Delay before kick screen action resolves
		banDuration = -1, -- Ban duration in seconds if your ban path uses it; -1 commonly means permanent
		banReason = "Election fraud: alternative account detected.", -- Message shown/logged for moderation action
		rapidVoteThresholdSeconds = 60, -- If heuristic includes rapid: votes too close together are flagged
	},

	-- PARTIES
	parties = {
		{
			partyId = "party_a", -- Stable unique ID used by candidates and seat allocation
			name = "Example Party", -- Display name in UI/results
			decalId = 0, -- Roblox image asset id (number only, no "rbxassetid://" prefix)
			colour = { r = 220, g = 36, b = 36 }, -- RGB values 0-255 used for charts/cards
			description = "", -- Optional manifesto/description text
		},
	},

	-- CANDIDATES
	candidates = {
		{
			candidateId = "candidate_1", -- Stable unique ID referenced by ballots/results
			userId = "0", -- Roblox UserId as string (example: "12345678")
			partyId = "party_a", -- Set nil for independent candidates
			name = "", -- Display name
			bio = "", -- Candidate biography/summary
			policyTags = {}, -- Short labels (example: {"Economy", "Healthcare"})
		},
	},

	-- DISTRICTS (optional)
	districts = {}, -- Leave empty for non-district elections; otherwise fill with { districtId, name, seats }

	-- CMDR ADMIN
	cmdr = {
		adminGroupId = 0, -- Roblox group ID allowed to use election admin commands; 0 means no group restriction
		adminMinRank = 255, -- Minimum group rank required for command access
	},

	-- UI
	ui = {
		placeholderAvatarId = "rbxassetid://0", -- Fallback image when candidate avatar/image is unavailable
		accentColour = { r = 50, g = 100, b = 200 }, -- Global accent RGB for election UI
		electionTitle = "General Election", -- Main heading shown in client UI/results surfaces
	},
}

return Settings
