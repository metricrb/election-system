--!strict

local Signal = require(script.Parent.Parent.Signal)

--[[
	@class Network
	@within ElectionSystem

	Creates and manages RemoteEvents/RemoteFunctions for client-server communication.
]]

local Network = {}
local remoteFolder: Folder?

function Network.init()
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "ElectionSystemRemotes"
	remoteFolder.Parent = game:GetService("ReplicatedStorage")

	-- Server → client
	Network.createRemoteEvent("PhaseChanged")
	Network.createRemoteEvent("BallotOpened")
	Network.createRemoteEvent("ResultsPublished")
	Network.createRemoteEvent("ElectionStateUpdated")
	Network.createRemoteEvent("AlreadyVoted")
	Network.createRemoteEvent("AltDetectedClient")
	Network.createRemoteEvent("IneligibleResult")
	Network.createRemoteEvent("DebugElectionToggle")

	-- Client ↔ server (RemoteFunctions)
	Network.createRemoteFunction("SubmitVote")
	Network.createRemoteFunction("RequestState")
	Network.createRemoteFunction("RequestElectionConfig")
	Network.createRemoteFunction("RequestDebugState")
end

function Network.createRemoteEvent(name: string)
	if not remoteFolder then return end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remoteFolder
end

function Network.createRemoteFunction(name: string)
	if not remoteFolder then return end
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = remoteFolder
end

function Network.getRemote(name: string)
	if not remoteFolder then return nil end
	return remoteFolder:FindFirstChild(name)
end

return Network
