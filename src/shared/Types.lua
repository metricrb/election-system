--!strict

--[[
	Universal election system type definitions.

	All exported types are used throughout the election system for type checking
	and runtime validation.
]]

-- Error information
export type Error = {
	type: string,
	raw: string,
	message: string,
	trace: string
}

-- Election phases
export type ElectionPhase = "Scheduled" | "Open" | "Closed" | "ResultsOut" | "Coalition" | "Formed"

-- Voting methods
export type VotingMethod = "FPTP" | "TwoRound" | "IRV" | "Approval" | "Score" | "STAR" | "STV" | "PartyListPR" | "MMP" | "Parallel" | "Condorcet" | "Borda" | "Cumulative" | "Sortition"

-- Government types
export type GovernmentType = "Presidential" | "Parliamentary" | "SemiPresidential" | "ConstitutionalMonarchy"

-- Seat system types
export type SeatSystem = "SingleMemberDistrict" | "MultiMemberDistrict" | "AtLarge" | "Federal"

-- Apportionment methods for multi-seat allocation
export type ApportionmentMethod = "DHondt" | "SainteLague" | "HareNiemeyer"

-- Alt detection heuristics
export type AltHeuristic = "age" | "rapid" | "both"

-- Party definition
export type Party = {
	partyId: string,
	name: string,
	decalId: number,
	colour: { r: number, g: number, b: number },
	description: string,
}

-- Candidate definition
export type Candidate = {
	candidateId: string,
	userId: string,
	partyId: string?,
	name: string,
	bio: string,
	policyTags: { string },
}

-- District definition
export type District = {
	districtId: string,
	name: string,
	seats: number,
}

-- Eligibility configuration
export type EligibilityConfig = {
	minGroupRank: { groupId: number, minRank: number },
	minAccountAgeDays: number,
	bannedGroupIds: { number },
	bannedUsernames: { string },
}

-- Alt detection configuration
export type AltDetectionConfig = {
	enabled: boolean,
	onDetect: "KickWithScreen" | "InvalidateVote",
	heuristic: AltHeuristic,
	kickDelaySeconds: number,
	banDuration: number,
	banReason: string,
	rapidVoteThresholdSeconds: number,
}

-- CMDR configuration
export type CmdrConfig = {
	adminGroupId: number,
	adminMinRank: number,
}

-- UI configuration
export type UiConfig = {
	placeholderAvatarId: string,
	accentColour: { r: number, g: number, b: number },
	electionTitle: string,
}

-- Master election configuration
export type ElectionConfig = {
	-- Change each Studio run when batch-testing (see Settings header); echoed in server prints.
	testRunId: string?,
	countryId: string,
	votingMethod: VotingMethod,
	governmentType: GovernmentType,
	seatSystem: SeatSystem,
	seats: number,
	threshold: number,
	runoffThreshold: number,
	compulsoryVoting: boolean,
	electoralCollege: boolean,
	seatAllocationMethod: ApportionmentMethod,

	openAt: number,
	closeAt: number,

	-- When true, removes this player's persisted + in-memory vote on join so they can vote again (Studio / QA). **Never use in production live elections.**
	clearPlayerVoteOnJoin: boolean,

	eligibility: EligibilityConfig,
	altDetection: AltDetectionConfig,

	parties: { Party },
	candidates: { Candidate },
	districts: { District },

	cmdr: CmdrConfig,
	ui: UiConfig,
}

-- Ballot entry (varies by voting method)
export type BallotEntry = {
	candidateId: string,
	rank: number?,      -- for ranked methods (IRV, STV, Borda)
	score: number?,     -- for scored methods (Score, STAR, Cumulative)
	approved: boolean?, -- for approval method
}

export type Ballot = { BallotEntry }

-- Vote record
export type VoteRecord = {
	userId: string,
	ballot: Ballot,
	timestamp: number,
	roundId: number?,
	partyVote: string?, -- for party-based methods (PR, MMP)
	districtId: string?,
}

-- Winner result from a voting method
export type WinnerResult = {
	winner: Candidate | { Candidate },  -- single winner or multiple
	voteShare: { [string]: number },     -- candidateId -> percentage
	roundHistory: { any }?,              -- for multi-round methods
}

-- Seat allocation result
export type SeatAllocation = {
	[string]: {
		seats: number,
		candidates: { Candidate },
	}
}

-- Full election result
export type ElectionResult = {
	phase: ElectionPhase,
	votesRecorded: number,
	eligibleVoters: number,

	winner: Candidate | { Candidate },
	voteShare: { [string]: number },

	seats: SeatAllocation?,
	coalition: { partyId: string }?,

	roundHistory: { any }?,
	calculatedAt: number,
}

-- Eligibility check result
export type EligibilityResult = {
	eligible: boolean,
	reason: string,
}

-- Alt detection result
export type AltFlagResult = {
	flagged: boolean,
	reason: string,
	shouldKick: boolean,
	shouldInvalidate: boolean,
}

-- Ballot template for UI
export type BallotTemplate = {
	votingMethod: VotingMethod,
	candidates: { Candidate },
	parties: { Party },
	maxSelections: number,
	minSelections: number,
	allowRanking: boolean,
	allowScoring: boolean,
	allowApproval: boolean,
	scoreRange: { min: number, max: number }?,
	dualBallot: boolean,  -- for MMP, Parallel
	partyBallot: { Party }?,  -- for party-based methods
}

return nil
