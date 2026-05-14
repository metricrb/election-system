# Settings Configuration Guide

All election behavior is controlled in **ServerScriptService → ElectionManager → Settings.lua**

This guide walks through each setting so you know what to change.

## Opening Settings.lua

1. In Roblox Studio, expand **ServerScriptService** in the Explorer
2. Expand **ElectionManager** folder
3. Click on **Settings.lua** (opens in the Script Editor)
4. You'll see a long list of settings

## Essential Settings (Start Here)

### 1. Election Title & Country

```lua
countryId = "MyGame",
ui = {
    electionTitle = "President of MyGame",
    accentColour = { r = 0, g = 100, b = 255 },  -- Blue (RGB 0-255)
    placeholderAvatarId = "0",
},
```

- **countryId** — Internal name for your election (can be anything, doesn't show to players)
- **electionTitle** — What players see at the top of the voting booth
- **accentColour** — Main color of the UI (change the RGB values)
  - Red: `{ r = 255, g = 0, b = 0 }`
  - Green: `{ r = 0, g = 255, b = 0 }`
  - Blue: `{ r = 0, g = 100, b = 255 }`

### 2. Voting Method

```lua
votingMethod = "FPTP",
```

Choose ONE voting method:

| Method | What It Does | Best For |
|--------|------------|----------|
| **FPTP** | Most votes wins (no ranking) | Simple, quick elections |
| **IRV** | Voters rank candidates; eliminates lowest until majority | Fair, representative |
| **Approval** | Voters approve multiple candidates | consensus-based |
| **Score** | Voters give scores to candidates (1-5 stars) | Detailed feedback |
| **TwoRound** | Two-round runoff if no majority | Guaranteed majority |
| **Borda** | Points awarded based on ranking | Proportional |
| **STV** | Multi-winner ranked choice | Multiple seats needed |
| **PartyListPR** | Party-based proportional | Party-focused |
| **MMP** | Hybrid (local + party votes) | Mixed representation |
| **Condorcet** | Pairwise comparisons | Theoretical best |
| **STAR** | Score then automatic runoff | Hybrid scoring |
| **Cumulative** | Voters allocate points across candidates | Budget-style voting |
| **Parallel** | Separate local & party votes | Dual ballot |
| **Sortition** | Random selection | Lottery style |

**Recommendation for beginners:** Use `"FPTP"` or `"IRV"` (ranked choice is popular and fair).

### 3. Voting Times

```lua
openAt = 1700000000,    -- Unix timestamp when voting opens
closeAt = 1700086400,   -- Unix timestamp when voting closes
```

**Problem:** Unix timestamps are confusing. Use this website:
- Go to **unixtimestamp.com**
- Choose your open date/time
- Copy the number into `openAt`
- Choose your close date/time
- Copy into `closeAt`

**Example:**
```lua
openAt = 1735689600,    -- Jan 1, 2025, 12:00 PM UTC
closeAt = 1735776000,   -- Jan 2, 2025, 12:00 PM UTC
```

⚠️ **Don't set times in the past!** Your election will skip straight to "Closed" phase.

### 4. Candidates

```lua
candidates = {
    { candidateId = "alice", userId = "0", name = "Alice", bio = "Candidate for President", policyTags = {}, partyId = nil },
    { candidateId = "bob", userId = "0", name = "Bob", bio = "Candidate for President", policyTags = {}, partyId = nil },
},
```

**For each candidate:**
- **candidateId** — Internal unique ID (use lowercase, no spaces)
- **name** — What players see
- **userId** — Can be "0" (doesn't matter for place file users)
- **bio** — Short description
- **partyId** — Which party they belong to (can be `nil` for non-party elections)

**Example:**
```lua
candidates = {
    { candidateId = "john_smith", userId = "0", name = "John Smith", bio = "Experienced leader with 10 years in government", policyTags = {}, partyId = nil },
    { candidateId = "jane_doe", userId = "0", name = "Jane Doe", bio = "Community organizer focused on local issues", policyTags = {}, partyId = nil },
},
```

### 5. Parties (Optional, for party-based elections)

```lua
parties = {
    { partyId = "dems", name = "Democratic Party", decalId = 0, colour = { r = 0, g = 100, b = 255 }, description = "Left-leaning party" },
    { partyId = "reps", name = "Republican Party", decalId = 0, colour = { r = 255, g = 0, b = 0 }, description = "Right-leaning party" },
},
```

Only needed if your candidates belong to parties. Otherwise leave as empty:
```lua
parties = {},
```

## Eligibility Settings (Who Can Vote?)

```lua
eligibility = {
    minGroupRank = { groupId = 0, minRank = 0 },  -- 0 = don't check
    minAccountAgeDays = 0,                         -- 0 = no age requirement
    bannedGroupIds = {},
    bannedUsernames = {},
},
```

### Examples

**Allow everyone to vote:**
```lua
eligibility = {
    minGroupRank = { groupId = 0, minRank = 0 },
    minAccountAgeDays = 0,
    bannedGroupIds = {},
    bannedUsernames = {},
},
```

**Require players in a specific group with minimum rank:**
```lua
eligibility = {
    minGroupRank = { groupId = 12345, minRank = 5 },  -- Replace 12345 with your group ID
    minAccountAgeDays = 0,
    bannedGroupIds = {},
    bannedUsernames = {},
},
```

**Ban specific usernames:**
```lua
eligibility = {
    minGroupRank = { groupId = 0, minRank = 0 },
    minAccountAgeDays = 0,
    bannedGroupIds = {},
    bannedUsernames = { "BadPlayer", "AltAccount" },
},
```

**Require accounts to be at least 30 days old:**
```lua
eligibility = {
    minGroupRank = { groupId = 0, minRank = 0 },
    minAccountAgeDays = 30,
    bannedGroupIds = {},
    bannedUsernames = {},
},
```

## Alt Detection (Prevent Cheating)

```lua
altDetection = {
    enabled = false,
    onDetect = "InvalidateVote",  -- or "KickWithScreen"
    heuristic = "both",
    rapidVoteThresholdSeconds = 2,
},
```

**What is it?** Detects if someone is voting multiple times from different accounts.

**Settings:**
- **enabled** — `true` to turn on, `false` to turn off
- **onDetect** — `"InvalidateVote"` (reject the alt's vote) or `"KickWithScreen"` (kick from game)
- **rapidVoteThresholdSeconds** — If 2 accounts vote within 2 seconds, flag as suspicious

**Recommendation:** Leave as `false` for testing, turn on `true` in production.

## Administrative Settings

```lua
cmdr = {
    adminGroupId = 0,
    adminMinRank = 0,
},
```

If you have admin commands, set your group ID and minimum rank. Otherwise leave as 0.

## Discord webhook (optional, server-only)

You can mirror **admin-facing** alerts to a Discord channel (successful votes, rejected votes including eligibility/ban-rule denials, alt-detection signals, and optionally phase transitions). Runs **only on the server** inside `DiscordNotifier`; it does **not** use Cmdr roles (your Discord admins see the channel you choose).

### Security

- The webhook URL belongs in **`Settings.lua` on the server only**. Treat it like a password: anyone with the URL can post to your channel.
- **`RequestElectionConfig` never sends `discord`** (nor `cmdr`, `countryId`, or full `Settings`) to clients. Only UI-safe fields — voting method, seats, threshold, allocation method, `ui`, `parties`, `candidates` — are returned.

### Requirements

1. In **Home → Game Settings → Security**, turn **Allow HTTP Requests** **ON** (published games may already allow this depending on configuration). Without HTTP access, webhook posts fail silently with a `[DiscordNotifier]` warning in server output.

### Configuration (`discord` block)

```lua
discord = {
    enabled = false,              -- set true after pasting webhookUrl
    webhookUrl = "",               -- full URL from Discord: Server Settings → Integrations → Webhooks
    botUsername = "ElectionNotifier",  -- optional display name on Discord
    notifyVoteRecorded = true,      -- votes that stay recorded (not alt-flag invalidated)
    notifyVoteDenied = true,        -- ineligible / duplicate vote / invalid ballot
    notifyAltFlag = true,           -- alt heuristic triggered (invalidate or kick path)
    notifyPhaseChanges = false,     -- set true if you want every phase transition posted
},
```

If `enabled` is `false`, or `webhookUrl` is empty, nothing is posted.

Discord webhook overview: https://discord.com/developers/docs/resources/webhook

## Government & Seat Settings

```lua
governmentType = "Presidential",
seatSystem = "SingleMemberDistrict",
seats = 1,
seatAllocationMethod = "DHondt",
threshold = 0,
runoffThreshold = 0.5,
compulsoryVoting = false,
electoralCollege = false,
```

**For beginners:** Leave all of these as default. They're for advanced setups.

## Districts (For Geographic Elections)

```lua
districts = {},
```

Leave as empty list `{}` unless you want to divide voting by districts. Example:

```lua
districts = {
    { districtId = "north", name = "North District", seats = 5 },
    { districtId = "south", name = "South District", seats = 5 },
},
```

## Complete Example: Simple Two-Candidate Election

```lua
countryId = "MyGame",
votingMethod = "FPTP",
governmentType = "Presidential",

openAt = 1735689600,    -- Jan 1, 2025, 12:00 PM
closeAt = 1735776000,   -- Jan 2, 2025, 12:00 PM

candidates = {
    { candidateId = "alice", userId = "0", name = "Alice", bio = "Experienced leader", policyTags = {}, partyId = nil },
    { candidateId = "bob", userId = "0", name = "Bob", bio = "Change maker", policyTags = {}, partyId = nil },
},

parties = {},

eligibility = {
    minGroupRank = { groupId = 0, minRank = 0 },
    minAccountAgeDays = 0,
    bannedGroupIds = {},
    bannedUsernames = {},
},

altDetection = {
    enabled = false,
    onDetect = "InvalidateVote",
    heuristic = "both",
    rapidVoteThresholdSeconds = 2,
},

cmdr = {
    adminGroupId = 0,
    adminMinRank = 255,
},

discord = {
    enabled = false,
    webhookUrl = "",
    botUsername = "ElectionNotifier",
    notifyVoteRecorded = true,
    notifyVoteDenied = true,
    notifyAltFlag = true,
    notifyPhaseChanges = false,
},

ui = {
    electionTitle = "Presidential Election",
    accentColour = { r = 0, g = 100, b = 255 },
    placeholderAvatarId = "0",
},

clearPlayerVoteOnJoin = false,
```

## Saving Your Changes

After editing Settings.lua:
1. Press **Ctrl+S** (or **Cmd+S** on Mac) to save
2. Click the green **Play** button to test

## Troubleshooting

**"votingMethod unknown"**
- Make sure you spelled it correctly (case-sensitive). `"FPTP"` not `"fptp"`.

**"No candidates found"**
- The `candidates` table is empty. Add at least one candidate.

**"Times are in the past"**
- Set new times using unixtimestamp.com. Make sure `openAt` is before `closeAt`.

**"Can't vote" or "You are ineligible"**
- Check your `eligibility` settings. You might have set a group requirement or ban list that blocks yourself.

**Discord webhook not firing**
- Set `discord.enabled = true` and paste a valid webhook URL (`https://discord.com/api/webhooks/...`).
- Enable **Allow HTTP Requests** under Game Settings → Security.
- If the URL leaked, regenerate the webhook in Discord and update `webhookUrl`.

---

Next: [Custom UI Implementation](CUSTOM_UI.md)
