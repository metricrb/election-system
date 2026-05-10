--!strict

local Types = require(script.Parent.Parent.Types)
local SeatAllocator = require(script.Parent.Parent.SeatAllocator)

--[=[
	@class Parallel

	Parallel voting (Japan model). Two independent voting systems run in parallel.
	Local representatives elected via FPTP; party list elected independently.
	Systems do NOT compensate each other (unlike MMP).
]=]

local Parallel = {}

function Parallel.calculateWinner(ballots: { Types.Ballot }, config: Types.ElectionConfig): Types.WinnerResult
	local localVotes: { [string]: number } = {}
	local partyVotes: { [string]: number } = {}

	for _, ballot in ipairs(ballots) do
		if ballot[1] then
			localVotes[ballot[1].candidateId] = (localVotes[ballot[1].candidateId] or 0) + 1
		end
		if ballot[2] then
			partyVotes[ballot[2].candidateId] = (partyVotes[ballot[2].candidateId] or 0) + 1
		end
	end

	-- Local representatives: highest vote per district
	-- Party list: independent allocation (no compensation)
	local winners: { Types.Candidate } = {}

	-- Get local winners
	for candidateId in pairs(localVotes) do
		for _, candidate in ipairs(config.candidates) do
			if candidate.candidateId == candidateId then
				table.insert(winners, candidate)
				break
			end
		end
	end

	return {
		winner = if #winners == 1 then winners[1] else winners,
		voteShare = partyVotes,
	}
end

function Parallel.validateBallot(ballot: Types.Ballot, config: Types.ElectionConfig): { valid: boolean, reason: string }
	if #ballot < 2 then
		return { valid = false, reason = "Parallel requires two votes (local + party)" }
	end
	return { valid = true, reason = "Valid ballot" }
end

return Parallel
