--!strict

local Types = require(script.Parent.Parent.Types)

--[=[
	@class FPTP
	@tag Elections & Results

	First-Past-The-Post (FPTP) voting method.

	The candidate with the most votes wins, regardless of whether they have a majority.
	Each voter casts a single vote for one candidate.

	## How It Works

	1. Each ballot contains one vote (ballot[1].candidateId)
	2. Votes are tallied for each candidate
	3. Candidate with the most votes wins
	4. Vote shares are calculated as percentages

	## Example Results

	```
	Ballots:    [Alice, Alice, Bob, Carol]
	Vote Tally: Alice=2, Bob=1, Carol=1
	Winner:     Alice
	Share:      Alice=50%, Bob=25%, Carol=25%
	```

	## Ballot Format

	Voters select exactly one candidate:
	```lua
	ballot = {
		{ candidateId = "alice", rank = 1 }  -- only first entry used
	}
	```

	## Use Cases

	- Simple elections with clear majority support
	- Single-winner elections
	- Government models: Presidential (president only), Parliamentary (single seat)

	## Limitations

	- Can elect a winner with <50% of votes
	- Does not represent minority preferences
	- In multi-candidate races, may split votes among similar candidates
]=]

local FPTP = {}

--[=[
	@function calculateWinner
	@within FPTP
	@param ballots { Types.Ballot } — Array of all cast ballots
	@param config Types.ElectionConfig — Election configuration
	@return Types.WinnerResult — Winner object with voteShare percentages

	Counts votes and returns the candidate with the most votes.

	```lua
	local result = FPTP.calculateWinner(ballots, Settings)
	print("Winner:", result.winner.name)
	print("Vote share:", result.voteShare[result.winner.candidateId] .. "%")
	```
]=]
function FPTP.calculateWinner(ballots: { Types.Ballot }, config: Types.ElectionConfig): Types.WinnerResult
	local voteShare: { [string]: number } = {}

	-- Count votes
	for _, ballot in ipairs(ballots) do
		if ballot[1] then
			local candidateId = ballot[1].candidateId
			voteShare[candidateId] = (voteShare[candidateId] or 0) + 1
		end
	end

	-- Find winner (most votes)
	local maxVotes = 0
	local winnerId: string?

	for candidateId, votes in pairs(voteShare) do
		if votes > maxVotes then
			maxVotes = votes
			winnerId = candidateId
		end
	end

	-- Convert to percentages
	local totalVotes = #ballots
	local sharePercentages: { [string]: number } = {}
	for candidateId, votes in pairs(voteShare) do
		sharePercentages[candidateId] = if totalVotes > 0 then (votes / totalVotes) * 100 else 0
	end

	-- Find candidate object
	local winner: Types.Candidate?
	for _, candidate in ipairs(config.candidates) do
		if candidate.candidateId == winnerId then
			winner = candidate
			break
		end
	end

	return {
		winner = winner or config.candidates[1],
		voteShare = sharePercentages,
	}
end

--[=[
	@function validateBallot
	@within FPTP
	@param ballot Types.Ballot
	@param config Types.ElectionConfig
	@return { valid: boolean, reason: string }

	Validates that ballot has exactly one candidate selected.
]=]
function FPTP.validateBallot(ballot: Types.Ballot, config: Types.ElectionConfig): { valid: boolean, reason: string }
	if #ballot ~= 1 then
		return { valid = false, reason = "FPTP requires exactly one vote" }
	end

	local candidateId = ballot[1].candidateId
	local found = false
	for _, candidate in ipairs(config.candidates) do
		if candidate.candidateId == candidateId then
			found = true
			break
		end
	end

	if not found then
		return { valid = false, reason = "Selected candidate does not exist" }
	end

	return { valid = true, reason = "Valid ballot" }
end

return FPTP
