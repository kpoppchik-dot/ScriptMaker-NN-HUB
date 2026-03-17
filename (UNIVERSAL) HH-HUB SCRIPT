--[[
    HH-HUB v3.0 — КРОСС-СЕРВЕР СЕТЬ
    
    База данных: kvdb.io (бесплатный HTTP key-value стор)
    Ключ bucket'а известен только пользователям скрипта.
    
    Каждый пользователь каждые 8с пишет себя в общую БД.
    Все читают БД и видят ВСЕХ пользователей на всех серверах/плейсах.
    Запись автоматически удаляется через 20с (TTL) если игрок вышел.
    
    Команды работают через ту же БД:
    Пишем команду в ключ CMD_userId — цель читает и выполняет.
]]

-- ═══════════════════════════════════════════════════════════
-- СЕРВИСЫ
-- ═══════════════════════════════════════════════════════════
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui       = game:GetService("StarterGui")
local RunService       = game:GetService("RunService")
local CoreGui          = game:GetService("CoreGui")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")

local LP        = Players.LocalPlayer
local PlayerGui = LP:FindFirstChild("PlayerGui")
    or LP:WaitForChild("PlayerGui", 10)

-- ═══════════════════════════════════════════════════════════
-- СКРЫТАЯ БАЗА ДАННЫХ
-- kvdb.io — бесплатный KV, bucket защищён секретным ключом
-- Никто без этого UUID не найдёт данные
-- ═══════════════════════════════════════════════════════════
local DB_BUCKET  = "b_k8x92mNqR7vTpL4wZcJ3hYdFs"   -- секретный bucket
local DB_BASE    = "https://kvdb.io/" .. DB_BUCKET .. "/"
local DB_TTL     = 20       -- секунд до auto-expire записи
local HEARTBEAT  = 8        -- секунд между обновлениями присутствия
local POLL_RATE  = 5        -- секунд между чтением списка
local CMD_PREFIX = "cmd_"   -- ключ команды: cmd_userId

-- HTTP хелперы
local httpOk = false
local function httpGet(url)
    local ok, res = pcall(function()
        return HttpService:GetAsync(url, true)
    end)
    if ok then httpOk=true; return res end
    return nil
end

local function httpSet(url, body)
    local ok, res = pcall(function()
        return HttpService:RequestAsync({
            Url    = url,
            Method = "POST",
            Headers= {["Content-Type"]="text/plain"},
            Body   = tostring(body),
        })
    end)
    if ok then httpOk=true end
    return ok
end

local function httpDel(url)
    pcall(function()
        HttpService:RequestAsync({Url=url, Method="DELETE"})
    end)
end

-- kvdb поддерживает TTL через заголовок X-Expire
local function dbSet(key, value, ttl)
    ttl = ttl or DB_TTL
    local ok, res = pcall(function()
        return HttpService:RequestAsync({
            Url    = DB_BASE .. key,
            Method = "POST",
            Headers= {
                ["Content-Type"] = "text/plain",
                ["X-Expire"]     = tostring(ttl),
            },
            Body   = tostring(value),
        })
    end)
    if ok then httpOk=true end
    return ok
end

local function dbGet(key)
    local ok, res = pcall(function()
        return HttpService:GetAsync(DB_BASE .. key, true)
    end)
    if ok and res and res ~= "" then httpOk=true; return res end
    return nil
end

local function dbDel(key)
    pcall(function()
        HttpService:RequestAsync({Url=DB_BASE..key, Method="DELETE"})
    end)
end

-- ═══════════════════════════════════════════════════════════
-- КЛЮЧИ В БД
-- presence_userId  = "displayName|name|placeId|jobId|tick"
-- cmd_userId       = "SENDER_ID|CMD|data|timestamp"
-- ═══════════════════════════════════════════════════════════
local MY_KEY     = "presence_" .. tostring(LP.UserId)
local MY_CMD_KEY = CMD_PREFIX   .. tostring(LP.UserId)

local function makePresenceValue()
    local placeId = tostring(game.PlaceId)
    local jobId   = tostring(game.JobId):sub(1, 8)  -- короткий ID сервера
    local t       = tostring(math.floor(tick()))
    -- Формат: displayName§name§placeId§jobId§timestamp
    return table.concat({
        LP.DisplayName,
        LP.Name,
        placeId,
        jobId,
        t,
    }, "§")
