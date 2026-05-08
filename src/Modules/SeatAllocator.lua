--!strict

local Types = require(script.Parent.Types)
local Settings = require(script.Parent.Parent.Settings)

--[[
	@class SeatAllocator
	@within ElectionSystem

	Allocates seats in multi-seat electoral systems using configurable apportionment methods:
	- DHondt (divisor, favors larger parties)
	- SainteLague (divisor, more proportional)
	- HareNiemeyer (quota, traditional)
]]

local SeatAllocator = {}

--[[
	@function allocate
	@within SeatAllocator
	@param partyVotes { [string]: number }
	@param totalSeats number
	@return { [string]: number }

	Allocates seats based on Settings.seatAllocationMethod.
]]
function SeatAllocator.allocate(partyVotes: { [string]: number }, totalSeats: number): { [string]: number }
	local method = Settings.seatAllocationMethod

	if method == "DHondt" then
		return SeatAllocator._dhondt(partyVotes, totalSeats)
	elseif method == "SainteLague" then
		return SeatAllocator._sainteLague(partyVotes, totalSeats)
	elseif method == "HareNiemeyer" then
		return SeatAllocator._hareNiemeyer(partyVotes, totalSeats)
	else
		return SeatAllocator._dhondt(partyVotes, totalSeats)
	end
end

--[[
	@function _dhondt
	@within SeatAllocator
	@private

	D'Hondt (Jefferson) method divisor apportionment.
]]
function SeatAllocator._dhondt(partyVotes: { [string]: number }, totalSeats: number): { [string]: number }
	local seats: { [string]: number } = {}
	for partyId in pairs(partyVotes) do
		seats[partyId] = 0
	end

	-- Allocate seats one by one
	for _ = 1, totalSeats do
		local highestQuotient = -1
		local highestParty: string?

		for partyId, votes in pairs(partyVotes) do
			local divisor = seats[partyId] + 1
			local quotient = votes / divisor

			if quotient > highestQuotient then
				highestQuotient = quotient
				highestParty = partyId
			end
		end

		if highestParty then
			seats[highestParty] = seats[highestParty] + 1
		end
	end

	return seats
end

--[[
	@function _sainteLague
	@within SeatAllocator
	@private

	Sainte-Laguë (Webster) method divisor apportionment.
]]
function SeatAllocator._sainteLague(partyVotes: { [string]: number }, totalSeats: number): { [string]: number }
	local seats: { [string]: number } = {}
	for partyId in pairs(partyVotes) do
		seats[partyId] = 0
	end

	-- Allocate seats one by one
	for _ = 1, totalSeats do
		local highestQuotient = -1
		local highestParty: string?

		for partyId, votes in pairs(partyVotes) do
			local divisor = 2 * seats[partyId] + 1
			local quotient = votes / divisor

			if quotient > highestQuotient then
				highestQuotient = quotient
				highestParty = partyId
			end
		end

		if highestParty then
			seats[highestParty] = seats[highestParty] + 1
		end
	end

	return seats
end

--[[
	@function _hareNiemeyer
	@within SeatAllocator
	@private

	Hare-Niemeyer (Hamilton) method quota apportionment.
]]
function SeatAllocator._hareNiemeyer(partyVotes: { [string]: number }, totalSeats: number): { [string]: number }
	local seats: { [string]: number } = {}
	local totalVotes = 0

	for _, votes in pairs(partyVotes) do
		totalVotes = totalVotes + votes
	end

	-- Allocate initial seats based on quota
	for partyId, votes in pairs(partyVotes) do
		local quota = (votes / totalVotes) * totalSeats
		seats[partyId] = math.floor(quota)
	end

	-- Distribute remainder seats to parties with largest remainders
	local remainders: { { partyId: string, remainder: number } } = {}
	local seatsAllocated = 0

	for partyId, votes in pairs(partyVotes) do
		local quota = (votes / totalVotes) * totalSeats
		local remainder = quota - math.floor(quota)
		table.insert(remainders, { partyId = partyId, remainder = remainder })
		seatsAllocated = seatsAllocated + seats[partyId]
	end

	table.sort(remainders, function(a, b) return a.remainder > b.remainder end)

	local remainingSeats = totalSeats - seatsAllocated
	for i = 1, remainingSeats do
		if remainders[i] then
			seats[remainders[i].partyId] = seats[remainders[i].partyId] + 1
		end
	end

	return seats
end

return SeatAllocator
