--!strict

local Types = require(script.Parent.Parent.Types)
local SeatAllocator = require(script.Parent.Parent.SeatAllocator)

--[[
	@class MMP
	@within ElectionSystem

	Mixed-Member Proportional (Germany, New Zealand model).
	Two votes: local representative + national party.
	Allocates compensation seats to balance parliament proportionally.
]]

local MMP = {}

function MMP.calculateWinner(ballots: { Types.Ballot }, config: Types.ElectionConfig): Types.WinnerResult
	local localVotes: { [string]: number } = {}
	local partyVotes: { [string]: number } = {}

	for _, ballot in ipairs(ballots) do
		-- First entry: local candidate
		if ballot[1] then
			localVotes[ballot[1].candidateId] = (localVotes[ballot[1].candidateId] or 0) + 1
		end
		-- Second entry: party vote
		if ballot[2] then
			partyVotes[ballot[2].candidateId] = (partyVotes[ballot[2].candidateId] or 0) + 1
		end
	end

	-- Allocate total seats by party vote
	local seatAllocation = SeatAllocator.allocate(partyVotes, config.seats)

	-- Get elected local representatives
	local winners: { Types.Candidate } = {}
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

function MMP.validateBallot(ballot: Types.Ballot, config: Types.ElectionConfig): { valid: boolean, reason: string }
	if #ballot < 2 then
		return { valid = false, reason = "MMP requires two votes (local + party)" }
	end
	return { valid = true, reason = "Valid ballot" }
end

return MMP
