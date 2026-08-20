-- ============================================================
-- Roll A Gnome - Auto Teleport + Buy + UI
-- วาร์ปไปหาเปา้ หมาย + กดซอื้ + แสดง UI สถานะ
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- ตัง้ ค่า
local TARGET_NAMES = {"Hornet", "Bunny", "Frog"}
local SCAN_RANGE = 1000
local SCAN_INTERVAL = 2
local TELEPORT_DISTANCE = 5  -- วาร์ปไปหางเปา้ หมายในระยะน้ี
local BUY_BUTTON_NAMES = {"Buy", "buy", "Purchase", "purchase", "ซื้ อ", "BuyButton", "Button", "Claim"}

-- ตัวแปรสถิต ิ
local stats = {
    found = 0,
    bought = 0,
    hornet = 0,
    bunny = 0,
    frog = 0,
    errors = 0
}

-- ============================================================
-- สว่ น UI
-- ============================================================
local function createUI()
    -- ลบ UI เก่าถ้ามี
    local oldUI = Player:FindFirstChild("BluezyGPT_UI")
    if oldUI then oldUI:Destroy() end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BluezyGPT_UI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = Player:FindFirstChild("PlayerGui") or Player
    
    -- Frame หลัก
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 280, 0, 220)
    mainFrame.Position = UDim2.new(0, 10, 0, 10)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    -- ขอบสเี ส้ น
    local border = Instance.new("Frame")
    border.Name = "Border"
    border.Size = UDim2.new(1, 0, 1, 0)
    border.Position = UDim2.new(0, 0, 0, 0)
    border.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
    border.BorderSizePixel = 0
    border.BackgroundTransparency = 0.7
    border.Parent = mainFrame
    
    -- หัวข้อ
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 35)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundColor3 = Color3.fromRGB(40, 20, 60)
    title.BorderSizePixel = 0
    title.Text = "🐝 BluezyGPT Auto-Find"
    title.TextColor3 = Color3.fromRGB(255, 200, 100)
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.Parent = mainFrame
    
    -- ปุ่มปิด
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -30, 0, 2)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = mainFrame
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    -- ข้อความสถานะ
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, -10, 0, 25)
    statusLabel.Position = UDim2.new(0, 5, 0, 40)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "สถานะ: กำลังสแกน..."
    statusLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
    statusLabel.TextSize = 13
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = mainFrame
    
    local targetLabel = Instance.new("TextLabel")
    targetLabel.Name = "TargetLabel"
    targetLabel.Size = UDim2.new(1, -10, 0, 25)
    targetLabel.Position = UDim2.new(0, 5, 0, 65)
    targetLabel.BackgroundTransparency = 1
    targetLabel.Text = "เป้าหมาย: -"
    targetLabel.TextColor3 = Color3.fromRGB(255, 180, 50)
    targetLabel.TextSize = 13
    targetLabel.Font = Enum.Font.Gotham
    targetLabel.TextXAlignment = Enum.TextXAlignment.Left
    targetLabel.Parent = mainFrame
    
    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "DistLabel"
    distLabel.Size = UDim2.new(1, -10, 0, 25)
    distLabel.Position = UDim2.new(0, 5, 0, 90)
    distLabel.BackgroundTransparency = 1
    distLabel.Text = "ระยะทาง: -"
    distLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    distLabel.TextSize = 12
    distLabel.Font = Enum.Font.Gotham
    distLabel.TextXAlignment = Enum.TextXAlignment.Left
    distLabel.Parent = mainFrame
    
    -- สถิติ
    local statsFrame = Instance.new("Frame")
    statsFrame.Name = "StatsFrame"
    statsFrame.Size = UDim2.new(1, -10, 0, 90)
    statsFrame.Position = UDim2.new(0, 5, 0, 120)
    statsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    statsFrame.BorderSizePixel = 0
    statsFrame.Parent = mainFrame
    
    local statsText = Instance.new("TextLabel")
    statsText.Name = "StatsText"
    statsText.Size = UDim2.new(1, 0, 1, 0)
    statsText.Position = UDim2.new(0, 5, 0, 0)
    statsText.BackgroundTransparency = 1
    statsText.Text = "พบ: 0 | ซื้อ: 0\nHornet: 0 | Bunny: 0 | Frog: 0"
    statsText.TextColor3 = Color3.fromRGB(180, 180, 220)
    statsText.TextSize = 11
    statsText.Font = Enum.Font.Gotham
    statsText.TextXAlignment = Enum.TextXAlignment.Left
    statsText.TextYAlignment = Enum.TextYAlignment.Top
    statsText.TextWrapped = true
    statsText.Parent = statsFrame
    
    -- ปุ่มเริ่ม/หยุด
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleBtn"
    toggleBtn.Size = UDim2.new(1, -10, 0, 30)
    toggleBtn.Position = UDim2.new(0, 5, 0, 185)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
    toggleBtn.Text = "⏸ หยุดชั่วคราว"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.TextSize = 13
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.Parent = mainFrame
    
    -- UI References
    local uiRefs = {
        status = statusLabel,
        target = targetLabel,
        dist = distLabel,
        stats = statsText,
        toggle = toggleBtn
    }
    
    return screenGui, uiRefs