end

local function parsePresence(raw)
    if not raw or raw == "" then return nil end
    local parts = raw:split("§")
    if #parts < 5 then return nil end
    return {
        displayName = parts[1],
        name        = parts[2],
        placeId     = parts[3],
        jobId       = parts[4],
        lastSeen    = tonumber(parts[5]) or 0,
    }
end

-- ═══════════════════════════════════════════════════════════
-- РЕЕСТР ПОЛЬЗОВАТЕЛЕЙ (локальный кэш)
-- ═══════════════════════════════════════════════════════════
local Registry = {}   -- [userId] = {displayName, name, placeId, jobId, lastSeen, isLocal}
local RegistryLock = false

-- Регистрируем СЕБЯ в локальном сервере (атрибут) и в БД
local function registerSelf()
    pcall(function() LP:SetAttribute(NET_FLAG_LOCAL, "1") end)
    task.spawn(function()
        dbSet(MY_KEY, makePresenceValue(), DB_TTL + 5)
    end)
end
NET_FLAG_LOCAL = "__HHv3"

local function unregisterSelf()
    pcall(function() LP:SetAttribute(NET_FLAG_LOCAL, nil) end)
    task.spawn(function() dbDel(MY_KEY) end)
    task.spawn(function() dbDel(MY_CMD_KEY) end)
end

-- Читаем всех пользователей из БД
-- kvdb поддерживает list keys через /keys?prefix=...
local function fetchAllUsers()
    -- Получаем список ключей с префиксом "presence_"
    local keysRaw = httpGet(DB_BASE .. "?prefix=presence_&format=keys")
    if not keysRaw or keysRaw == "" then return end

    local newRegistry = {}

    -- Парсим список ключей (каждый на новой строке)
    for key in keysRaw:gmatch("[^\n]+") do
        key = key:match("^%s*(.-)%s*$")  -- trim
        if key:sub(1,9) == "presence_" then
            local userId = key:sub(10)
            local raw = dbGet(key)
            local info = parsePresence(raw)
            if info then
                info.userId  = userId
                info.isLocal = (userId == tostring(LP.UserId))
                    or (Players:FindFirstChild(info.name) ~= nil)
                -- Помечаем кто в текущем сервере
                info.sameServer = (info.jobId == tostring(game.JobId):sub(1,8))
                newRegistry[userId] = info
            end
        end
    end

    -- Добавляем локальных игроков с атрибутом (мгновенное обнаружение)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local ok, flag = pcall(function()
                return plr:GetAttribute(NET_FLAG_LOCAL)
            end)
            if ok and flag == "1" then
                local uid = tostring(plr.UserId)
                if not newRegistry[uid] then
                    newRegistry[uid] = {
                        displayName = plr.DisplayName,
                        name        = plr.Name,
                        placeId     = tostring(game.PlaceId),
                        jobId       = tostring(game.JobId):sub(1,8),
                        lastSeen    = tick(),
                        userId      = uid,
                        isLocal     = false,
                        sameServer  = true,
                    }
                end
            end
        end
    end

    -- Убираем устаревшие записи (lastSeen > DB_TTL+10 секунд назад)
    local now = math.floor(tick())
    for uid, info in pairs(newRegistry) do
        if now - info.lastSeen > DB_TTL + 10 then
            newRegistry[uid] = nil
        end
    end

    Registry = newRegistry
end

-- ═══════════════════════════════════════════════════════════
-- КОМАНДЫ
-- ═══════════════════════════════════════════════════════════
local processedCmds = {}  -- дедупликация

local function sendCmd(targetUserId, cmd, data)
    local payload = table.concat({
        tostring(LP.UserId),
        cmd,
        data or "",
        tostring(math.floor(tick())),
    }, "|")
    task.spawn(function()
        dbSet(CMD_PREFIX .. tostring(targetUserId), payload, 30)
    end)
end

