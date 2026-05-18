--!strict

local Players = game:GetService("Players")

local Types = require(script.Parent.Types)
local Settings = require(script.Parent.Parent.Settings)

--[=[
	@class DistrictManager

	Routes votes by electoral district. Supports single-member, multi-member, at-large, federal.

	**Assignment (no explicit `DistrictId` attribute):**
	1. If this user already has a vote in the store (loaded from DataStore), use that record’s `districtId`.
	2. Else if we cached a constituency for this session, reuse it.
	3. Else assign the constituency with the **fewest current load**: recorded votes in the store **plus**
	   players already assigned this session who have not voted yet. **Ties** (including all-zero) pick **uniformly at random**
	   among those districts so voters spread across districts instead of always using `districts[1]`.

	Call `DistrictManager.setStore(store)` from `ElectionManager.init` after creating the store.
]=]

local DistrictManager = {}

-- In-memory session cache: userId string -> districtId (authoritative assignment before/without a stored vote).
local userIdToDistrictId: { [string]: string } = {}

-- Random tie-break for minimum-load assignment (spread voters when counts tie).
local balanceRng = Random.new()

-- Set by ElectionManager after `Store.new()`; tallies come from `getAllVotes()` (hydrated from DataStore).
local voteStore: any = nil

function DistrictManager.setStore(store: any): ()
	voteStore = store
end

function DistrictManager.init()
	Players.PlayerRemoving:Connect(function(player: Player)
		DistrictManager.clearAssignmentForUser(tostring(player.UserId))
	end)
end

function DistrictManager.clearAssignmentForUser(userId: string)
	userIdToDistrictId[userId] = nil
end

--[[ Replicates server constituency to the client (`ElectionDistrictId`). Never infer from UserId % n on the client. ]]
function DistrictManager.syncDistrictAttribute(player: Player): ()
	if #Settings.districts == 0 then
		player:SetAttribute("ElectionDistrictId", nil)
		return
	end
	local d = DistrictManager.getDistrict(player)
	if d then
		player:SetAttribute("ElectionDistrictId", d.districtId)
	else
		player:SetAttribute("ElectionDistrictId", nil)
	end
end

local function districtById(districtId: string): Types.District?
	for _, d in ipairs(Settings.districts) do
		if d.districtId == districtId then
			return d
		end
	end
	return nil
end

local function isKnownDistrictId(districtId: string): boolean
	return districtById(districtId) ~= nil
end

-- Load per constituency: cast votes (store) + session assignments not yet written as a vote record.
local function voteCountsByDistrict(): { [string]: number }
	local counts: { [string]: number } = {}
	for _, d in ipairs(Settings.districts) do
		counts[d.districtId] = 0
	end
	if voteStore and voteStore.getAllVotes then
		local votes = voteStore:getAllVotes()
		for _, rec in ipairs(votes) do
			local did = rec.districtId
			if type(did) == "string" and counts[did] ~= nil then
				counts[did] += 1
			end
		end
	end
	if voteStore and voteStore.getVoteRecord then
		for uid, did in pairs(userIdToDistrictId) do
			if type(did) == "string" and counts[did] ~= nil then
				local rec = voteStore:getVoteRecord(uid)
				if not rec then
					counts[did] += 1
				end
			end
		end
	end
	return counts
end

-- Pick district with minimum load (cast votes + pending assignments). Ties choose uniformly at random among tied districts.
local function pickDistrictByVoteBalance(): Types.District
	local counts = voteCountsByDistrict()
	local minN = math.huge
	for _, d in ipairs(Settings.districts) do
		local n = counts[d.districtId] or 0
		if n < minN then
			minN = n
		end
	end
	local tied: { Types.District } = {}
	for _, d in ipairs(Settings.districts) do
		if (counts[d.districtId] or 0) == minN then
			table.insert(tied, d)
		end
	end
	return tied[balanceRng:NextInteger(1, #tied)]
end

local function assignAndCache(userId: string, district: Types.District): Types.District
	userIdToDistrictId[userId] = district.districtId
	return district
end

function DistrictManager.getConstituencyIdFromCandidate(candidate: Types.Candidate): string?
	for _, tag in ipairs(candidate.policyTags) do
		local prefix = "constituency:"
		if string.sub(tag, 1, #prefix) == prefix then
			return string.sub(tag, #prefix + 1)
		end
	end
	return nil
end

function DistrictManager.isBallotAllowedForDistrict(ballot: Types.Ballot, district: Types.District?): boolean
	if not district then
		return true
	end
	local entry = ballot[1]
	if not entry or not entry.candidateId then
		return false
	end
	for _, c in ipairs(Settings.candidates) do
		if c.candidateId == entry.candidateId then
			local cid = DistrictManager.getConstituencyIdFromCandidate(c)
			return cid == district.districtId
		end
	end
	return false
end

function DistrictManager.getDistrict(player: Player): Types.District?
	if #Settings.districts == 0 then
		return nil
	end
	local uid = tostring(player.UserId)

	local explicitDistrictId = player:GetAttribute("DistrictId")
	if type(explicitDistrictId) == "string" then
		for _, district in ipairs(Settings.districts) do
			if district.districtId == explicitDistrictId then
				return assignAndCache(uid, district)
			end
		end
	end

	if voteStore and voteStore.getVoteRecord then
		local rec = voteStore:getVoteRecord(uid)
		if rec and type(rec.districtId) == "string" and isKnownDistrictId(rec.districtId) then
			local d = districtById(rec.districtId) :: Types.District
			userIdToDistrictId[uid] = d.districtId
			return d
		end
	end

	local cached = userIdToDistrictId[uid]
	if cached then
		local d = districtById(cached)
		if d then
			return d
		end
		userIdToDistrictId[uid] = nil
	end

	return assignAndCache(uid, pickDistrictByVoteBalance())
end

function DistrictManager.getDistrictVotes(districtId: string, votes: { Types.VoteRecord }): { Types.VoteRecord }
	local filtered: { Types.VoteRecord } = {}
	for _, vote in ipairs(votes) do
		if vote.districtId == districtId then
			table.insert(filtered, vote)
		end
	end
	return filtered
end

return DistrictManager
