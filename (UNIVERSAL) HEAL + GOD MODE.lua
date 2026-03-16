--[[
====NN HUB UNIVERSAL GOD MOD + INSTANT HEAL====
]]--
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local GodModeActive = false
local DamageConnection = nil

local L = {
    godMode = "👑 GOD MODE",
    heal = "💚 HEAL",
    godOn = "ENABLED - you are immortal",
    godOff = "DISABLED",
    healed = "Health restored",
    pcControls = "INSERT - heal | DELETE - God Mode",
    mobileHint = "Buttons at the bottom",
    godButton = "GOD",
    healButton = "HEAL"
}

local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function healToFull()
    local character = getCharacter()
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.Health = humanoid.MaxHealth
        StarterGui:SetCore("SendNotification", {
            Title = L.heal,
            Text = L.healed,
            Duration = 1
        })
    end
end

local function enableGodMode()
    GodModeActive = true
    local character = getCharacter()
    local humanoid = character:FindFirstChild("Humanoid")
    
    if humanoid then
        humanoid.MaxHealth = 9e9
        humanoid.Health = 9e9
        humanoid.BreakJointsOnDeath = false
        
        if DamageConnection then
            DamageConnection:Disconnect()
        end
        
        DamageConnection = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            if GodModeActive and humanoid.Health < 9e9 then
                humanoid.Health = 9e9
            end
        end)
        
        for _, v in pairs(character:GetChildren()) do
            if v:IsA("Script") or v:IsA("LocalScript") then
                if v.Name:lower():find("damage") or v.Name:lower():find("kill") or v.Name:lower():find("health") then
                    v.Disabled = true
                end
            end
        end
        
        for _, v in pairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("RemoteEvent") and (v.Name:lower():find("damage") or v.Name:lower():find("hit") or v.Name:lower():find("take")) then
                local oldFire = v.FireServer
                v.FireServer = function() end
            end
        end
    end
    
    StarterGui:SetCore("SendNotification", {
        Title = L.godMode,
        Text = L.godOn,
        Duration = 2
    })
end

local function disableGodMode()
    GodModeActive = false
    if DamageConnection then
        DamageConnection:Disconnect()
        DamageConnection = nil
    end
    StarterGui:SetCore("SendNotification", {
        Title = L.godMode,
        Text = L.godOff,
        Duration = 1
    })
end

local function toggleGodMode()
    if GodModeActive then
        disableGodMode()
    else
        enableGodMode()
    end
end

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

if isMobile then
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "MobileGodMode"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local success = pcall(function()
        ScreenGui.Parent = CoreGui
    end)
    if not success then
        ScreenGui.Parent = PlayerGui
    end
    
    local GodButton = Instance.new("ImageButton")
    GodButton.Size = UDim2.new(0, 70, 0, 70)
    GodButton.Position = UDim2.new(0.5, -75, 0.9, -35)
    GodButton.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    GodButton.BackgroundTransparency = 0.2
    GodButton.Parent = ScreenGui
    
    local GodCorner = Instance.new("UICorner")
    GodCorner.CornerRadius = UDim.new(1, 0)
    GodCorner.Parent = GodButton
    
    local GodText = Instance.new("TextLabel")
    GodText.Size = UDim2.new(1, 0, 1, 0)
    GodText.BackgroundTransparency = 1
    GodText.Text = "👑\n" .. L.godButton
    GodText.TextColor3 = Color3.fromRGB(255, 255, 255)
    GodText.TextScaled = true
    GodText.Font = Enum.Font.GothamBold
    GodText.Parent = GodButton
    
    local HealButton = Instance.new("ImageButton")
    HealButton.Size = UDim2.new(0, 70, 0, 70)
    HealButton.Position = UDim2.new(0.5, 5, 0.9, -35)
    HealButton.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
    HealButton.BackgroundTransparency = 0.2
    HealButton.Parent = ScreenGui
    
    local HealCorner = Instance.new("UICorner")
    HealCorner.CornerRadius = UDim.new(1, 0)
    HealCorner.Parent = HealButton
    
    local HealText = Instance.new("TextLabel")
    HealText.Size = UDim2.new(1, 0, 1, 0)
    HealText.BackgroundTransparency = 1
    HealText.Text = "💚\n" .. L.healButton
    HealText.TextColor3 = Color3.fromRGB(255, 255, 255)
    HealText.TextScaled = true
    HealText.Font = Enum.Font.GothamBold
    HealText.Parent = HealButton
    
    GodButton.MouseButton1Click:Connect(toggleGodMode)
    HealButton.MouseButton1Click:Connect(healToFull)
    
    local function makeDraggable(button)
        local dragging = false
        local dragStart
        local startPos
        button.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = button.Position
            end
        end)
        button.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.Touch then
                local delta = input.Position - dragStart
                button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        button.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    end
    
    makeDraggable(GodButton)
    makeDraggable(HealButton)
    
else
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.Insert then
            healToFull()
        elseif input.KeyCode == Enum.KeyCode.Delete then
            toggleGodMode()
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(function(newChar)
    wait(1)
    if GodModeActive then
        enableGodMode()
    end
end)

StarterGui:SetCore("SendNotification", {
    Title = "💚👑 GOD MODE",
    Text = isMobile and "Buttons added" or "INSERT heal | DELETE God",
    Duration = 3
})
