--!strict

local Signal = require(script.Parent.Parent.Signal)
local Types = require(script.Parent.Types)

--[=[
	@class Store
	@tag State Management

	In-memory vote cache and election state store.

	The Store maintains all election data during the game session:
	- Vote records (keyed by userId)
	- Current phase and round information
	- Cached election results
	- Alt detection logs
	- Round history

	Data is synced with DataStore via the Data module. Store provides fast, in-memory access to
	election state without repeated DataStore calls.

	## Usage

	```lua
	local store = ElectionManager:getStore()

	-- Record a vote
	store:recordVote(userId, ballot)

	-- Check if voted
	if store:hasVoted(userId) then
		print("Player already voted")
	end

	-- Get all votes for result calculation
	local allVotes = store:getAllVotes()

	-- Listen for state changes
	store.dataChanged:connect(function(key, value)
		print("Field changed:", key)
	end)
	```
]=]

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

--[=[
	@function new
	@within Store
	@return Store

	Creates a new Store instance.
]=]
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

--[=[
	@method get
	@within Store
	@param key string
	@return any

	Retrieves a value from the store.
]=]
function Store:get(key: string): any
	return (self._data :: any)[key]
end

--[=[
	@method set
	@within Store
	@param key string
	@param value any

	Sets a value in the store and fires dataChanged signal.
]=]
function Store:set(key: string, value: any): ()
	(self._data :: any)[key] = value
	self.dataChanged:fire(key, value)
end

--[=[
	@method recordVote
	@within Store
	@param userId string
	@param ballot Types.Ballot
	@param roundId number?

	Records a vote for a player.
]=]
function Store:recordVote(userId: string, ballot: Types.Ballot, roundId: number?, districtId: string?): ()
	self._data.voteRecords[userId] = {
		userId = userId,
		ballot = ballot,
		timestamp = os.time(),
		roundId = roundId,
		districtId = districtId,
	}
	self:set("voteRecords", self._data.voteRecords)
end

--[=[
	@method getVoteRecord
	@within Store
	@param userId string
	@return Types.VoteRecord?

	Retrieves the vote record for a user, or nil if not found.
]=]
function Store:getVoteRecord(userId: string): Types.VoteRecord?
	return self._data.voteRecords[userId]
end

--[=[
	@method hasVoted
	@within Store
	@param userId string
	@return boolean

	Checks if a user has already voted.
]=]
function Store:hasVoted(userId: string): boolean
	return self._data.voteRecords[userId] ~= nil
end

--[=[
	@method seedVoteFromData
	@within Store
	@param userId string
	@param voteRecord Types.VoteRecord

	Merges a persisted vote into memory if this session has no record yet.
]=]
function Store:seedVoteFromData(userId: string, voteRecord: Types.VoteRecord): ()
	if self._data.voteRecords[userId] ~= nil then
		return
	end
	self._data.voteRecords[userId] = voteRecord
	self:set("voteRecords", self._data.voteRecords)
end

--[=[
	@method removeVote
	@within Store
	@param userId string

	Removes a vote record (used for alt detection invalidation).
]=]
function Store:removeVote(userId: string): ()
	self._data.voteRecords[userId] = nil
	self:set("voteRecords", self._data.voteRecords)
end

--[=[
	@method getAllVotes
	@within Store
	@return { Types.VoteRecord }

	Returns all vote records.
]=]
function Store:getAllVotes(): { Types.VoteRecord }
	local votes = {}
	for _, vote in pairs(self._data.voteRecords) do
		table.insert(votes, vote)
	end
	return votes
end

--[=[
	@method setPhase
	@within Store
	@param phase Types.ElectionPhase

	Sets the current election phase.
]=]
function Store:setPhase(phase: Types.ElectionPhase): ()
	self._data.phase = phase
	self:set("phase", phase)
end

--[=[
	@method getPhase
	@within Store
	@return Types.ElectionPhase

	Gets the current election phase.
]=]
function Store:getPhase(): Types.ElectionPhase
	return self._data.phase
end

--[=[
	@method setResultsCache
	@within Store
	@param result Types.ElectionResult

	Caches the election results.
]=]
function Store:setResultsCache(result: Types.ElectionResult): ()
	self._data.resultsCache = result
	self:set("resultsCache", result)
end

--[=[
	@method getResultsCache
	@within Store
	@return Types.ElectionResult?

	Gets cached election results, or nil if not set.
]=]
function Store:getResultsCache(): Types.ElectionResult?
	return self._data.resultsCache
end

--[=[
	@method logAltDetection
	@within Store
	@param userId string
	@param flagged boolean

	Logs an alt detection check result.
]=]
function Store:logAltDetection(userId: string, flagged: boolean): ()
	table.insert(self._data.altDetectionLog, {
		userId = userId,
		timestamp = os.time(),
		flagged = flagged,
	})
	self:set("altDetectionLog", self._data.altDetectionLog)
end

--[=[
	@method serialize
	@within Store
	@return table

	Serializes the store data for ProfileService persistence.
]=]
function Store:serialize(): StoreData
	return self._data
end

--[=[
	@method deserialize
	@within Store
	@param data StoreData

	Loads store data from ProfileService.
]=]
function Store:deserialize(data: StoreData): ()
	self._data = data
end

--[=[
	@method clear
	@within Store

	Clears all data from the store.
]=]
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
