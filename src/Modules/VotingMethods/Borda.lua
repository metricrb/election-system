--!strict

local Types = require(script.Parent.Parent.Types)

--[=[
	@class Borda

	Borda count. Ranked voting where each rank position gives points.
	Highest total points wins.
]=]

local Borda = {}

function Borda.calculateWinner(ballots: { Types.Ballot }, config: Types.ElectionConfig): Types.WinnerResult
	local points: { [string]: number } = {}
	local numCandidates = #config.candidates

	for _, ballot in ipairs(ballots) do
		for _, entry in ipairs(ballot) do
			if entry.rank then
				local candidateId = entry.candidateId
				local pointsForRank = numCandidates - entry.rank + 1
				points[candidateId] = (points[candidateId] or 0) + pointsForRank
			end
		end
	end

	local maxPoints = 0
	local winnerId: string?
	for candidateId, pts in pairs(points) do
		if pts > maxPoints then
			maxPoints = pts
			winnerId = candidateId
		end
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
		voteShare = points,
	}
end

function Borda.validateBallot(ballot: Types.Ballot, config: Types.ElectionConfig): { valid: boolean, reason: string }
	if #ballot ~= #config.candidates then
		return { valid = false, reason = "Borda requires ranking all candidates" }
	end

	local rankedSet: { [number]: boolean } = {}
	for _, entry in ipairs(ballot) do
		if not entry.rank then
			return { valid = false, reason = "All candidates must be ranked" }
		end
		if rankedSet[entry.rank] then
			return { valid = false, reason = "Duplicate rank" }
		end
		rankedSet[entry.rank] = true
	end

	return { valid = true, reason = "Valid ballot" }
end

return Borda
