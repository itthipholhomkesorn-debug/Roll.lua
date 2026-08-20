-- ============================================================
-- Roll A Gnome - Auto Find + Buy (Fluent UI)
-- 8 เป้าหมาย: Hornet, Bunny, Frog, Cat, Dog, Turtle, Bee, Owl
-- ============================================================

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "🐝 BluezyGPT Auto-Find 🚀",
    SubTitle = "Roll A Gnome — 8 Targets",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 480),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Find = Window:AddTab({ Title = "🔍 หา & ซื้ อ", Icon = "search" }),
    Settings = Window:AddTab({ Title = "⚙️ ตั้ งค ่ า", Icon = "settings" }),
    Stats = Window:AddTab({ Title = "📊 สถิต ิ", Icon = "bar-chart-2" })
}

-- ตัวแปรหลัก
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

local TARGET_NAMES = {"Hornet", "Bunny", "Frog", "Cat", "Dog", "Turtle", "Bee", "Owl"}
local TARGET_THAI = {Hornet="ฮอร ์เนต", Bunny="กระต ่ าย", Frog="กบ", Cat="แมว", Dog="หมา", Turtle="เต ่ า", Bee="ผึ้ ง", Owl="นกฮ ู ก"}
local TARGET_ENABLED = {}
for _,n in ipairs(TARGET_NAMES) do TARGET_ENABLED[n] = true end

local SCAN_RANGE = 1000
local SCAN_INTERVAL = 2
local running = true
local skipCurrent = false

local stats = {found=0, bought=0}
for _,n in ipairs(TARGET_NAMES) do stats[string.lower(n)] = 0 end

-- UI References
local toggles = {}
local statusLabel = nil
local targetLabel = nil
local distLabel = nil
local statsContent = nil

-- ============================================================
-- TAB 1: หา & ซื้ อ
-- ============================================================

-- ส่วนควบคุมหลัก
Tabs.Find:AddParagraph({
    Title = "ควบคุมการทำงาน",
    Content = "เปิ ด/ปิ ด การหาอ ตโนม ต ิ + เล ือกเป้ าหมาย"
})

Tabs.Find:AddButton({
    Title = "▶ เริม่ / ⏸ หย ุด",
    Description = "เปิ ด/ปิ ด การทำงานอ ตโนม ต ิ",
    Callback = function()
        running = not running
        if running then
            addLog("ดำเน ินการต ่ อ...")
        else
            addLog("หย ุดช ั่ วคราว")
        end
    end
})

Tabs.Find:AddButton({
    Title = "⏭ ข้ ามต ัวป ั จจ ุบ ัน",
    Description = "ข้ ามส ต ว์ต ัวป ั จจ ุบ ัน แล้ วหาต ัวใหม ่",
    Callback = function()
        skipCurrent = true
        addLog("ข้ ามต ัวป ั จจ ุบ ัน")
    end
})

Tabs.Find:AddParagraph({
    Title = "เล ือกเป้ าหมาย",
    Content = "เปิ ด/ปิ ด การหาส ต ว์แ ต ่ ละชน ิด"
})

-- Toggle สำหรับแต่ละสัตว์
for _, name in ipairs(TARGET_NAMES) do
    local toggle = Tabs.Find:AddToggle("Toggle_"..name, {
        Title = TARGET_THAI[name].." ("..name..")",
        Default = true,
        Callback = function(state)
            TARGET_ENABLED[name] = state
            addLog("Toggle "..TARGET_THAI[name]..": "..tostring(state))
        end
    })
    toggles[name] = toggle
end

-- ============================================================
-- TAB 2: ตั้งค่า
-- ============================================================

Tabs.Settings:AddSlider("SliderRange", {
    Title = "ระยะสแกน (Studs)",
    Description = "กำหนดระยะสแกนหาส ต ว์",
    Default = 1000,
    Min = 100,
    Max = 5000,
    Rounding = 0,
    Callback = function(val)
        SCAN_RANGE = val
    end
})

Tabs.Settings:AddSlider("SliderInterval", {
    Title = "ความถ ี่สแกน (วิ)",
    Description = "กำหนดช ่ วงระหว ่ างการสแกน",
    Default = 2,
    Min = 0.5,
    Max = 10,
    Rounding = 1,
    Callback = function(val)
        SCAN_INTERVAL = val
    end
})

Tabs.Settings:AddInput("InputTeleportDist", {
    Title = "ระยะวาร ์ป (Studs)",
    Description = "ระยะห ่ างจากส ต ว์เม ื่อวาร ์ปไป",
    Default = "3",
    Numeric = true,
    Finished = true,
    Callback = function(val)
        _G.TeleportDist = tonumber(val) or 3
    end
})

