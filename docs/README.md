# ElectionSystem Documentation

Complete guide to setting up and using the universal election system for Roblox.

## For Place File Users (You Downloaded .rbxl)

Start here if you downloaded `ElectionSystem.rbxl` and just want to get it working.

### Quick Start (5 minutes)

1. **[Getting Started Guide](GETTING_STARTED.md)** ← Start here
   - Open the place file
   - Enable DataStore (critical!)
   - Test it works

2. **[DataStore Setup](DATASTORE_SETUP.md)** ← Do this first!
   - Enable in Game Settings
   - Verify votes save
   - Troubleshoot if needed

3. **[Settings Configuration](SETTINGS_SETUP.md)** ← Configure your election
   - Add candidates
   - Set voting method (FPTP, IRV, Approval, etc.)
   - Set voting times
   - Configure eligibility rules

4. **[Custom UI Implementation](CUSTOM_UI.md)** ← Create your own voting booth
   - Build custom voting interface
   - Connect to election system
   - Display results

### Full Setup Checklist

```
□ Open ElectionSystem.rbxl in Roblox Studio
□ Enable DataStore (Game Settings → Security)
□ Verify DataStore works (check Output panel)
□ Edit Settings.lua with your candidates and voting method
□ Test voting in Studio
□ Create custom UI (or use default booth)
□ Publish to your game
□ Test with real players
```

## Key Concepts

### Voting Flow

```
Player joins game
    ↓
Loads previous vote from DataStore (if any)
    ↓
[Voting Phase]
    ↓
Player submits ballot via UI
    ↓
Server validates (eligibility, ballot format, alts)
    ↓
Vote saved to DataStore
    ↓
All players notified via event
    ↓
[Closed Phase]
    ↓
Admin/system calculates results
    ↓
Results sent to all clients
```

### The Three Core Systems

1. **Settings (Your Config)**
   - File: `ServerScriptService → ElectionManager → Settings.lua`
   - Controls: candidates, voting method, times, eligibility
   - You edit this to customize your election

2. **ElectionManager (Core System)**
   - File: `ServerScriptService → ElectionManager → init.module.lua`
   - Controls: vote recording, result calculation, state management
   - Auto-initializes when server starts
   - You don't edit this (it's the system core)

3. **Your UI (What Players See)**
   - Create as LocalScript in StarterPlayer
   - Sends votes to ElectionManager via RemoteFunction
   - Displays candidates, phases, and results
   - You build this or customize the default

## Voting Methods Explained

| Method | How It Works | Best For | Complexity |
|--------|------------|----------|-----------|
| **FPTP** | Most votes wins | Simple, quick elections | Easy |
| **IRV** | Rank candidates; eliminate losers until majority | Fair representation | Medium |
| **Approval** | Approve multiple candidates | Consensus building | Easy |
| **Score** | Give 1-5 stars to candidates | Detailed preference feedback | Medium |
| **TwoRound** | Two-round runoff if no majority | Guaranteed majority | Medium |
| **Borda** | Points for ranking position | Proportional | Hard |
| **Condorcet** | Pairwise comparisons | Theoretical fairness | Hard |
| **STV** | Multi-winner ranked choice | Multiple positions | Hard |
| **PartyListPR** | Party proportional representation | Party-focused elections | Hard |
| **Cumulative** | Allocate points across candidates | Budget voting | Medium |
| **STAR** | Score then automatic runoff | Hybrid scoring | Medium |
| **Parallel** | Separate local & party votes | Mixed representation | Hard |
| **MMP** | Mixed-member proportional | Balanced representation | Hard |
| **Sortition** | Random selection | Lottery-style | Easy |

**Recommendation:** Start with `FPTP` or `IRV` (most common and well-understood).

## File Structure You Need to Know

```
ServerScriptService/
├── ElectionManager/                    ← Main system (don't move!)
│   ├── Settings.lua                    ← ⭐ YOU EDIT THIS
│   ├── init.module.lua                 ← Core system (read-only)
│   ├── Modules/
│   │   ├── Store.lua                   ← In-memory vote storage
│   │   ├── Data.lua                    ← DataStore persistence
│   │   ├── Network.lua                 ← Client/server communication
│   │   ├── ResultCalculator.lua        ← Vote counting
│   │   ├── EligibilityChecker.lua      ← Voter validation
│   │   ├── AltDetector.lua             ← Prevent vote cheating
│   │   ├── VotingMethods/              ← 14 voting algorithms
│   │   │   ├── FPTP.lua
│   │   │   ├── IRV.lua
│   │   │   ├── Approval.lua
│   │   │   └── ... (others)
│   │   └── ... (other modules)
│   └── Signal.lua                      ← Event system

ReplicatedStorage/
├── Packages/                           ← Dependencies
│   └── ProfileService/                 ← DataStore library
```

