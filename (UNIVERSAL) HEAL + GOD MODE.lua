local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local LocalizationService = game:GetService("LocalizationService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local GodModeActive = false
local GodModeConnection = nil

local function getSystemLanguage()
    local locale = ""
    pcall(function()
        locale = LocalizationService.SystemLocaleId
    end)
    if locale == "" or locale == nil then
        pcall(function()
            locale = UserInputService:GetStringForKey("LANGUAGE") or "en"
        end)
    end
    if locale == "" or locale == nil then
        locale = "en"
    end
    locale = locale:lower():sub(1, 2)
    return locale
end

local systemLang = getSystemLanguage()
local L = {}

if systemLang == "ru" then
    L = {
        godMode = "👑 РЕЖИМ БОГА",
        heal = "💚 ИСЦЕЛЕНИЕ",
        godOn = "ВКЛЮЧЕН - ты бессмертен",
        godOff = "ВЫКЛЮЧЕН",
        healed = "Здоровье восстановлено",
        pcControls = "INSERT - исцеление | DELETE - Режим Бога",
        mobileHint = "Кнопки внизу экрана",
        loaded = "Загружен",
        platform = "Платформа",
        godButton = "БОГ",
        healButton = "ХИЛ",
        godDesc = "Режим Бога",
        healDesc = "Исцеление",
    }
elseif systemLang == "en" then
    L = {
        godMode = "👑 GOD MODE",
        heal = "💚 HEAL",
        godOn = "ENABLED - you are immortal",
        godOff = "DISABLED",
        healed = "Health restored",
        pcControls = "INSERT - heal | DELETE - God Mode",
        mobileHint = "Buttons at the bottom",
        loaded = "Loaded",
        platform = "Platform",
        godButton = "GOD",
        healButton = "HEAL",
        godDesc = "God Mode",
        healDesc = "Heal",
    }
elseif systemLang == "es" then
    L = {
        godMode = "👑 MODO DIOS",
        heal = "💚 CURAR",
        godOn = "ACTIVADO - eres inmortal",
        godOff = "DESACTIVADO",
        healed = "Salud restaurada",
        pcControls = "INSERT - curar | DELETE - Modo Dios",
        mobileHint = "Botones abajo",
        loaded = "Cargado",
        platform = "Plataforma",
        godButton = "DIOS",
        healButton = "CURAR",
        godDesc = "Modo Dios",
        healDesc = "Curar",
    }
elseif systemLang == "de" then
    L = {
        godMode = "👑 GOTT-MODUS",
        heal = "💚 HEILEN",
        godOn = "AKTIVIERT - du bist unsterblich",
        godOff = "DEAKTIVIERT",
        healed = "Gesundheit wiederhergestellt",
        pcControls = "INSERT - heilen | DELETE - Gott-Modus",
        mobileHint = "Tasten unten",
        loaded = "Geladen",
        platform = "Plattform",
        godButton = "GOTT",
        healButton = "HEILEN",
        godDesc = "Gott-Modus",
        healDesc = "Heilen",
    }
elseif systemLang == "fr" then
    L = {
        godMode = "👑 MODE DIEU",
        heal = "💚 SOIN",
        godOn = "ACTIVÉ - tu es immortel",
        godOff = "DÉSACTIVÉ",
        healed = "Vie restaurée",
        pcControls = "INSERT - soin | DELETE - Mode Dieu",
        mobileHint = "Boutons en bas",
        loaded = "Chargé",
        platform = "Plateforme",
        godButton = "DIEU",
        healButton = "SOIN",
        godDesc = "Mode Dieu",
        healDesc = "Soin",
    }
elseif systemLang == "zh" then
    L = {
        godMode = "👑 上帝模式",
        heal = "💚 治疗",
        godOn = "已开启 - 你是不朽的",
        godOff = "已关闭",
        healed = "生命值已恢复",
        pcControls = "INSERT - 治疗 | DELETE - 上帝模式",
        mobileHint = "按钮在屏幕底部",
        loaded = "已加载",
        platform = "平台",
        godButton = "上帝",
        healButton = "治疗",
        godDesc = "上帝模式",
        healDesc = "治疗",
    }
elseif systemLang == "ja" then
    L = {
        godMode = "👑 ゴッドモード",
        heal = "💚 回復",
        godOn = "有効 - あなたは不死身です",
        godOff = "無効",
        healed = "体力が回復しました",
        pcControls = "INSERT - 回復 | DELETE - ゴッドモード",
        mobileHint = "ボタンは画面下部",
        loaded = "ロード完了",
        platform = "プラットフォーム",
        godButton = "ゴッド",
        healButton = "回復",
        godDesc = "ゴッドモード",
        healDesc = "回復",
    }
elseif systemLang == "ko" then
    L = {
        godMode = "👑 신 모드",
        heal = "💚 치유",
        godOn = "활성화 - 당신은 불멸입니다",
        godOff = "비활성화",
        healed = "체력이 회복되었습니다",
        pcControls = "INSERT - 치유 | DELETE - 신 모드",
        mobileHint = "버튼은 화면 하단에",
        loaded = "로드됨",
        platform = "플랫폼",
        godButton = "신",
        healButton = "치유",
        godDesc = "신 모드",
        healDesc = "치유",
    }
else
    L = {
        godMode = "👑 GOD MODE",
        heal = "💚 HEAL",
        godOn = "ENABLED - you are immortal",
        godOff = "DISABLED",
        healed = "Health restored",
        pcControls = "INSERT - heal | DELETE - God Mode",
        mobileHint = "Buttons at the bottom",
        loaded = "Loaded",
        platform = "Platform",
        godButton = "GOD",
        healButton = "HEAL",
        godDesc = "God Mode",
        healDesc = "Heal",
    }
end

local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function healToFull()
    local character = getCharacter()
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.Health = humanoid.MaxHealth
        local highlight = Instance.new("Highlight")
        highlight.Parent = character
        highlight.FillColor = Color3.fromRGB(0, 255, 0)
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 1
        game:GetService("Debris"):AddItem(highlight, 0.5)
        StarterGui:SetCore("SendNotification", {
            Title = L.heal,
            Text = L.healed,
            Duration = 1
        })
    end
end

local function toggleGodMode()
    GodModeActive = not GodModeActive
    if GodModeActive then
        if GodModeConnection then
            GodModeConnection:Disconnect()
        end
        GodModeConnection = RunService.Heartbeat:Connect(function()
            pcall(function()
                local char = getCharacter()
                local hum = char:FindFirstChild("Humanoid")
                if hum then
                    if hum.Health < hum.MaxHealth then
                        hum.Health = hum.MaxHealth
                    end
                    local rootPart = char:FindFirstChild("HumanoidRootPart")
                    if rootPart and rootPart.Velocity.Y < -50 then
                        rootPart.Velocity = Vector3.new(rootPart.Velocity.X, 0, rootPart.Velocity.Z)
                    end
                end
            end)
        end)
        local char = getCharacter()
        local aura = Instance.new("Highlight")
        aura.Parent = char
        aura.FillColor = Color3.fromRGB(255, 215, 0)
        aura.FillTransparency = 0.3
        aura.OutlineTransparency = 1
        aura.Name = "GodModeAura"
        StarterGui:SetCore("SendNotification", {
            Title = L.godMode,
            Text = L.godOn,
            Duration = 2
        })
    else
        if GodModeConnection then
            GodModeConnection:Disconnect()
            GodModeConnection = nil
        end
        local char = getCharacter()
        local oldAura = char:FindFirstChild("GodModeAura")
        if oldAura then
            oldAura:Destroy()
        end
        StarterGui:SetCore("SendNotification", {
            Title = L.godMode,
            Text = L.godOff,
            Duration = 1
        })
    end
end

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isAndroid = isMobile and (UserInputService:GetPlatform() == Enum.Platform.Android)
local isIOS = isMobile and (UserInputService:GetPlatform() == Enum.Platform.IOS)

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
    GodButton.Name = "GodModeButton"
    GodButton.Size = UDim2.new(0, 70, 0, 70)
    GodButton.Position = UDim2.new(0.5, -75, 0.9, -35)
    GodButton.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    GodButton.BackgroundTransparency = 0.2
    GodButton.Parent = ScreenGui
    local GodCorner = Instance.new("UICorner")
    GodCorner.CornerRadius = UDim.new(1, 0)
    GodCorner.Parent = GodButton
    local GodIcon = Instance.new("TextLabel")
    GodIcon.Size = UDim2.new(1, 0, 0.6, 0)
    GodIcon.Position = UDim2.new(0, 0, 0, 5)
    GodIcon.BackgroundTransparency = 1
    GodIcon.Text = "👑"
    GodIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
    GodIcon.TextScaled = true
    GodIcon.Font = Enum.Font.GothamBold
    GodIcon.Parent = GodButton
    local GodText = Instance.new("TextLabel")
    GodText.Size = UDim2.new(1, 0, 0.3, 0)
    GodText.Position = UDim2.new(0, 0, 0.6, 0)
    GodText.BackgroundTransparency = 1
    GodText.Text = L.godButton
    GodText.TextColor3 = Color3.fromRGB(255, 255, 255)
    GodText.TextScaled = true
    GodText.Font = Enum.Font.GothamBold
    GodText.Parent = GodButton
    local HealButton = Instance.new("ImageButton")
    HealButton.Name = "HealButton"
    HealButton.Size = UDim2.new(0, 70, 0, 70)
    HealButton.Position = UDim2.new(0.5, 5, 0.9, -35)
    HealButton.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
    HealButton.BackgroundTransparency = 0.2
    HealButton.Parent = ScreenGui
    local HealCorner = Instance.new("UICorner")
    HealCorner.CornerRadius = UDim.new(1, 0)
    HealCorner.Parent = HealButton
    local HealIcon = Instance.new("TextLabel")
    HealIcon.Size = UDim2.new(1, 0, 0.6, 0)
    HealIcon.Position = UDim2.new(0, 0, 0, 5)
    HealIcon.BackgroundTransparency = 1
    HealIcon.Text = "💚"
    HealIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
    HealIcon.TextScaled = true
    HealIcon.Font = Enum.Font.GothamBold
    HealIcon.Parent = HealButton
    local HealText = Instance.new("TextLabel")
    HealText.Size = UDim2.new(1, 0, 0.3, 0)
    HealText.Position = UDim2.new(0, 0, 0.6, 0)
    HealText.BackgroundTransparency = 1
    HealText.Text = L.healButton
    HealText.TextColor3 = Color3.fromRGB(255, 255, 255)
    HealText.TextScaled = true
    HealText.Font = Enum.Font.GothamBold
    HealText.Parent = HealButton
    local function animateButton(button)
        TweenService:Create(button, TweenInfo.new(0.1), {Size = UDim2.new(0, 65, 0, 65)}):Play()
        wait(0.1)
        TweenService:Create(button, TweenInfo.new(0.1), {Size = UDim2.new(0, 70, 0, 70)}):Play()
    end
    GodButton.MouseButton1Click:Connect(function()
        animateButton(GodButton)
        toggleGodMode()
        GodButton.BackgroundColor3 = GodModeActive and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(150, 150, 150)
    end)
    HealButton.MouseButton1Click:Connect(function()
        animateButton(HealButton)
        healToFull()
        HealButton.BackgroundColor3 = Color3.fromRGB(0, 255, 200)
        wait(0.2)
        HealButton.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
    end)
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
end

if not isMobile then
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.Insert then
            healToFull()
        elseif input.KeyCode == Enum.KeyCode.Delete then
            toggleGodMode()
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(function()
    wait(1)
    healToFull()
    if GodModeActive then
        wait(0.1)
        toggleGodMode()
        wait(0.1)
        toggleGodMode()
    end
end)

StarterGui:SetCore("SendNotification", {
    Title = "💚👑 " .. L.godDesc .. " + " .. L.healDesc,
    Text = isMobile and L.mobileHint or L.pcControls,
    Duration = 4
})