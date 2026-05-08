# Universal Roblox Election System — Implementation Plan

## Context

You are building a comprehensive, modular election system for Roblox that supports 14 different voting methods and multiple electoral structures/government models. The system must be:
- **Strictly typed** (`--!strict` throughout)
- **Configurable** via a single Settings.lua file
- **Published** as a .rbxm release artifact via GitHub Actions CI/CD
- **Built with Rojo** and sourced into ReplicatedStorage as an ElectionSystem ModuleScript tree
- **Tested** with TestEZ fixtures covering all voting methods, seat allocation, round management, eligibility, and alt detection

The current codebase has partial scaffolding (old Fusion 0.2 dependencies, skeleton modules) that needs a complete architectural rewrite to match the detailed specification.

---

## Implementation Strategy

### Phase 1: Project Configuration & Bootstrap
**Files to create/modify:**
- `wally.toml` — update to dev-dependencies only (Fusion 0.3, ProfileService, Cmdr, TestEZ)
- `default.project.json` — restructure to root ElectionSystem ModuleScript in ServerScriptService; keep Packages under ReplicatedStorage
- `.moonwave.toml` — new; configure Moonwave output directory and source patterns
- `README.md` — new; project overview, Rojo setup, Settings reference, Cmdr commands

**Outcome:** Correct project structure in place, dependencies declared properly, documentation baseline ready.

---

### Phase 2: Core Modules (Server-Side)

**Codebase approach:** Preserve existing Logging/ utilities and Types.lua; rebuild all election modules from scratch.

**Tier 1: Foundation (no dependencies between them)**
These modules establish types, data structures, and utility functions:

1. **src/Types.lua** (update existing)
   - Define all interfaces: `ElectionConfig`, `Candidate`, `Party`, `Ballot`, `VoteRecord`, `ElectionResult`, `WinnerResult`, `SeatAllocation`, `Phase`, `VotingMethod`, `GovernmentType`, `SeatSystem`
   - Include strict type safety via `type` declarations
   - Document all interfaces with Moonwave `@interface` blocks

2. **src/Signal.lua**
   - Custom signal/event library (simple .Connect(), .Fire() pattern)
   - Used throughout for event broadcasting (PhaseChanged, ResultsPublished, etc.)

3. **src/Modules/Types.lua** (or consolidate with Types.lua above)
   - Validate types at runtime; re-export from src/Types.lua

4. **src/Modules/Store.lua**
   - In-memory storage for:
     - Vote records: `{ [tostring(userId)]: { ballot, timestamp, roundId } }`
     - Election state: phase, current round, results cache
     - Eligibility rejection log
   - Methods: `get()`, `set()`, `clear()`
   - Serialize/deserialize for ProfileService integration
   - Full Moonwave documentation

5. **src/Modules/TimestampManager.lua**
   - Derive phase from os.time() vs Settings.openAt / Settings.closeAt
   - Methods: `getPhase()` → ElectionPhase, `getCountdown()` → seconds to next transition
   - Broadcast PhaseChanged signal on heartbeat
   - Handle phase transitions: Scheduled → Open → Closed → ResultsOut → Coalition → Formed

**Tier 2: Voting Methods (all 14, each standalone module)**
**Path:** `src/Modules/VotingMethods/{METHOD_NAME}.lua`

Each method module exports:
- `.calculateWinner(ballots: { Ballot }, config: ElectionConfig) → WinnerResult`
- `.validateBallot(ballot: Ballot, config: ElectionConfig) → { valid: boolean, reason: string }`