end

-- ============================================================
-- ฟังก์ชันทำงาน
-- ============================================================
local running = true
local uiRefs = nil

local function updateUI(status, target, dist)
    if not uiRefs then return end
    uiRefs.status.Text = "สถานะ: " .. status
    uiRefs.target.Text = "เป้าหมาย: " .. (target or "-")
    uiRefs.dist.Text = "ระยะทาง: " .. (dist and math.floor(dist) .. " studs" or "-")
    uiRefs.stats.Text = string.format(
        "พบ: %d | ซื้อ: %d\nHornet: %d | Bunny: %d | Frog: %d",
        stats.found, stats.bought, stats.hornet, stats.bunny, stats.frog
    )
end

local function findTarget()
    local closest = nil
    local closestDist = math.huge
    local closestName = ""
    
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("Part") then
            local name = string.lower(obj.Name)
            
            for _, target in ipairs(TARGET_NAMES) do
                if string.find(name, string.lower(target)) then
                    local root = obj:FindFirstChild("HumanoidRootPart") 
                                 or obj:FindFirstChild("RootPart") 
                                 or obj.PrimaryPart
                    
                    if root then
                        local pos = root.Position
                        local dist = (pos - HumanoidRootPart.Position).Magnitude
                        
                        if dist < SCAN_RANGE and dist < closestDist then
                            closestDist = dist
                            closest = pos
                            closestName = target
                        end
                    end
                end
            end
        end
    end
    
    return closest, closestDist, closestName
end

-- ฟังก์ชันวาร์ป
local function teleportTo(position)
    if not HumanoidRootPart then return false end
    
    -- วาร์ปไปห่างจากเป้าหมายนิดหน่อย (กันติด)
    local teleportPos = position + Vector3.new(3, 0, 0)
    HumanoidRootPart.CFrame = CFrame.new(teleportPos)
    return true
end

-- ฟังก์ชันกด Buy
local function clickBuyButton()
    local ui = Player:FindFirstChild("PlayerGui")
    if not ui then return false end
    
    for _, descendant in ipairs(ui:GetDescendants()) do
        if descendant:IsA("TextButton") or descendant:IsA("ImageButton") then
            local text = descendant.Text or ""
            local name = descendant.Name or ""
            
            for _, buyName in ipairs(BUY_BUTTON_NAMES) do
                if string.find(string.lower(text), string.lower(buyName)) or 
                   string.find(string.lower(name), string.lower(buyName)) then
                    if descendant.Visible then
                        pcall(function()
                            descendant.Activated:Fire()
                        end)
                        pcall(function()
                            descendant:FireServer()
                        end)
                        print(">>> กดปุ่ม: " .. name .. " (" .. text .. ")")
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- ฟังก์ชันหลัก
local function startScript()
    local screenGui, refs = createUI()
    uiRefs = refs
    
    -- ปุ่ม toggle
    uiRefs.toggle.MouseButton1Click:Connect(function()
        running = not running
        uiRefs.toggle.Text = running and "⏸ หยุดชั่วคราว" or "▶ ดำเนินการต่อ"
        uiRefs.toggle.BackgroundColor3 = running and Color3.fromRGB(50, 200, 100) or Color3.fromRGB(200, 150, 50)
    end)
    
    updateUI("กำลังสแกน...", "-", nil)
    
    while true do
        wait(SCAN_INTERVAL)
        
        if not running then
            updateUI("หยุดชั่วคราว", "-", nil)
            continue
        end
        
        local targetPos, dist, name = findTarget()
        
        if targetPos then
            stats.found = stats.found + 1
            if name == "Hornet" then stats.hornet = stats.hornet + 1 end
            if name == "Bunny" then stats.bunny = stats.bunny + 1 end
            if name == "Frog" then stats.frog = stats.frog + 1 end
            
            updateUI("✓ พบ!", name, dist)
            
            -- วาร์ปไปหา
            updateUI("วาร์ป...", name, dist)
            teleportTo(targetPos)
            wait(0.5)
            
            -- กด Buy
            updateUI("กำลังซื้อ...", name, 0)
            local clicked = clickBuyButton()
            
            if clicked then
                stats.bought = stats.bought + 1
                updateUI("✓ ซื้อสำเร็จ!", name, 0)
                print(">>> ซื้อ " .. name .. " สำเร็จ! (รวม " .. stats.bought .. " ตัว)")
            else
                updateUI("⚠ ไม่พบปุ่ม Buy", name, 0)
                print(">>> ไม่พบปุ่ม Buy สำหรับ " .. name)
                stats.errors = stats.errors + 1
            end
            
            updateUI("รอ...", name, 0)
            wait(3)
        else
            updateUI("กำลังสแกน...", "-", nil)
        end
    end
end

-- เริ่มทำงาน
print("=== BluezyGPT Auto-Find + Teleport + Buy เริ่มทำงาน ===")
startScript()
