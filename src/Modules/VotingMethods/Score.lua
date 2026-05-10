--!strict

local Types = require(script.Parent.Parent.Types)

--[=[
	@class Score

	Score/Range voting. Each voter scores each candidate.
	Candidate with highest average score wins.
]=]

local Score = {}

function Score.calculateWinner(ballots: { Types.Ballot }, config: Types.ElectionConfig): Types.WinnerResult
	local scoreSum: { [string]: number } = {}
	local scoreCount: { [string]: number } = {}

	for _, ballot in ipairs(ballots) do
		for _, entry in ipairs(ballot) do
			if entry.score then
				scoreSum[entry.candidateId] = (scoreSum[entry.candidateId] or 0) + entry.score
				scoreCount[entry.candidateId] = (scoreCount[entry.candidateId] or 0) + 1
			end
		end
	end

	local maxAverage = -1
	local winnerId: string?
	local voteShare: { [string]: number } = {}

	for candidateId, sum in pairs(scoreSum) do
		local count = scoreCount[candidateId] or 1
		local average = sum / count
		voteShare[candidateId] = average

		if average > maxAverage then
			maxAverage = average
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
		voteShare = voteShare,
	}
end

function Score.validateBallot(ballot: Types.Ballot, config: Types.ElectionConfig): { valid: boolean, reason: string }
	for _, entry in ipairs(ballot) do
		if not entry.score or entry.score < 0 or entry.score > 5 then
			return { valid = false, reason = "All candidates must have scores 0-5" }
		end
	end

	return { valid = true, reason = "Valid ballot" }
end

return Score
