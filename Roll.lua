-- ============================================================
-- Roll A Gnome - Auto Teleport + Buy + Draggable UI
-- 8 เป้าหมาย: Hornet, Bunny, Frog, Cat, Dog, Turtle, Bee, Owl
-- ============================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- ตั้ งค ่ า
local TARGET_NAMES = {"Hornet", "Bunny", "Frog", "Cat", "Dog", "Turtle", "Bee", "Owl"}
local TARGET_THAI = {Hornet="ฮอร์เนต", Bunny="กระต่าย", Frog="กบ", Cat="แมว", Dog="หมา", Turtle="เต่า", Bee="ผึ้ง", Owl="นกฮูก"}
local TARGET_ENABLED = {}
for _,n in ipairs(TARGET_NAMES) do TARGET_ENABLED[n] = true end

local SCAN_RANGE = 1000
local SCAN_INTERVAL = 2

-- สถิต ิ
local stats = {found=0, bought=0}
for _,n in ipairs(TARGET_NAMES) do stats[string.lower(n)] = 0 end

-- UI vars
local uiRefs = {}
local isDragging = false
local dragOffset = Vector2.new(0,0)
local running = true
local skipCurrent = false
local logHistory = {}

-- ============================================================
-- UI
-- ============================================================
local function createUI()
    local old = Player:FindFirstChild("BluezyGPT_UI")
    if old then old:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BluezyGPT_UI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = Player:FindFirstChild("PlayerGui") or Player

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 340, 0, 420)
    main.Position = UDim2.new(0, 10, 0, 10)
    main.BackgroundColor3 = Color3.fromRGB(12, 12, 28)
    main.BorderSizePixel = 0
    main.Parent = screenGui

    local border = Instance.new("Frame")
    border.Size = UDim2.new(1,0,1,0)
    border.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
    border.BackgroundTransparency = 0.7
    border.BorderSizePixel = 0
    border.Parent = main

    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1,0,0,35)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 15, 50)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = main

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1,-30,1,0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "🐝 BluezyGPT Auto-Find v3"
    titleLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
    titleLbl.TextSize = 14
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0,30,0,35)
    closeBtn.Position = UDim2.new(1,-30,0,0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180,40,40)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

    -- Drag
    titleBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            dragOffset = inp.Position - Vector2.new(main.AbsolutePosition.X, main.AbsolutePosition.Y)
        end
    end)
    titleBar.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = false end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(inp)
        if isDragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local p = inp.Position - dragOffset
            main.Position = UDim2.new(0,p.X,0,p.Y)
        end
    end)

    -- Status
    local stLbl = Instance.new("TextLabel")
    stLbl.Size = UDim2.new(1,-10,0,22)
    stLbl.Position = UDim2.new(0,5,0,40)
    stLbl.BackgroundTransparency = 1
    stLbl.Text = "สถานะ: กำลังสแกน..."
    stLbl.TextColor3 = Color3.fromRGB(100,220,255)
    stLbl.TextSize = 12
    stLbl.Font = Enum.Font.Gotham
    stLbl.TextXAlignment = Enum.TextXAlignment.Left
    stLbl.Parent = main

    local tgLbl = Instance.new("TextLabel")
    tgLbl.Size = UDim2.new(1,-10,0,22)
    tgLbl.Position = UDim2.new(0,5,0,62)
    tgLbl.BackgroundTransparency = 1
    tgLbl.Text = "เป้าหมาย: -"
    tgLbl.TextColor3 = Color3.fromRGB(255,180,50)
    tgLbl.TextSize = 12
    tgLbl.Font = Enum.Font.Gotham
    tgLbl.TextXAlignment = Enum.TextXAlignment.Left
    tgLbl.Parent = main

    local dsLbl = Instance.new("TextLabel")
    dsLbl.Size = UDim2.new(1,-10,0,22)
    dsLbl.Position = UDim2.new(0,5,0,84)
    dsLbl.BackgroundTransparency = 1
    dsLbl.Text = "ระยะ: -"
    dsLbl.TextColor3 = Color3.fromRGB(180,180,180)
    dsLbl.TextSize = 11
    dsLbl.Font = Enum.Font.Gotham
    dsLbl.TextXAlignment = Enum.TextXAlignment.Left
    dsLbl.Parent = main

    -- Toggle buttons (8 ตัว เรียง 2 แถว)
    local colors = {
        Hornet=Color3.fromRGB(200,180,50), Bunny=Color3.fromRGB(220,120,120),
        Frog=Color3.fromRGB(80,180,80), Cat=Color3.fromRGB(180,140,80),
        Dog=Color3.fromRGB(160,100,60), Turtle=Color3.fromRGB(60,140,60),
        Bee=Color3.fromRGB(220,200,50), Owl=Color3.fromRGB(120,80,160)
    }
    local btnSize = 78
    local gap = 5
    local startX = 5
    local startY = 110

    for i, name in ipairs(TARGET_NAMES) do
        local col = (i-1) % 4
        local row = math.floor((i-1) / 4)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, btnSize, 0, 28)
        btn.Position = UDim2.new(0, startX + col*(btnSize+gap), 0, startY + row*33)
        btn.BackgroundColor3 = colors[name]
        btn.Text = TARGET_THAI[name] .. " (" .. name .. ")"
        btn.TextColor3 = Color3.fromRGB(255,255,255)
        btn.TextSize = 10
        btn.Font = Enum.Font.GothamBold
        btn.Parent = main
        btn.MouseButton1Click:Connect(function()
            TARGET_ENABLED[name] = not TARGET_ENABLED[name]
            btn.BackgroundColor3 = TARGET_ENABLED[name] and colors[name] or Color3.fromRGB(80,80,80)
            btn.TextStrokeTransparency = TARGET_ENABLED[name] and 1 or 0
        end)
    end

    -- Stats
    local sf = Instance.new("Frame")
    sf.Size = UDim2.new(1,-10,0,80)
    sf.Position = UDim2.new(0,5,0,180)
    sf.BackgroundColor3 = Color3.fromRGB(20,20,40)
    sf.BorderSizePixel = 0
    sf.Parent = main

    local stTxt = Instance.new("TextLabel")
    stTxt.Name = "StatsText"
    stTxt.Size = UDim2.new(1,0,1,0)
    stTxt.Position = UDim2.new(0,5,0,0)
    stTxt.BackgroundTransparency = 1
    stTxt.Text = "พบ: 0 | ซื้อ: 0"
    stTxt.TextColor3 = Color3.fromRGB(160,160,200)
    stTxt.TextSize = 11
    stTxt.Font = Enum.Font.Gotham
    stTxt.TextXAlignment = Enum.TextXAlignment.Left
    stTxt.TextYAlignment = Enum.TextYAlignment.Top
    stTxt.TextWrapped = true
    stTxt.Parent = sf

    -- Buttons row
    local btnY = 270
    local skipBtn = Instance.new("TextButton")
    skipBtn.Size = UDim2.new(0,75,0,28)
    skipBtn.Position = UDim2.new(0,5,0,btnY)
    skipBtn.BackgroundColor3 = Color3.fromRGB(200,150,30)
    skipBtn.Text = "⏭ ข้าม"
    skipBtn.TextColor3 = Color3.fromRGB(255,255,255)
    skipBtn.TextSize = 11
    skipBtn.Font = Enum.Font.GothamBold
    skipBtn.Parent = main

    local runBtn = Instance.new("TextButton")
    runBtn.Size = UDim2.new(0,90,0,28)
    runBtn.Position = UDim2.new(0,90,0,btnY)
    runBtn.BackgroundColor3 = Color3.fromRGB(50,180,80)
    runBtn.Text = "⏸ หยุด"
    runBtn.TextColor3 = Color3.fromRGB(255,255,255)
    runBtn.TextSize = 11
    runBtn.Font = Enum.Font.GothamBold
    runBtn.Parent = main

    local refBtn = Instance.new("TextButton")
    refBtn.Size = UDim2.new(0,75,0,28)
    refBtn.Position = UDim2.new(0,190,0,btnY)
    refBtn.BackgroundColor3 = Color3.fromRGB(60,100,200)
    refBtn.Text = "🔄 รีเฟรช"
    refBtn.TextColor3 = Color3.fromRGB(255,255,255)
    refBtn.TextSize = 10
    refBtn.Font = Enum.Font.GothamBold
    refBtn.Parent = main

    local allBtn = Instance.new("TextButton")
    allBtn.Size = UDim2.new(0,75,0,28)
    allBtn.Position = UDim2.new(0,275,0,btnY)
    allBtn.BackgroundColor3 = Color3.fromRGB(180,60,180)
    allBtn.Text = "📋 ทั้งหมด"
    allBtn.TextColor3 = Color3.fromRGB(255,255,255)
    allBtn.TextSize = 10
    allBtn.Font = Enum.Font.GothamBold
    allBtn.Parent = main

    -- Log
    local lf = Instance.new("Frame")
    lf.Size = UDim2.new(1,-10,0,100)
    lf.Position = UDim2.new(0,5,0,310)
    lf.BackgroundColor3 = Color3.fromRGB(8,8,18)
    lf.BorderSizePixel = 0
    lf.Parent = main

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1,0,1,0)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = lf

    local logLbl = Instance.new("TextLabel")
    logLbl.Name = "LogLbl"
    logLbl.Size = UDim2.new(1,-6,0,0)
    logLbl.Position = UDim2.new(0,3,0,0)
    logLbl.BackgroundTransparency = 1
    logLbl.Text = "> พร้อมทำงาน..."
    logLbl.TextColor3 = Color3.fromRGB(100,180,100)
    logLbl.TextSize = 9
    logLbl.Font = Enum.Font.Gotham
    logLbl.TextXAlignment = Enum.TextXAlignment.Left
    logLbl.TextYAlignment = Enum.TextYAlignment.Top
    logLbl.TextWrapped = true
    logLbl.Parent = scroll

    uiRefs = {
        status = stLbl, target = tgLbl, dist = dsLbl,
        stats = stTxt, log = logLbl,
        run = runBtn, skip = skipBtn, refresh = refBtn, all = allBtn
    }

    return screenGui
