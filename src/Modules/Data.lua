--!strict

local Types = require(script.Parent.Types)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ProfileService = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("ProfileService"))
local Settings = require(script.Parent.Parent.Settings)

--[=[
	@class Data
	@tag State Management

	Manages persistent player data via ProfileService.

	The Data module provides a wrapper around ProfileService for storing and retrieving
	election-related player information. Each player gets a profile that survives server restarts
	and maintains vote records across sessions.

	## Data Structure

	Each player's profile contains:
	```lua
	{
		Elections = {
			voteRecords = { ... },  -- historical vote data
			-- other election fields
		}
	}
	```

	## Lifecycle

	- **Player joins**: Profile is loaded from DataStore (or created if new)
	- **Vote recorded**: Vote data persisted to player's profile
	- **Player leaves**: Profile released (data auto-saves)

	## Usage

	```lua
	-- Load a player's profile
	Data.loadProfile(player.UserId)

	-- Store a vote record
	local voteRecord = { userId = userId, ballot = ballot, timestamp = os.time() }
	Data.setVoteRecord(player.UserId, voteRecord)

	-- Retrieve later
	local record = Data.getVoteRecord(player.UserId)
	```

	## Dependencies

	Requires ProfileService from Wally (DevPackages/Packages/ProfileService).
]=]

local Data = {}
local profiles: { [number]: any } = {}

local profileTemplate = {
	Elections = {},
}

local store = ProfileService.GetProfileStore("ElectionPlayerData", profileTemplate)

local function globalLedgerEnabled(): boolean
	local g = (Settings :: any).globalVoteLedger
	return type(g) == "table" and g.enabled == true
end

local function globalLedgerDataStore(): any
	local g = (Settings :: any).globalVoteLedger
	local name = if type(g) == "table" and type((g :: any).dataStoreName) == "string" and (g :: any).dataStoreName ~= ""
		then (g :: any).dataStoreName
		else "ElectionGlobalVotes"
	return DataStoreService:GetDataStore(name)
end

local function globalLedgerKey(): string
	return "votes_" .. Settings.countryId
end

-- One `GetAsync` per short window so RequestState + tallies don't spam DataStore.
local globalLedgerCache: { doc: any, at: number }? = nil
local GLOBAL_LEDGER_CACHE_TTL = 8

function Data.bumpGlobalLedgerCache(): ()
	globalLedgerCache = nil
end

local function getGlobalLedgerDocumentCached(): any
	if not globalLedgerEnabled() then
		return { votes = {} }
	end
	local now = os.clock()
	if globalLedgerCache and (now - globalLedgerCache.at) < GLOBAL_LEDGER_CACHE_TTL then
		return globalLedgerCache.doc
	end
	local ds = globalLedgerDataStore()
	local key = globalLedgerKey()
	local ok, data = pcall(function()
		return ds:GetAsync(key)
	end)
	local doc: any
	if ok and type(data) == "table" then
		doc = data
	else
		doc = { votes = {} }
	end
	if type(doc.votes) ~= "table" then
		doc = { votes = {} }
	end
	globalLedgerCache = { doc = doc, at = now }
	return doc
end

local function profileKey(userId: number): string
	return "Player_" .. tostring(userId)
end

function Data.init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			local profile = store:LoadProfileAsync(profileKey(player.UserId), "ForceLoad")
			if profile then
				profile:AddUserId(player.UserId)
				profile:Reconcile()
				profiles[player.UserId] = profile
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player.UserId]
		if profile then
			profile:Release()
			profiles[player.UserId] = nil
		end
	end)
end

function Data.loadProfile(userId: number)
	if profiles[userId] then
		return profiles[userId]
	end

	local profile = store:LoadProfileAsync(profileKey(userId), "ForceLoad")
	if profile then
		profile:AddUserId(userId)
		profile:Reconcile()
		profiles[userId] = profile
	end

	return profile
end

function Data.saveProfile(userId: number, data: any)
	local profile = Data.loadProfile(userId)
	if not profile then
		return
	end

	profile.Data = data
	profile:Save()
end

function Data.getVoteRecord(userId: number): Types.VoteRecord?
	local profile = profiles[userId]
	if not profile then
		return nil
	end

	local electionData = profile.Data.Elections[Settings.countryId]
	if not electionData then
		return nil
	end

	return electionData.voteRecord
end

function Data.setVoteRecord(userId: number, voteRecord: Types.VoteRecord)
	local profile = profiles[userId]
	if not profile then
		profile = Data.loadProfile(userId)
	end
	if not profile then
		warn("[ElectionSystem] setVoteRecord: profile unavailable for " .. tostring(userId) .. "; DataStore write skipped.")
		return
	end

	profile.Data.Elections[Settings.countryId] = profile.Data.Elections[Settings.countryId] or {}
	profile.Data.Elections[Settings.countryId].voteRecord = voteRecord
	task.spawn(function()
		profile:Save()
	end)
