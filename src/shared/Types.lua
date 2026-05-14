--!strict

--[[
	Type definitions for the election system.

	This module exports all types used throughout ElectionSystem for type checking, validation,
	and API documentation. All client code should import Types for proper type annotations.

	Key types:
	- ElectionPhase — Current election state
	- VotingMethod — Counting algorithm selection
	- Candidate/Party — Election participants
	- Ballot/VoteRecord — Voting data structures
	- ElectionResult — Calculated outcomes
]]

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

-- Discord webhook (server-only admin log channel; webhook URL never sent to clients)
export type DiscordWebhookConfig = {
	enabled: boolean,
	webhookUrl: string,
	botUsername: string,
	notifyVoteRecorded: boolean,
	notifyVoteDenied: boolean,
	notifyAltFlag: boolean,
	notifyPhaseChanges: boolean,
}

-- UI configuration
export type UiConfig = {
	placeholderAvatarId: string,
	accentColour: { r: number, g: number, b: number },
	electionTitle: string,
}

-- Master election configuration
export type ElectionConfig = {
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

	clearPlayerVoteOnJoin: boolean,

	eligibility: EligibilityConfig,
	altDetection: AltDetectionConfig,

	parties: { Party },
	candidates: { Candidate },
	districts: { District },

	cmdr: CmdrConfig,
	discord: DiscordWebhookConfig,
	ui: UiConfig,
}

-- Ballot entry (varies by voting method)
export type BallotEntry = {
	candidateId: string,
	rank: number?,
	score: number?,
	approved: boolean?,
}

export type Ballot = { BallotEntry }

-- Vote record
export type VoteRecord = {
	userId: string,
	ballot: Ballot,
	timestamp: number,
	roundId: number?,
	partyVote: string?,
	districtId: string?,
}

-- Winner result from a voting method
export type WinnerResult = {
	winner: Candidate | { Candidate },
	voteShare: { [string]: number },
	roundHistory: { any }?,
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
	dualBallot: boolean,
	partyBallot: { Party }?,
}

return nil
