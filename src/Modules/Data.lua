--!strict

local Types = require(script.Parent.Types)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProfileService = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("ProfileService"))
local Settings = require(script.Parent.Parent.Settings)

--[[
	@class Data
	@within ElectionSystem

	ProfileService integration for persistent player profile data.
]]

local Data = {}
local profiles: { [number]: any } = {}

local profileTemplate = {
	Elections = {},
}

local store = ProfileService.GetProfileStore("ElectionPlayerData", profileTemplate)

function Data.init()
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

	local profile = store:LoadProfileAsync("Player_" .. tostring(userId), "ForceLoad")
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
	local profile = Data.loadProfile(userId)
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
	local profile = Data.loadProfile(userId)
	if not profile then
		return
	end

	profile.Data.Elections[Settings.countryId] = profile.Data.Elections[Settings.countryId] or {}
	profile.Data.Elections[Settings.countryId].voteRecord = voteRecord
	profile:Save()
end

return Data