**Methods to implement:**
1. `FPTP.lua` — First-Past-The-Post
2. `TwoRound.lua` — Two-round runoff (delegates to RoundManager)
3. `IRV.lua` — Instant Runoff Voting (ranked, elimination; delegates to RoundManager)
4. `Approval.lua` — Approval voting
5. `Score.lua` — Score/Range voting
6. `STAR.lua` — Score Then Automatic Runoff
7. `STV.lua` — Single Transferable Vote (multi-seat, ranked; uses SeatAllocator)
8. `PartyListPR.lua` — Party-List Proportional Representation (uses SeatAllocator)
9. `MMP.lua` — Mixed-Member Proportional (two ballots, compensation; uses SeatAllocator)
10. `Parallel.lua` — Parallel voting (two independent ballots; uses SeatAllocator)
11. `Condorcet.lua` — Condorcet method (head-to-head pairwise)
12. `Borda.lua` — Borda count (ranked, points)
13. `Cumulative.lua` — Cumulative voting (multi-vote, stackable)
14. `Sortition.lua` — Random selection (selects N random eligible players)

Each method is tested with known ballot fixtures.

**Tier 3: Supporting Electoral Systems**

6. **src/Modules/RoundManager.lua**
   - Manages multi-round voting (TwoRound, IRV)
   - Methods: `initRound()`, `eliminateCandidate()`, `transferVotes()`, `getRoundHistory()`
   - Stores round state in Store
   - Returns round results for calculation

7. **src/Modules/SeatAllocator.lua**
   - Allocates seats per voting method (STV, PR, MMP, Parallel)
   - Supports open-list, closed-list PR variants
   - Methods: `allocate(votes: {}, config) → SeatAllocation`
   - Implements three apportionment algorithms (configurable via Settings.seatAllocationMethod):
     - `DHondt`: Divisor method (default, slightly favors larger parties)
     - `SainteLague`: Divisor method (more proportional)
     - `HareNiemeyer`: Quota method (legacy, alternative)
   - Returns seat allocation per party + candidate assignment

8. **src/Modules/DistrictManager.lua**
   - Routes votes by district (if configured)
   - Methods: `getDistrict(player) → District?`, `getDistrictVotes(districtId) → { votes }`
   - Supports: SingleMemberDistrict, MultiMemberDistrict, AtLarge, Federal
   - Noop if districts empty in config

9. **src/Modules/CoalitionSystem.lua**
   - Forms governments from elected parliament (Parliamentary only)
   - Methods: `suggestCoalition(votes: {}) → CoalitionProposal`, `validateCoalition(members: {}) → boolean`
   - Stores coalition composition in Store
   - Fires CoalitionFormed signal

10. **src/Modules/EligibilityChecker.lua**
    - Single method: `check(player: Player) → { eligible: boolean, reason: string }`
    - Checks in order: bannedUsernames, bannedGroupIds, minGroupRank, minAccountAgeDays
    - Returns first failure reason or eligible=true
    - No side effects; pure eligibility logic

11. **src/Modules/AltDetector.lua**
    - Runs post-vote to flag suspicious accounts
    - Methods: `detectAlt(userId: number, playerName: string) → AltFlagResult`
    - Heuristics controlled by Settings.altDetection.heuristic: "age" | "rapid" | "both"
      - `age`: flag if account age < Settings.minAccountAgeDays
      - `rapid`: flag if player votes within X seconds of previous vote (stored in Store)
      - `both`: flag if either condition met
    - Path 1: KickWithScreen → AltDetectedClient event → Client mounts KickScreen → BanAPI call after kickDelaySeconds
    - Path 2: InvalidateVote → removes vote from Store, fires AltDetected signal server-side
    - Path 3: altDetection.enabled=false → no action, AlreadyVoted event sent to client
    - Vote invalidation happens atomically

12. **src/Modules/BallotFormatter.lua**
    - Converts config to ballot input shape per voting method
    - Methods: `format(votingMethod: string, candidates: {}, parties: {}) → BallotTemplate`
    - Returns template for UI: which candidates are selectable, how many, ranking vs scoring vs approval, etc.
    - Used by Client to render correct ballot component

13. **src/Modules/ResultCalculator.lua**
    - Orchestrates voting method resolution
    - Methods: `calculate(votingMethod: string, ballots: {}, config) → ElectionResult`
    - Calls appropriate VotingMethod module, interprets result, formats for display
    - Handles seat allocation if needed
    - Returns final winner(s), vote shares, seat breakdown, round history

**Tier 4: Network & Data**