Tabs.Settings:AddButton({
    Title = "🔄 รีเซ็ตค ่ า",
    Description = "รีเซ็ตท ุกอย ่ างกล ับเป ็ นค ่ าเริมต ้ น",
    Callback = function()
        SCAN_RANGE = 1000
        SCAN_INTERVAL = 2
        for _,n in ipairs(TARGET_NAMES) do TARGET_ENABLED[n] = true end
        for _,name in ipairs(TARGET_NAMES) do
            if toggles[name] then toggles[name]:SetValue(true) end
        end
        addLog("รีเซ็ตค ่ าแล ้ ว")
    end
})

-- ============================================================
-- TAB 3: สถิติ
-- ============================================================

Tabs.Stats:AddParagraph({
    Title = "สถิต ิรวม",
    Content = "ต ัวเลขสะสมต ั้งแต ่ เริมต ้ นสคริปต ์"
})

local statsBox = Tabs.Stats:AddParagraph({
    Title = "",
    Content = "พบ: 0 | ซื้ อ: 0"
})

Tabs.Stats:AddButton({
    Title = "🔄 รีเฟรชสถิต ิ",
    Description = "อ ัพเดทต ัวเลขสถิต ิล ่ าสุ ด",
    Callback = function()
        updateStatsDisplay()
    end
})

Tabs.Stats:AddButton({
    Title = "🗑️ ล ้ างสถิต ิ",
    Description = "รีเซ็ตสถิต ิกล ับเป ็ น 0",
    Callback = function()
        stats.found = 0
        stats.bought = 0
        for _,n in ipairs(TARGET_NAMES) do stats[string.lower(n)] = 0 end
        updateStatsDisplay()
        addLog("ล ้ างสถิต ิแล ้ ว")
    end
})

-- ============================================================
-- ฟังก์ชันทำงาน
-- ============================================================
local logCount = 0

local function addLog(msg)
    logCount = logCount + 1
    Fluent:Notify({
        Title = "Log #"..logCount,
        Content = msg,
        Duration = 3
    })
end

local function updateStatsDisplay()
    local s = string.format("พบ: %d | ซื้ อ: %d\n", stats.found, stats.bought)
    for _,n in ipairs(TARGET_NAMES) do
        s = s..string.format("%s: %d\n", TARGET_THAI[n], stats[string.lower(n)] or 0)
    end
    -- อัพเดทผ่าน Paragraph (Fluent ไม่รองรับการแก้ Content ตรงๆ ต้องสร้างใหม่)
    -- วิธีที่ง่าย: ส่ง notify แทน
    Fluent:Notify({
        Title = "📊 สถิต ิป ั จจ ุบ ัน",
        Content = s,
        Duration = 5
    })
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
    local dist = _G.TeleportDist or 3
    HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(dist, 0, 0))
    return true
end

local function clickBuy()
    local gui = Player:FindFirstChild("PlayerGui")
    if not gui then return false end
    local keywords = {"Buy","buy","Purchase","purchase","ซื้ อ","Claim","claim","Get","get"}
    for _,desc in ipairs(gui:GetDescendants()) do
        if desc:IsA("TextButton") or desc:IsA("ImageButton") then
            local t = desc.Text or ""
            local n = desc.Name or ""
            for _,kw in ipairs(keywords) do
                if string.find(string.lower(t), string.lower(kw)) or string.find(string.lower(n), string.lower(kw)) then
                    if desc.Visible then
                        pcall(function() desc.Activated:Fire() end)
                        pcall(function() desc:FireServer() end)
                        addLog("กดป ุ่ ม: "..n)
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- ============================================================
-- Loop หลัก
-- ============================================================
local function startScript()
    addLog("เริมต ้ นทำงาน — Fluent UI Edition")
    addLog("เป้ าหมาย: 8 ส ต ว์ (Hornet, Bunny, Frog, Cat, Dog, Turtle, Bee, Owl)")
    
    while true do
        wait(SCAN_INTERVAL)
        
        if not running then
            wait(1)
        end
        
        if skipCurrent then
            skipCurrent = false
            wait(0.5)
        end
        
        if not running then continue end
        
        local pos, dist, name = findTarget()
        
        if pos then
            stats.found = stats.found + 1
            stats[string.lower(name)] = (stats[string.lower(name)] or 0) + 1
            
            addLog("พบ "..TARGET_THAI[name].." ระยะ "..math.floor(dist).." studs")
            
            -- Teleport
            teleport(pos)
            wait(0.8)
            
            -- Buy
            local ok = clickBuy()
            if ok then
                stats.bought = stats.bought + 1
                addLog("ซื้ อ "..TARGET_THAI[name].." สำเร ็จ! รวม "..stats.bought.." ต ัว")
                updateStatsDisplay()
            else
                addLog("ไม ่พบป ุ่ ม Buy สำหร ับ "..TARGET_THAI[name])
            end
            
            wait(3)
        end
    end
end

-- เริ่มต้น
Fluent:Notify({
    Title = "🐝 BluezyGPT Auto-Find",
    Content = "UI โหลดแล ้ ว — เริมต ้ นหาส ต ว์ได ้ เลย",
    Duration = 4
})

startScript()
