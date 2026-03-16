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
local AdminPanelVisible = false
local AdminFrame = nil

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

local function safeNotify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 2
        })
    end)
end

local function getCharacter()
    local success, result = pcall(function()
        return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait(5)
    end)
    if success and result then
        return result
    end
    return nil
end

local function healToFull()
    local character = getCharacter()
    if not character then return end
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.Health = humanoid.MaxHealth
        safeNotify(L.heal, L.healed, 1)
    end
end

local function enableGodMode()
    GodModeActive = true
    local character = getCharacter()
    if not character then return end
    local humanoid = character:FindFirstChild("Humanoid")
    
    if humanoid then
        humanoid.MaxHealth = 9e9
        humanoid.Health = 9e9
        humanoid.BreakJointsOnDeath = false
        
        if DamageConnection then
            DamageConnection:Disconnect()
        end
        
        DamageConnection = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            if GodModeActive and humanoid and humanoid.Health < 9e9 then
                humanoid.Health = 9e9
            end
        end)
        
        pcall(function()
            for _, v in pairs(character:GetChildren()) do
                if v:IsA("Script") or v:IsA("LocalScript") then
                    if v.Name:lower():find("damage") or v.Name:lower():find("kill") or v.Name:lower():find("health") then
                        v.Disabled = true
                    end
                end
            end
        end)
    end
    
    safeNotify(L.godMode, L.godOn, 2)
end

local function disableGodMode()
    GodModeActive = false
    if DamageConnection then
        DamageConnection:Disconnect()
        DamageConnection = nil
    end
    safeNotify(L.godMode, L.godOff, 1)
end

local function toggleGodMode()
    if GodModeActive then
        disableGodMode()
    else
        enableGodMode()
    end
end

local isMobile = pcall(function()
    return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end) or false

if isMobile then
    pcall(function()
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
        
        local GodButton = Instance.new("TextButton")
        GodButton.Size = UDim2.new(0, 70, 0, 70)
        GodButton.Position = UDim2.new(0.5, -75, 0.9, -35)
        GodButton.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
        GodButton.BackgroundTransparency = 0.2
        GodButton.Text = "👑\n" .. L.godButton
        GodButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        GodButton.TextScaled = true
        GodButton.Font = Enum.Font.GothamBold
        GodButton.Parent = ScreenGui
        
        local HealButton = Instance.new("TextButton")
        HealButton.Size = UDim2.new(0, 70, 0, 70)
        HealButton.Position = UDim2.new(0.5, 5, 0.9, -35)
        HealButton.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
        HealButton.BackgroundTransparency = 0.2
        HealButton.Text = "💚\n" .. L.healButton
        HealButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        HealButton.TextScaled = true
        HealButton.Font = Enum.Font.GothamBold
        HealButton.Parent = ScreenGui
        
        local function roundCorners(btn)
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(1, 0)
            c.Parent = btn
        end
        roundCorners(GodButton)
        roundCorners(HealButton)
        
        GodButton.MouseButton1Click:Connect(toggleGodMode)
        HealButton.MouseButton1Click:Connect(healToFull)
        
        local function makeDraggable(btn)
            local dragging = false
            local dragStart
            local startPos
            btn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    dragStart = input.Position
                    startPos = btn.Position
                end
            end)
            btn.InputChanged:Connect(function(input)
                if dragging and input.UserInputType == Enum.UserInputType.Touch then
                    local delta = input.Position - dragStart
                    btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                end
            end)
            btn.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)
        end
        makeDraggable(GodButton)
        makeDraggable(HealButton)
    end)
end

pcall(function()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.Insert then
            healToFull()
        elseif input.KeyCode == Enum.KeyCode.Delete then
            toggleGodMode()
        elseif input.KeyCode == Enum.KeyCode.End and not isMobile then
            if not AdminPanelVisible then
                showAdminLogin()
            else
                if AdminFrame then
                    AdminFrame:Destroy()
                    AdminPanelVisible = false
                end
            end
        end
    end)
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if GodModeActive then
        enableGodMode()
    end
end)