local function readMyCmd()
    local raw = dbGet(MY_CMD_KEY)
    if not raw or raw == "" then return end

    -- Дедупликация
    if processedCmds[raw] then return end
    processedCmds[raw] = true
    -- Чистим старые
    local cnt = 0
    for k in pairs(processedCmds) do cnt=cnt+1 end
    if cnt > 50 then processedCmds = {} end

    local parts = raw:split("|")
    if #parts < 3 then return end
    local senderId = parts[1]
    local cmd      = parts[2]:upper()
    local data     = parts[3]

    -- Находим имя отправителя
    local senderName = senderId
    if Registry[senderId] then
        senderName = Registry[senderId].displayName
    else
        local sPlr = Players:GetPlayerByUserId(tonumber(senderId))
        if sPlr then senderName = sPlr.DisplayName end
    end

    executeCmd(cmd, data, senderName)
end

-- ═══════════════════════════════════════════════════════════
-- ВЫПОЛНЕНИЕ КОМАНД
-- ═══════════════════════════════════════════════════════════
local SpinConn     = nil
local LoopKillConn = nil

function executeCmd(cmd, data, senderName)
    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")

    if cmd == "KILL" then
        if hum then pcall(function() hum.Health=0 end) end

    elseif cmd == "FREEZE" then
        if hum then pcall(function() hum.WalkSpeed=0; hum.JumpPower=0 end) end

    elseif cmd == "UNFREEZE" then
        if hum then pcall(function() hum.WalkSpeed=16; hum.JumpPower=50 end) end

    elseif cmd == "FLING" then
        if root then pcall(function()
            local bv=Instance.new("BodyVelocity")
            bv.Velocity=Vector3.new(math.random(-100,100),math.random(150,250),math.random(-100,100))
            bv.MaxForce=Vector3.new(1e6,1e6,1e6); bv.P=1e6; bv.Parent=root
            game:GetService("Debris"):AddItem(bv,0.2)
        end) end

    elseif cmd == "SPIN" then
        if SpinConn then SpinConn:Disconnect() end
        local ang=0
        SpinConn=RunService.RenderStepped:Connect(function()
            ang=ang+12
            pcall(function()
                local p=root.Position
                root.CFrame=CFrame.new(p)*CFrame.Angles(0,math.rad(ang),0)
            end)
        end)

    elseif cmd == "UNSPIN" then
        if SpinConn then SpinConn:Disconnect(); SpinConn=nil end

    elseif cmd == "FLASH" then
        pcall(function()
            local old=CoreGui:FindFirstChild("_HHFlash")
            if old then old:Destroy() end
            local sg=Instance.new("ScreenGui")
            sg.Name="_HHFlash"; sg.ResetOnSpawn=false; sg.Parent=CoreGui
            local f=Instance.new("Frame",sg)
            f.Size=UDim2.new(1,0,1,0)
            f.BackgroundColor3=Color3.fromRGB(255,255,255)
            f.BackgroundTransparency=0
            TweenService:Create(f,TweenInfo.new(1),{BackgroundTransparency=1}):Play()
            game:GetService("Debris"):AddItem(sg,1.5)
        end)

    elseif cmd == "GOTO" then
        pcall(function()
            if not root then return end
            local p=data:split(",")
            if #p==3 then
                local x,y,z=tonumber(p[1]),tonumber(p[2]),tonumber(p[3])
                if x and y and z then root.CFrame=CFrame.new(x,y+5,z) end
            end
        end)

    elseif cmd == "NOTIFY" then
        safeNotify("📨 " .. (senderName or "?"), data ~= "" and data or "👋", 5)
        return  -- не показываем второе уведомление

    elseif cmd == "LOOPKILL" then
        if LoopKillConn then LoopKillConn:Disconnect() end
        LoopKillConn=RunService.Heartbeat:Connect(function()
            local h=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if h then pcall(function() h.Health=0 end) end
        end)
        task.delay(30,function()
            if LoopKillConn then LoopKillConn:Disconnect(); LoopKillConn=nil end
        end)

    elseif cmd == "STOPLOOPKILL" then
        if LoopKillConn then LoopKillConn:Disconnect(); LoopKillConn=nil end

    elseif cmd == "CRASH" then
        -- Максимально лагает клиент
        task.spawn(function()
            local t={}
            for i=1,1e6 do t[i]=i end
        end)
    end

    safeNotify("⚡ Получено", cmd .. " от " .. (senderName or "?"), 2)
end

-- ═══════════════════════════════════════════════════════════
-- GOD MODE
-- ═══════════════════════════════════════════════════════════
local GodModeActive = false
local GodConns      = {}

