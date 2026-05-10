--!strict

local Types = require(script.Parent.Types)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProfileService = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("ProfileService"))
local Settings = require(script.Parent.Parent.Settings)

--[=[
	@class Data

	ProfileService integration for persistent player profile data.
]=]

local Data = {}
local profiles: { [number]: any } = {}

local profileTemplate = {
	Elections = {},
}

local store = ProfileService.GetProfileStore("ElectionPlayerData", profileTemplate)

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

return Data