local function showAdminLogin()
    pcall(function()
        local loginGui = Instance.new("ScreenGui")
        loginGui.Name = "AdminLogin"
        loginGui.ResetOnSpawn = false
        loginGui.Parent = PlayerGui
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 300, 0, 150)
        frame.Position = UDim2.new(0.5, -150, 0.5, -75)
        frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
        frame.BackgroundTransparency = 0.1
        frame.Active = true
        frame.Draggable = true
        frame.Parent = loginGui
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = frame
        
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 40)
        title.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
        title.Text = "🔐 ADMIN LOGIN"
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextScaled = true
        title.Font = Enum.Font.GothamBold
        title.Parent = frame
        
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 25, 0, 25)
        closeBtn.Position = UDim2.new(1, -30, 0, 8)
        closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
        closeBtn.Text = "✕"
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.TextScaled = true
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.Parent = title
        
        closeBtn.MouseButton1Click:Connect(function()
            loginGui:Destroy()
        end)
        
        local input = Instance.new("TextBox")
        input.Size = UDim2.new(0.8, 0, 0, 35)
        input.Position = UDim2.new(0.1, 0, 0.5, -20)
        input.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        input.PlaceholderText = "Enter password..."
        input.Text = ""
        input.TextColor3 = Color3.fromRGB(255, 255, 255)
        input.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
        input.Parent = frame
        
        local inputCorner = Instance.new("UICorner")
        inputCorner.CornerRadius = UDim.new(0, 5)
        inputCorner.Parent = input
        
        local loginBtn = Instance.new("TextButton")
        loginBtn.Size = UDim2.new(0.5, 0, 0, 35)
        loginBtn.Position = UDim2.new(0.25, 0, 0.8, 0)
        loginBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        loginBtn.Text = "LOGIN"
        loginBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        loginBtn.TextScaled = true
        loginBtn.Font = Enum.Font.GothamBold
        loginBtn.Parent = frame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 5)
        btnCorner.Parent = loginBtn
        
        local function checkPassword()
            if input.Text == "HH-HUB|ADMIN" or input.Text == "S1R0TA" then
                loginGui:Destroy()
                showAdminPanel()
            else
                safeNotify("❌ Access Denied", "Invalid password", 2)
            end
        end
        
        loginBtn.MouseButton1Click:Connect(checkPassword)
        input.FocusLost:Connect(function()
            if input.Text ~= "" then
                checkPassword()
            end
        end)
    end)
end

