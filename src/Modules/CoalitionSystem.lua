--!strict

local Signal = require(script.Parent.Parent.Signal)
local Types = require(script.Parent.Types)
local Store = require(script.Parent.Store)

--[[
	@class CoalitionSystem
	@within ElectionSystem

	Forms coalition governments in parliamentary systems after PR/MMP elections.
]]

local CoalitionSystem = {}

CoalitionSystem.CoalitionFormed = Signal.new()

function CoalitionSystem.suggestCoalition(seatCounts: { [string]: number }, totalSeats: number): { string }
	local majority = math.ceil(totalSeats / 2)
	local coalition: { string } = {}
	local coalitionSeats = 0

	for partyId, seats in pairs(seatCounts) do
		if coalitionSeats < majority then
			table.insert(coalition, partyId)
			coalitionSeats = coalitionSeats + seats
		end
		if coalitionSeats >= majority then break end
	end

	return coalition
end

function CoalitionSystem.validateCoalition(members: { string }, seatCounts: { [string]: number }, totalSeats: number): boolean
	local seats = 0
	for _, partyId in ipairs(members) do
		seats = seats + (seatCounts[partyId] or 0)
	end
	return seats > math.ceil(totalSeats / 2)
end

return CoalitionSystem
