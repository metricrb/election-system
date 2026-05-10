--!strict

local Signal = require(script.Parent.Parent.Signal)

--[=[
	@class Network
	@tag State Management

	Creates and manages RemoteEvents and RemoteFunctions for client-server communication.

	Network is initialized automatically by ElectionManager.init(). It sets up 8 RemoteEvents
	and 4 RemoteFunctions in ReplicatedStorage.ElectionSystemRemotes.

	## RemoteEvents (Server → Clients)
	- **PhaseChanged** — Current election phase updated
	- **BallotOpened** — Voting ballot opened
	- **ResultsPublished** — Election results calculated
	- **ElectionStateUpdated** — General state sync (votes, phase, countdown)
	- **AlreadyVoted** — Player denied (duplicate vote attempt)
	- **AltDetectedClient** — Alt account detected (shows kick screen)
	- **IneligibleResult** — Player denied (eligibility failed)
	- **DebugElectionToggle** — Admin debug mode toggled

	## RemoteFunctions (Client ↔ Server)
	- **SubmitVote** — Player submits ballot; returns boolean success
	- **RequestState** — Client requests current election state
	- **RequestElectionConfig** — Client requests election settings
	- **RequestDebugState** — Client requests phase/countdown/hasVoted (debug only)

	## Usage

	```lua
	-- Server side: send phase change to all clients
	local phaseChangedRemote = Network.getRemote("PhaseChanged")
	if phaseChangedRemote then
		phaseChangedRemote:FireAllClients("Open")
	end

	-- Client side: listen for phase changes
	Network.getRemote("PhaseChanged").OnClientEvent:Connect(function(newPhase)
		print("Phase:", newPhase)
	end)
	```
]=]

local Network = {}
local remoteFolder: Folder?

--[=[
	@function init
	@within Network

	Initializes the network system by creating the ElectionSystemRemotes folder in ReplicatedStorage
	and instantiating all RemoteEvents and RemoteFunctions.

	Called automatically by ElectionManager.init().
]=]
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

--[=[
	@function createRemoteEvent
	@within Network
	@param name string

	Creates a RemoteEvent with the given name and parents it to ElectionSystemRemotes.
]=]
function Network.createRemoteEvent(name: string)
	if not remoteFolder then return end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remoteFolder
end

--[=[
	@function createRemoteFunction
	@within Network
	@param name string

	Creates a RemoteFunction with the given name and parents it to ElectionSystemRemotes.
]=]
function Network.createRemoteFunction(name: string)
	if not remoteFolder then return end
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = remoteFolder
end

--[=[
	@function getRemote
	@within Network
	@param name string
	@return Instance?

	Retrieves a RemoteEvent or RemoteFunction by name from ElectionSystemRemotes.

	```lua
	local submitVote = Network.getRemote("SubmitVote")
	if submitVote then
		local success = submitVote:InvokeClient(player, ballot)
	end
	```
]=]
function Network.getRemote(name: string)
	if not remoteFolder then return nil end
	return remoteFolder:FindFirstChild(name)
end

return Network
