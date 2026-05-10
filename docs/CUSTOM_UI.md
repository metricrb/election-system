# Custom UI Implementation Guide

The election system works with **any UI you build**. This guide shows you how to create your own voting booth or integrate voting into existing UI.

## How It Works (High Level)

The voting process has two parts:

1. **Client Side (GUI)** — What players see and click on
2. **Server Side (ElectionManager)** — Records votes and calculates results

Your custom UI sends the player's choices to the server via a **RemoteFunction**, which is Roblox's way of client-server communication.

```
Player clicks "Vote for Alice"
    ↓
Your UI collects the vote
    ↓
Sends to server via RemoteFunction
    ↓
Server validates and saves vote
    ↓
Server notifies all players (vote was recorded)
```

## Step 1: Access the Election System from Your Script

In your **LocalScript** (client-side), get access to the election system:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ElectionSystemRemotes = ReplicatedStorage:WaitForChild("ElectionSystemRemotes")

-- Get the remote functions
local submitVoteRemote = ElectionSystemRemotes:WaitForChild("SubmitVote")
local requestConfigRemote = ElectionSystemRemotes:WaitForChild("RequestElectionConfig")
local requestStateRemote = ElectionSystemRemotes:WaitForChild("RequestState")

-- Listen for state updates
local stateUpdatedEvent = ElectionSystemRemotes:WaitForChild("ElectionStateUpdated")
local resultsPublishedEvent = ElectionSystemRemotes:WaitForChild("ResultsPublished")
```

## Step 2: Get Election Info

When your UI loads, fetch the candidates and voting method:

```lua
local config = requestConfigRemote:InvokeServer()

print("Voting Method:", config.votingMethod)
print("Candidates:")
for _, candidate in ipairs(config.candidates) do
    print("  - " .. candidate.name .. " (" .. candidate.candidateId .. ")")
end
print("Parties:")
for _, party in ipairs(config.parties) do
    print("  - " .. party.name)
end
```

**What you get back:**
- `votingMethod` — "FPTP", "IRV", "Approval", etc.
- `candidates` — Array of candidates with name, bio, etc.
- `parties` — Array of parties (if applicable)
- `governmentType` — "Presidential", "Parliamentary", etc.
- `seats` — Number of seats (for multi-seat elections)

## Step 3: Display the Ballot

Create a UI that shows:
- **Candidate names** (from `config.candidates`)
- **Selection method based on voting method:**

### FPTP (Single Choice)

```lua
-- Create radio buttons or dropdown for single candidate
for _, candidate in ipairs(config.candidates) do
    local button = Instance.new("TextButton")
    button.Name = candidate.candidateId
    button.Text = candidate.name
    button.Parent = yourUIContainer
    
    button.Activated:Connect(function()
        -- Create ballot: one entry for this candidate
        local ballot = {
            { candidateId = candidate.candidateId, rank = 1 }
        }
        submitBallot(ballot)
    end)
end
```

### IRV (Ranked Choice)

```lua
-- Create drag-and-drop or up/down arrows to rank candidates
-- Each candidate gets a rank number

local ballot = {
    { candidateId = "alice", rank = 1 },      -- 1st choice
    { candidateId = "bob", rank = 2 },        -- 2nd choice
    { candidateId = "carol", rank = 3 },      -- 3rd choice
}
submitBallot(ballot)
```

### Approval Voting

```lua
-- Create checkboxes - voters select multiple candidates they approve of

local ballot = {
    { candidateId = "alice", approved = true },
    { candidateId = "bob", approved = true },
    { candidateId = "carol", approved = false },
}
submitBallot(ballot)
```

### Score Voting (1-5 Stars)

```lua
-- Create star sliders for each candidate

local ballot = {
    { candidateId = "alice", score = 5 },    -- 5 stars
    { candidateId = "bob", score = 3 },      -- 3 stars
    { candidateId = "carol", score = 1 },    -- 1 star
}
submitBallot(ballot)
```

## Step 4: Submit the Vote

Create a function to send the ballot to the server:

```lua
local function submitBallot(ballot)
    -- Show "Submitting..." message
    statusLabel.Text = "Submitting your vote..."
    
    -- Send to server
    local success = submitVoteRemote:InvokeServer(ballot)
    
    if success then
        statusLabel.Text = "✓ Vote recorded! Thank you for voting."
        -- Disable voting buttons so they can't vote again
        voteButton.Enabled = false
    else
        statusLabel.Text = "✗ Your vote was rejected. See chat for details."
    end
end
```

## Step 5: Listen for Updates

Show players when votes are recorded and when results are ready:

```lua
-- Listen for state changes (whenever a vote is recorded)
stateUpdatedEvent.OnClientEvent:Connect(function(state)
    -- Update vote count display
    voteCountLabel.Text = "Votes recorded: " .. state.countdown
end)

