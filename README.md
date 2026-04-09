# GameGuard Anti-Exploit & Logging System for Roblox

This comprehensive system is designed to maintain your game's integrity by providing robust server-side validation, critical error trapping, and an immediate, non-negotiable permanent ban response upon detecting exploitation. All critical events (Exploits, Critical Errors/Glitches, Player Joins/Bans) are logged with exhaustive detail to a dedicated Discord channel via Webhook.

---

## 🚀 Installation Guide

### Step 1: Preparation and File Structure Setup

1.  **GameGuardModule.lua (The Core Logic):**
    * In Roblox Studio's Explorer, locate **`ReplicatedStorage`** (or `ServerScriptService` for maximum security, but `ReplicatedStorage` is often convenient).
    * Right-click the chosen location and select **Insert Object > ModuleScript**.
    * Rename the new object to **`GameGuardModule`**.
    * Copy and paste the entire code from **Section 1 (GameGuardModule.lua)** into this ModuleScript.

2.  **GameGuardInitializer.lua (The Setup Script):**
    * In Roblox Studio's Explorer, locate **`ServerScriptService`** (This script MUST run on the server).
    * Right-click **`ServerScriptService`** and select **Insert Object > Script**.
    * Rename the script to **`GameGuardInitializer`**.
    * Copy and paste the entire code from **Section 2 (GameGuardInitializer.lua)** into this script.

### Step 2: Configuration and External Service Activation

1.  **Enable HTTP Service (CRUCIAL for Logging!):**
    * Go to **Roblox Studio Menu -> Game Settings** (Alt + A).
    * Navigate to the **Security** tab.
    * Ensure the **"Allow HTTP Requests"** option is **enabled (checked)**. If this is disabled, Discord logging will fail silently.

2.  **Setup Discord Webhook (Your Log Receiver):**
    * Open your Discord Server where you want to receive cheat and error reports.
    * Go to the target channel's settings (Gear Icon) -> **Integrations** -> **Webhooks**.
    * Click **New Webhook**, name it something professional (e.g., "GameGuard Bot"), and **copy the Webhook URL**.

3.  **Update Module Configuration (The Single Point of Change):**
    * Open the **`GameGuardModule`** file.
    * Locate the `CONFIG` table at the top and replace the placeholder with the Discord Webhook URL you just copied.

    ```lua
    local CONFIG = {
        DISCORD_WEBHOOK_URL = "PASTE_YOUR_DISCORD_WEBHOOK_URL_HERE", -- <<< MUST BE CHANGED AND UPDATED
        -- ... rest of the config ...
    }
    ```
    * **NEVER** share this Webhook URL with anyone, as it grants posting rights to your channel.

---

## 🔑 Key Features and Immediate Punishment System

The GameGuard system operates on a zero-tolerance policy for detected exploits, prioritizing game integrity above all else.

| Feature | Description | Action Taken |
| :--- | :--- | :--- |
| **B. Detecting & Punishing Exploits** | The core function (`GameGuard.ReportExploit`) is designed to be called by your existing server scripts whenever a client-side anomaly (e.g., speed hack, infinite money) is detected by the server. | **IMMEDIATE PERMANENT BAN** and **KICK**. |
| **Permanent Ban Mechanism** | The system bypasses typical temporary bans by using **Roblox DataStores** to save the player's User ID permanently with the ban reason. This is the **most robust form of permanent ban** possible on the Roblox platform. | The ban record is stored permanently under the unique User ID. |
| **IP Ban Equivalence** | Since Roblox does not allow direct IP banning due to privacy policies, this system enforces a ban on the User ID that is **checked instantly** upon every attempt to join the game, making it an effective permanent barrier against the banned account. | Banned players are **KICKED** instantly upon joining via `GameGuard.CheckBanStatus`. |
| **Anti-Anti-Detect/Ban Evasion** | The ban is enforced and validated exclusively on the **SERVER** using **DataStoreService**. Any client-side exploit attempting to bypass the ban is rendered useless, as the server reads the permanent ban status before any game script can even load. | Detection occurs server-side, and punishment is server-enforced, defeating client-side anti-detect scripts. |

