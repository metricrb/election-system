# Welcome to ElectionSystem

ElectionSystem is a universal, multi-method voting system for Roblox. It supports 14 different voting algorithms, comprehensive eligibility checking, alt detection, and real-time result calculation.

## Start Here

**First time?** Follow these steps in order:

1. **[Getting Started](GETTING_STARTED.md)** — Open the place file and verify it works (5 minutes)
2. **[DataStore Setup](DATASTORE_SETUP.md)** — Enable vote persistence (critical!)
3. **[Settings Configuration](SETTINGS_SETUP.md)** — Add candidates and configure your election (optional [Discord webhook](SETTINGS_SETUP.md#discord-webhook-optional-server-only) for staff alerts)
4. **[Custom UI Implementation](CUSTOM_UI.md)** — Build a custom voting interface

## What Can It Do?

- **14 voting methods:** FPTP, IRV, Approval, Score, STAR, Borda, Condorcet, STV, PartyListPR, MMP, Parallel, TwoRound, Cumulative, Sortition
- **Eligibility rules:** Group membership, account age, ban lists
- **Alt detection:** Prevent vote fraud with configurable heuristics
- **Multi-seat elections:** Districts, seat allocation, coalition support
- **Real-time results:** Live vote counts and result calculation
- **Player persistence:** Votes survive server restarts via DataStore
- **Full customization:** Voting method, candidates, UI, rules all configurable

## Key Concepts

### The Three Parts of ElectionSystem

1. **Settings (Your Config)** — Customize candidates, voting method, times, eligibility (optional **`discord`** block for admin-only webhook posts; never sent to clients)
2. **ElectionManager (Core System)** — Records votes, calculates results, manages state
3. **Your UI (What Players See)** — Any GUI you build that connects to the system via RemoteFunction

### The Voting Flow

```
Player joins game
    ↓
System loads their previous vote from storage
    ↓
[Voting Phase] Player selects candidates via your UI
    ↓
Server validates eligibility, ballot format, and detects alts
    ↓
Vote saved to DataStore
    ↓
All players notified
    ↓
[Closed Phase] Admin/system calculates results
    ↓
Results sent to all clients
```

## Quick Navigation

- **Setting up:** Start with [Getting Started](GETTING_STARTED.md)
- **Configuring elections:** Go to [Settings Configuration](SETTINGS_SETUP.md)
- **Building UI:** See [Custom UI Implementation](CUSTOM_UI.md)
- **API reference:** Check the auto-generated API documentation
- **Troubleshooting:** Each guide has a troubleshooting section

## Common Questions

**Do I need Rojo?**
No. Download the `.rbxl` place file and open it directly in Roblox Studio.

**How do I save votes?**
Enable DataStore (it's critical!). See [DataStore Setup](DATASTORE_SETUP.md).

**Can I use my own voting booth UI?**
Yes. See [Custom UI Implementation](CUSTOM_UI.md) for how to connect your UI to the system.

**Which voting method should I use?**
Start with FPTP (first-past-the-post, most votes wins) or IRV (ranked choice). See [Settings Configuration](SETTINGS_SETUP.md) for details.

**How do I prevent cheating?**
Use alt detection (detects rapid voting) and eligibility rules (group membership, account age, bans).

---

**Ready to begin?** → [Getting Started](GETTING_STARTED.md)