local function showAdminPanel()
    AdminPanelVisible = true
    AdminFrame = Instance.new("ScreenGui")
    AdminFrame.Name = "AdminPanel"
    AdminFrame.ResetOnSpawn = false
    AdminFrame.Parent = PlayerGui
    
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 600, 0, 400)
    main.Position = UDim2.new(0.5, -300, 0.5, -200)
    main.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    main.BackgroundTransparency = 0.05
    main.Active = true
    main.Draggable = true
    main.Parent = AdminFrame
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 15)
    mainCorner.Parent = main
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
    title.Text = "👑 ADMIN PANEL 👑"
    title.TextColor3 = Color3.fromRGB(255, 215, 0)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = main
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextScaled = true
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = title
    
    closeBtn.MouseButton1Click:Connect(function()
        if AdminFrame then
            AdminFrame:Destroy()
            AdminPanelVisible = false
        end
    end)
    
    local playerList = Instance.new("ScrollingFrame")
    playerList.Size = UDim2.new(0.4, -10, 1, -60)
    playerList.Position = UDim2.new(0, 10, 0, 50)
    playerList.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    playerList.BackgroundTransparency = 0.3
    playerList.BorderSizePixel = 0
    playerList.CanvasSize = UDim2.new(0, 0, 0, 0)
    playerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    playerList.Parent = main
    
    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0, 10)
    listCorner.Parent = playerList
    
    local listTitle = Instance.new("TextLabel")
    listTitle.Size = UDim2.new(1, 0, 0, 30)
    listTitle.BackgroundColor3 = Color3.fromRGB(40, 35, 50)
    listTitle.Text = "PLAYERS ONLINE"
    listTitle.TextColor3 = Color3.fromRGB(200, 200, 255)
    listTitle.TextScaled = true
    listTitle.Font = Enum.Font.GothamBold
    listTitle.Parent = playerList
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 2)
    listLayout.Parent = playerList
    
    local controlPanel = Instance.new("Frame")
    controlPanel.Size = UDim2.new(0.6, -20, 1, -60)
    controlPanel.Position = UDim2.new(0.4, 10, 0, 50)
    controlPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    controlPanel.BackgroundTransparency = 0.3
    controlPanel.Parent = main
    
    local controlCorner = Instance.new("UICorner")
    controlCorner.CornerRadius = UDim.new(0, 10)
    controlCorner.Parent = controlPanel
    
    local controlTitle = Instance.new("TextLabel")
    controlTitle.Size = UDim2.new(1, 0, 0, 30)
    controlTitle.BackgroundColor3 = Color3.fromRGB(40, 35, 50)
    controlTitle.Text = "CONTROL PANEL"
    controlTitle.TextColor3 = Color3.fromRGB(200, 200, 255)
    controlTitle.TextScaled = true
    controlTitle.Font = Enum.Font.GothamBold
    controlTitle.Parent = controlPanel
    
    local selectedLabel = Instance.new("TextLabel")
    selectedLabel.Size = UDim2.new(1, -20, 0, 25)
    selectedLabel.Position = UDim2.new(0, 10, 0, 40)
    selectedLabel.BackgroundTransparency = 1
    selectedLabel.Text = "Selected: None"
    selectedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
    selectedLabel.TextScaled = true
    selectedLabel.Font = Enum.Font.Gotham
    selectedLabel.Parent = controlPanel
    
    local killBtn = Instance.new("TextButton")
    killBtn.Size = UDim2.new(0.8, 0, 0, 35)
    killBtn.Position = UDim2.new(0.1, 0, 0, 80)
    killBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    killBtn.Text = "💀 KILL"
    killBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    killBtn.TextScaled = true
    killBtn.Font = Enum.Font.GothamBold
    killBtn.Parent = controlPanel
    
    local kickBox = Instance.new("TextBox")
    kickBox.Size = UDim2.new(0.8, 0, 0, 30)
    kickBox.Position = UDim2.new(0.1, 0, 0, 125)
    kickBox.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    kickBox.PlaceholderText = "Kick reason..."
    kickBox.Text = ""
    kickBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    kickBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    kickBox.Parent = controlPanel
    
    local kickBtn = Instance.new("TextButton")
    kickBtn.Size = UDim2.new(0.8, 0, 0, 35)
    kickBtn.Position = UDim2.new(0.1, 0, 0, 165)
    kickBtn.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
    kickBtn.Text = "👢 KICK"
    kickBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    kickBtn.TextScaled = true
    kickBtn.Font = Enum.Font.GothamBold
    kickBtn.Parent = controlPanel
    
    local notifyBox = Instance.new("TextBox")
    notifyBox.Size = UDim2.new(0.8, 0, 0, 30)
    notifyBox.Position = UDim2.new(0.1, 0, 0, 215)
    notifyBox.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    notifyBox.PlaceholderText = "Notification..."
    notifyBox.Text = ""
    notifyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    notifyBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    notifyBox.Parent = controlPanel
    
    local notifyBtn = Instance.new("TextButton")
    notifyBtn.Size = UDim2.new(0.8, 0, 0, 35)
    notifyBtn.Position = UDim2.new(0.1, 0, 0, 255)
    notifyBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
    notifyBtn.Text = "📨 NOTIFY"
    notifyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    notifyBtn.TextScaled = true
    notifyBtn.Font = Enum.Font.GothamBold
    notifyBtn.Parent = controlPanel
    
    local infoBtn = Instance.new("TextButton")
    infoBtn.Size = UDim2.new(0.8, 0, 0, 35)
    infoBtn.Position = UDim2.new(0.1, 0, 0, 305)
    infoBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
    infoBtn.Text = "ℹ️ INFO"
    infoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    infoBtn.TextScaled = true
    infoBtn.Font = Enum.Font.GothamBold
    infoBtn.Parent = controlPanel
    
    local selectedPlayer = nil
    
    local function updatePlayerList()
        pcall(function()
            for _, v in pairs(playerList:GetChildren()) do
                if v:IsA("TextButton") and v ~= listTitle then
                    v:Destroy()
                end
            end
            for _, plr in pairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    local btn = Instance.new("TextButton")
                    btn.Size = UDim2.new(1, -10, 0, 30)
                    btn.BackgroundColor3 = Color3.fromRGB(50, 45, 65)
                    btn.Text = plr.Name
                    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    btn.TextScaled = true
                    btn.Font = Enum.Font.Gotham
                    btn.Parent = playerList
                    
                    local c = Instance.new("UICorner")
                    c.CornerRadius = UDim.new(0, 5)
                    c.Parent = btn
                    
                    btn.MouseButton1Click:Connect(function()
                        selectedPlayer = plr
                        selectedLabel.Text = "Selected: " .. plr.Name
                    end)
                end
            end
        end)
    end
    
    updatePlayerList()
    
    killBtn.MouseButton1Click:Connect(function()
        if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("Humanoid") then
            pcall(function()
                selectedPlayer.Character.Humanoid.Health = 0
                safeNotify("💀 KILLED", selectedPlayer.Name .. " killed", 2)
            end)
        end
    end)
    
    kickBtn.MouseButton1Click:Connect(function()
        if selectedPlayer then
            local reason = kickBox.Text
            if reason == "" then reason = "Kicked" end
            pcall(function()
                selectedPlayer:Kick(reason)
                safeNotify("👢 KICKED", selectedPlayer.Name .. " kicked", 2)
            end)
        end
    end)
    
    notifyBtn.MouseButton1Click:Connect(function()
        if selectedPlayer then
            local msg = notifyBox.Text
            if msg == "" then msg = "Hello!" end
            pcall(function()
                safeNotify("📨 Admin", msg, 3)
            end)
        end
    end)
    
    infoBtn.MouseButton1Click:Connect(function()
        if selectedPlayer then
            local device = "PC"
            pcall(function()
                if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
                    device = "Mobile"
                end
            end)
            safeNotify("ℹ️ Info", selectedPlayer.Name .. "\nDevice: " .. device, 3)
        end
    end)
    
    while AdminPanelVisible do
        task.wait(3)
        if AdminPanelVisible then
            pcall(updatePlayerList)
        end
    end
end

safeNotify("💚👑 LOADED", "INSERT heal | DELETE God", 4)
