--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage:WaitForChild("ElectionSystemShared"):WaitForChild("ClientSettings"))

local CountdownScreen = require(script.Components.CountdownScreen)
local CandidateBrowser = require(script.Components.CandidateBrowser)
local BallotComponent = require(script.Components.BallotComponent)
local VoteConfirmation = require(script.Components.VoteConfirmation)
local ResultsView = require(script.Components.ResultsView)
local HUDBar = require(script.Components.HUDBar)
local KickScreen = require(script.Components.KickScreen)
local AlreadyVotedScreen = require(script.Components.AlreadyVotedScreen)
local IneligibleScreen = require(script.Components.IneligibleScreen)
local ThankYouScreen = require(script.Components.ThankYouScreen)

local ElectionUI = {}

function ElectionUI.mount()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ElectionSystemUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromScale(1, 1)
	container.Parent = screenGui

	local views = {
		Countdown = CountdownScreen({ text = "Election opens soon", position = UDim2.fromScale(0, 0.08), size = UDim2.fromScale(1, 0.92) }),
		Candidates = CandidateBrowser({ text = "Browse candidates", visible = false, position = UDim2.fromScale(0, 0.08), size = UDim2.fromScale(1, 0.92) }),
		Ballot = BallotComponent({ votingMethod = Settings.votingMethod, text = "Cast your vote", visible = false, position = UDim2.fromScale(0, 0.08), size = UDim2.fromScale(1, 0.92) }),
		Confirmation = VoteConfirmation({ text = "Confirm your ballot", visible = false, position = UDim2.fromScale(0, 0.08), size = UDim2.fromScale(1, 0.92) }),
		Results = ResultsView({ text = "Results", visible = false, position = UDim2.fromScale(0, 0.08), size = UDim2.fromScale(1, 0.92) }),
		Kick = KickScreen({ text = "Account flagged", visible = false, position = UDim2.fromScale(0, 0.08), size = UDim2.fromScale(1, 0.92), backgroundColor3 = Color3.fromRGB(90, 30, 30) }),
		AlreadyVoted = AlreadyVotedScreen({ text = "You have already voted", visible = false, position = UDim2.fromScale(0, 0.08), size = UDim2.fromScale(1, 0.92) }),
		Ineligible = IneligibleScreen({ text = "You are not eligible", visible = false, position = UDim2.fromScale(0, 0.08), size = UDim2.fromScale(1, 0.92) }),
		ThankYou = ThankYouScreen({ text = "Thank you for voting", visible = false, position = UDim2.fromScale(0, 0.08), size = UDim2.fromScale(1, 0.92) }),
	}

	local hud = HUDBar({
		text = Settings.ui.electionTitle,
		size = UDim2.fromScale(1, 0.08),
		position = UDim2.fromScale(0, 0),
	})
	hud.Parent = container

	for _, view in pairs(views) do
		view.Parent = container
	end

	local function show(target)
		for name, view in pairs(views) do
			view.Visible = name == target
		end
	end

	show("Countdown")

	return {
		setPhase = function(nextPhase)
			if nextPhase == "Open" then
				show("Candidates")
			elseif nextPhase == "ResultsOut" then
				show("Results")
			end
		end,
		showBallot = function()
			show("Ballot")
		end,
		showResults = function(_results)
			show("Results")
		end,
		showAlreadyVoted = function()
			show("AlreadyVoted")
		end,
		showIneligible = function(_reason)
			show("Ineligible")
		end,
		showKick = function()
			show("Kick")
		end,
		showThankYou = function()
			show("ThankYou")
		end,
		unmount = function()
			screenGui:Destroy()
		end,
	}
end

return ElectionUI