end

-- ============================================================
-- Functions
-- ============================================================
local function addLog(msg)
    local t = os.date("%H:%M:%S")
    table.insert(logHistory, "["..t.."] "..msg)
    if #logHistory > 60 then table.remove(logHistory,1) end
    uiRefs.log.Text = table.concat(logHistory, "\n")
end

local function updateUI(status, target, dist)
    if not uiRefs.status then return end
    uiRefs.status.Text = "สถานะ: "..status
    uiRefs.target.Text = "เป้าหมาย: "..(target or "-")
    uiRefs.dist.Text = "ระยะ: "..(dist and math.floor(dist).." studs" or "-")

    local s = string.format("พบ: %d | ซื้อ: %d\n", stats.found, stats.bought)
    for _,n in ipairs(TARGET_NAMES) do
        local v = stats[string.lower(n)] or 0
        s = s..string.format("%s:%d ", TARGET_THAI[n], v)
    end
    uiRefs.stats.Text = s
end

local function findTarget()
    local closest, closestDist, closestName = nil, math.huge, ""
    for _,obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("Part") then
            local nm = string.lower(obj.Name)
            for _,tgt in ipairs(TARGET_NAMES) do
                if TARGET_ENABLED[tgt] and string.find(nm, string.lower(tgt)) then
                    local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("RootPart") or obj.PrimaryPart
                    if root then
                        local d = (root.Position - HumanoidRootPart.Position).Magnitude
                        if d < SCAN_RANGE and d < closestDist then
                            closestDist = d
                            closest = root.Position
                            closestName = tgt
                        end
                    end
                end
            end
        end
    end
    return closest, closestDist, closestName