14. **src/Modules/Network.lua**
    - Creates RemoteEvent/RemoteFunction instances under ReplicatedStorage.ElectionSystemRemotes
    - Server event list: PhaseChanged, BallotOpened, ResultsPublished, ElectionStateUpdated, AlreadyVoted, AltDetectedClient, IneligibleResult
    - Client event list: SubmitVote, RequestState
    - Methods: `getRemote(name: string, direction: "ServerToClient" | "ClientToServer") → RemoteEvent | RemoteFunction`
    - Lazy-creates on first call
    - Registers listeners server-side

15. **src/Modules/Data.lua**
    - ProfileService integration
    - Methods: `loadProfile(userId: number)`, `saveProfile(userId: number)`, `getVoteRecord(userId: number) → VoteRecord?`
    - Stores per-election state in Profile.Data.Elections[countryId]
    - Handles profile auto-load/load-release lifecycle

**Tier 5: Main Orchestrator**

16. **src/init.lua**
    - ElectionManager root module
    - Requires and exports all modules
    - Initializes on first require:
      1. Load Settings.lua
      2. Create TimestampManager (bind to heartbeat)
      3. Load parties/candidates from Settings
      4. Create Network remotes
      5. Bind RemoteEvent listeners for SubmitVote, RequestState
      6. Expose public API: `openElection(countryId)`, `closeElection()`, `getResults()`, `getPhase()`
    - Exports all submodules for client/server access

---

### Phase 3: Client-Side UI

**Path:** `src/Client/`

1. **src/Client/ElectionClient.lua**
   - Client-side counterpart to init.lua
   - Requires UI modules and sets up client listeners
   - Methods: `submitVote(ballot)`, `requestState()`, `onAltDetected()`, `onIneligible()`, `onAlreadyVoted()`
   - Mounts ElectionUI modal on first RemoteEvent from server

2. **src/Client/UI/ElectionUI.lua**
   - Fusion 0.3 UI modal root
   - Manages step progression: CountdownScreen → CandidateBrowser → BallotComponent → VoteConfirmation → PostVote
   - All components accept `scope` as first argument
   - Central scope:Value() for currentStep
   - Auto-advances on phase transitions
   - Unmounts on election close or voting complete

