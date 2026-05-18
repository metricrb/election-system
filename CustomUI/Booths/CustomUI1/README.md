# CustomUI1 voting booth

Optional booth skin (navy/cream modal, tricolor accent bar). **Not** included in the default `ElectionClient` — copy into your place when needed.

## Install

1. Copy `CustomUI1.lua` into your client UI folder (e.g. `StarterPlayerScripts.ClientModules.UI`).
2. Point your bootstrap at this module instead of `ElectionUI`:

```lua
local CustomUI1 = require(path.to.CustomUI1)
mountedUi = CustomUI1.mount(electionConfig, {
	submitVote = function(ballot)
		return ElectionClient.submitVote(ballot)
	end,
})
```

Or replace the require in a forked `ElectionClient.lua`:

```lua
local ElectionUI = require(script.Parent.UI.CustomUI1)
```

## Requirements

- `ReplicatedStorage.ElectionSystemShared` (Types) — same as the core package.
- Server must send `playerDistrict` and `districts` in `RequestElectionConfig` when using constituency-scoped ballots.
- Supports FPTP, TwoRound (`RegisteredRoll`), and other methods listed in the module; unsupported methods show a footer message.

## Default UI

For the stock Fusion UI shipped with ElectionSystem, use `src/client/UI/ElectionUI.lua` (wired by default in `ElectionClient`).