end

local function teleport(pos)
    if not HumanoidRootPart then return false end
    HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(3,0,0))
    return true
end

local function clickBuy()
    local gui = Player:FindFirstChild("PlayerGui")
    if not gui then return false end
    local keywords = {"Buy","buy","Purchase","purchase","ซื้อ","Claim","claim","Get","get"}
    for _,desc in ipairs(gui:GetDescendants()) do
        if desc:IsA("TextButton") or desc:IsA("ImageButton") then
            local t = desc.Text or ""
            local n = desc.Name or ""
            for _,kw in ipairs(keywords) do
                if string.find(string.lower(t), string.lower(kw)) or string.find(string.lower(n), string.lower(kw)) then
                    if desc.Visible then
                        pcall(function() desc.Activated:Fire() end)
                        pcall(function() desc:FireServer() end)
                        addLog("กดปุ่ม: "..n.." ("..t..")")
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- ============================================================
-- Button events
-- ============================================================
local function setupButtons()
    uiRefs.run.MouseButton1Click:Connect(function()
        running = not running
        uiRefs.run.Text = running and "⏸ หยุด" or "▶ ดำเนินการ"
        uiRefs.run.BackgroundColor3 = running and Color3.fromRGB(50,180,80) or Color3.fromRGB(200,150,30)
        addLog(running and "ดำเนินการต่อ..." or "หยุดชั่วคราว")
    end)

    uiRefs.skip.MouseButton1Click:Connect(function()
        skipCurrent = true
        addLog("ข้ามตัวปัจจุบัน")
    end)

    uiRefs.refresh.MouseButton1Click:Connect(function()
        addLog("รีเฟรชสแกน...")
    end)

    uiRefs.all.MouseButton1Click:Connect(function()
        addLog("สรุป: พบ "..stats.found.." | ซื้อ "..stats.bought)
        for _,n in ipairs(TARGET_NAMES) do
            addLog("  "..TARGET_THAI[n]..": "..(stats[string.lower(n)] or 0))
        end
    end)
