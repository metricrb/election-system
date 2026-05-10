--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Iris: any = nil
do
	local packagesFolder = ReplicatedStorage:FindFirstChild("Packages")
	if packagesFolder then
		local irisModule = packagesFolder:FindFirstChild("Iris")
		if irisModule then
			Iris = require(irisModule)
		end
	end
end

local ElectionDebug = {}

function ElectionDebug.init(remotes: Folder, getLastSubmitOk: () -> boolean?)
	local showDebug = false
	local cached = {
		phase = "?",
		countdown = 0,
		hasVoted = false,
	}
	local irisStarted = false

	local function refreshServerState()
		local rf = remotes:FindFirstChild("RequestDebugState")
		if rf and rf:IsA("RemoteFunction") then
			local ok, data = pcall(function()
				return rf:InvokeServer()
			end)
			if ok and type(data) == "table" then
				cached.phase = tostring(data.phase or "?")
				cached.countdown = tonumber(data.countdown) or 0
				cached.hasVoted = data.hasVoted == true
			end
		end
	end

	local function ensureIris()
		if irisStarted or not Iris then
			return
		end
		irisStarted = true
		Iris.Init()
		Iris.UpdateGlobalConfig({ DisplayOrderOffset = 2_000_000 })
		Iris:Connect(function()
			if not showDebug then
				return
			end
			Iris.Window({ "Election debug" })
			Iris.Text({ string.format("Phase: %s", cached.phase) })
			Iris.Text({ string.format("Countdown (server): %ds", math.floor(cached.countdown)) })
			Iris.Text({ string.format("Has voted (server): %s", tostring(cached.hasVoted)) })
			local lastOk = if getLastSubmitOk then getLastSubmitOk() else nil
			local submitLine = if lastOk == nil
				then "Last submit (client): (none yet)"
				elseif lastOk then "Last submit (client): OK"
				else "Last submit (client): FAILED"
			Iris.Text({ submitLine })
			Iris.Text({ "(Toggle again with Cmdr: election_debug)" })
			Iris.End()
		end)
	end

	task.spawn(function()
		while true do
			task.wait(0.4)
			if showDebug then
				refreshServerState()
			end
		end
	end)

	local ev = remotes:WaitForChild("DebugElectionToggle", 10) :: RemoteEvent
	ev.OnClientEvent:Connect(function()
		showDebug = not showDebug
		if showDebug then
			ensureIris()
			refreshServerState()
		end
	end)
end

return ElectionDebug