local function cleanGodConns()
    for _, c in ipairs(GodConns) do pcall(function() c:Disconnect() end) end
    GodConns = {}
end
local function addConn(c) if c then table.insert(GodConns, c) end end

local function applyForceField()
    local char = LP.Character
    if not char then return end
    local old = char:FindFirstChildOfClass("ForceField")
    if old then old:Destroy() end
    local ff = Instance.new("ForceField")
    ff.Visible = false
    ff.Parent  = char
end

local function enableGodMode()
    GodModeActive = true
    cleanGodConns()
    local char = LP.Character
    if not char then return end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum then return end

    -- 1. MaxHealth = math.huge
    pcall(function()
        hum.MaxHealth          = math.huge
        hum.Health             = math.huge
        hum.BreakJointsOnDeath = false
        hum.RequiresNeck       = false
    end)

    -- 2. Health watcher — мгновенный ответ на урон
    addConn(hum:GetPropertyChangedSignal("Health"):Connect(function()
        if not GodModeActive then return end
        if hum and hum.Parent and hum.Health < math.huge * 0.5 then
            pcall(function() hum.Health = math.huge end)
        end
    end))

    -- 3. MaxHealth watcher — игра не сбросит
    addConn(hum:GetPropertyChangedSignal("MaxHealth"):Connect(function()
        if not GodModeActive then return end
        pcall(function() hum.MaxHealth = math.huge; hum.Health = math.huge end)
    end))

    -- 4. ForceField — защита от взрывов и снарядов
    applyForceField()

    -- 5. Если ForceField удалили — восстанавливаем
    addConn(char.ChildRemoved:Connect(function(child)
        if not GodModeActive then return end
        if child:IsA("ForceField") then task.defer(applyForceField) end
    end))

    -- 6. Died event — восстанавливаем до respawn
    addConn(hum.Died:Connect(function()
        if not GodModeActive then return end
        task.defer(function()
            pcall(function() hum.Health = math.huge; hum.MaxHealth = math.huge end)
        end)
    end))

    -- 7. Heartbeat — последний рубеж каждый кадр
    addConn(RunService.Heartbeat:Connect(function()
        if not GodModeActive then return end
        local currentChar = LP.Character
        local h = currentChar and currentChar:FindFirstChildOfClass("Humanoid")
        -- Если персонаж сменился — переинициализируем
        if h and h ~= hum then
            task.defer(enableGodMode); return
        end
        if h and h.Health < 1 then
            pcall(function() h.Health = math.huge end)
        end
    end))

    -- 8. Защита root от заморозки
    if root then
        addConn(root:GetPropertyChangedSignal("Anchored"):Connect(function()
            if root.Anchored then
                pcall(function() root.Anchored = false end)
            end
        end))
    end

    -- 9. Удаляем Script/LocalScript внутри персонажа которые могут убивать
    addConn(char.DescendantAdded:Connect(function(desc)
        if not GodModeActive then return end
        if desc:IsA("Script") or desc:IsA("LocalScript") then
            task.defer(function() pcall(function() desc:Destroy() end) end)
        end
    end))

    safeNotify("👑 GOD MODE", "ENABLED — 9 слоёв защиты", 2)
end

local function disableGodMode()
    GodModeActive = false
    cleanGodConns()
    pcall(function()
        local char = LP.Character
        if not char then return end
        local ff = char:FindFirstChildOfClass("ForceField")
        if ff then ff:Destroy() end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.MaxHealth = 100; hum.Health = 100 end
    end)
    safeNotify("👑 GOD MODE", "DISABLED", 1)
end

local function healToFull()
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum.Health = hum.MaxHealth end)
        safeNotify("💚", "HP restored", 1)
    end
end

LP.CharacterAdded:Connect(function()
    task.wait(0.6)
    pcall(function() LP:SetAttribute(NET_FLAG_LOCAL, "1") end)
    if GodModeActive then
        task.wait(0.2)
        enableGodMode()
    end
end)

-- ═══════════════════════════════════════════════════════════
-- МОБИЛЬНЫЕ КНОПКИ
-- ═══════════════════════════════════════════════════════════
local isMobile=false
pcall(function()
    isMobile=UserInputService.TouchEnabled
        and not UserInputService.KeyboardEnabled
        and not UserInputService.MouseEnabled
end)

