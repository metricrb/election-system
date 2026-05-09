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

	--[[
		MCP / Studio batch test protocol
		-------------------------
		1) Edit **both** `testRunId` and `countryId` so each run is unique in the Output window.
		2) Save → Rojo sync → **quit & reopen Studio once** (fresh DataModel / server) after changes on disk.
		3) Single-ballot matrix: keep `votingMethod` **out of** `"MMP"` and `"Parallel"` (dual UI). Test those in a separate pass.
		4) Rotate through: FPTP, TwoRound, IRV, Approval, Score, STAR, STV, PartyListPR, Condorcet, Borda, Cumulative, Sortition
		   (Some methods need UI your client does not implement — watch `BALLOT_INVALID` prints.)
		5) “Ban API” here = eligibility only (no Roblox BanService): use `bannedUsernames`, `bannedGroupIds`, `minAccountAgeDays`, `altDetection.enabled`.
		6) Duplicate vote: submit twice → `DUPLICATE_VOTE (dual voting not permitted)`.

		Prefix in Output: `[ElectionSystem:<testRunId or countryId>]`
	]]

	-- Identifiers (change every run — new `countryId` = separate saved votes in ProfileService)
	testRunId = "retest-003-20260508",
	countryId = "sandbox_election_sess_003",

	-- ELECTION METADATA
	votingMethod = "IRV", -- Retest rotation (was FPTP): still works with single pick + rank in UI
	governmentType = "Presidential", -- Retest: distinct from Parliamentary
	seatSystem = "MultiMemberDistrict", -- Multiple seats
	seats = 8, -- 8 parliamentary seats
	threshold = 5, -- 5% threshold for seat allocation
	runoffThreshold = 50, -- Not used in MMP but kept for config structure
	compulsoryVoting = false,
	electoralCollege = false,
	seatAllocationMethod = "DHondt", -- D'Hondt apportionment (Europe standard)

	-- TIMESTAMPS (Unix seconds, UTC)
	-- **Voting open:** `now >= openAt` and `now < closeAt` ⇒ phase `Open`. To close: set `closeAt` in the past.
	openAt = os.time() - 60, -- Opened 1 minute ago
	closeAt = os.time() + 86400, -- Closes in 24 hours

	-- **Studio / QA only:** wipe this player's saved vote every join so you can vote again without Cmdr reset.
	-- Set **false** for any real election (live game).
	clearPlayerVoteOnJoin = false,

	-- ELIGIBILITY (PLAYTEST: groupId 0 skips group check; minAccountAgeDays 0 skips age)
	eligibility = {
		minGroupRank = { groupId = 0, minRank = 1 }, -- Set groupId to 7412080 + minRank 1 for production RoAntarctica gate
		minAccountAgeDays = 0, -- Set to 7 for production minimum account age
		bannedGroupIds = {}, -- No ban groups for this election
		bannedUsernames = {}, -- No username bans
	},

	-- ALT DETECTION
	altDetection = {
		enabled = true, -- Set true for production; false avoids false positives during rapid Studio playtests
		onDetect = "InvalidateVote", -- Silently remove suspect votes
		heuristic = "both", -- Check both account age AND rapid voting
		kickDelaySeconds = 5,
		banDuration = -1, -- Not used with InvalidateVote but kept
		banReason = "Election integrity: account flagged for suspicious activity.",
		rapidVoteThresholdSeconds = 120, -- Flag if votes within 2 minutes
	},

	-- PARTIES: 4-party system for realistic parliamentary dynamics
	parties = {
		{
			partyId = "explorers_union",
			name = "Explorers Union",
			decalId = 0, -- Replace with actual party logo decal ID
			colour = { r = 220, g = 36, b = 36 }, -- Red
			description = "Focused on Antarctic research and discovery expansion",
		},
		{
			partyId = "conservation_party",
			name = "Conservation Party",
			decalId = 0,
			colour = { r = 34, g = 139, b = 34 }, -- Green
			description = "Environmental protection and habitat preservation",
		},
		{
			partyId = "development_bloc",
			name = "Development Bloc",
			decalId = 0,
			colour = { r = 0, g = 102, b = 204 }, -- Blue
			description = "Infrastructure growth and economic development",
		},
		{
			partyId = "harmony_independent",
			name = "Harmony Independent",
			decalId = 0,
			colour = { r = 255, g = 140, b = 0 }, -- Orange
			description = "Community-focused and pragmatic independents",
		},
	},

	-- CANDIDATES: 16 candidates (4 per party) for 8 seats
	candidates = {
		-- Explorers Union (4 candidates)
		{
			candidateId = "eu_lead",
			userId = "0", -- Replace with actual Roblox UserIds
			partyId = "explorers_union",
			name = "M_etrics",
			bio = "Chief expedition planner, 5+ years Antarctic leadership experience",
			policyTags = { "Research", "Exploration", "Science" },
		},
		{
			candidateId = "eu_tech",
			userId = "0",
			partyId = "explorers_union",
			name = "Nova Snowpeak",
			bio = "Technology coordinator, advocates for research infrastructure",
			policyTags = { "Tech", "Innovation", "Research" },
		},
		{
			candidateId = "eu_diplomacy",
			userId = "0",
			partyId = "explorers_union",
			name = "Glacier Morgan",
			bio = "International relations specialist",
			policyTags = { "Diplomacy", "Cooperation", "Expansion" },
		},
		{
			candidateId = "eu_youth",
			userId = "0",
			partyId = "explorers_union",
			name = "Ember Frostwell",
			bio = "Youth engagement officer",
			policyTags = { "Youth", "Community", "Growth" },
		},

		-- Conservation Party (4 candidates)
		{
			candidateId = "cp_chair",
			userId = "0",
			partyId = "conservation_party",
			name = "Iris Tundra",
			bio = "Environmental biologist, conservation parliament veteran",
			policyTags = { "Environment", "Protection", "Sustainability" },
		},
		{
			candidateId = "cp_habitat",
			userId = "0",
			partyId = "conservation_party",
			name = "Zephyr Snowedge",
			bio = "Habitat restoration specialist",
			policyTags = { "Wildlife", "Restoration", "Climate" },
		},
		{
			candidateId = "cp_policy",
			userId = "0",
			partyId = "conservation_party",
			name = "Echo Crystal",
			bio = "Environmental policy advocate",
			policyTags = { "Policy", "Regulation", "Responsibility" },
		},
		{
			candidateId = "cp_community",
			userId = "0",
			partyId = "conservation_party",
			name = "Aurora Greenwhite",
			bio = "Community environmental educator",
			policyTags = { "Education", "Awareness", "Community" },
		},

		-- Development Bloc (4 candidates)
		{
			candidateId = "db_chief",
			userId = "0",
			partyId = "development_bloc",
			name = "Victor Buildstone",
			bio = "Infrastructure architect, pro-growth policies",
			policyTags = { "Development", "Infrastructure", "Growth" },
		},
		{
			candidateId = "db_commerce",
			userId = "0",
			partyId = "development_bloc",
			name = "Commodore Tradewise",
			bio = "Commerce and trade minister candidate",
			policyTags = { "Economy", "Trade", "Commerce" },
		},
		{
			candidateId = "db_tech",
			userId = "0",
			partyId = "development_bloc",
			name = "Cyborg Frostbyte",
			bio = "Technology and industrialization advocate",
			policyTags = { "Technology", "Industry", "Efficiency" },
		},
		{
			candidateId = "db_logistics",
			userId = "0",
			partyId = "development_bloc",
			name = "Tracker Pathfinder",
			bio = "Logistics and transportation coordinator",
			policyTags = { "Logistics", "Transport", "Efficiency" },
		},

		-- Harmony Independent (4 candidates)
		{
			candidateId = "hi_founder",
			userId = "0",
			partyId = "harmony_independent",
			name = "Serenity Peaks",
			bio = "Independent voices candidate, coalition-builder",
			policyTags = { "Harmony", "Balance", "Cooperation" },
		},
		{
			candidateId = "hi_advocate",
			userId = "0",
			partyId = "harmony_independent",
			name = "Beacon Lightbringer",
			bio = "Community advocate and mediator",
			policyTags = { "Community", "Mediation", "Dialogue" },
		},
		{
			candidateId = "hi_grassroots",
			userId = "0",
			partyId = "harmony_independent",
			name = "Summit Voiceofpeople",
			bio = "Grassroots community organizer",
			policyTags = { "Community", "Voice", "Participation" },
		},
		{
			candidateId = "hi_consensus",
			userId = "0",
			partyId = "harmony_independent",
			name = "Bridge Connector",
			bio = "Cross-party consensus builder",
			policyTags = { "Consensus", "Cooperation", "Unity" },
		},
	},

	-- DISTRICTS (empty for at-large MMP)
	districts = {},

	-- CMDR ADMIN: RoAntarctica admins (rank 200+)
	cmdr = {
		adminGroupId = 7412080, -- Only RoAntarctica admins
		adminMinRank = 5, -- Admin+ rank required
	},

	-- UI
	ui = {
		placeholderAvatarId = "rbxassetid://6032863815", -- Roblox default avatar
		accentColour = { r = 100, g = 149, b = 237 }, -- Cornflower blue (Antarctic theme)
		electionTitle = "Sandbox Election — Retest 003 (IRV · Presidential)",
	},
}

return Settings
