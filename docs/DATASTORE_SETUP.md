# DataStore Setup (CRITICAL!)

**DataStore is how votes are saved.** Without it, votes disappear when the server restarts.

⚠️ **If you skip this section, all votes will be lost.**

## What is DataStore?

DataStore is Roblox's database. It saves player data (in this case, votes) so they persist across server restarts.

**Without DataStore:**
- Server restarts → all votes gone
- Players lose their votes
- Election resets

**With DataStore:**
- Server restarts → votes are still there
- Players rejoin → their vote is loaded
- Election data survives

## Step 1: Enable Studio DataStore Access

This is the **most important step**. You must do this in the place where you're testing.

### For Place File Users

1. Open your `.rbxl` place file in Roblox Studio
2. Click **Home** tab
3. Find **Game Settings** button (looks like a gear/settings icon)
4. In the left panel, click **Security**
5. Scroll down and find these two toggles:
   - **Enable Studio Access to API Services** → Turn **ON** (green)
   - **Enable DataStore Access in Studio** → Turn **ON** (green)
6. Click **Save** or close the panel

**Visual Guide:**
```
Home Tab → Game Settings (gear icon)
    ↓
Left Panel → Security
    ↓
Find "Enable Studio Access to API Services" → Toggle ON
Find "Enable DataStore Access in Studio" → Toggle ON
```

⚠️ **If you don't do this:**
- You'll see errors like "DataStore access denied"
- Votes won't save
- Testing won't work properly

### For Published Games

If you've published this to your actual game:

1. Go to https://www.roblox.com/games
2. Find your game
3. Click **⋯ (three dots)** → **Configure Game**
4. Go to **Security** in left panel
5. Enable "Enable API Services" if not already on
6. DataStore is automatically enabled for published games

### Optional: HTTP requests for Discord webhooks

If you use **`Settings.discord`** to notify an admin Discord channel, the server must be allowed to call outbound HTTP (**Home → Game Settings → Security → Allow HTTP Requests → ON**). This is independent of DataStore but uses the same **Security** panel. Full setup: [Settings — Discord webhook](SETTINGS_SETUP.md#discord-webhook-optional-server-only).

## Step 2: Test That DataStore Works

After enabling, test it:

1. Open your place in Studio
2. Click **Play**
3. Look at the **Output** panel (at bottom of Studio)
4. Check for these messages:

**Good Signs** ✓
```
[ElectionSystem] Initialized
[DataStore] Profile loaded for player 12345
```

**Bad Signs** ✗
```
DataStore access denied
Failed to load profile
HTTP 403: Forbidden
```

If you see bad signs, go back to Step 1 and make sure both toggles are ON.

## Step 3: Verify Votes Save

Test that votes actually persist:

1. **Start the game** (click Play)
2. **Vote for someone** (use your custom UI or the built-in booth)
3. Check Output for:
   ```
   VOTE recorded ok user=Player1
   ```
4. **Stop the game** (click Stop)
5. **Start again** (click Play)
6. Check the Output for:
   ```
   [DataStore] Profile loaded - 1 vote found
   ```

If you see the second message, DataStore is working! Your vote persisted across restarts.

## Understanding Vote Persistence

When DataStore works correctly, here's what happens:

### Player Joins
```
Player connects
    ↓
ElectionManager loads player's DataStore profile
    ↓
Profile contains: { userId: "123", ballot: [...], timestamp: 1234567890 }
    ↓
Vote is restored to in-memory Store
    ↓
Player can see they already voted (button disabled)
```

### Player Votes
```
Player clicks "Vote for Alice"
    ↓
Server records vote in memory (Store)
    ↓
Server saves to DataStore immediately
    ↓
If server restarts → vote is still there
```

## Troubleshooting

### Error: "DataStore access denied" or "HTTP 403"

**Solution:**
1. Check that both toggles in Game Settings → Security are ON
2. Make sure you're in the correct place file
3. Try closing Studio completely and reopening it
4. If it still fails, check your Roblox account permissions

### Error: "Failed to load profile"

**Solution:**
- This usually means ProfileService can't find the DataStore
- Make sure you enabled both API Services toggles
- Wait a few seconds and test again (DataStore initialization takes time)

### Votes disappear on restart

**Solution:**
- DataStore likely isn't enabled
- Go back to Step 1
- Make sure **both** toggles are ON (not just one)

### How do I know if DataStore is actually saving?

Look in the **Output panel** while playing:

**DataStore saving vote:**
```
VOTE recorded ok user=Player1 uid=123456789
```

**DataStore persisting vote on rejoin:**
```
[DataStore] Profile loaded - vote found for user Player1
```

If you see these messages, you're good!

## For Published Games (After You Publish)

Once you publish your game to Roblox:

1. DataStore is **automatically enabled** for published games
2. Votes **automatically persist**
3. No special setup needed

Just make sure in the game settings (roblox.com/games) that **API Services** is enabled (it usually is).

## Advanced: Clearing DataStore (for Testing)

If you need to reset all votes for a fresh test:

⚠️ **Warning: This deletes all stored votes permanently!**

1. In Roblox Studio, go to **View** → **Server Script Activity**
2. Click **Command Bar**
3. Type this (warning: this clears everything!):
   ```lua
   game:GetService("DataStoreService"):GetDataStore("ElectionPlayerData"):RemoveAsync("Player_123")
   ```
   (Replace `123` with the player's user ID)

**Better way:** Use the admin command in-game:
```
/cleardata [username]
```

## Summary Checklist

Before testing elections:

- [ ] Opened place file in Roblox Studio
- [ ] Clicked Home → Game Settings
- [ ] Clicked Security in left panel
- [ ] Toggled **ON**: "Enable Studio Access to API Services"
- [ ] Toggled **ON**: "Enable DataStore Access in Studio"
- [ ] Saved settings
- [ ] Clicked Play to test
- [ ] Checked Output for "Profile loaded" message
- [ ] Cast a test vote
- [ ] Stopped and restarted game
- [ ] Verified vote persisted (shows in Output)

If all checkboxes are done, **DataStore is working correctly!**

---

**Next Steps:**
- [Getting Started Guide](GETTING_STARTED.md)
- [Settings Configuration](SETTINGS_SETUP.md)
- [Custom UI Implementation](CUSTOM_UI.md)