end

--[[
	Clears the persisted vote for the current `Settings.countryId` election only (for dev retests).
]]
function Data.clearVoteRecord(userId: number)
	local profile = profiles[userId]
	if not profile then
		profile = Data.loadProfile(userId)
	end
	if not profile then
		return
	end

	local elections = profile.Data.Elections
	local bucket = elections[Settings.countryId]
	if bucket and bucket.voteRecord then
		bucket.voteRecord = nil
		task.spawn(function()
			profile:Save()
		end)
	end
end

--[=[
	Returns every vote record for `Settings.countryId` from profiles **currently loaded in memory**
	on this server. Offline players are omitted (ProfileService releases on leave). Used to refresh
	the in-memory tally so Cmdr and surface charts match DataStore for everyone connected.
]=]
function Data.getAllPersistedVoteRecordsFromLoadedProfiles(): { Types.VoteRecord }
	local cid = Settings.countryId
	local out: { Types.VoteRecord } = {}
	for userId, profile in pairs(profiles) do
		if profile and type(profile.Data) == "table" then
			local elections = profile.Data.Elections
			if type(elections) == "table" then
				local bucket = elections[cid]
				if type(bucket) == "table" and bucket.voteRecord then
					local recAny = bucket.voteRecord :: any
					local uidStr = if type(recAny.userId) == "string"
						then recAny.userId
						else tostring(userId)
					local rec = table.clone(recAny) :: Types.VoteRecord
					(rec :: any).userId = uidStr
					table.insert(out, rec)
				end
			end
		end
	end
	return out
end

--[=[
	Cross-server tally: Standard DataStore document `votes_<countryId>` with `{ votes = { [userId] = VoteRecord } }`.
	Written when a vote is accepted; read when computing results. Complements per-player ProfileService copies.
	Upserts one row per userId (latest ballot wins, including vote replacement when enabled in Settings).
]=]
function Data.tryInsertGlobalVoteRecord(userId: number, voteRecord: Types.VoteRecord): boolean
	if not globalLedgerEnabled() then
		return true
	end
	local uid = tostring(userId)
	local recPlain: any = {
		userId = voteRecord.userId,
		ballot = voteRecord.ballot,
		timestamp = voteRecord.timestamp,
		roundId = voteRecord.roundId,
		partyVote = voteRecord.partyVote,
		districtId = voteRecord.districtId,
	}
	local ds = globalLedgerDataStore()
	local key = globalLedgerKey()
	local ok, err = pcall(function()
		ds:UpdateAsync(key, function(old)
			local data: any
			if type(old) == "table" then
				data = old
			else
				data = { votes = {} }
			end
			if type(data.votes) ~= "table" then
				data.votes = {}
			end
			data.votes[uid] = recPlain
			return data
		end)
	end)
	if not ok then
		warn("[ElectionSystem] tryInsertGlobalVoteRecord: " .. tostring(err))
		return false
	end
	Data.bumpGlobalLedgerCache()
	return true
end

function Data.removeGlobalVoteRecord(userId: number): ()
	if not globalLedgerEnabled() then
		return
	end
	local uid = tostring(userId)
	local ds = globalLedgerDataStore()
	local key = globalLedgerKey()
	pcall(function()
		ds:UpdateAsync(key, function(old)
			if type(old) ~= "table" or type(old.votes) ~= "table" then
				return old
			end
			(old.votes :: any)[uid] = nil
			return old
		end)
	end)
	Data.bumpGlobalLedgerCache()
end

function Data.getGlobalVoteRecordForUser(userId: number): Types.VoteRecord?
	if not globalLedgerEnabled() then
		return nil
	end
	local doc = getGlobalLedgerDocumentCached()
	local votes = (doc :: any).votes
	if type(votes) ~= "table" then
		return nil
	end
	local rec = votes[tostring(userId)]
	if type(rec) == "table" and type((rec :: any).ballot) == "table" then
		return rec :: Types.VoteRecord
	end
	return nil
end

function Data.getAllGlobalVoteRecords(): { Types.VoteRecord }
	if not globalLedgerEnabled() then
		return {}
	end
	local data = getGlobalLedgerDocumentCached()
	if type(data) ~= "table" or type((data :: any).votes) ~= "table" then
		return {}
	end
	local out: { Types.VoteRecord } = {}
	for _, rec in pairs((data :: any).votes) do
		if type(rec) == "table" and type((rec :: any).userId) == "string" and type((rec :: any).ballot) == "table" then
			table.insert(out, rec :: Types.VoteRecord)
		end
	end
	return out
end

function Data.clearGlobalVoteLedger(): ()
	if not globalLedgerEnabled() then
		return
	end
	local ds = globalLedgerDataStore()
	local key = globalLedgerKey()
	pcall(function()
		ds:RemoveAsync(key)
	end)
	Data.bumpGlobalLedgerCache()
end

return Data
