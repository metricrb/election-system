--!strict

local Types = require(script.Parent.Parent.Types)
local RoundManager = require(script.Parent.Parent.RoundManager)

--[=[
	@class IRV
	@tag Elections & Results

	Instant Runoff Voting (IRV) — Ranked choice voting system.

	Voters rank candidates in order of preference. The system iteratively eliminates the
	lowest-vote candidate and recounts votes, moving ballots to voters' next choices until
	someone achieves a majority (>50%).

	## How It Works

	1. Count first-choice votes
	2. If a candidate has >50% of votes, they win
	3. Eliminate the candidate with the fewest votes
	4. Move ballots that ranked that candidate first to their next choice
	5. Recount and repeat until someone reaches majority

	## Example Ballot

	Voters rank their top candidates:
	```lua
	ballot = {
		{ candidateId = "alice", rank = 1 },
		{ candidateId = "bob", rank = 2 },
		{ candidateId = "carol", rank = 3 },
	}
	```

	## Example Results

	```
	Round 1: Alice=40%, Bob=35%, Carol=25%
	   (Carol eliminated; her ballots reassigned)
	Round 2: Alice=45%, Bob=55%
	   (Bob wins with majority)
	```

	## Advantages

	- Encourages consensus-building
	- Eliminates "lesser of two evils" voting
	- Captures voter preferences across spectrum
	- Used in: Australian elections, Maine/Alaska US, many organizations

	## Disadvantages

	- More complex for voters and election officials
	- Results depend on ballot order (ranked preference)
	- Can produce counterintuitive outcomes with certain distributions
]=]

local IRV = {}

function IRV.calculateWinner(ballots: { Types.Ballot }, config: Types.ElectionConfig): Types.WinnerResult
	local currentBallots = ballots
	local totalVotes = #ballots
	local majority = math.ceil(totalVotes / 2)
	local roundHistory: { any } = {}

	while true do
		local votes = RoundManager.getRoundVotes(currentBallots)
		table.insert(roundHistory, votes)

		-- Check for majority
		for candidateId, voteCount in pairs(votes) do
			if voteCount >= majority then
				return {
					winner = { candidateId = candidateId } :: any,
					voteShare = votes,
					roundHistory = roundHistory,
				}
			end
		end

		-- Eliminate loser
		if #currentBallots == 0 then break end

		local loser = RoundManager.getLoser(votes)
		currentBallots = RoundManager.eliminateCandidate(loser, currentBallots)

		-- Check if only one candidate left
		local remaining: { [string]: boolean } = {}
		for _, ballot in ipairs(currentBallots) do
			if #ballot > 0 then
				remaining[ballot[1].candidateId] = true
			end
		end

		if #(function() local t = {} for k in pairs(remaining) do table.insert(t, k) end return t end)() <= 1 then
			local lastCandidate = next(remaining)
			return {
				winner = { candidateId = lastCandidate or loser } :: any,
				voteShare = votes,
				roundHistory = roundHistory,
			}
		end
	end

	return {
		winner = config.candidates[1],
		voteShare = {},
		roundHistory = roundHistory,
	}
end

function IRV.validateBallot(ballot: Types.Ballot, config: Types.ElectionConfig): { valid: boolean, reason: string }
	if #ballot < 1 then
		return { valid = false, reason = "IRV requires at least one ranked candidate" }
	end

	local rankedSet: { [number]: boolean } = {}
	for _, entry in ipairs(ballot) do
		if not entry.rank then
			return { valid = false, reason = "All ranked candidates must have distinct ranks" }
		end
		if rankedSet[entry.rank] then
			return { valid = false, reason = "Duplicate rank" }
		end
		rankedSet[entry.rank] = true
	end

	return { valid = true, reason = "Valid ballot" }
end

return IRV
