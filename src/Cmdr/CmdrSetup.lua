--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Settings = require(script.Parent.Parent.Settings)
local Signal = require(script.Parent.Parent.Signal)
local Cmdr = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Cmdr"))

local CmdrSetup = {}

local chartMode = "bar"
local chartModeChanged = Signal.new()

local function canRun(player: Player): boolean
	local cfg = Settings.cmdr
	if cfg.adminGroupId <= 0 then
		return true
	end
	return player:GetRankInGroup(cfg.adminGroupId) >= cfg.adminMinRank
end

function CmdrSetup.getChartMode(): string
	return chartMode
end

function CmdrSetup.connectChartModeChanged(callback: () -> ())
	return chartModeChanged:connect(callback)
end

function CmdrSetup.register(electionManager)
	Cmdr.Registry:RegisterDefaultCommands()

	local commandsFolder = script:FindFirstChild("Commands")
	if not commandsFolder then
		local electionSystem = game:GetService("ServerScriptService"):WaitForChild("ElectionSystem", 5)
		local cmdrFolder = electionSystem and electionSystem:FindFirstChild("Cmdr")
		commandsFolder = cmdrFolder and cmdrFolder:FindFirstChild("Commands")
	end

	if commandsFolder then
		Cmdr.Registry:RegisterCommandsIn(commandsFolder)
	else
		warn("[CmdrSetup] Commands folder not found; custom election commands were not registered.")
	end

	Cmdr.Registry:RegisterHook("BeforeRun", function(context)
		if context.Group ~= "ElectionAdmin" then
			return
		end

		local executor = context.Executor
		if not executor or not canRun(executor) then
			return "You are not allowed to run election admin commands."
		end
	end)

	Cmdr.Registry:RegisterHook("AfterRun", function(context)
		if context.Name == "election_chart" then
			local modeArg = context.Arguments[1]
			if modeArg and modeArg.Value then
				chartMode = modeArg.Value
				chartModeChanged:fire()
			end
		elseif context.Name == "election_reset" then
			electionManager:getStore():clear()
		end
	end)
end

return CmdrSetup