3. **src/Client/UI/Components/** (6 primary, 5 utility)

   **Primary step components:**
   - `CountdownScreen.lua` — title, country decal, live countdown ticker via scope:Value() + TimestampManager
   - `CandidateBrowser.lua` — party cards + nested candidate cards, search/filter, expand detail panel
   - `BallotComponent.lua` — delegates to method-specific ballot (RankableBallot, ScoredBallot, button grid, etc.)
   - `VoteConfirmation.lua` — summary of selections, "Confirm Vote" button
   - `ResultsView.lua` — bar chart/pie chart, seat breakdown, coalition display, round history timeline
   - `HUDBar.lua` — fixed top bar: title, phase badge, voter status

   **Post-vote screens:**
   - `KickScreen.lua` — shows player avatar, countdown, ban reason message
   - `AlreadyVotedScreen.lua` — "You have already voted in this election"
   - `IneligibleScreen.lua` — reason string from EligibilityChecker
   - `ThankYouScreen.lua` — "Thank you for voting" (default post-vote)

   **Ballot method components:**
   - `RankableBallot.lua` — drag-to-rank list (IRV, STV, Condorcet, Borda)
   - `ScoredBallot.lua` — slider/stepper per candidate (Score, STAR, Cumulative)
   - `ApprovalBallot.lua` — candidate button grid, toggle on/off (Approval)
   - `PartyListBallot.lua` — party card grid, open-list expands candidate list (PartyListPR)
   - `DualBallot.lua` — two columns side-by-side (MMP, Parallel)

   **Utility components:**
   - `CandidateCard.lua` — headshot, name, bio, policy tags; async thumbnail fetch with placeholder
   - `PartyCard.lua` — decal, name, colour, member count badge
   - `ResultsChart.lua` — bar/pie chart builder from vote shares
   - `CoalitionDisplay.lua` — shows coalition composition (parties, seat counts)
   - `CountdownTicker.lua` — live countdown display

---

### Phase 4: Example Scripts

**Path:** `src/Example/`

1. **src/Example/VotingBoothPart.server.lua**
   - Tags a Part as "VotingBooth" via CollectionService
   - Creates ProximityPrompt if not present
   - On prompt triggered:
     - Calls EligibilityChecker:check(player)
     - If eligible: fires BallotOpened RemoteEvent → Client opens modal at Step 2 (CandidateBrowser)
     - If ineligible: fires IneligibleResult RemoteEvent → Client opens IneligibleScreen
     - If already voted: fires AlreadyVoted RemoteEvent → Client opens AlreadyVotedScreen

2. **src/Example/ResultsPartScript.server.lua**
   - Tags a Part as "ResultsPart" via CollectionService
   - Creates SurfaceGui on part front face
   - Renders ResultsSurfaceUI (Fusion component) showing bar/pie chart
   - Listens to ResultsPublished, updates reactively
   - Cmdr command `election_chart bar|pie` toggles chart type

---

### Phase 5: CMDR Admin Commands

**Path:** `src/Cmdr/CmdrSetup.lua` (instantiated by init.lua)

Commands to register:
- `election_results [countryId]` — print full result breakdown to output
- `election_votes [countryId]` — list all recorded votes (playerIds, ballot summaries, timestamps)
- `election_chart [bar|pie]` — toggle ResultsPartScript chart type
- `election_reset [countryId] confirm` — clear vote records and reset election state

All commands gated by Settings.cmdr.adminGroupId + adminMinRank.

---

### Phase 6: Settings & Configuration

**Path:** `src/Settings.lua`

Returns a single config table with:
- Election metadata: countryId, votingMethod, governmentType, seatSystem, seats, threshold, runoffThreshold, compulsoryVoting, electoralCollege, seatAllocationMethod (DHondt | SainteLague | HareNiemeyer)
- Timestamps: openAt, closeAt (Unix)
- Eligibility rules: minGroupRank, minAccountAgeDays, bannedGroupIds, bannedUsernames
- Alt detection: enabled, onDetect (KickWithScreen | InvalidateVote), heuristic (age | rapid | both), kickDelaySeconds, banDuration, banReason, rapidVoteThresholdSeconds
- Parties array: { partyId, name, decalId, colour, description }
- Candidates array: { candidateId, userId, partyId, name, bio, policyTags }
- Districts array: (optional, empty if not used)
- CMDR config: adminGroupId, adminMinRank
- UI config: placeholderAvatarId, accentColour, electionTitle

Developer edits this file once at startup; no runtime registration needed.

---

### Phase 7: Testing

**Path:** `tests/`

TestEZ specs to cover:
- `EligibilityChecker_spec.lua` — all four rules individually, combined rules, pass scenarios
- `VotingMethods_spec.lua` — each of 14 methods with known ballot fixtures, winner determination
- `SeatAllocator_spec.lua` — PR and MMP seat distribution with realistic party vote shares
- `RoundManager_spec.lua` — IRV elimination rounds, two-round phase transitions
- `TimestampManager_spec.lua` — phase resolution from mock os.time() values
- `AltDetector_spec.lua` — KickWithScreen path, InvalidateVote path, enabled=false path
- `Store_spec.lua` — serialize/deserialize round-trip for ProfileService

Each spec uses known fixtures (ballots, configs, player mocks) to ensure deterministic results.

---

### Phase 8: CI/CD & Documentation

**Files to create:**
- `.github/workflows/release.yml` — on tag push (v*.*.*)  or manual workflow_dispatch: build with Rojo, publish to GitHub Releases
- `.moonwave.toml` — configure Moonwave output, source patterns, link root
- `README.md` — project overview, Rojo setup, Settings reference, Cmdr commands, CI/CD notes, moonwave build

---

## File Dependency Graph

```
src/
├── Types.lua (standalone)
├── Signal.lua (standalone)
├── Settings.lua (standalone, config only)
│
├── Modules/
│   ├── Store.lua (depends: Signal)
│   ├── TimestampManager.lua (depends: Signal, Settings)
│   ├── EligibilityChecker.lua (depends: Types, Settings)
│   ├── BallotFormatter.lua (depends: Types, Settings)
│   ├── VotingMethods/ (all depend: Types)
│   │   ├── FPTP.lua
│   │   ├── TwoRound.lua (depends: RoundManager)
│   │   ├── IRV.lua (depends: RoundManager)
│   │   └── ... (13 more)
│   ├── RoundManager.lua (depends: Types, Store)
│   ├── SeatAllocator.lua (depends: Types)
│   ├── DistrictManager.lua (depends: Types, Settings)
│   ├── CoalitionSystem.lua (depends: Types, Signal, Store)
│   ├── AltDetector.lua (depends: Signal, Types, Settings)
│   ├── ResultCalculator.lua (depends: all VotingMethods, SeatAllocator, RoundManager, Types)
│   ├── Network.lua (depends: Signal)
│   ├── Data.lua (depends: ProfileService)
│   └── Types.lua (re-export from src/Types.lua)
│
├── init.lua (ElectionManager root, depends: all above modules)
│
├── Client/
│   ├── ElectionClient.lua (depends: init.lua, UI modules, Network)
│   └── UI/
│       ├── ElectionUI.lua (depends: all components, Fusion 0.3)
│       └── Components/ (all depend: Fusion 0.3, Types)
│
└── Example/
    ├── VotingBoothPart.server.lua (depends: init.lua, EligibilityChecker, Network)
    └── ResultsPartScript.server.lua (depends: init.lua, Fusion, Network)
```

---

## Execution Sequence

1. **Bootstrap** (Phase 1): wally.toml, default.project.json, .moonwave.toml, README stub
2. **Core types** (Phase 2, Tier 1): Types.lua, Signal.lua, Store.lua, TimestampManager.lua
3. **Electoral logic** (Phase 2, Tier 2–4): All 14 voting methods, RoundManager, SeatAllocator, DistrictManager, CoalitionSystem, EligibilityChecker, AltDetector, BallotFormatter, ResultCalculator, Network, Data
4. **Init** (Phase 2, Tier 5): init.lua ties everything together
5. **Client UI** (Phase 3): ElectionClient.lua, ElectionUI.lua, all UI components
6. **Examples** (Phase 4): VotingBoothPart.server.lua, ResultsPartScript.server.lua
7. **CMDR** (Phase 5): CmdrSetup.lua integration
8. **Tests** (Phase 7): All TestEZ specs
9. **CI/CD** (Phase 8): .github/workflows/release.yml, finalize docs

---

## Verification Strategy

**Unit tests (TestEZ):**
- Run: `rojo run --build Tests.rbxm && luau tests/` or via Rojo studio
- All voting methods pass with fixture ballots
- Seat allocation matches expected seats per party
- Eligibility checks return correct pass/fail per rule
- Alt detection paths execute correctly

**Integration (manual playtesting):**
1. Load ElectionSystem into studio via Rojo
2. Configure one country in Settings.lua (e.g., UK FPTP setup)
3. Teleport players to VotingBooth, verify:
   - Eligible players see BallotComponent with correct method UI
   - Ineligible players see IneligibleScreen
   - Already-voted players see AlreadyVotedScreen
   - Vote submits, phase transitions, results display
4. If altDetection.enabled: verify KickScreen appears post-vote
5. Verify Cmdr commands (admin): election_results, election_votes, election_reset

**Build (CI/CD):**
- `rojo build default.project.json --output ElectionSystem.rbxm` succeeds
- GitHub Actions publishes .rbxm to Releases on tag push

---

## Notes

- **No Wally publishing** — released as .rbxm artifact only; dev dependencies in Packages/
- **Single-country at a time** — Settings.lua is global; multi-country requires multiple instances
- **Deterministic results** — all voting methods produce reproducible outcomes from same ballot set
- **Strict Luau** — all files begin with `--!strict`
- **Moonwave docs** — every public method documented with @param, @return, @interface blocks