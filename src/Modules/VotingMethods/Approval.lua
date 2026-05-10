--!strict

local Types = require(script.Parent.Parent.Types)

--[=[
	@class Approval

	Approval voting. Each voter approves any number of candidates.
	Candidate with most approvals wins.
]=]

local Approval = {}

function Approval.calculateWinner(ballots: { Types.Ballot }, config: Types.ElectionConfig): Types.WinnerResult
	local voteShare: { [string]: number } = {}

	for _, ballot in ipairs(ballots) do
		for _, entry in ipairs(ballot) do
			if entry.approved then
				voteShare[entry.candidateId] = (voteShare[entry.candidateId] or 0) + 1
			end
		end
	end

	local maxVotes = 0
	local winnerId: string?
	for candidateId, votes in pairs(voteShare) do
		if votes > maxVotes then
			maxVotes = votes
			winnerId = candidateId
		end
	end

	local totalVotes = #ballots
	local sharePercentages: { [string]: number } = {}
	for candidateId, votes in pairs(voteShare) do
		sharePercentages[candidateId] = if totalVotes > 0 then (votes / totalVotes) * 100 else 0
	end

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

function Approval.validateBallot(ballot: Types.Ballot, config: Types.ElectionConfig): { valid: boolean, reason: string }
	if #ballot == 0 then
		return { valid = false, reason = "At least one approval required" }
	end

	for _, entry in ipairs(ballot) do
		local found = false
		for _, candidate in ipairs(config.candidates) do
			if candidate.candidateId == entry.candidateId then
				found = true
				break
			end
		end
		if not found then
			return { valid = false, reason = "Invalid candidate in ballot" }
		end
	end

	return { valid = true, reason = "Valid ballot" }
end

return Approval