if isMobile then pcall(function()
    local sg=Instance.new("ScreenGui")
    sg.Name="_HHMob"; sg.ResetOnSpawn=false
    local ok=pcall(function() sg.Parent=CoreGui end)
    if not ok then sg.Parent=PlayerGui end
    local function mkB(pos,txt,col)
        local b=Instance.new("TextButton")
        b.Size=UDim2.new(0,68,0,68); b.Position=pos
        b.BackgroundColor3=col; b.BackgroundTransparency=0.15
        b.Text=txt; b.TextColor3=Color3.fromRGB(255,255,255)
        b.TextScaled=true; b.Font=Enum.Font.GothamBold; b.Parent=sg
        Instance.new("UICorner",b).CornerRadius=UDim.new(0,34)
        return b
    end
    local gb=mkB(UDim2.new(0.5,-72,0.9,-34),"👑\nGOD",Color3.fromRGB(255,215,0))
    local hb=mkB(UDim2.new(0.5,4,0.9,-34),"💚\nHEAL",Color3.fromRGB(0,200,80))
    gb.MouseButton1Click:Connect(function()
        if GodModeActive then disableGodMode() else enableGodMode() end
    end)
    hb.MouseButton1Click:Connect(healToFull)
    local function drag(b)
        local dg,ds,sp=false,nil,nil
        b.InputBegan:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.Touch then
                dg=true;ds=i.Position;sp=b.Position end
        end)
        b.InputChanged:Connect(function(i)
            if dg and i.UserInputType==Enum.UserInputType.Touch then
                local d=i.Position-ds
                b.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
            end
        end)
        b.InputEnded:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.Touch then dg=false end
        end)
    end
    drag(gb); drag(hb)
end) end

-- ═══════════════════════════════════════════════════════════
-- ГОРЯЧИЕ КЛАВИШИ
-- ═══════════════════════════════════════════════════════════
local showPanel  -- forward ref
local panelOpen  = false
local panelFrame = nil

pcall(function()
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if not isMobile then
            if input.KeyCode==Enum.KeyCode.Insert then healToFull()
            elseif input.KeyCode==Enum.KeyCode.Delete then
                if GodModeActive then disableGodMode() else enableGodMode() end
            end
        end
        if input.KeyCode==Enum.KeyCode.End then
            if not panelOpen then showPanel()
            else
                if panelFrame and panelFrame.Parent then panelFrame:Destroy() end
                panelOpen=false
            end
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════
-- GUI УТИЛИТЫ
-- ═══════════════════════════════════════════════════════════
local function F(par,sz,pos,bg,r)
    local f=Instance.new("Frame")
    f.Size=sz;f.Position=pos
    f.BackgroundColor3=bg or Color3.fromRGB(12,10,22)
    f.BorderSizePixel=0;f.Parent=par
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,r or 10)
    return f
end
local function L(par,sz,pos,txt,col,bold,xa)
    local l=Instance.new("TextLabel")
    l.Size=sz;l.Position=pos;l.BackgroundTransparency=1
    l.Text=txt;l.TextColor3=col or Color3.fromRGB(200,200,200)
    l.TextScaled=true;l.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextXAlignment=xa or Enum.TextXAlignment.Left;l.Parent=par
    return l
end
local function B(par,sz,pos,txt,bg)
    local b=Instance.new("TextButton")
    b.Size=sz;b.Position=pos;b.BackgroundColor3=bg
    b.Text=txt;b.TextColor3=Color3.fromRGB(255,255,255)
    b.TextScaled=true;b.Font=Enum.Font.GothamBold
    b.BorderSizePixel=0;b.Parent=par
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,8)
    return b
end
local function TB(par,sz,pos,ph)
    local b=Instance.new("TextBox")
    b.Size=sz;b.Position=pos
    b.BackgroundColor3=Color3.fromRGB(22,20,38)
    b.PlaceholderText=ph;b.Text=""
    b.TextColor3=Color3.fromRGB(240,240,240)
    b.PlaceholderColor3=Color3.fromRGB(100,100,110)
    b.TextScaled=true;b.Font=Enum.Font.Gotham
    b.ClearTextOnFocus=false;b.Parent=par
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,7)
    return b
end

