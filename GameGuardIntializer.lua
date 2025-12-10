-- GameGuardInitializer.lua (Placed in ServerScriptService)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Require the ModuleScript
local GameGuard = require(ReplicatedStorage:WaitForChild("GameGuardModule")) 
-- Adjust the path above if you placed GameGuardModule elsewhere

print("Initializing GameGuard Security System...")

-- Monitor players as they join
Players.PlayerAdded:Connect(function(player)
    -- 1. Check if the player is permanently banned immediately upon joining.
    local isBanned = GameGuard.CheckBanStatus(player)
    
    if not isBanned then
        -- 2. Log when a player successfully joins.
        GameGuard.LogInfo("Player Joined", string.format("Player %s (%d) successfully joined the game.", player.Name, player.UserId))
    end
end)

-- Initial System Check (ProtectedCall Example)
GameGuard.ProtectedCall(function()
    -- This block is protected. If an error occurs here, it is logged to Discord.
    
    -- Example of an Anti-Cheat check that is always running (e.g., in a loop or heartbeat)
    -- This is where you would continuously monitor critical values.
    
    local function continuousChecks()
        for _, player in ipairs(Players:GetPlayers()) do
            local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 100 then
                -- Anti-God Mode/Health Exploit check
                GameGuard.ReportExploit(player, "God Mode/Health Manipulator", "Humanoid health exceeded max value (100).")
            end
        end
    end
    
    -- Start a basic continuous check loop
    game:GetService("RunService").Heartbeat:Connect(continuousChecks)
    
    print("GameGuard: Initialization complete. Continuous checks started.")
end)