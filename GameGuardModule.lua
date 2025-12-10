-- GameGuardModule.lua (Placed in ReplicatedStorage/ServerScriptService)

local GameGuard = {}
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

-- Configuration
local CONFIG = {
    DISCORD_WEBHOOK_URL = "YOUR_DISCORD_WEBHOOK_URL_HERE", -- <<< MUST BE CHANGED
    BAN_DATASTORE_NAME = "PermanentBanList",
    BAN_IP_EQUIVALENT_DURATION = 315360000 -- 10 years in seconds (permanent/IP ban)
}

local BanDataStore = DataStoreService:GetDataStore(CONFIG.BAN_DATASTORE_NAME)

-- Check HTTP Status
if not HttpService.HttpEnabled then
    warn("HttpService is not enabled! Discord reporting will be disabled.")
end

----------------------------------------------------------------------
-- PRIVATE CORE FUNCTIONS
----------------------------------------------------------------------

-- Sends a detailed, embedded message to the Discord Webhook.
local function sendToDiscord(logTitle, logType, details, player)
    if not HttpService.HttpEnabled or CONFIG.DISCORD_WEBHOOK_URL == "YOUR_DISCORD_WEBHOOK_URL_HERE" then return end
    
    local timestamp = DateTime.now():ToIsoDate()
    local messageContent = string.format("🚨 **[%s] DETECTED!** 🚨", logType)
    
    local embedColor = 15158332
    if logType == "ERROR" then embedColor = 16711680
    elseif logType == "EXPLOIT" then embedColor = 16750080
    end

    local embed = {
        title = logTitle,
        description = string.format("```lua\n%s\n```", details),
        color = embedColor,
        footer = { text = "GameGuard System | Session ID: " .. HttpService:GenerateGUID(false) },
        timestamp = timestamp,
        fields = {
            { name = "Server Time", value = timestamp, inline = true },
            { name = "Report Type", value = logType, inline = true },
        }
    }
    
    if player and player:IsA("Player") then
        table.insert(embed.fields, 1, { name = "Player ID", value = tostring(player.UserId), inline = true })
        table.insert(embed.fields, 1, { name = "Username", value = player.Name, inline = true })
    end
    
    local payload = {
        content = messageContent,
        embeds = { embed }
    }

    local success, response = pcall(function()
        HttpService:PostAsync(
            CONFIG.DISCORD_WEBHOOK_URL, 
            HttpService:JSONEncode(payload)
        )
    end)

    if not success then
        warn("[GameGuard] Failed to send log to Discord:", response)
    end
end

-- Permanently bans the player using DataStore.
local function permanentBan(player, reason)
    if not player or not player:IsA("Player") then return end
    
    local banData = {
        Reason = reason,
        Moderator = "GameGuardSystem",
        Timestamp = os.time(),
        Duration = CONFIG.BAN_IP_EQUIVALENT_DURATION -- Permanent
    }
    
    local key = tostring(player.UserId)
    local success, err = pcall(function()
        BanDataStore:SetAsync(key, banData)
    end)

    if success then
        print(string.format("[BAN SUCCESS] Player %s (%d) permanently banned. Reason: %s", player.Name, player.UserId, reason))
        player:Kick("You have been permanently banned from this game for exploiting. Reason: " .. reason)
    else
        warn(string.format("[BAN FAIL] Could not save ban data for %s: %s", player.Name, err))
        -- Kick anyway, but log the failure
        player:Kick("Exploit detected, but system failed to save permanent ban. Please try again.")
    end
end

----------------------------------------------------------------------
-- PUBLIC API FUNCTIONS
----------------------------------------------------------------------

-- 1. Checks if the player is currently banned and kicks them if so.
function GameGuard.CheckBanStatus(player)
    if not player or not player:IsA("Player") then return end
    
    local key = tostring(player.UserId)
    local success, banData = pcall(function()
        return BanDataStore:GetAsync(key)
    end)

    if success and banData then
        -- This logic can be expanded for temporary bans, but here we assume permanent
        player:Kick("You are permanently banned from this game. Reason: " .. banData.Reason)
        return true
    end
    
    return false
end

-- 2. The main exploit detection and punishment function.
function GameGuard.ReportExploit(player, exploitType, reason)
    if not player or not player:IsA("Player") then return end

    local details = string.format(
        "Username: %s (ID: %d)\nExploit Type: %s\nReason: %s\nTime: %s",
        player.Name,
        player.UserId,
        exploitType,
        reason,
        DateTime.now():ToIsoDate()
    )

    -- Player location and character status (for detailed root cause analysis)
    if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
        local pos = player.Character.PrimaryPart and player.Character.PrimaryPart.Position or Vector3.new(0,0,0)
        details = details .. string.format(
            "\nLocation: (%s)\nHealth: %d\nWalkSpeed: %d",
            pos,
            player.Character:FindFirstChildOfClass("Humanoid").Health,
            player.Character:FindFirstChildOfClass("Humanoid").WalkSpeed
        )
    end
    
    print(string.format("[GameGuard] EXPLOIT REPORT: %s (%s) detected.", player.Name, exploitType))
    sendToDiscord("⚠️ PERMANENT BAN: " .. player.Name, "EXPLOIT", details, player)

    -- IMMEDIATE PUNISHMENT: Permanent Ban and Kick
    permanentBan(player, exploitType .. " (Exploiting/Cheating)")
end

-- 3. Function to capture and report Server Errors/Bugs (The 'Glitch/Bug' Catcher)
function GameGuard.ProtectedCall(func, ...)
    local success, result = xpcall(func, debug.traceback, ...)

    if not success then
        local errorMessage = result
        local logTitle = "🚫 CRITICAL SERVER ERROR OCCURRED"
        
        local details = string.format(
            "Time: %s\nError Message:\n%s",
            DateTime.now():ToIsoDate(),
            errorMessage
        )
        
        warn("[GameGuard] SERVER ERROR CAPTURED:", errorMessage)
        sendToDiscord(logTitle, "ERROR", details)
    end
    
    return success, result
end

-- 4. General Info Logging
function GameGuard.LogInfo(title, message)
    local details = string.format(
        "Message: %s\nTime: %s",
        message,
        DateTime.now():ToIsoDate()
    )
    sendToDiscord(title, "INFO", details)
end

return GameGuard