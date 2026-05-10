--!strict

local Types = require(script.Parent.Types)
local Settings = require(script.Parent.Parent.Settings)
local Store = require(script.Parent.Store)
local DistrictManager = require(script.Parent.DistrictManager)

-- Load all voting methods
local FPTP = require(script.Parent.VotingMethods.FPTP)
local TwoRound = require(script.Parent.VotingMethods.TwoRound)
local IRV = require(script.Parent.VotingMethods.IRV)
local Approval = require(script.Parent.VotingMethods.Approval)
local Score = require(script.Parent.VotingMethods.Score)
local STAR = require(script.Parent.VotingMethods.STAR)
local STV = require(script.Parent.VotingMethods.STV)
local PartyListPR = require(script.Parent.VotingMethods.PartyListPR)
local MMP = require(script.Parent.VotingMethods.MMP)
local Parallel = require(script.Parent.VotingMethods.Parallel)
local Condorcet = require(script.Parent.VotingMethods.Condorcet)
local Borda = require(script.Parent.VotingMethods.Borda)
local Cumulative = require(script.Parent.VotingMethods.Cumulative)
local Sortition = require(script.Parent.VotingMethods.Sortition)

--[=[
	@class ResultCalculator
	@tag Elections & Results

	Coordinates all 14 voting methods and calculates election results from ballots.

	The ResultCalculator dispatches to method-specific implementation modules (FPTP, IRV, Score, etc.)
	based on the configured voting method in Settings. It also handles:
	- Ballot format validation (custom per voting method)
	- Result formatting into a standard ElectionResult structure
	- District-by-district vote counting for geographic elections

	## Voting Methods

	All 14 methods return winners and vote shares:
	- **FPTP** — First-past-the-post, single winner
	- **TwoRound** — Two-round runoff, single winner
	- **IRV** — Instant runoff voting, ranked choice
	- **Approval** — Approval voting
	- **Score** — Range/score voting
	- **STAR** — Score Then Automatic Runoff
	- **STV** — Single Transferable Vote, multi-winner
	- **PartyListPR** — Party-list proportional representation
	- **MMP** — Mixed-member proportional
	- **Parallel** — Parallel voting systems
	- **Condorcet** — Condorcet method
	- **Borda** — Borda count
	- **Cumulative** — Cumulative voting
	- **Sortition** — Random selection (for sortition-based elections)

	## Usage

	```lua
	-- Usually handled internally by ElectionManager.calculateResults()
	local ballots = store:getAllVotes()
	local result = ResultCalculator.calculate(Settings.votingMethod, ballots, store)
	print("Winner:", result.winner.name)
	print("Votes recorded:", result.votesRecorded)
	```
]=]

local ResultCalculator = {}

local METHODS: { [string]: any } = {
	FPTP = FPTP,
	TwoRound = TwoRound,
	IRV = IRV,
	Approval = Approval,
	Score = Score,
	STAR = STAR,
	STV = STV,
	PartyListPR = PartyListPR,
	MMP = MMP,
	Parallel = Parallel,
	Condorcet = Condorcet,
	Borda = Borda,
	Cumulative = Cumulative,
	Sortition = Sortition,
}

--[=[
	@function calculate
	@within ResultCalculator
	@param votingMethod string — The voting method to use (e.g., "FPTP", "IRV")
	@param ballots { Types.Ballot } — Array of all cast ballots
	@param store Store — The election store instance
	@return Types.ElectionResult — Complete election results with winners and vote shares

	Calculates election results using the specified voting method.

	Delegates to the method-specific module (e.g., FPTP.lua, IRV.lua) which implements
	the counting algorithm. Returns a standardized ElectionResult object.

	```lua
	local result = ResultCalculator.calculate("IRV", ballots, store)
	```
]=]

--[=[
	@function validateBallot
	@within ResultCalculator
	@param ballot Types.Ballot
	@return { valid: boolean, reason: string }

	Validates a ballot against the currently configured voting method's rules.

	Different voting methods have different ballot constraints:
	- FPTP: single selection
	- Ranked methods: no duplicate selections
	- Score: numeric ranges
	- Approval: binary choices

	Returns `{valid=true}` if the ballot is acceptable, otherwise an error reason.
]=]
function ResultCalculator.validateBallot(ballot: Types.Ballot): { valid: boolean, reason: string }
	local method = METHODS[Settings.votingMethod]
	if not method or not method.validateBallot then
		return { valid = true, reason = "OK" }
	end
	return method.validateBallot(ballot, Settings)
end

function ResultCalculator.calculate(votingMethod: string, ballots: { Types.Ballot }, store: Store): Types.ElectionResult
	local method = METHODS[votingMethod]
	if not method then
		error("Unknown voting method: " .. votingMethod)
	end

	local winnerResult = method.calculateWinner(ballots, Settings)

	return {
		phase = "ResultsOut",
		votesRecorded = #ballots,
		eligibleVoters = #Settings.candidates,
		winner = winnerResult.winner,
		voteShare = winnerResult.voteShare,
		seats = nil,
		coalition = nil,
		roundHistory = winnerResult.roundHistory,
		calculatedAt = os.time(),
	}
end

function ResultCalculator.calculateByDistrict(votingMethod: string, voteRecords: { Types.VoteRecord }, store: Store): { [string]: Types.ElectionResult }
	local resultsByDistrict: { [string]: Types.ElectionResult } = {}
	for _, district in ipairs(Settings.districts) do
		local districtVotes = DistrictManager.getDistrictVotes(district.districtId, voteRecords)
		local ballots: { Types.Ballot } = {}
		for _, vote in ipairs(districtVotes) do
			table.insert(ballots, vote.ballot)
		end
		resultsByDistrict[district.districtId] = ResultCalculator.calculate(votingMethod, ballots, store)
	end
	return resultsByDistrict
end

return ResultCalculator
