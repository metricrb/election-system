--!strict

local Types = require(script.Parent.Parent.Types)
local SeatAllocator = require(script.Parent.Parent.SeatAllocator)

--[=[
	@class PartyListPR

	Party-List Proportional Representation.
	Voters vote for parties. Seats allocated by party vote share.
	Candidates from each party fill seats in order (closed or open list).
]=]

local PartyListPR = {}

function PartyListPR.calculateWinner(ballots: { Types.Ballot }, config: Types.ElectionConfig): Types.WinnerResult
	local partyVotes: { [string]: number } = {}

	-- Count votes per party
	for _, ballot in ipairs(ballots) do
		if ballot[1] then
			local partyId = ballot[1].candidateId
			partyVotes[partyId] = (partyVotes[partyId] or 0) + 1
		end
	end

	-- Allocate seats
	local seatAllocation = SeatAllocator.allocate(partyVotes, config.seats)

	-- Assign candidates to seats
	local winners: { Types.Candidate } = {}
	for partyId, seats in pairs(seatAllocation) do
		for _ = 1, seats do
			for _, candidate in ipairs(config.candidates) do
				if candidate.partyId == partyId then
					table.insert(winners, candidate)
					break
				end
			end
		end
	end

	return {
		winner = if #winners == 1 then winners[1] else winners,
		voteShare = partyVotes,
	}
end

function PartyListPR.validateBallot(ballot: Types.Ballot, config: Types.ElectionConfig): { valid: boolean, reason: string }
	if #ballot ~= 1 then
		return { valid = false, reason = "PR requires voting for one party" }
	end

	local partyId = ballot[1].candidateId
	local found = false
	for _, party in ipairs(config.parties) do
		if party.partyId == partyId then
			found = true
			break
		end
	end

	if not found then
		return { valid = false, reason = "Selected party does not exist" }
	end

	return { valid = true, reason = "Valid ballot" }
end

return PartyListPR