## Common Tasks

### Add a Candidate
Edit `Settings.lua`:
```lua
candidates = {
    { candidateId = "alice", userId = "0", name = "Alice", bio = "...", policyTags = {}, partyId = nil },
    -- Add more here
}
```

### Change Voting Method
Edit `Settings.lua`:
```lua
votingMethod = "IRV",  -- or "FPTP", "Approval", etc.
```

### Set Voting Times
Use https://unixtimestamp.com to convert dates:
```lua
openAt = 1735689600,    -- Jan 1, 2025 12:00 PM UTC
closeAt = 1735776000,   -- Jan 2, 2025 12:00 PM UTC
```

### Create Custom UI
See [Custom UI Implementation Guide](CUSTOM_UI.md)

### Prevent Cheating (Alt Detection)
Edit `Settings.lua`:
```lua
altDetection = {
    enabled = true,
    onDetect = "InvalidateVote",
    heuristic = "both",
}
```

### Require Players to Have Been in Your Group
Edit `Settings.lua`:
```lua
eligibility = {
    minGroupRank = { groupId = 12345, minRank = 1 },  -- Replace 12345
    minAccountAgeDays = 0,
    bannedGroupIds = {},
    bannedUsernames = {},
}
```

## Remote Functions (For UI Developers)

### SubmitVote
Send a ballot from client to server
```lua
local ballot = { { candidateId = "alice", rank = 1 } }
local success = submitVoteRemote:InvokeServer(ballot)
```

### RequestState
Get current election state (phase, votes, results)
```lua
local state = requestStateRemote:InvokeServer()
-- Returns: { phase, countdown, votes, results }
```

### RequestElectionConfig
Get candidates, parties, voting method
```lua
local config = requestConfigRemote:InvokeServer()
-- Returns: { candidates, parties, votingMethod, ... }
```

## Remote Events (For UI Developers)

### PhaseChanged
Fires when election phase changes (Scheduled → Open → Closed, etc.)
```lua
phaseChangedEvent.OnClientEvent:Connect(function(newPhase)
    print("Phase is now: " .. newPhase)
end)
```

### ElectionStateUpdated
Fires whenever any vote is recorded
```lua
stateUpdatedEvent.OnClientEvent:Connect(function(state)
    print("Vote count: " .. #state.votes)
end)
```

### ResultsPublished
Fires when election results are calculated
```lua
resultsPublishedEvent.OnClientEvent:Connect(function(results)
    print("Winner: " .. results.winner.name)
end)
```

## Troubleshooting

### Votes aren't saving
→ Go to [DataStore Setup Guide](DATASTORE_SETUP.md) and enable DataStore

### "Candidate not found" error
→ Check [Settings Configuration](SETTINGS_SETUP.md) - make sure candidates are spelled correctly

### Voting UI doesn't appear
→ Follow [Custom UI Implementation Guide](CUSTOM_UI.md)

### Phase doesn't change
→ Check Settings.lua - times might be in the past. Use https://unixtimestamp.com

### Players can vote multiple times
→ Server prevents this automatically; if not working, disable vote buttons after vote succeeds

### Results look wrong
→ Wrong voting method selected? Check [Voting Methods](#voting-methods-explained) above

## API Documentation (For Developers)

For detailed API reference of all modules:

- **ElectionManager** — Main election control and voting
- **Store** — In-memory election state
- **Data** — DataStore persistence
- **Network** — Client/server communication
- **ResultCalculator** — Vote counting algorithms
- **EligibilityChecker** — Voter validation
- **AltDetector** — Fraud detection
- **BallotFormatter** — Vote formatting
- **Types** — TypeScript-style type definitions
- **VotingMethods** — Individual voting algorithm implementations

See the generated Moonwave API docs for complete references.

## Performance Notes

- **Large elections (1000+ votes):** IRV might be slow. Use FPTP for speed.
- **Many candidates (50+):** Increase UI responsiveness by paginating ballot display.
- **Concurrent players (100+):** Monitor DataStore request rate; Roblox has limits.

## Support & Contributing

- Found a bug? Open an issue on GitHub
- Want to add a voting method? See VotingMethods/ folder structure
- Questions? Check the guides above first, then see API docs

---

**Start with:** [Getting Started Guide](GETTING_STARTED.md)