-- Listen for results
resultsPublishedEvent.OnClientEvent:Connect(function(results)
    -- Show winners
    if results.winner then
        if typeof(results.winner) == "table" and results.winner[1] then
            -- Multiple winners
            print("Winners:")
            for _, winner in ipairs(results.winner) do
                print("  - " .. winner.name)
            end
        else
            -- Single winner
            print("Winner: " .. results.winner.name)
        end
    end
    
    -- Show vote percentages
    for candidateId, percentage in pairs(results.voteShare) do
        print(candidateId .. ": " .. percentage .. "%")
    end
end)
```

## Complete Example: Simple FPTP Voting Booth

Here's a working example you can copy and modify:

**Create a LocalScript in StarterPlayer → StarterPlayerScripts:**

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Get election system remotes
local ElectionSystemRemotes = ReplicatedStorage:WaitForChild("ElectionSystemRemotes")
local submitVoteRemote = ElectionSystemRemotes:WaitForChild("SubmitVote")
local requestConfigRemote = ElectionSystemRemotes:WaitForChild("RequestElectionConfig")
local stateUpdatedEvent = ElectionSystemRemotes:WaitForChild("ElectionStateUpdated")
local resultsPublishedEvent = ElectionSystemRemotes:WaitForChild("ResultsPublished")

-- Fetch election config
local config = requestConfigRemote:InvokeServer()

-- Create a simple UI (ScreenGui with buttons)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VotingBooth"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Title
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Text = config.ui.electionTitle or "Vote Now"
title.Size = UDim2.new(1, 0, 0.1, 0)
title.Position = UDim2.new(0, 0, 0, 0)
title.TextScaled = true
title.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Parent = screenGui

-- Candidates container
local candidatesFrame = Instance.new("Frame")
candidatesFrame.Name = "Candidates"
candidatesFrame.Size = UDim2.new(1, 0, 0.7, 0)
candidatesFrame.Position = UDim2.new(0, 0, 0.1, 0)
candidatesFrame.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
candidatesFrame.Parent = screenGui

-- UIListLayout to arrange buttons vertically
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Parent = candidatesFrame
uiListLayout.Padding = UDim.new(0, 10)

-- Create a button for each candidate
for i, candidate in ipairs(config.candidates) do
    local button = Instance.new("TextButton")
    button.Name = candidate.candidateId
    button.Text = candidate.name .. "\n" .. candidate.bio
    button.Size = UDim2.new(1, -20, 0, 80)
    button.BackgroundColor3 = Color3.fromRGB(0, 100, 255)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextScaled = true
    button.Parent = candidatesFrame
    
    button.Activated:Connect(function()
        -- Create ballot for FPTP (single vote)
        local ballot = {
            { candidateId = candidate.candidateId, rank = 1 }
        }
        
        -- Submit vote
        local success = submitVoteRemote:InvokeServer(ballot)
        
        -- Show result
        if success then
            title.Text = "✓ Vote Recorded!"
            title.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
            -- Disable all buttons
            for _, btn in ipairs(candidatesFrame:GetChildren()) do
                if btn:IsA("TextButton") then
                    btn.Enabled = false
                end
            end
        else
            title.Text = "✗ Vote Failed"
            title.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
        end
    end)
end

-- Status label
local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Text = "Select a candidate to vote"
statusLabel.Size = UDim2.new(1, 0, 0.2, 0)
statusLabel.Position = UDim2.new(0, 0, 0.8, 0)
statusLabel.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.TextScaled = true
statusLabel.Parent = screenGui

-- Listen for results
resultsPublishedEvent.OnClientEvent:Connect(function(results)
    statusLabel.Text = "Results: " .. results.winner.name .. " wins!"
end)
```

## Ballot Format Reference

Each ballot is an array of entries. Format depends on the voting method:

### FPTP (First-Past-The-Post)
```lua
{ { candidateId = "alice", rank = 1 } }
```

### IRV (Instant Runoff Voting)
```lua
{
    { candidateId = "alice", rank = 1 },
    { candidateId = "bob", rank = 2 },
    { candidateId = "carol", rank = 3 },
}
```

### Approval Voting
```lua
{
    { candidateId = "alice", approved = true },
    { candidateId = "bob", approved = true },
    { candidateId = "carol", approved = false },
}
```

### Score/Range Voting
```lua
{
    { candidateId = "alice", score = 5 },
    { candidateId = "bob", score = 3 },
    { candidateId = "carol", score = 1 },
}
```

## Remote Functions Reference

| Remote | Direction | Purpose | Example |
|--------|-----------|---------|---------|
| **SubmitVote** | Client → Server | Submit a ballot | `submitVoteRemote:InvokeServer(ballot)` |
| **RequestState** | Client → Server | Get current phase, votes, results | `requestStateRemote:InvokeServer()` |
| **RequestElectionConfig** | Client → Server | Get candidates, parties, voting method | `requestConfigRemote:InvokeServer()` |
| **RequestDebugState** | Client → Server | Get debug info (phase, countdown) | `debugRemote:InvokeServer()` |

## Remote Events Reference

| Event | Direction | Fires When |
|-------|-----------|-----------|
| **PhaseChanged** | Server → Client | Election phase changes |
| **ElectionStateUpdated** | Server → Client | Any vote is recorded |
| **ResultsPublished** | Server → Client | Results calculated |
| **AlreadyVoted** | Server → Client | Player tries to vote twice |
| **AltDetectedClient** | Server → Client | Alt account suspected |
| **IneligibleResult** | Server → Client | Player doesn't meet requirements |

## Tips for Custom UI

1. **Test with multiple players** — Open multiple play sessions in Studio to test multiplayer voting
2. **Handle errors gracefully** — Check the return value of `submitVoteRemote:InvokeServer(ballot)`
3. **Show phase status** — Display whether voting is "Scheduled", "Open", "Closed", etc.
4. **Disable after voting** — Once someone votes, disable their voting buttons
5. **Use proper ballot format** — Wrong ballot format will get rejected by server

## Troubleshooting

**"RemoteFunction not found"**
- Make sure the server is running (click Play). The remotes are created when ElectionManager initializes.

**"Vote was rejected"**
- Ballot format might be wrong. Check the [Ballot Format Reference](#ballot-format-reference) above.
- Player might not be eligible (check [Settings Configuration](SETTINGS_SETUP.md)).

**"Players can vote multiple times"**
- The server should prevent this automatically. If not, disable vote buttons after `success == true`.

**"Results don't show"**
- Make sure you're listening to `resultsPublishedEvent`. Results are calculated when an admin calls the calculation function or when the phase changes.

---

Previous: [Settings Configuration](SETTINGS_SETUP.md)