---

## 💡 Integrating Anti-Cheat and Logging Logic (The Crux of the System)

The strength of GameGuard depends on **where and how often** you call its functions in your other server scripts.

### 1. Actively Checking Ban Status (Automatic)

This is already set up in the `GameGuardInitializer` script. It ensures that the system checks the `PermanentBanList` **immediately** when a player joins, preventing banned accounts from loading the game.

### 2. B. Detecting and Punishing Exploits (Your Manual Integration)

This function is the **ZERO TOLERANCE** trigger. Use this whenever a client-side request violates basic game rules (e.g., impossible speed, impossible damage, attempting to use an ability without cooldown).

**Integration Procedure:**

1.  **Require the Module:** In any server script where you handle a remote event or process player data, add this line at the top:
    ```lua
    local GameGuard = require(game:GetService("ReplicatedStorage"):WaitForChild("GameGuardModule"))
    ```

2.  **Server-Side Validation Example (Fly Hack Check):**
    * If a player's character is too high without permission (e.g., no jetpack, no admin fly), it's an exploit.
    
    ```lua
    -- Example Check: Run this on a periodic loop (e.g., using RunService.Heartbeat or a while true loop)
    local function checkFlyHack(player)
        local character = player.Character
        if character and player.Character:FindFirstChildOfClass("Humanoid") then
            local rootPart = character.PrimaryPart
            -- Check if the player is above a "safe height" and not standing on ground.
            if rootPart.Position.Y > 200 and character:FindFirstChildOfClass("Humanoid").FloorMaterial == Enum.Material.Air then
                
                -- CRITICAL DETECTION: Trigger the immediate ban.
                GameGuard.ReportExploit(
                    player, 
                    "Fly Hack/Teleportation", 
                    "Observed height ("..rootPart.Position.Y..") is impossible without external scripts."
                )
            end
        end
    end
    
    -- GameGuard.ProtectedCall(checkFlyHack) -- You can even protect your anti-cheat loop!
    ```

3.  **Server-Side Validation Example (Money/Value Injection Check via RemoteEvent):**
    * NEVER trust values sent by the client. Always re-calculate or re-validate on the server.
    
    ```lua
    local RemoteEvent = game:GetService("ReplicatedStorage"):WaitForChild("AddMoneyRequest")
    
    RemoteEvent.OnServerEvent:Connect(function(player, amount)
        if amount > 1000 then 
            -- If a client tries to add an unreasonably large amount of money.
            
            -- CRITICAL DETECTION: Trigger the immediate ban.
            GameGuard.ReportExploit(
                player, 
                "Value Injection/Money Hack", 
                "Attempted to inject unreasonable amount of currency: " .. tostring(amount)
            )
            return 
        end
        
        -- If validation passes, proceed with legitimate logic.
        player.leaderstats.Money.Value += amount 
    end)
    ```

### 3. A. Protecting Critical Code (Bug/Glitch Catcher)

Use `GameGuard.ProtectedCall()` to wrap any piece of code that could potentially stop the server due to a script error (e.g., DataStore failures, referencing nil objects).

**Integration Procedure:**

```lua
local GameGuard = require(game:GetService("ReplicatedStorage"):WaitForChild("GameGuardModule"))

local success, loadedData = GameGuard.ProtectedCall(function()
    local DataStore = game:GetService("DataStoreService"):GetDataStore("PlayerInventoryData")
    -- This operation might fail due to network or key issues
    local data = DataStore:GetAsync(player.UserId) 
    
    -- Intentional bug check (will log to Discord):
    -- local nilObject = nil
    -- nilObject:DoSomething()
    
    return data
end)

if success then
    -- Code ran successfully
    print("Data loaded without issue.")
else
    -- Code failed, and the full error trace has been sent to Discord for bug fixing.
    warn("Operation failed, bug details logged by GameGuard.")
end