-- ═══════════════════════════════════════════════════════════
-- ГЛАВНАЯ ПАНЕЛЬ
-- ═══════════════════════════════════════════════════════════
showPanel = function()
    if panelOpen then return end
    panelOpen=true

    panelFrame=Instance.new("ScreenGui")
    panelFrame.Name="_HHPanel"; panelFrame.ResetOnSpawn=false; panelFrame.Parent=PlayerGui

    local alive=true
    panelFrame.Destroying:Connect(function() alive=false; panelOpen=false end)

    -- Главное окно
    local win=F(panelFrame,UDim2.new(0,720,0,500),UDim2.new(0.5,-360,0.5,-250),
        Color3.fromRGB(10,9,20),16)
    win.Active=true; win.Draggable=true
    local ws=Instance.new("UIStroke",win)
    ws.Color=Color3.fromRGB(90,55,200); ws.Thickness=1.8

    -- Шапка
    local hdr=F(win,UDim2.new(1,0,0,48),UDim2.new(0,0,0,0),Color3.fromRGB(18,14,44),16)
    L(hdr,UDim2.new(0.5,0,1,0),UDim2.new(0,14,0,0),"⚡  HH-HUB  v3.0",
        Color3.fromRGB(200,160,255),true)

    -- Счётчик онлайн
    local onlineLbl=L(hdr,UDim2.new(0.3,0,1,0),UDim2.new(0.5,0,0,0),
        "🌐 0 онлайн",Color3.fromRGB(100,255,170),false,Enum.TextXAlignment.Center)

    -- HTTP статус
    local httpLbl=L(hdr,UDim2.new(0.18,0,1,0),UDim2.new(0.82,0,0,0),
        "DB: ...",Color3.fromRGB(200,200,100),false,Enum.TextXAlignment.Right)

    -- Закрыть
    local closeB=B(win,UDim2.new(0,32,0,32),UDim2.new(1,-38,0,8),"✕",Color3.fromRGB(200,40,40))
    closeB.ZIndex=5
    closeB.MouseButton1Click:Connect(function()
        panelFrame:Destroy(); panelOpen=false
    end)

    -- ── ЛЕВАЯ: список пользователей ─────────────────────────
    local leftBg=F(win,UDim2.new(0.42,-8,1,-60),UDim2.new(0,6,0,54),Color3.fromRGB(15,14,28),10)

    -- Поиск
    local searchBox=TB(leftBg,UDim2.new(1,-16,0,28),UDim2.new(0,8,0,6),"🔍 Поиск по нику...")

    -- Фильтр: все / этот сервер
    local filterAll=B(leftBg,UDim2.new(0.47,0,0,24),UDim2.new(0,8,0,40),"🌐 Все",Color3.fromRGB(60,50,110))
    local filterLocal=B(leftBg,UDim2.new(0.47,0,0,24),UDim2.new(0.53,-4,0,40),"📍 Этот сервер",Color3.fromRGB(30,25,60))
    local filterMode="all"  -- "all" или "local"

    -- Список
    local scroll=Instance.new("ScrollingFrame")
    scroll.Size=UDim2.new(1,-8,1,-76); scroll.Position=UDim2.new(0,4,0,72)
    scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0
    scroll.CanvasSize=UDim2.new(0,0,0,0); scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
    scroll.ScrollBarThickness=4; scroll.ScrollBarImageColor3=Color3.fromRGB(90,70,180)
    scroll.Parent=leftBg
    local sL=Instance.new("UIListLayout",scroll)
    sL.Padding=UDim.new(0,4); sL.SortOrder=Enum.SortOrder.LayoutOrder
    local sP=Instance.new("UIPadding",scroll)
    sP.PaddingLeft=UDim.new(0,4); sP.PaddingRight=UDim.new(0,4); sP.PaddingTop=UDim.new(0,2)

    filterAll.MouseButton1Click:Connect(function()
        filterMode="all"
        filterAll.BackgroundColor3=Color3.fromRGB(80,60,160)
        filterLocal.BackgroundColor3=Color3.fromRGB(30,25,60)
    end)
    filterLocal.MouseButton1Click:Connect(function()
        filterMode="local"
        filterAll.BackgroundColor3=Color3.fromRGB(30,25,60)
        filterLocal.BackgroundColor3=Color3.fromRGB(80,60,160)
    end)

    -- ── ПРАВАЯ: команды ──────────────────────────────────────
    local rightBg=F(win,UDim2.new(0.58,-8,1,-60),UDim2.new(0.42,2,0,54),Color3.fromRGB(15,14,28),10)

    local selLbl=L(rightBg,UDim2.new(1,-16,0,22),UDim2.new(0,8,0,8),
        "← Выбери игрока",Color3.fromRGB(160,160,180))
    local statusLbl=L(rightBg,UDim2.new(1,-16,0,18),UDim2.new(0,8,0,32),
        "",Color3.fromRGB(100,255,150))

    local notifyBox=TB(rightBg,UDim2.new(1,-16,0,26),UDim2.new(0,8,0,54),"📨 Текст уведомления...")

    local function setSt(txt,col)
        statusLbl.Text=txt; statusLbl.TextColor3=col or Color3.fromRGB(100,255,150)
        task.delay(3,function() if statusLbl.Parent then statusLbl.Text="" end end)
    end

    -- Команды
    local CMDS={
        {"💀 KILL",       "KILL",        nil,                       Color3.fromRGB(210,35,35)},
        {"❄️ FREEZE",     "FREEZE",      nil,                       Color3.fromRGB(40,110,220)},
        {"🔥 UNFREEZE",   "UNFREEZE",    nil,                       Color3.fromRGB(210,100,20)},
        {"💥 FLING",      "FLING",       nil,                       Color3.fromRGB(190,50,180)},
        {"🌀 SPIN",       "SPIN",        nil,                       Color3.fromRGB(60,170,210)},
        {"⏹ UNSPIN",     "UNSPIN",      nil,                       Color3.fromRGB(50,130,150)},
        {"✨ FLASH",      "FLASH",       nil,                       Color3.fromRGB(240,190,0)},
        {"🔁 LOOPKILL",  "LOOPKILL",    nil,                       Color3.fromRGB(170,20,20)},
        {"⛔ STOP LK",   "STOPLOOPKILL",nil,                       Color3.fromRGB(70,70,70)},
        {"💻 CRASH",     "CRASH",       nil,                       Color3.fromRGB(100,0,0)},
        {"📍 GOTO ME",   "GOTO",        function()
            local r=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if r then local p=r.Position; return p.X..","..p.Y..","..p.Z end
            return "0,0,0"
        end,                                                        Color3.fromRGB(40,170,90)},
        {"📨 NOTIFY",    "NOTIFY",      function()
            return notifyBox.Text~="" and notifyBox.Text or "👋"
        end,                                                        Color3.fromRGB(30,110,240)},
    }

    local COL=3; local BW=0.31; local BH=32; local GX=0.02; local SY=84
    local selectedUserId=nil

    for i,ci in ipairs(CMDS) do
        local col=(i-1)%COL; local row=math.floor((i-1)/COL)
        local xp=col*(BW+GX)+0.015; local yp=SY+row*(BH+5)
        local b=B(rightBg,UDim2.new(BW,0,0,BH),UDim2.new(xp,0,0,yp),ci[1],ci[4])
        b.TextSize=12; b.TextScaled=false

        local cmdName=ci[2]; local dataFn=ci[3]
        b.MouseButton1Click:Connect(function()
            if not selectedUserId then
                setSt("⚠️ Выбери игрока!",Color3.fromRGB(255,200,0)); return
            end
            local data=dataFn and dataFn() or ""
            sendCmd(selectedUserId, cmdName, data)
            local info=Registry[selectedUserId]
            local tName=info and info.displayName or selectedUserId
            setSt("✅ "..cmdName.." → "..tName)
        end)
    end

    -- ── СПИСОК ИГРОКОВ (обновляется) ──────────────────────────
    local searchStr=""
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        searchStr=searchBox.Text:lower()
    end)

    local function rebuildList()
        if not alive then return end
        pcall(function()
            for _,ch in ipairs(scroll:GetChildren()) do
                if ch:IsA("Frame") or ch:IsA("TextButton") then ch:Destroy() end
            end

            local total=0
            local shown=0

            for uid, info in pairs(Registry) do
                if uid==tostring(LP.UserId) then continue end
                total=total+1

                -- Фильтр сервер
                if filterMode=="local" and not info.sameServer then continue end

                -- Фильтр поиск
                if searchStr~="" then
                    local n=(info.name or ""):lower()
                    local dn=(info.displayName or ""):lower()
                    if not n:find(searchStr,1,true) and not dn:find(searchStr,1,true) then
                        continue
                    end
                end

                shown=shown+1
                local isSelected=uid==selectedUserId

                local card=F(scroll,UDim2.new(1,0,0,52),UDim2.new(0,0,0,0),
                    isSelected and Color3.fromRGB(60,46,110) or Color3.fromRGB(22,20,38),8)

                -- Индикатор: зелёный=этот сервер, синий=другой сервер
                local dot=Instance.new("Frame",card)
                dot.Size=UDim2.new(0,8,0,8); dot.Position=UDim2.new(0,6,0.5,-4)
                dot.BackgroundColor3=info.sameServer
                    and Color3.fromRGB(60,255,120)
                    or  Color3.fromRGB(80,140,255)
                dot.BorderSizePixel=0
                Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)

                -- Имя
                local nameLbl=L(card,UDim2.new(1,-20,0,22),UDim2.new(0,18,0,4),
                    info.displayName.."  (@"..info.name..")",
                    Color3.fromRGB(230,225,255),true)

                -- Инфо: плейс + сервер
                local placeStr=info.sameServer and "📍 Этот сервер" or ("🌐 Place "..info.placeId)
                L(card,UDim2.new(1,-20,0,18),UDim2.new(0,18,0,28),
                    placeStr.."  •  srv "..info.jobId,
                    Color3.fromRGB(140,135,170),false)

                -- Клик = выбор
                local clickArea=Instance.new("TextButton",card)
                clickArea.Size=UDim2.new(1,0,1,0)
                clickArea.BackgroundTransparency=1
                clickArea.Text=""; clickArea.ZIndex=2
                clickArea.MouseButton1Click:Connect(function()
                    selectedUserId=uid
                    selLbl.Text="🎯 "..info.displayName.." (@"..info.name..")"
                    setSt("Выбран: "..info.displayName)
                end)
            end

            -- Счётчик
            local countStr=total.." пользователей"
            if shown~=total then countStr=shown.."/"..total end
            onlineLbl.Text="🌐 "..countStr
            httpLbl.Text="DB: "..(httpOk and "✅" or "❌")

            if total==0 then
                local el=Instance.new("TextLabel",scroll)
                el.Size=UDim2.new(1,0,0,36); el.BackgroundTransparency=1
                el.Text="Нет других пользователей"
                el.TextColor3=Color3.fromRGB(130,130,130)
                el.TextScaled=true; el.Font=Enum.Font.Gotham
            end
        end)
    end

    rebuildList()

    -- Авто-обновление UI
    task.spawn(function()
        while alive do
            task.wait(POLL_RATE)
            if alive then pcall(rebuildList) end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
-- ФОНОВЫЕ ЗАДАЧИ
-- ═══════════════════════════════════════════════════════════

-- 1. Heartbeat: пишем себя в БД каждые N секунд
local function heartbeatLoop()
    task.spawn(function()
        while true do
            pcall(function()
                dbSet(MY_KEY, makePresenceValue(), DB_TTL + 5)
                -- Читаем свои команды
                readMyCmd()
            end)
            task.wait(HEARTBEAT)
        end
    end)
end

-- 2. Обновление реестра из БД
local function registryLoop()
    task.spawn(function()
        while true do
            task.wait(POLL_RATE)
            pcall(fetchAllUsers)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
-- ЗАПУСК
-- ═══════════════════════════════════════════════════════════
pcall(function() LP:SetAttribute(NET_FLAG_LOCAL,"1") end)
task.spawn(registerSelf)
heartbeatLoop()
registryLoop()

-- Очистка при выходе
game:BindToClose(function()
    pcall(unregisterSelf)
end)

-- Уведомление
task.spawn(function()
    task.wait(4)
    local ok,_ = pcall(function()
        -- Тест соединения
        dbSet("_ping_"..LP.UserId,"1",10)
    end)
    local dbStatus=httpOk and "БД ✅" or "БД ❌ (вкл HTTP в настройках)"
    local hint=isMobile and "Кнопки внизу | END = Панель" or "INSERT heal | DELETE God | END панель"
    safeNotify("⚡ HH-HUB v3",hint.." | "..dbStatus,5)
end)
