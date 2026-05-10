--!strict

--[=[
	@module Types
	@tag Core API

	Type definitions for the election system.

	This module exports all types used throughout ElectionSystem for type checking, validation,
	and API documentation. All client code should import Types for proper type annotations.

	## Key Types

	- **ElectionPhase** — Current election state
	- **VotingMethod** — Counting algorithm selection
	- **Candidate/Party** — Election participants
	- **Ballot/VoteRecord** — Voting data structures
	- **ElectionResult** — Calculated outcomes

	## Configuration

	All election behavior is controlled via ElectionConfig, loaded from Settings.lua:
	- Voting method and government type
	- Eligibility and fraud detection rules
	- Candidates, parties, and districts
	- UI and administrative settings

	## Usage

	```lua
	local Types = require(game:GetService("ServerScriptService").ElectionManager).Types

	local ballot: Types.Ballot = {
		{ candidateId = "alice", rank = 1 },
		{ candidateId = "bob", rank = 2 },
	}
	```
]=]

--[=[
	@type ElectionPhase
	@within Types
	Possible election states: "Scheduled", "Open", "Closed", "ResultsOut", "Coalition", or "Formed"
]=]
export type ElectionPhase = "Scheduled" | "Open" | "Closed" | "ResultsOut" | "Coalition" | "Formed"

--[=[
	@type VotingMethod
	@within Types
	14 different voting/counting methods: FPTP, TwoRound, IRV, Approval, Score, STAR, STV,
	PartyListPR, MMP, Parallel, Condorcet, Borda, Cumulative, or Sortition
]=]
export type VotingMethod = "FPTP" | "TwoRound" | "IRV" | "Approval" | "Score" | "STAR" | "STV" | "PartyListPR" | "MMP" | "Parallel" | "Condorcet" | "Borda" | "Cumulative" | "Sortition"

--[=[
	@type GovernmentType
	@within Types
	Electoral system type: Presidential, Parliamentary, SemiPresidential, or ConstitutionalMonarchy
]=]
export type GovernmentType = "Presidential" | "Parliamentary" | "SemiPresidential" | "ConstitutionalMonarchy"

--[=[
	@type SeatSystem
	@within Types
	How seats are distributed: SingleMemberDistrict, MultiMemberDistrict, AtLarge, or Federal
]=]
export type SeatSystem = "SingleMemberDistrict" | "MultiMemberDistrict" | "AtLarge" | "Federal"

--[=[
	@type ApportionmentMethod
	@within Types
	Algorithm for multi-seat allocation: DHondt, SainteLague, or HareNiemeyer
]=]
export type ApportionmentMethod = "DHondt" | "SainteLague" | "HareNiemeyer"

--[=[
	@type AltHeuristic
	@within Types
	Alt detection method: "age" (account age), "rapid" (voting speed), or "both"
]=]
export type AltHeuristic = "age" | "rapid" | "both"

--[=[
	@type Party
	@within Types
	A political party in the election. Must set decalId (Roblox decal ID) and RGB color.
]=]
export type Party = {
	partyId: string,
	name: string,
	decalId: number,
	colour: { r: number, g: number, b: number },
	description: string,
}

--[=[
	@type Candidate
	@within Types
	A candidate running for office. Optional partyId for party-based voting methods.
]=]
export type Candidate = {
	candidateId: string,
	userId: string,
	partyId: string?,
	name: string,
	bio: string,
	policyTags: { string },
}

--[=[
	@type District
	@within Types
	A geographic or demographic district for district-based elections.
]=]
export type District = {
	districtId: string,
	name: string,
	seats: number,
}

--[=[
	@type EligibilityConfig
	@within Types
	Rules determining who can vote: group rank, account age, and ban lists.
]=]
export type EligibilityConfig = {
	minGroupRank: { groupId: number, minRank: number },
	minAccountAgeDays: number,
	bannedGroupIds: { number },
	bannedUsernames: { string },
}

--[=[
	@type AltDetectionConfig
	@within Types
	Settings for detecting and handling account duplicates (alt accounts).
]=]
export type AltDetectionConfig = {
	enabled: boolean,
	onDetect: "KickWithScreen" | "InvalidateVote",
	heuristic: AltHeuristic,
	kickDelaySeconds: number,
	banDuration: number,
	banReason: string,
	rapidVoteThresholdSeconds: number,
}

--[=[
	@type CmdrConfig
	@within Types
	Administrative access control for Cmdr commands.
]=]
export type CmdrConfig = {
	adminGroupId: number,
	adminMinRank: number,
}

--[=[
	@type UiConfig
	@within Types
	Customization for the client UI: colors, title, avatar settings.
]=]
export type UiConfig = {
	placeholderAvatarId: string,
	accentColour: { r: number, g: number, b: number },
	electionTitle: string,
}

--[=[
	@type ElectionConfig
	@within Types
	Master configuration object. Passed to Settings.lua and distributed to clients.
	Controls all election behavior: voting rules, candidates, eligibility, phases.
]=]
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
	ui: UiConfig,
}

--[=[
	@type BallotEntry
	@within Types
	A single vote entry on a ballot. Fields vary by voting method:
	- rank/score for rated methods
	- approved for approval voting
]=]
export type BallotEntry = {
	candidateId: string,
	rank: number?,
	score: number?,
	approved: boolean?,
}

--[=[
	@type Ballot
	@within Types
	Array of BallotEntry; represents one player's vote.
]=]
export type Ballot = { BallotEntry }

--[=[
	@type VoteRecord
	@within Types
	Persisted record of one player's vote with metadata.
]=]
export type VoteRecord = {
	userId: string,
	ballot: Ballot,
	timestamp: number,
	roundId: number?,
	partyVote: string?,
	districtId: string?,
}

--[=[
	@type WinnerResult
	@within Types
	Intermediate result from vote counting (before seat allocation).
]=]
export type WinnerResult = {
	winner: Candidate | { Candidate },
	voteShare: { [string]: number },
	roundHistory: { any }?,
}

--[=[
	@type SeatAllocation
	@within Types
	Multi-seat distribution by party or group.
]=]
export type SeatAllocation = {
	[string]: {
		seats: number,
		candidates: { Candidate },
	}
}

--[=[
	@type ElectionResult
	@within Types
	Complete election outcome: winners, vote shares, seats, coalitions.
]=]
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

--[=[
	@type EligibilityResult
	@within Types
	Outcome of eligibility check: pass/fail with reason.
]=]
export type EligibilityResult = {
	eligible: boolean,
	reason: string,
}

--[=[
	@type AltFlagResult
	@within Types
	Outcome of alt detection check: flagged/not, with action (kick or invalidate).
]=]
export type AltFlagResult = {
	flagged: boolean,
	reason: string,
	shouldKick: boolean,
	shouldInvalidate: boolean,
}

--[=[
	@type BallotTemplate
	@within Types
	Client-side ballot UI configuration: allowed selections, scoring, ranking rules.
]=]
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
