--!strict

local Signal = require(script.Parent.Parent.Signal)
local Types = require(script.Parent.Types)

--[[
	@class Store
	@within ElectionSystem

	In-memory storage for election state, vote records, and metadata.
	Provides methods for get, set, serialize/deserialize for ProfileService integration.
]]

local Store = {}
Store.__index = Store

export type StoreData = {
	voteRecords: { [string]: Types.VoteRecord },
	phase: Types.ElectionPhase,
	currentRound: number,
	resultsCache: Types.ElectionResult?,
	altDetectionLog: { { userId: string, timestamp: number, flagged: boolean } },
	roundHistory: { any },
}

--[[
	@function new
	@within Store
	@return Store

	Creates a new Store instance.
]]
function Store.new(): any
	local self = setmetatable({}, Store) :: any
	self._data = {
		voteRecords = {},
		phase = "Scheduled",
		currentRound = 0,
		resultsCache = nil,
		altDetectionLog = {},
		roundHistory = {},
	} :: StoreData
	self.dataChanged = Signal.new()
	return self
end

--[[
	@method get
	@within Store
	@param key string
	@return any

	Retrieves a value from the store.
]]
function Store:get(key: string): any
	return (self._data :: any)[key]
end

--[[
	@method set
	@within Store
	@param key string
	@param value any

	Sets a value in the store and fires dataChanged signal.
]]
function Store:set(key: string, value: any): ()
	(self._data :: any)[key] = value
	self.dataChanged:fire(key, value)
end

--[[
	@method recordVote
	@within Store
	@param userId string
	@param ballot Types.Ballot
	@param roundId number?

	Records a vote for a player.
]]
function Store:recordVote(userId: string, ballot: Types.Ballot, roundId: number?): ()
	self._data.voteRecords[userId] = {
		userId = userId,
		ballot = ballot,
		timestamp = os.time(),
		roundId = roundId,
	}
	self:set("voteRecords", self._data.voteRecords)
end

--[[
	@method getVoteRecord
	@within Store
	@param userId string
	@return Types.VoteRecord?

	Retrieves the vote record for a user, or nil if not found.
]]
function Store:getVoteRecord(userId: string): Types.VoteRecord?
	return self._data.voteRecords[userId]
end

--[[
	@method hasVoted
	@within Store
	@param userId string
	@return boolean

	Checks if a user has already voted.
]]
function Store:hasVoted(userId: string): boolean
	return self._data.voteRecords[userId] ~= nil
end

--[[
	@method removeVote
	@within Store
	@param userId string

	Removes a vote record (used for alt detection invalidation).
]]
function Store:removeVote(userId: string): ()
	self._data.voteRecords[userId] = nil
	self:set("voteRecords", self._data.voteRecords)
end

--[[
	@method getAllVotes
	@within Store
	@return { Types.VoteRecord }

	Returns all vote records.
]]
function Store:getAllVotes(): { Types.VoteRecord }
	local votes = {}
	for _, vote in pairs(self._data.voteRecords) do
		table.insert(votes, vote)
	end
	return votes
end

--[[
	@method setPhase
	@within Store
	@param phase Types.ElectionPhase

	Sets the current election phase.
]]
function Store:setPhase(phase: Types.ElectionPhase): ()
	self._data.phase = phase
	self:set("phase", phase)
end

--[[
	@method getPhase
	@within Store
	@return Types.ElectionPhase

	Gets the current election phase.
]]
function Store:getPhase(): Types.ElectionPhase
	return self._data.phase
end

--[[
	@method setResultsCache
	@within Store
	@param result Types.ElectionResult

	Caches the election results.
]]
function Store:setResultsCache(result: Types.ElectionResult): ()
	self._data.resultsCache = result
	self:set("resultsCache", result)
end

--[[
	@method getResultsCache
	@within Store
	@return Types.ElectionResult?

	Gets cached election results, or nil if not set.
]]
function Store:getResultsCache(): Types.ElectionResult?
	return self._data.resultsCache
end

--[[
	@method logAltDetection
	@within Store
	@param userId string
	@param flagged boolean

	Logs an alt detection check result.
]]
function Store:logAltDetection(userId: string, flagged: boolean): ()
	table.insert(self._data.altDetectionLog, {
		userId = userId,
		timestamp = os.time(),
		flagged = flagged,
	})
	self:set("altDetectionLog", self._data.altDetectionLog)
end

--[[
	@method serialize
	@within Store
	@return table

	Serializes the store data for ProfileService persistence.
]]
function Store:serialize(): StoreData
	return self._data
end

--[[
	@method deserialize
	@within Store
	@param data StoreData

	Loads store data from ProfileService.
]]
function Store:deserialize(data: StoreData): ()
	self._data = data
end

--[[
	@method clear
	@within Store

	Clears all data from the store.
]]
function Store:clear(): ()
	self._data = {
		voteRecords = {},
		phase = "Scheduled",
		currentRound = 0,
		resultsCache = nil,
		altDetectionLog = {},
		roundHistory = {},
	}
	self:set("voteRecords", {})
end

return Store
