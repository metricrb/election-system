--!strict

local Types = require(script.Parent.Parent.Types)

--[=[
	@class FPTP

	First-Past-The-Post voting method.
	Candidate with most votes wins. No majority required.
]=]

local FPTP = {}

--[=[
	@function calculateWinner
	@within FPTP
	@param ballots { Types.Ballot }
	@param config Types.ElectionConfig
	@return WinnerResult

	Returns the candidate with the most votes.
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
