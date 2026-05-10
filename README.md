# ElectionSystem

A universal, modular election system for Roblox supporting **14 different voting methods** and **multiple electoral structures**. Designed to be configurable for virtually any democratic or quasi-democratic system across multiple countries and game worlds.

## Features

### 14 Voting Methods
- **FPTP** — First-Past-The-Post
- **TwoRound** — Two-round runoff
- **IRV** — Instant Runoff Voting (ranked choice)
- **Approval** — Approval voting
- **Score** — Score/Range voting
- **STAR** — Score Then Automatic Runoff
- **STV** — Single Transferable Vote
- **PartyListPR** — Party-List Proportional Representation
- **MMP** — Mixed-Member Proportional
- **Parallel** — Parallel voting
- **Condorcet** — Condorcet method
- **Borda** — Borda count
- **Cumulative** — Cumulative voting
- **Sortition** — Random selection

### Electoral Structures
- Single-Member Districts, Multi-Member Districts, At-Large, Federal

### Government Models
- Presidential, Parliamentary, Semi-Presidential

### Supporting Systems
- Electoral thresholds, Coalition forming, Turnout requirements, Compulsory voting, Electoral college, Recall elections, Referendums, Primaries, Alt detection

## Quick Start

1. Run `rojo serve default.project.json`
2. Edit `src/Settings.lua` with your election parameters
3. Deploy voting booths using example scripts

Wally-managed libraries (`Fusion`, `Cmdr`, `Iris`, etc.) live in `DevPackages/` and are mirrored under `ReplicatedStorage.Packages` via `default.project.json`. After editing `wally.toml`, run `wally install` and sync with Rojo.

### Place build (`.rbxl`)

`default.project.json` describes a full **DataModel** (a place), not a single Model. Build a `.rbxl` and open it in Studio with **File → Open from File…**. *Insert from File* is only for `.rbxm` assets and will not load this project correctly.

```bash
rojo build default.project.json --output ElectionSystem.rbxl
```

## Publishing

Push a version tag to GitHub to trigger CI/CD release:

```bash
git tag v0.1.0 && git push origin v0.1.0
```

## License

MIT
