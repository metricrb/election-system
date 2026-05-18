# Custom UI Setups

Store and share custom UI implementations for ElectionSystem.

## Structure

- **Booths/** — Custom voting booth UI implementations
  - **CustomUI1/** — Optional booth skin (`CustomUI1.lua`); not used by default `ElectionClient`
- **ResultsDisplays/** — Custom results display and leaderboard UIs
- **Templates/** — Reusable UI components and templates

## Default vs custom

The package ships with **`src/client/UI/ElectionUI.lua`**, wired from `ElectionClient`. Everything under `CustomUI/` is copy-in only.

## How to Use

Copy the UI setup folder into your project and follow the included `README.md` to integrate with ElectionSystem (swap the `require` in your client bootstrap or forked `ElectionClient`).

Each folder should include a `README.md` with setup instructions and any required dependencies.
