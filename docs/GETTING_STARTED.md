# Getting Started (Place File Users)

If you downloaded the **ElectionSystem.rbxl** file, this guide is for you. No coding experience needed!

## What You Have

The election system is a **Roblox place file** that handles voting, ballot counting, and result display. It comes pre-configured but needs customization for your game.

## Step 1: Open the Place File

1. Open **Roblox Studio**
2. **File → Open** → Select `ElectionSystem.rbxl`
3. Wait for it to load (this may take a minute)

## Step 2: Enable Required Services

Before anything works, you need to turn on **DataStore**.

### Turn On DataStore (CRITICAL!)

Without DataStore, votes won't save and players will lose their votes if the server restarts.

1. Click **Home** tab at top
2. Look for **Game Settings** button (gear icon)
3. In the left panel, click **Security**
4. Find **Enable Studio Access to API Services** — toggle it **ON**
5. Scroll down and find **Enable DataStore Access in Studio** — toggle it **ON**
6. Click **Close**

⚠️ **Important:** If you don't do this, you'll see DataStore errors and votes won't save.

## Step 3: Configure Your Election

The election settings live in one file: **ServerScriptService → ElectionManager → Settings.lua**

See the [Settings Configuration Guide](SETTINGS_SETUP.md) for detailed instructions on:
- Setting voting method (FPTP, IRV, Approval, etc.)
- Adding candidates and parties
- Setting voting times
- Eligibility rules
- Alt detection (to prevent cheating)

## Step 4: Test In Studio

1. Click the green **Play** button
2. You should see no errors in the **Output** panel
3. If you see red errors, check the [Troubleshooting](#troubleshooting) section below

## Step 5: Add Your UI (Optional)

The place comes with a basic voting booth. To customize it or add your own interface, see:
- [Custom UI Implementation Guide](CUSTOM_UI.md)

## What Happens When You Play

1. **Server starts** → Election system initializes
2. **Players join** → Their votes are loaded from DataStore (if they already voted)
3. **Voting phase begins** → Players can submit ballots
4. **Phase changes** → System counts votes automatically
5. **Results show** → Winners are displayed

## File Structure (You Don't Need to Edit Most of This)

```
ServerScriptService/
├── ElectionManager/           ← Main system (don't move this!)
│   ├── Settings.lua           ← ⭐ YOU EDIT THIS (candidates, voting method, etc.)
│   ├── init.module.lua        ← Core system (don't edit)
│   ├── Modules/               ← Vote counting, storage (don't edit)
│   └── ...other files...
```

The only file you really need to touch is **Settings.lua**. Everything else is internal system code.

## Troubleshooting

### "DataStore Error" or "DataStore access denied"
- **Solution:** You didn't enable DataStore. Go back to Step 2 and toggle it on.

### "Module not found" errors
- **Solution:** Make sure the `ElectionManager` folder stayed in `ServerScriptService` and didn't get moved.

### No voting UI appears
- **Solution:** 
  1. Check that the voting booth model exists in Workspace
  2. See [Custom UI Implementation Guide](CUSTOM_UI.md)

### Phase doesn't change
- **Solution:** Check `Settings.lua` — make sure the times are set correctly (not in the past).

### Votes aren't saving
- **Solution:** Enable DataStore (Step 2). Without it, votes only exist in the current server session.

## Next Steps

1. **Configure Settings** → See [Settings Configuration Guide](SETTINGS_SETUP.md)
2. **Customize UI** → See [Custom UI Implementation Guide](CUSTOM_UI.md)
3. **Test voting** → Play in Studio and try voting
4. **Deploy to game** → Publish the place to your game

---

**Need help?** Check the other guides or see the [full API documentation](../README.md).