end

-- ============================================================
-- Main loop
-- ============================================================
local function startScript()
    createUI()
    setupButtons()
    addLog("เริ่มทำงาน — 8 เป้าหมาย, UI ลากได้")
    updateUI("กำลังสแกน...", "-", nil)

    while true do
        wait(SCAN_INTERVAL)

        if not running then
            updateUI("หยุดชั่วคราว", "-", nil)
            continue
        end

        if skipCurrent then
            skipCurrent = false
            addLog("ข้าม — สแกนใหม่")
            wait(1)
        end

        local pos, dist, name = findTarget()

        if pos then
            stats.found = stats.found + 1
            stats[string.lower(name)] = (stats[string.lower(name)] or 0) + 1

            updateUI("✓ พบ!", name, dist)
            addLog("พบ "..TARGET_THAI[name].." ("..name..") ระยะ "..math.floor(dist).." studs")

            updateUI("วาร์ป...", name, dist)
            teleport(pos)
            wait(0.8)

            updateUI("กำลังซื้อ...", name, 0)
            local ok = clickBuy()
            if ok then
                stats.bought = stats.bought + 1
                updateUI("✓ ซื้อสำเร็จ!", name, 0)
                addLog("ซื้อ "..TARGET_THAI[name].." สำเร็จ! รวม "..stats.bought.." ตัว")
            else
                updateUI("⚠ ไม่พบปุ่ม Buy", name, 0)
                addLog("ไม่พบปุ่ม Buy สำหรับ "..TARGET_THAI[name])
            end

            wait(3)
        else
            updateUI("กำลังสแกน...", "-", nil)
        end
    end
end

print("=== BluezyGPT Auto-Find v3 — 8 Targets ===")
startScript()
