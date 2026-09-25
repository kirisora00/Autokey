-- Autokey v2.38 (Head Stand: type a name -> warp to hover above their head, nearby-scan fallback if name not found): sidebar, flight (position-locked), targets, continuous follow (Devil Boat), Duck Boss summon loop, and Raid opener (E -> Open -> warp into portal ring)
-- Client script. AUTO starts disabled. Closing the UI stops tracking and AUTO.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
assert(player, "Run on Client")
local playerGui = player:WaitForChild("PlayerGui")

for _, name in ipairs({
    "LiveNPCScanner", "VillainScanner", "VillainLocator", "TargetLocator"
}) do
    local old = playerGui:FindFirstChild(name)
    if old then old:Destroy() end
end

local function create(class, props, parent)
    local obj = Instance.new(class)
    for key, value in pairs(props) do obj[key] = value end
    obj.Parent = parent
    return obj
end

-- follow = true: เป้าหมายที่เคลื่อนที่ตลอดเวลา ระบบ AUTO จะวาร์ปตามต่อเนื่องจนกว่าจะตาย/หายไป
local targets = {
    {label = "Villain", model = "Bacon Thief", follow = false},
    {label = "Devil Boat", model = "DevilBoat", follow = true},
}
local FOLLOW_DISTANCE = 9 -- ห่างจากเป้าหมายเกินกี่ studs ถึงจะวาร์ปตามใหม่
local selected = 2
local running = true
local antiAfk = {enabled = true}
local auto = false
local locked = nil
local visitedCharacter = nil
local nextWarpAt = 0
local tracked = {}
local markers = {}
local nextId = 0

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- ===== Anti-AFK: กันโดนเตะเพราะไม่ได้ขยับ =====
-- วิธีหลัก: Roblox จะยิง Players.LocalPlayer.Idled ก่อนเตะ AFK ~20-30 วินาที
-- เราจำลองว่ามีคนกดปุ่ม/ขยับกล้องผ่าน VirtualUser (มาตรฐานที่ใช้กันทั่วไป)
-- วิธีสำรอง: เผื่อ Idled ไม่ยิง (ตัวรันบางตัว/สถานการณ์บางแบบ) ให้แตะปุ่มกระโดดเองทุก ~90 วินาทีถ้าไม่มีอินพุตจริงเข้ามาเลย
local lastRealInput = os.clock()
UserInputService.InputBegan:Connect(function(_, processed)
    if not processed then lastRealInput = os.clock() end
end)
player.Idled:Connect(function()
    if not antiAfk.enabled then return end
    local ok, virtualUser = pcall(function() return game:GetService("VirtualUser") end)
    if ok and virtualUser then
        pcall(function()
            virtualUser:CaptureController()
            virtualUser:ClickButton2(Vector2.new())
        end)
    end
end)
task.spawn(function()
    while running do
        task.wait(15)
        if antiAfk.enabled and os.clock() - lastRealInput > 90 then
            local okInput, manager = pcall(function() return game:GetService("VirtualInputManager") end)
            if okInput and manager then
                pcall(function()
                    manager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                    task.wait(0.05)
                    manager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                end)
            end
            lastRealInput = os.clock() -- กันสแปมถ้าโดน error ซ้ำ
        end
    end
end)

local currentPage = "target"
local flight = nil
local flySpeed = 70
local flightConnections = {}
local pressed = {}
local setAuto
local stopDuck
local duck = {enabled = false, phase = "IDLE", prompt = nil, returnRoot = nil,
    boss = nil, held = nil, deadline = 0, deathSeen = false, fought = 0}
local duckConnections = {}
local duckMarker = nil
local releaseReturnGuard
local releaseSkillKeys
local skills = {enabled = true, selected = {Z = true, X = true, C = true, V = true, F = true},
    cursor = 0, nextAt = 0, gapUntil = 0, readyMode = true, minGap = 0.35,
    lastCastAt = -math.huge, held = {}, interval = 3, quiet = 6}
local skillInput = nil
local skillInputMode = nil
skills.castTracks = {}
local raid = {prompt = nil, promptPose = nil, ringPose = nil, running = false, token = 0,
    fighting = false, combatReady = false, auto = false, rounds = 0, held = nil, stop = nil,
    hover = true, bossEntry = nil, hoverPart = nil, hoverOffset = 10, bossHeight = 30, ignore = {}, orbFallback = false, bbCache = {}, bbAt = -math.huge, bbVirtual = {}, warned = {}, buff = true}
local extraTabs = {}
local gacha = {prompt = nil, promptPose = nil, running = false, token = 0, pulls = 0, held = nil}
local dungeon = {prompt = nil, promptPose = nil, ringPose = nil, running = false, token = 0, rounds = 0, height = 15, holdPart = nil, stop = nil}

local colors = {
    window = Color3.fromRGB(24, 25, 30),
    sidebar = Color3.fromRGB(31, 32, 42),
    muted = Color3.fromRGB(160, 166, 182),
    active = Color3.fromRGB(51, 58, 78),
    blue = Color3.fromRGB(53, 113, 220),
    green = Color3.fromRGB(38, 140, 93),
    tab = Color3.fromRGB(41, 43, 56),
}

local gui = create("ScreenGui", {
    Name = "TargetLocator", ResetOnSpawn = false, DisplayOrder = 10,
}, playerGui)

local panel = create("Frame", {
    AnchorPoint = Vector2.new(1, 0),
    Size = UDim2.fromOffset(600, 440),
    Position = UDim2.new(1, -20, 0, 100),
    BackgroundColor3 = colors.window, BorderSizePixel = 0,
}, gui)
create("UICorner", {CornerRadius = UDim.new(0, 12)}, panel)
create("UIStroke", {Color = Color3.fromRGB(62, 65, 80), Thickness = 1}, panel)

local title = create("TextLabel", {
    Position = UDim2.fromOffset(16, 0),
    Size = UDim2.new(1, -100, 0, 44),
    BackgroundTransparency = 1, Text = "AUTOKEY  /  TARGET LOCATOR",
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

local minimize = create("TextButton", {
    Position = UDim2.new(1, -76, 0, 7), Size = UDim2.fromOffset(30, 30),
    Text = "−", TextSize = 22, TextColor3 = Color3.new(1, 1, 1),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
}, panel)

local close = create("TextButton", {
    Position = UDim2.new(1, -39, 0, 7), Size = UDim2.fromOffset(30, 30),
    Text = "X", TextColor3 = Color3.new(1, 1, 1),
    BackgroundColor3 = Color3.fromRGB(140, 48, 58), BorderSizePixel = 0,
}, panel)

-- ===== ลากหน้าต่างไปวางตรงไหนของจอก็ได้ (คลิกค้างที่แถบหัวข้อ ยกเว้นปุ่มซ่อน/ปิด) =====
local dragHandle = create("Frame", {
    Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -90, 0, 44),
    BackgroundTransparency = 1, Active = true, ZIndex = 5,
}, panel)
do
    local dragging = false
    local dragStart, startPos
    local function updateDrag(input)
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = panel.Position
            local connection
            connection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    connection:Disconnect()
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            updateDrag(input)
        end
    end)
end

local content = create("Frame", {
    Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 396),
    BackgroundTransparency = 1,
}, panel)

local sidebar = create("Frame", {
    Size = UDim2.fromOffset(165, 396),
    BackgroundColor3 = colors.sidebar, BorderSizePixel = 0,
}, content)
create("TextLabel", {
    Position = UDim2.fromOffset(16, 12), Size = UDim2.fromOffset(130, 20),
    BackgroundTransparency = 1, Text = "MENU", TextColor3 = colors.muted,
    Font = Enum.Font.GothamBold, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
}, sidebar)

-- เมนูด้านซ้ายเรียงเองอัตโนมัติ (ScrollingFrame + UIListLayout) แทนการกำหนดตำแหน่ง Y เองทีละปุ่ม
-- เพิ่มเมนูใหม่ในอนาคตแค่ตั้ง LayoutOrder แล้ว Parent มาที่ navList ได้เลย ไม่ต้องคำนวณตำแหน่งเอง ไม่รกและไม่ชนกัน
local navList = create("ScrollingFrame", {
    Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 314),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 3, ScrollBarImageColor3 = colors.muted,
    CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, sidebar)
create("UIListLayout", {
    Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, navList)
create("UIPadding", {
    PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 10),
}, navList)

-- หัวข้อกลุ่มเมนู (แค่ป้ายข้อความ ไม่ใช่ปุ่ม)
local function navCaption(order, text)
    create("TextLabel", {
        LayoutOrder = order, Size = UDim2.fromOffset(145, 18),
        BackgroundTransparency = 1, Text = text, TextColor3 = colors.muted,
        Font = Enum.Font.GothamBold, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, navList)
end
navCaption(0, "เป้าหมาย")

local tabs = {}
for i, target in ipairs(targets) do
    tabs[i] = create("TextButton", {
        LayoutOrder = i,
        Size = UDim2.fromOffset(145, 34), Text = target.label,
        TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.Gotham,
        TextSize = 15, BackgroundColor3 = colors.tab, BorderSizePixel = 0,
    }, navList)
    create("UICorner", {CornerRadius = UDim.new(0, 7)}, tabs[i])
end
navCaption(9, "ระบบเสริม")
local flightTab = create("TextButton", {
    LayoutOrder = 10,
    Size = UDim2.fromOffset(145, 34),
    Text = "Flight / บิน", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.Gotham, TextSize = 15,
    BackgroundColor3 = colors.tab, BorderSizePixel = 0,
}, navList)
create("UICorner", {CornerRadius = UDim.new(0, 7)}, flightTab)

local antiAfkButton = create("TextButton", {
    Position = UDim2.fromOffset(10, 358), Size = UDim2.fromOffset(145, 32),
    BackgroundColor3 = colors.green, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 12, Text = "Anti-AFK: ON  •  v2.38",
}, sidebar)
create("UICorner", {CornerRadius = UDim.new(0, 6)}, antiAfkButton)
antiAfkButton.Activated:Connect(function()
    antiAfk.enabled = not antiAfk.enabled
    antiAfkButton.Text = (antiAfk.enabled and "Anti-AFK: ON  •  v2.38" or "Anti-AFK: OFF  •  v2.38")
    antiAfkButton.BackgroundColor3 = antiAfk.enabled and colors.green or colors.active
end)

local duckTab = create("TextButton", {
    LayoutOrder = 20, Size = UDim2.fromOffset(145, 34),
    Text = "Duck Boss / เป็ด", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.Gotham, TextSize = 15,
    BackgroundColor3 = colors.tab, BorderSizePixel = 0,
}, navList)
create("UICorner", {CornerRadius = UDim.new(0, 7)}, duckTab)

local skillsTab = create("TextButton", {
    LayoutOrder = 30, Size = UDim2.fromOffset(145, 34),
    Text = "Skills / สกิล", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.Gotham, TextSize = 15,
    BackgroundColor3 = colors.tab, BorderSizePixel = 0,
}, navList)
create("UICorner", {CornerRadius = UDim.new(0, 7)}, skillsTab)

local raidTab = create("TextButton", {
    LayoutOrder = 40, Size = UDim2.fromOffset(145, 34),
    Text = "Raid / เสกบอส", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.Gotham, TextSize = 15,
    BackgroundColor3 = colors.tab, BorderSizePixel = 0,
}, navList)
create("UICorner", {CornerRadius = UDim.new(0, 7)}, raidTab)

local function makePage()
    return create("Frame", {
        Position = UDim2.fromOffset(181, 10),
        Size = UDim2.fromOffset(403, 374), BackgroundTransparency = 1,
    }, content)
end
local targetPage = makePage()
local flightPage = makePage()
flightPage.Visible = false
local duckPage = makePage()
duckPage.Visible = false
local skillsPage = makePage()
skillsPage.Visible = false
local raidPage = makePage()
raidPage.Visible = false

local pageTitle = create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1,
    Text = "Devil Boat", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold, TextSize = 23,
    TextXAlignment = Enum.TextXAlignment.Left,
}, targetPage)
local output = create("TextLabel", {
    Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 176),
    BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(204, 218, 230),
    Font = Enum.Font.Code, TextSize = 15, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top, Text = "Scanning...",
}, targetPage)

local teleport = create("TextButton", {
    Position = UDim2.fromOffset(0, 228), Size = UDim2.new(1, 0, 0, 40),
    BackgroundColor3 = colors.blue, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 16, Text = "วาร์ปไปตัวใกล้ที่สุด",
}, targetPage)
local autoButton = create("TextButton", {
    Position = UDim2.fromOffset(0, 276), Size = UDim2.new(1, 0, 0, 40),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 16, Text = "AUTO: OFF — กดเพื่อเริ่ม",
}, targetPage)
local status = create("TextLabel", {
    Position = UDim2.fromOffset(0, 324), Size = UDim2.new(1, 0, 0, 47),
    BackgroundTransparency = 1, TextColor3 = colors.muted,
    TextSize = 14, TextWrapped = true, Text = "เลือกเป้าหมาย แล้วกดวาร์ปหรือเปิด AUTO",
}, targetPage)

create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1,
    Text = "Flight / การบิน", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold, TextSize = 23,
    TextXAlignment = Enum.TextXAlignment.Left,
}, flightPage)
create("TextLabel", {
    Position = UDim2.fromOffset(0, 45), Size = UDim2.new(1, 0, 0, 105),
    BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(204, 218, 230),
    Font = Enum.Font.Gotham, TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    Text = "W / A / S / D   เคลื่อนที่ตามมุมกล้อง\nSpace   บินขึ้น\nCtrl   บินลง\nปล่อยปุ่ม   ลอยอยู่กับที่",
}, flightPage)
local speedLabel = create("TextLabel", {
    Position = UDim2.fromOffset(54, 163), Size = UDim2.new(1, -108, 0, 40),
    BackgroundTransparency = 1, Text = "Speed: 70 studs/s",
    TextColor3 = Color3.new(1, 1, 1), TextSize = 17,
    Font = Enum.Font.GothamBold,
}, flightPage)
local slower = create("TextButton", {
    Position = UDim2.fromOffset(0, 163), Size = UDim2.fromOffset(45, 40),
    BackgroundColor3 = colors.active, Text = "−", TextSize = 22,
    TextColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
}, flightPage)
local faster = create("TextButton", {
    Position = UDim2.new(1, -45, 0, 163), Size = UDim2.fromOffset(45, 40),
    BackgroundColor3 = colors.active, Text = "+", TextSize = 22,
    TextColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
}, flightPage)
local flyButton = create("TextButton", {
    Position = UDim2.fromOffset(0, 228), Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = colors.blue, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 17, Text = "FLIGHT: OFF — กดเพื่อบิน",
}, flightPage)
local flyStatus = create("TextLabel", {
    Position = UDim2.fromOffset(0, 283), Size = UDim2.new(1, 0, 0, 85),
    BackgroundTransparency = 1, TextColor3 = colors.muted,
    TextSize = 14, TextWrapped = true,
    Text = "เปิดบินแล้ว AUTO วาร์ปจะหยุด\nกดปิดบินเพื่อกลับสู่การเดินตามปกติ",
}, flightPage)

create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1,
    Text = "Duck Boss / เสกบอสเป็ด", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold, TextSize = 21,
    TextXAlignment = Enum.TextXAlignment.Left,
}, duckPage)
create("TextLabel", {
    Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 49),
    BackgroundTransparency = 1, TextColor3 = colors.muted,
    TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    Text = "ครั้งแรก: ยืนข้างเป็ดเล็กที่กด E แล้วบันทึกจุด\nปิด AUTO สกิลเดิมของเกม แล้วเลือกปุ่มในเมนู Skills",
}, duckPage)
local bindDuck = create("TextButton", {
    Position = UDim2.fromOffset(0, 99), Size = UDim2.new(1, 0, 0, 37),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 15, Text = "บันทึกจุดเสกที่ยืนอยู่",
}, duckPage)
create("TextLabel", {
    Position = UDim2.fromOffset(0, 143), Size = UDim2.fromOffset(117, 34),
    BackgroundTransparency = 1, TextColor3 = colors.muted,
    TextSize = 14, Text = "ชื่อบอสจริง:",
    TextXAlignment = Enum.TextXAlignment.Left,
}, duckPage)
local duckName = create("TextBox", {
    Position = UDim2.fromOffset(118, 143), Size = UDim2.new(1, -118, 0, 34),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), TextSize = 16,
    Text = "DuckMonster", ClearTextOnFocus = false,
}, duckPage)
local duckButton = create("TextButton", {
    Position = UDim2.fromOffset(0, 190), Size = UDim2.new(1, 0, 0, 43),
    BackgroundColor3 = colors.blue, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 16, Text = "DUCK AUTO: OFF — กดเพื่อเริ่ม",
}, duckPage)
local duckStatus = create("TextLabel", {
    Position = UDim2.fromOffset(0, 245), Size = UDim2.new(1, 0, 0, 125),
    BackgroundTransparency = 1, TextColor3 = colors.muted,
    TextSize = 14, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    Text = "ยังไม่ได้บันทึกจุดเสก\nชื่อ DuckMonster อ้างอิงจากภาพและปรับได้\nยืนในระยะเสกนิ่งแล้วเริ่มนับ 10 วินาที หากบอสไม่เกิดจะหยุด",
}, duckPage)

create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1,
    Text = "Skills / สกิลตอนถึงบอส", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold, TextSize = 21,
    TextXAlignment = Enum.TextXAlignment.Left,
}, skillsPage)
create("TextLabel", {
    Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 52),
    BackgroundTransparency = 1, TextColor3 = colors.muted, TextSize = 14,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    Text = "ปิด AUTO สกิลเดิมของเกมก่อนใช้งาน\nระบบนี้กดสกิลเฉพาะตอน DUCK AUTO ถึงบอสและตัวนิ่ง",
}, skillsPage)
local skillButtons = {}
local skillOrder = {"Z", "X", "C", "V", "F"}
for i, key in ipairs(skillOrder) do
    skillButtons[key] = create("TextButton", {
        Position = UDim2.fromOffset((i - 1) * 81, 102),
        Size = UDim2.fromOffset(73, 38), Text = key .. ": ON",
        TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
        TextSize = 14, BackgroundColor3 = colors.green, BorderSizePixel = 0,
    }, skillsPage)
end
create("TextLabel", {
    Position = UDim2.fromOffset(0, 154), Size = UDim2.fromOffset(286, 32),
    BackgroundTransparency = 1, TextColor3 = colors.muted, TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left, Text = "เว้นระหว่างสกิลอย่างน้อย (วินาที)",
}, skillsPage)
local skillInterval = create("TextBox", {
    Position = UDim2.new(1, -97, 0, 154), Size = UDim2.fromOffset(97, 32),
    BackgroundColor3 = colors.active, TextColor3 = Color3.new(1, 1, 1),
    Text = "3", TextSize = 16, ClearTextOnFocus = false, BorderSizePixel = 0,
}, skillsPage)
create("TextLabel", {
    Position = UDim2.fromOffset(0, 196), Size = UDim2.fromOffset(286, 32),
    BackgroundTransparency = 1, TextColor3 = colors.muted, TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left, Text = "รอหลังสกิลก่อนวาร์ปอย่างน้อย (วินาที)",
}, skillsPage)
local skillQuiet = create("TextBox", {
    Position = UDim2.new(1, -97, 0, 196), Size = UDim2.fromOffset(97, 32),
    BackgroundColor3 = colors.active, TextColor3 = Color3.new(1, 1, 1),
    Text = "6", TextSize = 16, ClearTextOnFocus = false, BorderSizePixel = 0,
}, skillsPage)
local skillToggle = create("TextButton", {
    Position = UDim2.fromOffset(0, 244), Size = UDim2.new(1, 0, 0, 42),
    BackgroundColor3 = colors.green, TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold, TextSize = 15,
    Text = "BOSS SKILLS: ON — กดเพื่อปิด", BorderSizePixel = 0,
}, skillsPage)
local skillReadyToggle = create("TextButton", {
    Position = UDim2.fromOffset(0, 292), Size = UDim2.new(1, 0, 0, 34),
    BackgroundColor3 = colors.green, TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold, TextSize = 13,
    Text = "ใช้สกิลทันทีที่ Ready (อ่านจากแผงสกิลเกม): ON", BorderSizePixel = 0,
}, skillsPage)
local skillStatus = create("TextLabel", {
    Position = UDim2.fromOffset(0, 332), Size = UDim2.new(1, 0, 0, 40),
    BackgroundTransparency = 1, TextColor3 = colors.muted,
    TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    Text = "พร้อมรอ DUCK AUTO ถึงบอส\nหยุดส่งสกิลทันทีเมื่อบอสตาย และรอแอนิเมชันก่อนวาร์ป",
}, skillsPage)

create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1,
    Text = "Raid / เปิดประตูวาร์ป", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold, TextSize = 21,
    TextXAlignment = Enum.TextXAlignment.Left,
}, raidPage)
create("TextLabel", {
    Position = UDim2.fromOffset(0, 42), Size = UDim2.fromOffset(150, 30),
    BackgroundTransparency = 1, TextColor3 = colors.muted,
    TextSize = 13, Text = "อาวุธที่ถือ (ชื่อบนแถบ):",
    TextXAlignment = Enum.TextXAlignment.Left,
}, raidPage)
local raidBuffButton = create("TextButton", {
    Position = UDim2.new(1, -100, 0, 42), Size = UDim2.fromOffset(100, 30),
    BackgroundColor3 = colors.green, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 12, Text = "บัฟ J: ON",
}, raidPage)
local raidWeapon = create("TextBox", {
    Position = UDim2.fromOffset(152, 42), Size = UDim2.new(1, -258, 0, 30),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), TextSize = 15,
    Text = "CidBeta", ClearTextOnFocus = false,
    PlaceholderText = "ว่าง = ไม่เปลี่ยนอาวุธ",
}, raidPage)
local bindRaidPrompt = create("TextButton", {
    Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 0, 32),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 13, Text = "1) บันทึกจุดกด E (ยืนข้าง Open Raid)",
}, raidPage)
local bindRaidRing = create("TextButton", {
    Position = UDim2.fromOffset(0, 120), Size = UDim2.new(1, 0, 0, 32),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 13, Text = "2) บันทึกจุดกลางวงวาร์ป",
}, raidPage)
create("TextLabel", {
    Position = UDim2.fromOffset(0, 154), Size = UDim2.fromOffset(117, 28),
    BackgroundTransparency = 1, TextColor3 = colors.muted,
    TextSize = 13, Text = "ชื่อบอส Raid:",
    TextXAlignment = Enum.TextXAlignment.Left,
}, raidPage)
local raidBossName = create("TextBox", {
    Position = UDim2.fromOffset(118, 154), Size = UDim2.new(1, -118, 0, 28),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), TextSize = 14,
    Text = "Bacon of Grudge", ClearTextOnFocus = false,
}, raidPage)
create("TextLabel", {
    Position = UDim2.fromOffset(0, 186), Size = UDim2.fromOffset(280, 28),
    BackgroundTransparency = 1, TextColor3 = colors.muted,
    TextSize = 13, Text = "จำนวนรอบสูงสุด (0 = จนกว่าของหมด)",
    TextXAlignment = Enum.TextXAlignment.Left,
}, raidPage)
local raidMax = create("TextBox", {
    Position = UDim2.new(1, -97, 0, 186), Size = UDim2.fromOffset(97, 28),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), TextSize = 14,
    Text = "0", ClearTextOnFocus = false,
}, raidPage)
create("TextLabel", {
    Position = UDim2.fromOffset(0, 218), Size = UDim2.fromOffset(280, 28),
    BackgroundTransparency = 1, TextColor3 = colors.muted,
    TextSize = 13, Text = "ความสูงเหนือกลางตัวบอส (studs)",
    TextXAlignment = Enum.TextXAlignment.Left,
}, raidPage)
local raidHeight = create("TextBox", {
    Position = UDim2.new(1, -97, 0, 218), Size = UDim2.fromOffset(97, 28),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), TextSize = 14,
    Text = "30", ClearTextOnFocus = false,
}, raidPage)
local raidWarpToggle = create("TextButton", {
    Position = UDim2.fromOffset(0, 250), Size = UDim2.new(1, 0, 0, 26),
    BackgroundColor3 = colors.green, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 13, Text = "โหมดสู้: FULL AUTO เกาะเหนือหัวเป้าหมาย (กดเพื่อสลับ)",
}, raidPage)
local raidButton = create("TextButton", {
    Position = UDim2.fromOffset(0, 280), Size = UDim2.new(0.5, -3, 0, 26),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 12, Text = "เปิด + เข้าวง (1 ครั้ง ไม่สู้)",
}, raidPage)
local raidScanButton = create("TextButton", {
    Position = UDim2.new(0.5, 3, 0, 280), Size = UDim2.new(0.5, -3, 0, 26),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 12, Text = "สแกนรอบตัว (คัดลอก)",
}, raidPage)
local raidAutoButton = create("TextButton", {
    Position = UDim2.fromOffset(0, 310), Size = UDim2.new(1, 0, 0, 30),
    BackgroundColor3 = colors.blue, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 15, Text = "RAID AUTO: OFF — กดเพื่อวนต่อเนื่อง",
}, raidPage)
local raidStatus = create("TextLabel", {
    Position = UDim2.fromOffset(0, 344), Size = UDim2.new(1, 0, 0, 30),
    BackgroundTransparency = 1, TextColor3 = colors.muted,
    TextSize = 13, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    Text = "ยังไม่ได้บันทึกจุด\nAUTO: เปิด Raid → เข้าวง → ตีลูกบอล/ลูกน้องก่อน แล้วบอส (ลอยเหนือหัว) → ปิด Victory → วนใหม่",
}, raidPage)

local dungeonPage = makePage()
dungeonPage.Visible = false
local dungeonTab = create("TextButton", {
    LayoutOrder = 50, Size = UDim2.fromOffset(145, 34),
    Text = "Dungeon / ลงดัน", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.Gotham, TextSize = 15,
    BackgroundColor3 = colors.tab, BorderSizePixel = 0,
}, navList)
create("UICorner", {CornerRadius = UDim.new(0, 7)}, dungeonTab)

local function dungeonRow(y, text, default)
    create("TextLabel", {
        Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(290, 28),
        BackgroundTransparency = 1, TextColor3 = colors.muted,
        TextSize = 13, Text = text, TextXAlignment = Enum.TextXAlignment.Left,
    }, dungeonPage)
    return create("TextBox", {
        Position = UDim2.new(1, -90, 0, y), Size = UDim2.fromOffset(90, 28),
        BackgroundColor3 = colors.active, BorderSizePixel = 0,
        TextColor3 = Color3.new(1, 1, 1), TextSize = 14,
        Text = default, ClearTextOnFocus = false,
    }, dungeonPage)
end
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1,
    Text = "Dungeon / ลงดัน Full Auto", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold, TextSize = 20,
    TextXAlignment = Enum.TextXAlignment.Left,
}, dungeonPage)
local bindDunPrompt = create("TextButton", {
    Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 30),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 13, Text = "1) บันทึกจุดกด E (ยืนข้าง Open Dungeon)",
}, dungeonPage)
local bindDunRing = create("TextButton", {
    Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 0, 30),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 13, Text = "2) บันทึกจุดกลางวงแดง (หลังกด Spawn แล้ว)",
}, dungeonPage)
local dungeonAmount = dungeonRow(104, "จำนวน Orb ที่ใส่ (สูงสุด 25)", "25")
local dungeonHeight = dungeonRow(136, "ลอยเหนือมอนกี่ studs (บอส: ใช้ค่าหน้า Raid)", "15")
local dungeonMax = dungeonRow(168, "จำนวนรอบสูงสุด (0 = จนกว่า Orb หมด)", "0")
local dungeonTestButton = create("TextButton", {
    Position = UDim2.fromOffset(0, 202), Size = UDim2.new(0.5, -3, 0, 26),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 12, Text = "ทดสอบ: E→ใส่→Spawn→เข้าวง",
}, dungeonPage)
local dungeonScanButton = create("TextButton", {
    Position = UDim2.new(0.5, 3, 0, 202), Size = UDim2.new(0.5, -3, 0, 26),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 12, Text = "สแกนหน้าจอ GUI (คัดลอก)",
}, dungeonPage)
local dungeonSkipButton = create("TextButton", {
    Position = UDim2.fromOffset(0, 233), Size = UDim2.new(1, 0, 0, 26),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 12, Text = "ทดสอบกด Auto Skip (กดตอนอยู่ในดัน)",
}, dungeonPage)
local dungeonAutoButton = create("TextButton", {
    Position = UDim2.fromOffset(0, 264), Size = UDim2.new(1, 0, 0, 34),
    BackgroundColor3 = colors.blue, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 15, Text = "DUNGEON AUTO: OFF — กดเพื่อวนลงดัน",
}, dungeonPage)
local dungeonStatus = create("TextLabel", {
    Position = UDim2.fromOffset(0, 302), Size = UDim2.new(1, 0, 0, 72),
    BackgroundTransparency = 1, TextColor3 = colors.muted,
    TextSize = 13, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    Text = "วิธีตั้งค่า: ยืนข้าง Open Dungeon กดข้อ 1 → กด E ใส่ 25 กด Spawn ด้วยมือ 1 ครั้ง → ยืนกลางวงแดง กดข้อ 2\nอาวุธ/บัฟ J/ความสูงบอส ใช้ค่าจากหน้า Raid",
}, dungeonPage)

local function showPage(page)
    currentPage = page
    if extraTabs.gachaPage then
        extraTabs.gachaPage.Visible = page == "gacha"
        extraTabs.gachaTab.BackgroundColor3 = page == "gacha" and colors.active or colors.tab
    end
    if extraTabs.craftPage then
        extraTabs.craftPage.Visible = page == "craft"
        extraTabs.craftTab.BackgroundColor3 = page == "craft" and colors.active or colors.tab
    end
    if extraTabs.headPage then
        extraTabs.headPage.Visible = page == "headstand"
        extraTabs.headTab.BackgroundColor3 = page == "headstand" and colors.active or colors.tab
    end
    dungeonPage.Visible = page == "dungeon"
    dungeonTab.BackgroundColor3 = page == "dungeon" and colors.active or colors.tab
    raidPage.Visible = page == "raid"
    raidTab.BackgroundColor3 = page == "raid" and colors.active or colors.tab
    targetPage.Visible = page == "target"
    flightPage.Visible = page == "flight"
    duckPage.Visible = page == "duck"
    skillsPage.Visible = page == "skills"
    skillsTab.BackgroundColor3 = page == "skills" and colors.active or colors.tab
    duckTab.BackgroundColor3 = page == "duck" and colors.active or colors.tab
    flightTab.BackgroundColor3 = page == "flight" and colors.active or colors.tab
    for i, tab in ipairs(tabs) do
        tab.BackgroundColor3 = page == "target" and i == selected
            and colors.active or colors.tab
    end
end

local function stopFlight(message)
    local old = flight
    flight = nil
    table.clear(pressed)
    if old then
        for _, obj in ipairs(old.objects) do obj:Destroy() end
        if old.root.Parent then
            old.root.AssemblyLinearVelocity = Vector3.zero
            old.root.AssemblyAngularVelocity = Vector3.zero
        end
        if old.humanoid.Parent then
            old.humanoid.AutoRotate = old.autoRotate
            old.humanoid.PlatformStand = old.platformStand
            if old.humanoid.Health > 0 and not old.platformStand then
                old.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    end
    flyButton.Text = "FLIGHT: OFF — กดเพื่อบิน"
    flyButton.BackgroundColor3 = colors.blue
    flyStatus.Text = message or "ปิดบินแล้ว"
end

local function startFlight()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not humanoid or humanoid.Health <= 0 then
        flyStatus.Text = "รอตัวละครเกิดก่อนครับ"
        return
    end
    if humanoid.SeatPart then
        flyStatus.Text = "ลงจากที่นั่งก่อนเปิดบินครับ"
        return
    end
    if root.Anchored then
        flyStatus.Text = "ตัวละครยังถูกยึดอยู่ ลองเปิดบินอีกครั้งภายหลัง"
        return
    end
    setAuto(false)
    if stopDuck then stopDuck("หยุดเสกเป็ดเพื่อเปิดบิน") end
    status.Text = "หยุด AUTO เพื่อเปิดบิน"
    table.clear(pressed)
    flight = {
        character = character, humanoid = humanoid, root = root,
        autoRotate = humanoid.AutoRotate,
        platformStand = humanoid.PlatformStand,
        objects = {},
    }
    local function own(obj)
        table.insert(flight.objects, obj)
        return obj
    end
    local attachment = own(Instance.new("Attachment"))
    attachment.Name = "AutokeyFlightAttachment"
    attachment.Parent = root

    local velocity = own(Instance.new("LinearVelocity"))
    velocity.Enabled = false
    velocity.Name = "AutokeyFlightVelocity"
    velocity.Attachment0 = attachment
    velocity.RelativeTo = Enum.ActuatorRelativeTo.World
    velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    velocity.ForceLimitsEnabled = false
    velocity.VectorVelocity = Vector3.zero
    velocity.Parent = root

    local orientation = own(Instance.new("AlignOrientation"))
    orientation.Enabled = false
    orientation.Name = "AutokeyFlightOrientation"
    orientation.Attachment0 = attachment
    orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    orientation.RigidityEnabled = true
    orientation.CFrame = root.CFrame.Rotation
    orientation.Parent = root

    flight.velocity = velocity
    flight.orientation = orientation
    -- ตำแหน่งที่ล็อกไว้: สกิลจะดัน/ดึง/วาร์ปตัวละครไม่ได้ ขยับได้เฉพาะเมื่อเรากดปุ่มบินเอง
    flight.cf = root.CFrame
    humanoid.AutoRotate = false
    humanoid.PlatformStand = true
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    orientation.Enabled = true
    velocity.Enabled = true

    flyButton.Text = "FLIGHT: ON — กดเพื่อหยุด"
    flyButton.BackgroundColor3 = colors.green
    flyStatus.Text = "กำลังบิน • W/A/S/D + Space / Ctrl\nยุบหน้าต่างแล้วบินต่อได้"
end

flyButton.Activated:Connect(function()
    if flight then stopFlight() return end
    local ok, err = pcall(startFlight)
    if not ok then
        stopFlight("เปิดบินไม่สำเร็จ ดู Error ใน Console")
        warn("Autokey Flight:", err)
    end
end)
local function changeSpeed(delta)
    flySpeed = math.clamp(flySpeed + delta, 20, 200)
    speedLabel.Text = "Speed: " .. flySpeed .. " studs/s"
end
slower.Activated:Connect(function() changeSpeed(-10) end)
faster.Activated:Connect(function() changeSpeed(10) end)
flightTab.Activated:Connect(function() showPage("flight") end)

table.insert(flightConnections, UserInputService.InputBegan:Connect(function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() or not flight then return end
    pressed[input.KeyCode] = true
end))
table.insert(flightConnections, UserInputService.InputEnded:Connect(function(input)
    pressed[input.KeyCode] = nil
end))
table.insert(flightConnections, UserInputService.WindowFocusReleased:Connect(function()
    table.clear(pressed)
    if flight and flight.velocity then flight.velocity.VectorVelocity = Vector3.zero end
end))
table.insert(flightConnections, UserInputService.TextBoxFocused:Connect(function()
    table.clear(pressed)
end))
table.insert(flightConnections, player.CharacterRemoving:Connect(function()
    stopFlight("ตัวละครหายไป เปิดบินใหม่หลังเกิดครับ")
end))

-- หลังฟิสิกส์คำนวณเสร็จทุกเฟรม ดึงตัวละครกลับตำแหน่งที่ล็อกไว้ (กันสกิลเคลื่อนที่/พุ่ง/ดัน)
table.insert(flightConnections, RunService.Heartbeat:Connect(function()
    local f = flight
    if not running or not f or not f.cf then return end
    if player.Character ~= f.character or not f.root:IsDescendantOf(workspace) then return end
    -- เกมวาร์ปตัวละครไกล (เข้า/ออกด่าน Raid) ให้ยอมรับตำแหน่งใหม่ ส่วนสกิลที่ดัน/พุ่งระยะสั้นยังถูกล็อก
    if (f.root.Position - f.cf.Position).Magnitude > 200 then f.cf = f.root.CFrame end
    f.root.CFrame = f.cf
    f.root.AssemblyLinearVelocity = Vector3.zero
    f.root.AssemblyAngularVelocity = Vector3.zero
end))

table.insert(flightConnections, RunService.RenderStepped:Connect(function(dt)
    if not running or not flight then return end
    local ok, err = pcall(function()
        local f = flight
        if player.Character ~= f.character or not f.root:IsDescendantOf(workspace)
            or f.humanoid.Health <= 0 or f.humanoid.SeatPart then
            stopFlight("หยุดบินแล้ว เปิดใหม่เมื่อตัวละครพร้อมครับ")
            return
        end
        if (f.root.Position - f.cf.Position).Magnitude > 200 then f.cf = f.root.CFrame end
        local camera = workspace.CurrentCamera
        if not camera then
            f.velocity.VectorVelocity = Vector3.zero
            return
        end
        local look = camera.CFrame.LookVector
        local forward = Vector3.new(look.X, 0, look.Z)
        if forward.Magnitude < 0.001 then
            local right = camera.CFrame.RightVector
            forward = Vector3.new(right.Z, 0, -right.X)
        end
        forward = forward.Unit
        local right = Vector3.new(-forward.Z, 0, forward.X)
        local movement = Vector3.zero
        if not UserInputService:GetFocusedTextBox() then
            if pressed[Enum.KeyCode.W] then movement = movement + forward end
            if pressed[Enum.KeyCode.S] then movement = movement - forward end
            if pressed[Enum.KeyCode.D] then movement = movement + right end
            if pressed[Enum.KeyCode.A] then movement = movement - right end
            if pressed[Enum.KeyCode.Space] then movement = movement + Vector3.yAxis end
            if pressed[Enum.KeyCode.LeftControl] or pressed[Enum.KeyCode.RightControl] then
                movement = movement - Vector3.yAxis
            end
        end
        if movement.Magnitude > 1 then movement = movement.Unit end
        -- เคลื่อนที่ด้วยตำแหน่งที่ล็อกไว้เอง ไม่ใช้ความเร็วฟิสิกส์ จึงไม่โดนสกิลแทรก
        local newPos = f.cf.Position + movement * flySpeed * math.min(dt, 0.1)
        f.cf = CFrame.lookAt(newPos, newPos + forward)
        f.velocity.VectorVelocity = Vector3.zero
        f.orientation.CFrame = CFrame.lookAt(Vector3.zero, forward)
        f.root.CFrame = f.cf
        f.root.AssemblyLinearVelocity = Vector3.zero
        f.root.AssemblyAngularVelocity = Vector3.zero
    end)
    if not ok then
        stopFlight("หยุดบินเพราะเกิด Error ดู Console")
        warn("Autokey Flight:", err)
    end
end))

local function clearMarkers()
    for _, marker in pairs(markers) do marker.gui:Destroy() end
    table.clear(markers)
end

setAuto = function(enabled)
    if enabled and flight then stopFlight("ปิดบินเพื่อเปิด AUTO") end
    if enabled and stopDuck then stopDuck("หยุดเสกเป็ดเพื่อเปิด AUTO เป้าหมาย") end
    auto = enabled
    locked = nil
    visitedCharacter = nil
    nextWarpAt = 0
    autoButton.Text = enabled and "AUTO: ON — กดเพื่อหยุด"
        or "AUTO: OFF — กดเพื่อเริ่ม"
    autoButton.BackgroundColor3 = enabled
        and Color3.fromRGB(35, 145, 85) or Color3.fromRGB(70, 75, 85)
end

-- ===== ซ่อน/เรียกคืนทั้งหน้าต่าง: กดปุ่มซ่อนหรือ F1 เพื่อสลับ =====
local hintButton = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -20, 0, 20),
    Size = UDim2.fromOffset(176, 30),
    BackgroundColor3 = colors.window, BackgroundTransparency = 0.05,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 13,
    Text = "Autokey ซ่อนอยู่ • กด F1", Visible = false,
}, gui)
create("UICorner", {CornerRadius = UDim.new(0, 8)}, hintButton)
create("UIStroke", {Color = Color3.fromRGB(62, 65, 80), Thickness = 1}, hintButton)

local function setPanelVisible(visible)
    panel.Visible = visible
    hintButton.Visible = not visible
end
minimize.Activated:Connect(function() setPanelVisible(false) end)
hintButton.Activated:Connect(function() setPanelVisible(true) end)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F1 and not UserInputService:GetFocusedTextBox() then
        setPanelVisible(not panel.Visible)
    end
end)

local added = workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Humanoid") then tracked[obj] = true end
end)

local removed = workspace.DescendantRemoving:Connect(function(obj)
    tracked[obj] = nil
end)

gui.Destroying:Connect(function()
    running = false
    for _, connection in ipairs(flightConnections) do connection:Disconnect() end
    if skills.animationConnection then skills.animationConnection:Disconnect() end
    stopFlight()
    if stopDuck then stopDuck("ปิดระบบแล้ว") end
    auto = false
    locked = nil
    added:Disconnect()
    removed:Disconnect()
    clearMarkers()
    table.clear(tracked)
end)

close.Activated:Connect(function() gui:Destroy() end)

for _, obj in ipairs(workspace:GetDescendants()) do
    if obj:IsA("Humanoid") then tracked[obj] = true end
end

local function isPlayer(model)
    for _, p in ipairs(Players:GetPlayers()) do
        local character = p.Character
        if character and (
            model == character or model:IsDescendantOf(character)
        ) then return true end
    end
    return false
end

local function getPart(model)
    local part = model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart", true)
    return part and part:IsA("BasePart") and part or nil
end

local function isAlive(entry)
    return entry
        and entry.model:IsDescendantOf(workspace)
        and entry.humanoid:IsDescendantOf(entry.model)
        and entry.humanoid.Health > 0
end

local function collectTargets()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local seen, entries = {}, {}
    local total = 0

    for humanoid in pairs(tracked) do
        local model = humanoid.Parent
        if model
            and model:IsA("Model")
            and model.Name == targets[selected].model
            and humanoid:IsDescendantOf(workspace)
            and humanoid.Health > 0
            and not seen[model]
            and not isPlayer(model)
        then
            seen[model] = true
            total += 1
            local part = getPart(model)
            if part then
                table.insert(entries, {
                    model = model, humanoid = humanoid, part = part,
                    distance = root
                        and (root.Position - part.Position).Magnitude
                        or math.huge,
                })
            end
        end
    end

    table.sort(entries, function(a, b) return a.distance < b.distance end)
    return entries, total, root
end

local function makeMarker(part)
    nextId += 1
    local billboard = create("BillboardGui", {
        Adornee = part, Size = UDim2.fromOffset(230, 50),
        StudsOffsetWorldSpace = Vector3.new(0, 5, 0),
        AlwaysOnTop = true, MaxDistance = math.huge,
    }, gui)

    local label = create("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 16,
        TextStrokeTransparency = 0.2,
    }, billboard)

    return {gui = billboard, label = label, id = nextId}
end

local function warp(entry)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not root or not humanoid or humanoid.Health <= 0 then
        return false, "รอตัวละครเกิดก่อนครับ"
    end
    if humanoid.SeatPart then return false, "ลงจากที่นั่งก่อนครับ" end
    if not isAlive(entry) then return false, "เป้าหมายหายไปแล้ว" end

    local part = getPart(entry.model)
    if not part then return false, "รอตำแหน่งเป้าหมายโหลด" end

    local destination = (part.CFrame * CFrame.new(0, 2, 6)).Position
    local facing = Vector3.new(
        part.Position.X, destination.Y, part.Position.Z
    )
    local targetRoot = CFrame.lookAt(destination, facing)
    local rootToPivot = root.CFrame:ToObjectSpace(character:GetPivot())

    character:PivotTo(targetRoot * rootToPivot)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    if flight and flight.root == root then flight.cf = root.CFrame end

    return true, "วาร์ปแล้ว", character
end


-- Duck summon loop: bind the actual nearby ProximityPrompt; never call guessed remotes.
local DUCK_SPAWN_TIMEOUT = 10
local DUCK_RETURN_TIMEOUT = 15
local function normalizeDuck(text)
    return string.lower(tostring(text or "")):gsub("[%s%p]", "")
end


local function duckPromptPosition(prompt)
    if not prompt or not prompt:IsDescendantOf(workspace) then return nil end
    local parent = prompt.Parent
    if parent:IsA("Attachment") then return parent.WorldPosition end
    if parent:IsA("BasePart") then return parent.Position end
    if parent:IsA("Model") then return parent:GetPivot().Position end
    return nil
end

local function duckCharacter()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not humanoid or humanoid.Health <= 0 or humanoid.SeatPart then
        return nil
    end
    return character, root
end

local function endDuckHold()
    local prompt = duck.held
    duck.held = nil
    if prompt then pcall(function() prompt:InputHoldEnd() end) end
end


-- Own skill inputs only; native game AUTO toggles must be turned off by the player.
local function initializeSkillInput()
    if skillInput then return true end
    local ok, input = pcall(function() return UserInputService:CreateVirtualInput() end)
    if ok and input then
        skillInput = input
        skillInputMode = "virtual"
        return true
    end
    -- Older test runners expose VirtualInputManager instead.
    ok, input = pcall(function() return game:GetService("VirtualInputManager") end)
    if ok and input then
        skillInput = input
        skillInputMode = "manager"
        return true
    end
    return false
end

local function sendSkillKey(key, down)
    if skillInputMode == "virtual" then
        skillInput:SendKey(down, Enum.KeyCode[key], false)
    else
        skillInput:SendKeyEvent(down, Enum.KeyCode[key], false, game)
    end
end

releaseSkillKeys = function()
    for key in pairs(skills.held) do
        local ok, err = pcall(function() sendSkillKey(key, false) end)
        if ok then
            skills.held[key] = nil
        else
            warn("Autokey key release:", key, err)
        end
    end
end

local function actionAnimationPlaying(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if not animator then return false end
    for track in pairs(skills.castTracks) do
        if not track.IsPlaying and track.WeightCurrent <= 0.01 then skills.castTracks[track] = nil end
    end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local priority = track.Priority
        local action = priority == Enum.AnimationPriority.Action
            or priority == Enum.AnimationPriority.Action2
            or priority == Enum.AnimationPriority.Action3
            or priority == Enum.AnimationPriority.Action4
        local captured = skills.animationCharacter == character and skills.castTracks[track]
        if (action or captured) and not track.Looped and (track.IsPlaying or track.WeightCurrent > 0.01) then
            return true
        end
    end
    return false
end

local function duckMovementReady(character, root, returning)
    if next(skills.held) then return false, "รอปล่อยปุ่มสกิล" end
    if os.clock() < skills.lastCastAt + skills.quiet then
        return false, "รอพักหลังสกิลก่อนวาร์ป"
    end
    if root.Anchored then return false, "รอเกมปลดการยึดตัวละครจากสกิล" end
    if actionAnimationPlaying(character) then return false, "รอแอนิเมชันสกิลจบ" end
    if not returning and root.AssemblyLinearVelocity.Magnitude > 30 then
        return false, "รอตัวละครนิ่งหลังใช้สกิล"
    end
    return true
end

local function watchSkillAnimations(character)
    if skills.animationCharacter == character and skills.animationConnection then return end
    if skills.animationConnection then skills.animationConnection:Disconnect() end
    skills.animationConnection = nil
    skills.animationCharacter = character
    table.clear(skills.castTracks)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end
    skills.animationConnection = animator.AnimationPlayed:Connect(function(track)
        -- Also remember skill animations authored with a non-Action priority.
        if os.clock() - skills.lastCastAt <= 1.5 and not track.Looped then
            skills.castTracks[track] = true
        end
    end)
end

-- อ่านสถานะคูลดาวน์จากแผงสกิลของเกม (เช่น "Z - Ready" / "Z - UnReady 5")
local skillLabelMap, skillLabelAt = {}, -math.huge

local function stripRichText(text)
    return (tostring(text or ""):gsub("<[^>]->", ""))
end

local function skillGuiVisible(obj)
    local current = obj
    while current and current ~= playerGui do
        if current:IsA("GuiObject") and not current.Visible then return false end
        if current:IsA("ScreenGui") and not current.Enabled then return false end
        current = current.Parent
    end
    return true
end

local function stateWord(text)
    local word = string.match(string.lower(stripRichText(text)), "^%s*%a%s*%-%s*(%a+)")
        or string.match(string.lower(stripRichText(text)), "^%s*(%a+)")
    return word
end

local function refreshSkillLabels()
    skillLabelAt = os.clock()
    skillLabelMap = {}
    local wanted = {}
    for _, key in ipairs(skillOrder) do wanted[key] = true end
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsA("TextLabel") and not obj:IsDescendantOf(gui) and skillGuiVisible(obj) then
            local plain = stripRichText(obj.Text)
            local key, word = string.match(plain, "^%s*(%a)%s*%-%s*(%a+)")
            key = key and string.upper(key)
            if key and wanted[key] and word and (string.lower(word) == "ready" or string.lower(word) == "unready") then
                skillLabelMap[key] = obj -- ข้อความรวมในป้ายเดียว
            else
                -- แบบแยกป้าย: ป้าย "Z -" อยู่คู่กับป้าย "Ready"/"UnReady" ในแถวเดียวกัน
                local onlyKey = string.match(plain, "^%s*(%a)%s*%-?%s*$")
                onlyKey = onlyKey and string.upper(onlyKey)
                if onlyKey and wanted[onlyKey] and not skillLabelMap[onlyKey] then
                    local row = obj.Parent
                    for _ = 1, 2 do
                        if not row then break end
                        local found
                        for _, other in ipairs(row:GetDescendants()) do
                            if other ~= obj and other:IsA("TextLabel") then
                                local word2 = stateWord(other.Text)
                                if word2 == "ready" or word2 == "unready" then found = other break end
                            end
                        end
                        if found then skillLabelMap[onlyKey] = found break end
                        row = row.Parent
                    end
                end
            end
        end
    end
end

-- true = พร้อมใช้, false = ติดคูลดาวน์, nil = อ่านสถานะจากหน้าจอไม่ได้
local function skillIsReady(key)
    if os.clock() - skillLabelAt > 1.5 then refreshSkillLabels() end
    local label = skillLabelMap[key]
    if not label or not label.Parent then return nil end
    local word = stateWord(label.Text)
    if word == "ready" then return true end
    if word == "unready" then return false end
    return nil
end

local function useDuckSkill(character, root, boss)
    if not skills.enabled then return end
    if UserInputService:GetFocusedTextBox() then
        skillStatus.Text = "พักสกิลระหว่างพิมพ์ข้อความ"
        return
    end
    local inDuck = duck.enabled and duck.phase == "FIGHT" and duck.combatReady and not duck.deathSeen
    local inRaid = raid.fighting and raid.combatReady
    if not (inDuck or inRaid) or boss.humanoid.Health <= 0 then return end
    if os.clock() < skills.gapUntil or next(skills.held) then return end
    -- โหมดตามคูลดาวน์: ไม่รอแอนิเมชันจบ ใช้ทันทีที่เกมบอกว่า Ready
    if not skills.readyMode and (root.Anchored or actionAnimationPlaying(character)) then
        skillStatus.Text = "รอสกิลก่อนหน้าจบ..."
        return
    end
    local key
    local anySelected = false
    for _ = 1, #skillOrder do
        skills.cursor = skills.cursor % #skillOrder + 1
        local candidate = skillOrder[skills.cursor]
        if skills.selected[candidate] then
            anySelected = true
            if not skills.readyMode then
                key = candidate
                break
            end
            local ready = skillIsReady(candidate)
            -- ready == nil = อ่านสถานะไม่ได้ ใช้ตามเวลาเว้นระหว่างสกิลแทน
            if ready == true or (ready == nil and os.clock() >= skills.nextAt) then
                key = candidate
                break
            end
        end
    end
    if not anySelected then skillStatus.Text = "ยังไม่ได้เลือกปุ่มสกิล" return end
    if not key then skillStatus.Text = "รอคูลดาวน์สกิล..." return end

    if not initializeSkillInput() then
        skills.enabled = false
        skillToggle.Text = "BOSS SKILLS: OFF"
        skillStatus.Text = "ตัวรันไม่รองรับการจำลองปุ่มสกิล"
        stopDuck("หยุด: ตัวรันไม่รองรับปุ่มสกิล ดูเมนู Skills")
        if raid.stop then raid.stop("หยุด: ตัวรันไม่รองรับปุ่มสกิล") end
        return
    end
    watchSkillAnimations(character)
    local ok, err = pcall(function()
        -- Remember the key before sending, so errors and cancellation still release it.
        skills.held[key] = true
        skills.lastCastAt = os.clock()
        skills.nextAt = os.clock() + skills.interval
        skills.gapUntil = os.clock() + (skills.readyMode and skills.minGap or skills.interval)
        sendSkillKey(key, true)
    end)
    if not ok then
        releaseSkillKeys()
        skills.enabled = false
        skillToggle.Text = "BOSS SKILLS: OFF"
        skillToggle.BackgroundColor3 = colors.active
        skillStatus.Text = "ส่งปุ่มไม่สำเร็จ ปิดแชต/เมนู Roblox แล้วลองใหม่\nหากยังไม่ได้ ตัวรันอาจไม่รองรับ"
        stopDuck("หยุด: ส่งสกิลไม่สำเร็จ ดูเมนู Skills และ Console")
        if raid.stop then raid.stop("หยุด: ส่งสกิลไม่สำเร็จ ดู Console") end
        warn("Autokey skill input:", err)
        return
    end
    skillStatus.Text = "ส่งสกิล " .. key .. " แล้ว" .. (skills.readyMode and " • ใช้ตัวต่อไปทันทีที่ Ready" or " • รอสกิลก่อนหน้าจบ")
    task.delay(0.12, function()
        if skills.held[key] then
            local released, releaseError = pcall(function() sendSkillKey(key, false) end)
            if released then
                skills.held[key] = nil
            else
                releaseSkillKeys()
                if running then
                    stopDuck("หยุด: ปล่อยปุ่มสกิลไม่สำเร็จ ปิดแชต/เมนู Roblox")
                    if raid.stop then raid.stop("หยุด: ปล่อยปุ่มสกิลไม่สำเร็จ") end
                end
                warn("Autokey skill release:", releaseError)
            end
        end
    end)
end

for key, button in pairs(skillButtons) do
    local selectedKey = key
    local selectedButton = button
    selectedButton.Activated:Connect(function()
        skills.selected[selectedKey] = not skills.selected[selectedKey]
        selectedButton.Text = selectedKey .. (skills.selected[selectedKey] and ": ON" or ": OFF")
        selectedButton.BackgroundColor3 = skills.selected[selectedKey] and colors.green or colors.active
        if not skills.selected[selectedKey] then releaseSkillKeys() end
    end)
end
skillToggle.Activated:Connect(function()
    skills.enabled = not skills.enabled
    if not skills.enabled then releaseSkillKeys() end
    skillToggle.Text = skills.enabled and "BOSS SKILLS: ON — กดเพื่อปิด" or "BOSS SKILLS: OFF — กดเพื่อเปิด"
    skillToggle.BackgroundColor3 = skills.enabled and colors.green or colors.active
end)
skillReadyToggle.Activated:Connect(function()
    skills.readyMode = not skills.readyMode
    skillReadyToggle.Text = skills.readyMode and "ใช้สกิลทันทีที่ Ready (อ่านจากแผงสกิลเกม): ON"
        or "ใช้สกิลตามเวลาที่ตั้ง (ไม่อ่านคูลดาวน์): OFF"
    skillReadyToggle.BackgroundColor3 = skills.readyMode and colors.green or colors.active
end)
skillInterval.FocusLost:Connect(function()
    skills.interval = math.clamp(tonumber(skillInterval.Text) or 3, 1, 30)
    skillInterval.Text = tostring(skills.interval)
end)
skillQuiet.FocusLost:Connect(function()
    skills.quiet = math.clamp(tonumber(skillQuiet.Text) or 6, 2, 30)
    skillQuiet.Text = tostring(skills.quiet)
end)
skillsTab.Activated:Connect(function() showPage("skills") end)
table.insert(flightConnections, UserInputService.InputBegan:Connect(function(input)
    if (duck.enabled or raid.fighting) and skills.selected[input.KeyCode.Name]
        and not UserInputService:GetFocusedTextBox() then
        skills.lastCastAt = os.clock()
    end
end))
table.insert(flightConnections, UserInputService.WindowFocusReleased:Connect(function()
    releaseSkillKeys()
end))
table.insert(flightConnections, UserInputService.TextBoxFocused:Connect(function()
    releaseSkillKeys()
end))



-- A short, scoped physics guard for return warps; always restore on cancel/error.
local function clearCharacterMomentum(character)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.AssemblyLinearVelocity = Vector3.zero
            part.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

releaseReturnGuard = function()
    local guard = duck.returnGuard
    duck.returnGuard = nil
    if not guard then return end
    -- Restore Anchored even if clearing momentum fails during character removal.
    pcall(function() clearCharacterMomentum(guard.character) end)
    if guard.root.Parent then
        guard.root.Anchored = guard.anchored
    end
end

local function safeDuckReturnPose(character, root)
    local promptPosition = duckPromptPosition(duck.prompt)
    if not promptPosition then return nil, "จุดเสกยังไม่โหลดหรือหายไป" end

    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances = {character}
    ray.RespectCanCollide = true
    ray.IgnoreWater = true

    local overlap = OverlapParams.new()
    overlap.FilterType = Enum.RaycastFilterType.Exclude
    overlap.FilterDescendantsInstances = {character}
    overlap.RespectCanCollide = true
    overlap.MaxParts = 0

    local offsets = {
        Vector3.zero, Vector3.new(3, 0, 0), Vector3.new(-3, 0, 0),
        Vector3.new(0, 0, 3), Vector3.new(0, 0, -3),
    }
    local saved = duck.returnRoot
    local clearance = duck.floorClearance or 3
    local startIndex = ((duck.returnAttempts or 0) % #offsets) + 1
    for n = 0, #offsets - 1 do
        local offset = offsets[((startIndex + n - 1) % #offsets) + 1]
        local base = saved.Position + offset
        local floor = workspace:Raycast(base + Vector3.new(0, 4, 0), Vector3.new(0, -16, 0), ray)
        if floor and floor.Normal.Y >= 0.65 then
            local position = Vector3.new(base.X, floor.Position.Y + clearance + 0.15, base.Z)
            local pose = CFrame.new(position) * saved.Rotation
            local inRange = (position - promptPosition).Magnitude <= duck.prompt.MaxActivationDistance - 0.25
            local free = inRange
            if free then
                for _, part in ipairs(workspace:GetPartBoundsInBox(
                    pose, root.Size + Vector3.new(0.8, 0.8, 0.8), overlap
                )) do
                    if part.CanCollide and part ~= floor.Instance then free = false break end
                end
            end
            if free then return pose end
        end
    end
    return nil, "ไม่พบพื้นว่างในระยะเสก ยืนข้างเป็ดบนพื้นโล่งแล้วบันทึกจุดใหม่"
end

local function startDuckReturnWarp(character, root)
    releaseReturnGuard()
    local pose, reason = safeDuckReturnPose(character, root)
    if not pose then return false, reason end
    if root.Anchored then return false, "รอเกมปลดการยึดตัวละครก่อน" end

    duck.returnAttempts = (duck.returnAttempts or 0) + 1
    local guard = {character = character, root = root, anchored = root.Anchored}
    duck.returnGuard = guard
    -- Schedule restoration before changing physics, so later failures cannot leave it anchored.
    task.delay(0.4, function()
        if duck.returnGuard == guard then releaseReturnGuard() end
    end)
    root.Anchored = true
    clearCharacterMomentum(character)
    local rootToPivot = root.CFrame:ToObjectSpace(character:GetPivot())
    character:PivotTo(pose * rootToPivot)
    clearCharacterMomentum(character)

    duck.returnPose = pose
    duck.returnMoved = true
    duck.settleAt = os.clock() + 1
    duck.returnCheckUntil = os.clock() + 4
    duck.returnStableSince = nil
    return true
end


local function clearDuckBoss()
    if releaseReturnGuard then releaseReturnGuard() end
    for _, connection in ipairs(duckConnections) do connection:Disconnect() end
    table.clear(duckConnections)
    if duckMarker then duckMarker.gui:Destroy() duckMarker = nil end
    duck.boss = nil
    duck.deathSeen = false
    duck.visitedCharacter = nil
    duck.combatReady = false
    duck.stableSince = nil
    duck.retries = 0
end

stopDuck = function(message)
    duck.enabled = false
    if releaseSkillKeys then releaseSkillKeys() end
    endDuckHold()
    clearDuckBoss()
    duck.phase = "IDLE"
    duck.spawnDeadline = nil
    duckButton.Text = "DUCK AUTO: OFF — กดเพื่อเริ่ม"
    duckButton.BackgroundColor3 = colors.blue
    duckStatus.Text = message or "หยุดเสกเป็ดแล้ว"
end

local function bindDuckPrompt()
    local _, root = duckCharacter()
    if not root then return false, "รอตัวละครพร้อม และลงจากที่นั่งก่อนครับ" end
    local closest, distance = nil, math.huge
    for _, object in ipairs(workspace:GetDescendants()) do
        if object:IsA("ProximityPrompt") then
            local objectText = normalizeDuck(object.ObjectText)
            local actionText = normalizeDuck(object.ActionText)
            local parentText = normalizeDuck(object.Parent.Name)
            local matches = objectText == "duckmonster"
                or actionText == "needallduck"
                or parentText == "duckmonster"
            local position = matches and duckPromptPosition(object)
            if position then
                local d = (root.Position - position).Magnitude
                if d <= object.MaxActivationDistance and d < distance then
                    closest, distance = object, d
                end
            end
        end
    end
    if not closest then
        return false, "ไม่พบปุ่มเสกเป็ดในระยะ\nยืนให้เห็นปุ่ม E: DuckMonster / Need All Duck แล้วกดบันทึกอีกครั้ง"
    end
    duck.prompt = closest
    duck.returnRoot = root.CFrame
    local floorRay = RaycastParams.new()
    floorRay.FilterType = Enum.RaycastFilterType.Exclude
    floorRay.FilterDescendantsInstances = {player.Character}
    floorRay.RespectCanCollide = true
    floorRay.IgnoreWater = true
    local ground = workspace:Raycast(root.Position, Vector3.new(0, -10, 0), floorRay)
    duck.floorClearance = ground and math.clamp(root.Position.Y - ground.Position.Y, 2, 6) or 3
    return true, string.format(
        "บันทึกจุดเสกแล้ว • ระยะ %.1f studs\nปุ่ม %s • ต้องกดค้าง %.1f วินาที\nกด DUCK AUTO เพื่อเริ่ม",
        distance, closest.KeyboardKeyCode.Name, closest.HoldDuration
    )
end

local function findDuckBoss()
    local _, root = duckCharacter()
    if not root then return nil end
    local wanted = normalizeDuck(duckName.Text)
    if wanted == "" then return nil end
    local best, nearest = nil, math.huge
    for humanoid in pairs(tracked) do
        local model = humanoid.Parent
        if model and model:IsA("Model") and humanoid.Health > 0
            and humanoid:IsDescendantOf(workspace) and not isPlayer(model)
            and not (duck.prompt and duck.prompt:IsDescendantOf(model))
            and (normalizeDuck(model.Name) == wanted
                or normalizeDuck(humanoid.DisplayName) == wanted) then
            local part = getPart(model)
            if part then
                local d = (root.Position - part.Position).Magnitude
                if d < nearest then
                    nearest = d
                    best = {model = model, humanoid = humanoid, part = part, distance = d}
                end
            end
        end
    end
    return best
end

local function attachDuckBoss(entry)
    endDuckHold()
    clearDuckBoss()
    duck.boss = entry
    duck.deathSeen = entry.humanoid.Health <= 0
    duck.nextApproachAt = 0
    skills.nextAt = 0
    local function markDead()
        if duck.boss == entry then
            duck.deathSeen = true
            duck.combatReady = false
            releaseSkillKeys()
        end
    end
    table.insert(duckConnections, entry.humanoid.Died:Connect(markDead))
    table.insert(duckConnections, entry.humanoid.HealthChanged:Connect(function(health)
        if health <= 0 then markDead() end
    end))
    duck.phase = "FIGHT"
    duck.spawnDeadline = nil
    duck.missingSince = nil
    duck.warpDeadline = os.clock() + DUCK_RETURN_TIMEOUT
    duckMarker = makeMarker(entry.part)
end

local function summonPromptReady(root)
    local prompt = duck.prompt
    local position = duckPromptPosition(prompt)
    if not position then return false, "จุดเสกไม่อยู่ในข้อมูลที่โหลด กรุณาบันทึกจุดใหม่" end
    if not prompt.Enabled then return false, "ปุ่มเสกยังไม่พร้อม" end
    if (root.Position - position).Magnitude > prompt.MaxActivationDistance then
        return false, "ยังไม่ถึงระยะกด E หรือถูกดึงกลับจากจุดเสก"
    end
    return true
end

local function beginDuckReturn()
    releaseReturnGuard()
    duck.returnAttempts = 0
    duck.returnStableSince = nil
    duck.phase = "RETURN"
    duck.spawnDeadline = nil
    duck.deadline = os.clock() + DUCK_RETURN_TIMEOUT
    duck.returnMoved = false
end

local function duckStep()
    if not duck.enabled then return end
    local now = os.clock()
    local character, root = duckCharacter()
    if not character then
        releaseReturnGuard()
        releaseSkillKeys()
        duck.combatReady = false
        duck.stableSince = nil
        if duck.phase == "HOLD" or duck.phase == "WAIT_SPAWN"
            or (duck.phase == "RETURN" and duck.spawnDeadline) then
            stopDuck("หยุด: ตัวละครไม่พร้อมระหว่างเสก\nตรวจว่าบอสเกิดแล้วหรือไม่ก่อนเปิดใหม่")
        else
            duck.visitedCharacter = nil
            duck.warpDeadline = now + DUCK_RETURN_TIMEOUT
            duck.returnMoved = false
            duck.deadline = now + DUCK_RETURN_TIMEOUT
            duckStatus.Text = "รอตัวละครเกิดใหม่หรือลงจากที่นั่ง..."
        end
        return
    end

    if duck.phase == "FIGHT" then
        local boss = duck.boss
        if not boss then stopDuck("ไม่พบข้อมูลบอสที่ล็อกไว้") return end
        if duck.deathSeen or boss.humanoid.Health <= 0 then
            releaseSkillKeys()
            duck.fought = duck.fought + 1
            clearDuckBoss()
            duck.phase = "COOLDOWN"
            duck.deadline = now + 2
            duckStatus.Text = "บอสตายแล้ว • รอบที่สำเร็จ " .. duck.fought .. "\nกำลังรอกลับจุดเสก..."
            return
        end
        if not isAlive(boss) then
            releaseSkillKeys()
            duck.combatReady = false
            duck.stableSince = nil
            duck.missingSince = duck.missingSince or now
            duckStatus.Text = "บอสหายจากข้อมูลที่โหลด แต่ยังไม่ยืนยันว่าตาย\nรอโหลดกลับก่อน ยังไม่เสกตัวใหม่"
            if now - duck.missingSince >= 15 then
                stopDuck("หยุด: บอสหายจากข้อมูลที่โหลดและยังยืนยันการตายไม่ได้\nตรวจบอสก่อนเปิดใหม่")
            end
            return
        end
        duck.missingSince = nil
        local part = getPart(boss.model)
        if not part then
            if now >= duck.warpDeadline then stopDuck("รอตำแหน่งบอสไม่สำเร็จ ลองใหม่เมื่อโหลดครบ") end
            return
        end
        local distance = (root.Position - part.Position).Magnitude
        if duck.visitedCharacter ~= character or distance > 35 then
            duck.combatReady = false
            duck.stableSince = nil
            releaseSkillKeys()
            local ready, reason = duckMovementReady(character, root)
            if not ready then
                duckStatus.Text = "พักสกิลก่อนเข้าหาบอส: " .. reason
                return
            end
            if now < (duck.nextApproachAt or 0) then
                duckStatus.Text = "กำลังรอตำแหน่งหลังวาร์ป ยังไม่ส่งสกิล..."
                return
            end
            if (duck.retries or 0) >= 3 then
                duckStatus.Text = "AUTO ยังเปิดอยู่ แต่พักสกิล: วาร์ปยังไม่ถึงบอส\nเข้าหาบอสเอง หรือปิด/เปิด DUCK AUTO เพื่อลองใหม่"
                return
            end
            local ok, message = warp(boss)
            if not ok then duckStatus.Text = message return end
            duck.visitedCharacter = character
            duck.retries = (duck.retries or 0) + 1
            duck.nextApproachAt = now + 3
            duckStatus.Text = "วาร์ปไปบอสแล้ว รอให้ตัวนิ่งก่อนใช้สกิล..."
            return
        end
        if root.Anchored or root.AssemblyLinearVelocity.Magnitude > 25 then
            duck.combatReady = false
            duck.stableSince = nil
            duckStatus.Text = "พักสกิล: รอให้ตัวนิ่งใกล้บอส..."
            return
        end
        if not duck.combatReady then
            if now < (duck.nextApproachAt or 0) or actionAnimationPlaying(character) then
                duckStatus.Text = "รอหลังวาร์ป/แอนิเมชันก่อนเริ่มสกิล..."
                return
            end
            duck.stableSince = duck.stableSince or now
            if now - duck.stableSince < 1 then return end
            duck.combatReady = true
            duck.retries = 0
        end
        if duckMarker then
            duckMarker.gui.Adornee = part
            duckMarker.label.TextColor3 = Color3.fromRGB(255, 160, 70)
            duckMarker.label.Text = string.format("DUCK BOSS [TARGET]\n%.0f studs",
                (root.Position - part.Position).Magnitude)
        end
        duckStatus.Text = string.format(
            "อยู่ใกล้บอส: %s\nHP: %.0f • สำเร็จแล้ว %d รอบ\nบอสตายแล้วจะพักสกิลก่อนวาร์ปกลับ",
            boss.model.Name, boss.humanoid.Health, duck.fought)
        useDuckSkill(character, root, boss)
        return
    end

    if duck.phase == "COOLDOWN" then
        releaseSkillKeys()
        if now < duck.deadline then return end
        local ready, reason = duckMovementReady(character, root, true)
        if not ready then
            duckStatus.Text = "บอสตายแล้ว หยุดส่งสกิล • " .. reason
            return
        end
        duck.phase = "SEEK"
        return
    end

    -- If a boss already exists, fight it before spending another summon.
    local existing = findDuckBoss()
    if existing then attachDuckBoss(existing) return end

    -- Start the 10-second summon window only after stable arrival in prompt range.
    -- Return recovery never spends a summon; HOLD and WAIT_SPAWN share one deadline.
    if duck.spawnDeadline and now >= duck.spawnDeadline then
        stopDuck("หยุด AUTO: ถึงจุดเสกและกดเสกแล้ว บอสไม่เกิดภายใน 10 วินาที\nกดเปิดใหม่เมื่อต้องการลองอีกครั้ง")
        return
    end

    if duck.phase == "SEEK" then
        beginDuckReturn()
    elseif duck.phase == "RETURN" then
        if not duck.returnMoved then
            releaseSkillKeys()
            local ready, reason = duckMovementReady(character, root, true)
            if not ready then
                duckStatus.Text = "รอก่อนกลับจุดเสก: " .. reason
                return
            end
            if (duck.returnAttempts or 0) >= 3 then
                stopDuck("กลับจุดเสกแล้วยังไม่นิ่งหลังลอง 3 ครั้ง\nปิด AUTO สกิลเดิม ยืนบนพื้นโล่งข้างเป็ดแล้วบันทึกจุดใหม่")
                return
            end
            local moved, message = startDuckReturnWarp(character, root)
            if not moved then stopDuck(message) return end
            duckStatus.Text = "กลับจุดเสกครั้งที่ " .. duck.returnAttempts .. "\nกำลังหยุดแรงเหวี่ยงและรอให้ยืนนิ่ง..."
            return
        end
        if duck.returnGuard or now < duck.settleAt then return end
        local position = duckPromptPosition(duck.prompt)
        local near = position and (root.Position - position).Magnitude <= duck.prompt.MaxActivationDistance
        local stable = near and not root.Anchored
            and (root.Position - duck.returnPose.Position).Magnitude <= 3
            and root.AssemblyLinearVelocity.Magnitude <= 8
            and root.AssemblyAngularVelocity.Magnitude <= 3
            and not actionAnimationPlaying(character)

        if not stable then
            duck.returnStableSince = nil
            duckStatus.Text = "ยังยืนไม่มั่นคงหรือกระเด็นออกจากจุดเสก\nกำลังรอแก้ตำแหน่ง ยังไม่กด E..."
            if now >= duck.returnCheckUntil then
                duck.returnMoved = false
                duck.spawnDeadline = nil
            end
            return
        end
        duck.returnStableSince = duck.returnStableSince or now
        if now - duck.returnStableSince < 1 then
            duckStatus.Text = "อยู่ในระยะเสกแล้ว ตรวจว่ายืนนิ่ง..."
            return
        end

        -- No timer reset after holding starts; never duplicate an uncertain summon.
        if not duck.spawnDeadline then duck.spawnDeadline = now + DUCK_SPAWN_TIMEOUT end
        local ready, reason = summonPromptReady(root)
        if not ready then
            duckStatus.Text = "รอจุดเสก: " .. reason
            return
        end
        duck.phase = "HOLD"
        duck.deadline = now + math.max(0, duck.prompt.HoldDuration) + 0.2
        duck.held = duck.prompt
        duck.held:InputHoldBegin()
        duckStatus.Text = "ยืนนิ่งแล้ว กำลังกดเสก • รอบนี้รอบอสไม่เกิน 10 วินาที"
    elseif duck.phase == "HOLD" then
        local position = duckPromptPosition(duck.prompt)
        if not position or (root.Position - position).Magnitude > duck.prompt.MaxActivationDistance then
            endDuckHold()
            duck.phase = "WAIT_SPAWN"
            duckStatus.Text = "หลุดระยะระหว่างกดเสก รอตรวจว่าบอสเกิดแล้วหรือไม่\nยังไม่กดเสกซ้ำ"
            return
        end
        if now >= duck.deadline then
            endDuckHold()
            duck.phase = "WAIT_SPAWN"
        end
    elseif duck.phase == "WAIT_SPAWN" then
        duckStatus.Text = string.format(
            "กดเสกแล้ว รอตรวจพบบอสอีก %.0f วินาที\nหากไม่เกิด ระบบจะหยุด ไม่กดเสกซ้ำ",
            math.max(0, duck.spawnDeadline - now))
    end
end

bindDuck.Activated:Connect(function()
    stopDuck("กำลังบันทึกจุดเสก...")
    local ok, message = bindDuckPrompt()
    duckStatus.Text = message
    if ok then bindDuck.Text = "บันทึกจุดเสกแล้ว — กดเพื่อบันทึกใหม่" end
end)
duckTab.Activated:Connect(function() showPage("duck") end)
duckName.FocusLost:Connect(function()
    if duck.enabled then stopDuck("แก้ชื่อบอสแล้ว กดเปิดใหม่เพื่อใช้ชื่อใหม่") end
end)
duckButton.Activated:Connect(function()
    if duck.enabled then stopDuck("หยุดเสกเป็ดแล้ว") return end
    local ok, err = pcall(function()
        if normalizeDuck(duckName.Text) == "" then
            duckStatus.Text = "กรอกชื่อบอสก่อนครับ"
            return
        end
        if not duck.prompt or not duck.prompt:IsDescendantOf(workspace) or not duck.returnRoot then
            local bound, message = bindDuckPrompt()
            if not bound then duckStatus.Text = message return end
            bindDuck.Text = "บันทึกจุดเสกแล้ว — กดเพื่อบันทึกใหม่"
        end
        setAuto(false)
        if flight then stopFlight("ปิดบินเพื่อเสกเป็ด") end
        clearDuckBoss()
        duck.enabled = true
        duck.phase = "SEEK"
        duck.fought = 0
        duckButton.Text = "DUCK AUTO: ON — กดเพื่อหยุด"
        duckButton.BackgroundColor3 = colors.green
        duckStatus.Text = "เริ่มระบบเสกเป็ด กำลังตรวจหาบอสที่มีอยู่..."
    end)
    if not ok then
        stopDuck("เปิดระบบเสกเป็ดไม่สำเร็จ ดู Console")
        warn("Duck Auto:", err)
    end
end)


-- ===== Raid opener: E (Open Raid) -> กดปุ่ม Open ในหน้า Raid Boss -> วาร์ปเข้าวง =====
-- ไม่เรียก Remote เดาเอง: ใช้ ProximityPrompt และปุ่ม GUI จริงของเกมเท่านั้น

local function guiVisible(obj)
    local current = obj
    while current and current ~= playerGui do
        if current:IsA("GuiObject") and not current.Visible then return false end
        if current:IsA("ScreenGui") and not current.Enabled then return false end
        current = current.Parent
    end
    return true
end

local function buttonText(btn)
    if btn:IsA("TextButton") and btn.Text ~= "" then return btn.Text end
    for _, child in ipairs(btn:GetDescendants()) do
        if child:IsA("TextLabel") and child.Text ~= "" then return child.Text end
    end
    return ""
end

-- หา ปุ่ม Open ของหน้า "Raid Boss" (ตัวบนสุด = Bacon of Grudge)
local function findRaidOpenButton()
    for _, label in ipairs(playerGui:GetDescendants()) do
        if label:IsA("TextLabel") and not label:IsDescendantOf(gui)
            and normalizeDuck(label.Text) == "raidboss" and guiVisible(label) then
            local scope = label.Parent
            for _ = 1, 6 do
                if not scope or scope == playerGui then break end
                local best
                for _, obj in ipairs(scope:GetDescendants()) do
                    if obj:IsA("GuiButton") and guiVisible(obj)
                        and normalizeDuck(buttonText(obj)) == "open" then
                        if not best or obj.AbsolutePosition.Y < best.AbsolutePosition.Y then
                            best = obj
                        end
                    end
                end
                if best then return best, label end
                scope = scope.Parent
            end
        end
    end
    return nil
end

-- ปิดหน้าต่าง (Raid Boss / Victory): กดปุ่ม X ของหน้าต่างนั้น; ถ้า hide=true หรือไม่พบปุ่ม จะซ่อนกรอบหน้าต่างแทน
local function closeRaidWindow(label, press, hide)
    if not label or not label.Parent then return true end
    if not hide then
        local scope = label.Parent
        for _ = 1, 8 do
            if not scope or scope == playerGui or scope:IsA("ScreenGui") then break end
            for _, obj in ipairs(scope:GetDescendants()) do
                if obj:IsA("GuiButton") and guiVisible(obj)
                    and normalizeDuck(buttonText(obj)) == "x" then
                    if press(obj) then return true end
                end
            end
            scope = scope.Parent
        end
    end
    -- สำรอง: ซ่อนกรอบหน้าต่าง (ขนาดพอดีหน้าต่าง ไม่ใช่ทั้งจอ)
    local frame = label.Parent
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    while frame and frame ~= playerGui and not frame:IsA("ScreenGui") do
        if frame:IsA("GuiObject") and frame.AbsoluteSize.X >= 250 and frame.AbsoluteSize.Y >= 100
            and frame.AbsoluteSize.X < viewport.X * 0.8 and frame.AbsoluteSize.Y < viewport.Y * 0.9 then
            frame.Visible = false
            return true
        end
        frame = frame.Parent
    end
    label.Visible = false
    return false
end

local function pressGuiButton(btn, real)
    local fired = false
    if not real and btn:IsA("GuiButton") and typeof(getconnections) == "function" then
        for _, signal in ipairs({btn.Activated, btn.MouseButton1Click, btn.MouseButton1Down, btn.MouseButton1Up}) do
            pcall(function()
                for _, connection in ipairs(getconnections(signal)) do
                    connection:Fire()
                    fired = true
                end
            end)
        end
    end
    if fired then return true end
    -- ตัวรันที่ไม่มี getconnections: คลิกจริงที่กลางปุ่ม
    local okInput, manager = pcall(function() return game:GetService("VirtualInputManager") end)
    if okInput and manager then
        local inset = game:GetService("GuiService"):GetGuiInset()
        local center = btn.AbsolutePosition + btn.AbsoluteSize / 2 + inset
        local sent = pcall(function()
            pcall(function() manager:SendMouseMoveEvent(center.X, center.Y, game) end)
            task.wait(0.05)
            manager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
            task.wait(0.05)
            manager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
        end)
        return sent
    end
    return false
end

local function findOpenRaidPrompt(root)
    local closest, distance = nil, math.huge
    for _, object in ipairs(workspace:GetDescendants()) do
        if object:IsA("ProximityPrompt") then
            local objectText = normalizeDuck(object.ObjectText)
            local parentText = normalizeDuck(object.Parent and object.Parent.Name or "")
            if objectText == "openraid" or parentText == "openraid" then
                local position = duckPromptPosition(object)
                if position then
                    local d = (root.Position - position).Magnitude
                    if d <= object.MaxActivationDistance + 2 and d < distance then
                        closest, distance = object, d
                    end
                end
            end
        end
    end
    return closest, distance
end

local function raidMoveTo(character, root, pose)
    local rootToPivot = root.CFrame:ToObjectSpace(character:GetPivot())
    character:PivotTo(pose * rootToPivot)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    -- ถ้าบินอยู่ ให้ย้ายตำแหน่งล็อกของ Flight ตามด้วย ไม่งั้นจะถูกดึงกลับ
    if flight and flight.root == root then flight.cf = root.CFrame end
end

local function endRaidHold()
    local prompt = raid.held
    raid.held = nil
    if prompt then pcall(function() prompt:InputHoldEnd() end) end
end

local function raidStop(message)
    raid.token += 1
    raid.running = false
    raid.auto = false
    raid.fighting = false
    raid.combatReady = false
    raid.hoverPart = nil
    endRaidHold()
    if releaseSkillKeys then releaseSkillKeys() end
    raidButton.Text = "เปิด + เข้าวง (1 ครั้ง ไม่สู้)"
    raidButton.BackgroundColor3 = colors.active
    raidAutoButton.Text = "RAID AUTO: OFF — กดเพื่อวนต่อเนื่อง"
    raidAutoButton.BackgroundColor3 = colors.blue
    if message then raidStatus.Text = message end
end
raid.stop = raidStop

local function raidSay(text) raidStatus.Text = text end

-- หาบอส Raid: 1) ชื่อตรง/มีคำครบทุกคำ 2) ถ้าไม่พบ ใช้ตัวที่ HP สูงสุดในระยะ 250 studs (เฉพาะช่วงสู้)
local function refreshTracked()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Humanoid") then tracked[obj] = true end
    end
end

local function describeNearbyHumanoids(root)
    local rows = {}
    for humanoid in pairs(tracked) do
        local model = humanoid.Parent
        if model and model:IsA("Model") and humanoid.Health > 0
            and humanoid:IsDescendantOf(workspace) and not isPlayer(model) then
            local part = getPart(model)
            if part then
                table.insert(rows, {
                    d = (root.Position - part.Position).Magnitude,
                    text = string.format("%s (%s) HP %.0f/%.0f", model.Name, humanoid.DisplayName,
                        humanoid.Health, humanoid.MaxHealth),
                })
            end
        end
    end
    table.sort(rows, function(a, b) return a.d < b.d end)
    local lines = {}
    for i = 1, math.min(5, #rows) do
        table.insert(lines, string.format("%.0f studs: %s", rows[i].d, rows[i].text))
    end
    return #lines > 0 and table.concat(lines, "\n") or "ไม่พบ Humanoid ใกล้ตัวเลย"
end

local function findRaidBoss(root, allowFallback)
    local cached = raid.bossEntry
    if cached and isAlive(cached) then
        local part = getPart(cached.model)
        if part then
            cached.part = part
            cached.distance = (root.Position - part.Position).Magnitude
            return cached
        end
    end
    raid.bossEntry = nil

    local wanted = normalizeDuck(raidBossName.Text)
    local tokens = {}
    for word in string.gmatch(string.lower(raidBossName.Text), "%w+") do
        if #word >= 3 and word ~= "boss" then table.insert(tokens, word) end
    end
    local function nameMatches(text)
        if wanted ~= "" and text:find(wanted, 1, true) then return true end
        if #tokens == 0 then return false end
        for _, word in ipairs(tokens) do
            if not text:find(word, 1, true) then return false end
        end
        return true
    end

    local best, nearest = nil, math.huge
    local strongest, strongestHealth = nil, 0
    for humanoid in pairs(tracked) do
        local model = humanoid.Parent
        if model and model:IsA("Model") and humanoid.Health > 0
            and humanoid:IsDescendantOf(workspace) and not isPlayer(model) then
            local part = getPart(model)
            if part then
                local d = (root.Position - part.Position).Magnitude
                if nameMatches(normalizeDuck(model.Name)) or nameMatches(normalizeDuck(humanoid.DisplayName)) then
                    if d < nearest then
                        nearest = d
                        best = {model = model, humanoid = humanoid, part = part, distance = d}
                    end
                elseif allowFallback and d <= 250 and humanoid.MaxHealth >= 50000
                    and humanoid.MaxHealth > strongestHealth then
                    strongestHealth = humanoid.MaxHealth
                    strongest = {model = model, humanoid = humanoid, part = part, distance = d}
                end
            end
        end
    end
    best = best or strongest
    raid.bossEntry = best
    return best
end

-- ===== Raid combat helpers: ลูกบอล/ลูกน้อง (adds) ก่อน แล้วค่อยบอส โดยเกาะอยู่เหนือหัวเป้าหมายตลอด =====
local RAID_ADD_HEIGHT = 10     -- ลอยเหนือลูกบอล/ลูกน้องกี่ studs (บอสตั้งค่าในช่องบนหน้าจอ)
local RAID_ADD_RADIUS = 220    -- ลูกน้อง/ลูกบอลต้องอยู่ห่างจากบอสไม่เกินกี่ studs (กันไปเกาะของประดับฉากไกลๆ)

-- กันไม่ให้ไปนับ Ally/ของเราเป็นศัตรู (ลูกน้องที่บอสเรียกมีเจ้าของเป็นบอส จึงต้องไม่ถูกนับเป็นของเรา)
local function isFriendlyModel(model)
    local playerName = normalizeDuck(player.Name)
    local displayName = normalizeDuck(player.DisplayName)
    local current = model
    while current and current ~= workspace do
        local name = normalizeDuck(current.Name)
        if name == playerName or name == displayName
            or name:find("ally", 1, true) or name:find("companion", 1, true) then
            return true
        end
        -- เป็นของเราต่อเมื่อค่า Owner ชี้มาที่เรา (ไม่ใช่ Owner ของใครก็ได้)
        for _, attribute in ipairs({"Owner", "OwnerId", "OwnerUserId", "OwnerName"}) do
            local owner = current:GetAttribute(attribute)
            if owner ~= nil and (owner == player.UserId or tostring(owner) == tostring(player.UserId)
                or tostring(owner) == player.Name) then
                return true
            end
        end
        local ownerValue = current:FindFirstChild("Owner")
        if ownerValue and ownerValue:IsA("ObjectValue") and ownerValue.Value == player then
            return true
        end
        current = current.Parent
    end
    return false
end

-- ลูกบอลบางแบบไม่มี Humanoid แต่มีแถบเลือดลอยเหนือหัว (BillboardGui ข้อความ "525000/525000")
-- จึงอ่านเลือดจากแถบนั้นแทน เพื่อให้หาเจอและรู้ว่าตายหรือยัง
local function parseHealthText(text)
    local a, b = string.match(text or "", "^%s*([%d,%.]+)%s*/%s*([%d,%.]+)%s*$")
    if not a then return nil end
    local cur = tonumber((a:gsub(",", "")))
    local max = tonumber((b:gsub(",", "")))
    if cur and max and max > 0 then return cur, max end
    return nil
end

local function scanBillboardHealth()
    local found = {}
    local function scan(container)
        for _, bb in ipairs(container:GetDescendants()) do
            if bb:IsA("BillboardGui") and not bb:IsDescendantOf(gui) then
                local part = bb.Adornee
                if not part then part = bb.Parent end
                if part and part:IsA("Attachment") then part = part.Parent end
                if part and part:IsA("Model") then part = getPart(part) end
                if part and part:IsA("BasePart") and part:IsDescendantOf(workspace) then
                    for _, label in ipairs(bb:GetDescendants()) do
                        if label:IsA("TextLabel") and parseHealthText(label.Text) then
                            table.insert(found, {label = label, part = part})
                            break
                        end
                    end
                end
            end
        end
    end
    scan(workspace)
    scan(playerGui)
    return found
end

local function findBillboardAdds(root, boss)
    local now = os.clock()
    if now - (raid.bbAt or -math.huge) > 3 then
        raid.bbAt = now
        raid.bbCache = scanBillboardHealth()
    end
    local out = {}
    for _, item in ipairs(raid.bbCache or {}) do
        local label, part = item.label, item.part
        if label.Parent and part.Parent then
            local cur, max = parseHealthText(label.Text)
            local model = part:FindFirstAncestorOfClass("Model")
            if cur and cur > 0
                and not (boss and part:IsDescendantOf(boss.model))
                and not isPlayer(part) and not isFriendlyModel(part)
                and not (model and model:FindFirstChildOfClass("Humanoid")) then
                local virtual = raid.bbVirtual[label]
                if not virtual then
                    virtual = {Health = cur, MaxHealth = max, DisplayName = label.Text, virtual = true}
                    raid.bbVirtual[label] = virtual
                end
                virtual.Health = cur
                virtual.MaxHealth = max
                if not (raid.ignore[virtual] and raid.ignore[virtual] > now) then
                    table.insert(out, {
                        model = model or part, humanoid = virtual, part = part,
                        distance = (root.Position - part.Position).Magnitude,
                    })
                end
            end
        end
    end
    return out
end

-- ศัตรูอื่นที่ไม่ใช่บอส (ลูกบอลซ้าย/ขวา, ลูกน้องที่บอสเรียก) เรียงใกล้→ไกล
local function findRaidAdds(root, boss)
    local adds = {}
    local now = os.clock()
    for humanoid in pairs(tracked) do
        local model = humanoid.Parent
        if model and model:IsA("Model") and humanoid.Health > 0
            and humanoid:IsDescendantOf(workspace) and not isPlayer(model)
            and not (boss and model == boss.model)
            and not (raid.ignore[humanoid] and raid.ignore[humanoid] > now) then
            local part = getPart(model)
            local friendly = part and isFriendlyModel(model)
            if friendly and not raid.warned[model] then
                raid.warned[model] = true
                warn("Raid: ข้าม (ถูกมองว่าเป็นของฝ่ายเรา): " .. model:GetFullName())
            end
            if part and not friendly then
                local d = (root.Position - part.Position).Magnitude
                local center = boss and boss.part.Position or root.Position
                if (center - part.Position).Magnitude <= RAID_ADD_RADIUS then
                    table.insert(adds, {model = model, humanoid = humanoid, part = part, distance = d})
                end
            end
        end
    end
    for _, entry in ipairs(findBillboardAdds(root, boss)) do
        local center = boss and boss.part.Position or root.Position
        if (center - entry.part.Position).Magnitude <= RAID_ADD_RADIUS then
            table.insert(adds, entry)
        end
    end
    table.sort(adds, function(a, b) return a.distance < b.distance end)
    return adds
end

-- สำรอง: ถ้าบอสไม่ลดเลือดนานๆ และไม่เจอลูกบอลที่เป็น Humanoid ให้ลองหาวัตถุที่ชื่อคล้ายลูกบอล/โล่
local function findOrbCandidates(root)
    local out = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            local name = normalizeDuck(obj.Name)
            if (name:find("orb", 1, true) or name:find("ball", 1, true) or name:find("sphere", 1, true)
                or name:find("crystal", 1, true) or name:find("shield", 1, true))
                and not isPlayer(obj) and not obj:IsDescendantOf(gui) then
                local part = obj:IsA("BasePart") and obj or getPart(obj)
                if part and (root.Position - part.Position).Magnitude <= 200 then
                    table.insert(out, {name = obj.Name, part = part})
                end
            end
        end
    end
    return out
end

-- ล็อกให้ตัวละครลอยอยู่เหนือหัวเป้าหมายทุกเฟรม (ไม่ยืนบนพื้น) ตามเป้าหมายที่เคลื่อนที่
table.insert(flightConnections, RunService.Heartbeat:Connect(function()
    if not running or not raid.fighting or not raid.hoverPart then return end
    local part = raid.hoverPart
    if not part.Parent then return end
    local character, root = duckCharacter()
    if not character then return end
    local target = part.Position + Vector3.new(0, raid.hoverOffset or RAID_ADD_HEIGHT, 0)
    root.CFrame = CFrame.new(target) * root.CFrame.Rotation
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    -- ถ้าเปิด Flight ค้างไว้ ให้ตำแหน่งล็อกของ Flight ตามด้วย
    if flight and flight.root == root then flight.cf = root.CFrame end
end))

local function findVictoryLabel()
    for _, label in ipairs(playerGui:GetDescendants()) do
        if label:IsA("TextLabel") and not label:IsDescendantOf(gui)
            and normalizeDuck(label.Text) == "victory" and guiVisible(label) then
            return label
        end
    end
    return nil
end

-- ปิดหน้า Victory ให้ได้แน่นอน: ลองกดปุ่ม X (ยิงสัญญาณ) -> คลิกจริง -> ซ่อนกรอบ พร้อมตรวจว่าหายจริง
local function dismissVictory(label, pause)
    local pressReal = function(btn) return pressGuiButton(btn, true) end
    local attempts = {
        function() closeRaidWindow(label, pressGuiButton) end,
        function() closeRaidWindow(label, pressGuiButton) end,
        function() closeRaidWindow(label, pressReal) end,
        function() closeRaidWindow(label, pressReal, true) end,
        function() closeRaidWindow(label, pressReal, true) end,
    }
    for _, attempt in ipairs(attempts) do
        if not label.Parent or not guiVisible(label) then return true end
        attempt()
        if not pause(0.6) then return false end
    end
    return not label.Parent or not guiVisible(label)
end

-- ถืออาวุธ (Tool ในกระเป๋า/แถบด้านล่าง) ตามชื่อที่ตั้งไว้ ถ้ายังไม่ได้ถือ; เว้นช่องว่างเพื่อปิด
local function equipRaidWeapon(character)
    local wanted = normalizeDuck(raidWeapon.Text)
    if wanted == "" then return end
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    local function matches(tool)
        local name = normalizeDuck(tool.Name)
        local tip = normalizeDuck(tool.ToolTip)
        return name == wanted or tip == wanted or name:find(wanted, 1, true) ~= nil
    end
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") and matches(child) then return end -- ถืออยู่แล้ว
    end
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then return end
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and matches(tool) then
            pcall(function() humanoid:EquipTool(tool) end)
            return
        end
    end
end

-- กดปุ่มหนึ่งครั้ง (กดลง-ปล่อย) เช่น J เปิดบัฟเพิ่มพลัง: ปุ่มนี้กดซ้ำจะปิด จึงกดแค่รอบละครั้ง
local RAID_BUFF_KEY = "J"
local function tapKey(key)
    if not initializeSkillInput() then return false end
    local pressed = pcall(function() sendSkillKey(key, true) end)
    task.wait(0.1)
    pcall(function() sendSkillKey(key, false) end)
    return pressed
end

-- หนึ่งรอบ: เปิด Raid -> เข้าวง -> (ถ้า fight) สู้บอส -> ปิดหน้า Victory
-- คืนค่า "done" | "cancel" | "fail", ข้อความ
local function raidRound(alive, pause, fight)
    local function ready()
        if duck.enabled or auto then return false end
        return true
    end

    raid.bossEntry = nil
    raid.ignore = {}
    raid.bbCache = {}
    raid.bbAt = -math.huge
    raid.bbVirtual = {}
    raid.warned = {}
    raid.hoverPart = nil
    -- รอตัวละครพร้อม (เผื่อเพิ่งเกิดใหม่/กลับจากด่าน)
    local character, root
    local deadline = os.clock() + 20
    while alive() and os.clock() < deadline do
        character, root = duckCharacter()
        if character then break end
        raidSay("รอตัวละครพร้อม...")
        task.wait(0.5)
    end
    if not alive() then return "cancel" end
    if not character then return "fail", "ตัวละครไม่พร้อมภายใน 20 วินาที หยุดระบบ Raid" end
    if not ready() then return "fail", "หยุด Raid เพราะเปิด AUTO/Duck อยู่" end

    -- 0) ถ้ามีหน้า Victory ของรอบก่อนค้างอยู่ ต้องปิดก่อน ไม่งั้นรอบใหม่จะเข้าใจผิดว่าชนะแล้ว
    local leftover = findVictoryLabel()
    if leftover then
        raidSay("มีหน้า Victory ค้างอยู่ กำลังปิดก่อนเริ่มรอบ...")
        dismissVictory(leftover, pause)
        if not alive() then return "cancel" end
    end

    local prompt, button, windowLabel
    for attempt = 1, 12 do
        -- 1) วาร์ปไปจุดกด E แล้วหาปุ่ม (ปุ่มอาจถูกสร้างใหม่หลังจบรอบ)
        raidSay("วาร์ปไปจุด Open Raid...")
        raidMoveTo(character, root, raid.promptPose)
        if not pause(0.8) then return "cancel" end
        deadline = os.clock() + 6
        while alive() and os.clock() < deadline do
            character, root = duckCharacter()
            if not character then break end
            prompt = findOpenRaidPrompt(root)
            if prompt then break end
            task.wait(0.3)
        end
        if not alive() then return "cancel" end
        if not prompt then return "fail", "ไม่พบปุ่ม E: Open Raid ที่จุดที่บันทึก\nบันทึกจุดกด E ใหม่" end
        raid.prompt = prompt

        -- 2) กดค้าง E
        raidSay("กดค้าง E: Open Raid...")
        raid.held = prompt
        prompt:InputHoldBegin()
        if not pause(math.max(0, prompt.HoldDuration) + 0.25) then return "cancel" end
        endRaidHold()

        -- 3) รอหน้า Raid Boss แล้วกด Open
        raidSay("รอหน้า Raid Boss ขึ้น...")
        deadline = os.clock() + 6
        while alive() and os.clock() < deadline do
            button, windowLabel = findRaidOpenButton()
            if button then break end
            task.wait(0.15)
        end
        if not alive() then return "cancel" end
        if not button then return "fail", "ไม่พบหน้า Raid Boss หรือปุ่ม Open ภายใน 6 วินาที" end
        raidSay("กดปุ่ม Open...")
        if not pressGuiButton(button) then
            return "fail", "กดปุ่ม Open ไม่สำเร็จ ตัวรันอาจไม่รองรับ"
        end

        -- ปิดหน้าต่าง Raid Boss ที่ค้างบังจอ
        if not pause(0.4) then return "cancel" end
        for _ = 1, 3 do
            if not windowLabel or not windowLabel.Parent or not guiVisible(windowLabel) then break end
            closeRaidWindow(windowLabel, pressGuiButton)
            if not pause(0.3) then return "cancel" end
        end

        -- เกมแจ้ง "... Is Already Spawned!" = บอสรอบก่อนยังไม่หาย/ยังเสกไม่ได้: รอแล้วลองกด E ใหม่ ไม่ใช่วาร์ปเข้าวง
        local spawnedNotice = false
        local noticeUntil = os.clock() + 1.6
        while alive() and os.clock() < noticeUntil do
            for _, obj in ipairs(playerGui:GetDescendants()) do
                if obj:IsA("TextLabel") and not obj:IsDescendantOf(gui) and obj.Text ~= ""
                    and normalizeDuck(stripRichText(obj.Text)):find("alreadyspawned", 1, true)
                    and guiVisible(obj) then
                    spawnedNotice = true
                    break
                end
            end
            if spawnedNotice then break end
            task.wait(0.15)
        end
        if not alive() then return "cancel" end
        if spawnedNotice then
            if attempt >= 12 then
                return "fail", "เกมแจ้งว่าบอสยังเสกอยู่ (Already Spawned) ต่อเนื่องนานเกินไป หยุด AUTO"
            end
            raidSay(string.format("บอสรอบก่อนยังไม่หาย (Already Spawned) รอ 6 วินาทีแล้วลองกด Open ใหม่ (%d/12)", attempt))
            if not pause(6) then return "cancel" end
            continue
        end
        break

    end

    -- 4) รอวงเปิด แล้ววาร์ปเข้าวง
    raidSay("รอวงวาร์ปเปิด...")
    if not pause(1.0) then return "cancel" end
    character, root = duckCharacter()
    if not character then return "fail", "ตัวละครไม่พร้อมตอนเข้าวง" end
    raidMoveTo(character, root, raid.ringPose)
    raidSay("วาร์ปเข้าวงแล้ว...")
    if not pause(1.2) then return "cancel" end
    -- ถ้าโดนดันออกจากวงเล็กน้อย ให้วางกลับ (ถ้าถูกเกมย้ายไปไกลแล้วถือว่าเข้าด่านสำเร็จ)
    character, root = duckCharacter()
    if character then
        local d = (root.Position - raid.ringPose.Position).Magnitude
        if d > 6 and d < 40 then raidMoveTo(character, root, raid.ringPose) end
    end
    if not fight then return "done", "เปิด Raid และวาร์ปเข้าวงแล้ว" end

    -- 5) รอบอสเกิด (ไม่เกิด = วาร์ปไม่สำเร็จ/Portal Gun หมด ให้หยุด)
    local spawnDeadline = os.clock() + 35
    local boss
    local nextRefresh = 0
    while alive() and os.clock() < spawnDeadline do
        character, root = duckCharacter()
        if character then
            if os.clock() >= nextRefresh then
                nextRefresh = os.clock() + 2
                refreshTracked()
            end
            equipRaidWeapon(character)
            boss = findRaidBoss(root, true)
            if boss then break end
        end
        raidSay(string.format("รอบอสเกิด... เหลือ %.0f วินาที", math.max(0, spawnDeadline - os.clock())))
        task.wait(0.4)
    end
    if not alive() then return "cancel" end
    if not boss then
        local nearby = ""
        local _, nowRoot = duckCharacter()
        if nowRoot then nearby = "\nตัวที่อยู่ใกล้:\n" .. describeNearbyHumanoids(nowRoot) end
        warn("Raid: ไม่พบบอส" .. nearby)
        return "fail", "ไม่พบบอสตามชื่อ \"" .. raidBossName.Text .. "\" ภายใน 35 วินาที (Portal Gun หมด/วาร์ปไม่สำเร็จ/ชื่อบอสไม่ตรง)" .. nearby
    end

    -- 5.5) ถืออาวุธ แล้วกด J เปิดบัฟ 1 ครั้งต่อรอบ (บัฟหลุดทุกครั้งที่ออกจากด่าน และกดซ้ำจะปิด)
    if raid.buff then
        raidSay("ถืออาวุธและเปิดบัฟ " .. RAID_BUFF_KEY .. "...")
        character = duckCharacter()
        if character then equipRaidWeapon(character) end
        if not pause(0.7) then return "cancel" end
        local waitFocus = os.clock() + 3
        while alive() and UserInputService:GetFocusedTextBox() and os.clock() < waitFocus do
            task.wait(0.2)
        end
        if not alive() then return "cancel" end
        if not tapKey(RAID_BUFF_KEY) then
            warn("Raid: กดปุ่ม " .. RAID_BUFF_KEY .. " ไม่สำเร็จ (ตัวรันอาจไม่รองรับการจำลองปุ่ม)")
        end
        if not pause(0.8) then return "cancel" end
    end

    -- 6) สู้บอสแบบ Full Auto: ลูกบอล/ลูกน้อง (ตัวใกล้สุด) ก่อน -> บอส โดยลอยเหนือหัวเป้าหมายตลอด
    raid.fighting = true
    raid.combatReady = false
    raid.hoverPart = nil
    skills.nextAt = 0
    local fightDeadline = os.clock() + 1500
    local missingSince, victory, readySince
    local fightStart = os.clock()
    -- หน้า Victory จะนับก็ต่อเมื่อเพิ่งปรากฏหลังเริ่มสู้ (กันหน้าเก่าที่ค้างมาหลอกว่าชนะ)
    local victoryArmed = (findVictoryLabel() == nil)
    local nextVictory, nextRefresh, nextEquip = 0, 0, 0
    local track = {humanoid = nil, hp = 0, since = 0}
    local bossStale = {hp = nil, since = 0}
    local orbCache, orbCacheAt = {}, -math.huge
    local function endFight()
        raid.fighting = false
        raid.combatReady = false
        raid.hoverPart = nil
        releaseSkillKeys()
    end
    while alive() do
        if not ready() then
            endFight()
            return "fail", "หยุด Raid เพราะเปิด AUTO/Duck อยู่"
        end
        local now = os.clock()
        if now > fightDeadline then
            endFight()
            return "fail", "สู้บอสเกิน 25 นาที หยุดระบบ Raid"
        end
        if now >= nextVictory then
            nextVictory = now + 1
            local label = findVictoryLabel()
            if not label then
                victoryArmed = true
            elseif victoryArmed then
                local cached = raid.bossEntry
                if cached and isAlive(cached) and now - fightStart < 30 then
                    victoryArmed = false -- บอสยังไม่ตาย ไม่ใช่ชัยชนะจริง
                else
                    victory = label
                    break
                end
            end
        end
        character, root = duckCharacter()
        if not character then
            raid.combatReady = false
            raid.hoverPart = nil
            readySince = nil
            releaseSkillKeys()
            raidSay("รอตัวละครเกิดใหม่...")
            task.wait(0.5)
            continue
        end
        if now >= nextRefresh then
            nextRefresh = now + 5
            refreshTracked()
        end
        if now >= nextEquip then
            nextEquip = now + 1
            equipRaidWeapon(character)
        end

        local boss = findRaidBoss(root, true)
        local target, kind, addCount = nil, "", 0
        if raid.hover then
            local adds = findRaidAdds(root, boss)
            addCount = #adds
            if adds[1] then
                target, kind = adds[1], "ลูกบอล/ลูกน้อง"
            elseif boss then
                target, kind = boss, "บอส"
            end
        elseif boss then
            target, kind = boss, "บอส"
        end

        if target then
            missingSince = nil
            local health = target.humanoid.Health
            if track.humanoid ~= target.humanoid then
                track = {humanoid = target.humanoid, hp = health, since = now}
                readySince = nil
                raid.combatReady = false
                releaseSkillKeys()
                warn(string.format("Raid target [%s]: %s (%s) HP %.0f/%.0f • เหลือลูกน้อง/ลูกบอล %d",
                    kind, target.model.Name, target.humanoid.DisplayName,
                    health, target.humanoid.MaxHealth, addCount))
            end
            if health < track.hp - 0.5 then
                track.hp = health
                track.since = now
            elseif health > track.hp then
                track.hp = health
            end
            -- ลูกน้อง/ลูกบอลที่ตีเท่าไรก็ไม่ลด (ตีไม่ได้) ข้ามไป 30 วินาที กันค้าง
            if kind ~= "บอส" and now - track.since > 15 then
                raid.ignore[target.humanoid] = now + 30
                warn("Raid: ข้ามเป้าหมายที่ไม่ลดเลือด " .. target.model.Name)
                continue
            end

            local hoverPart, label = target.part, kind
            if raid.hover then
                if kind == "บอส" then
                    if not bossStale.hp or health < bossStale.hp - 0.5 then
                        bossStale.hp = health
                        bossStale.since = now
                    end
                    -- บอสไม่ลดเลือดนาน = อาจมีโล่จากลูกบอลที่ไม่ใช่ Humanoid: ลองตีวัตถุคล้ายลูกบอลสลับกัน
                    if raid.orbFallback and now - bossStale.since > 40 then
                        if now - orbCacheAt > 5 then
                            orbCache = findOrbCandidates(root)
                            orbCacheAt = now
                        end
                        if #orbCache > 0 then
                            local index = math.floor((now - bossStale.since - 15) / 8) % #orbCache + 1
                            hoverPart = orbCache[index].part
                            label = "วัตถุ " .. orbCache[index].name
                        end
                    end
                else
                    bossStale.hp = nil
                end
                raid.hoverPart = hoverPart
                raid.hoverOffset = (kind == "บอส" and hoverPart == target.part) and raid.bossHeight or RAID_ADD_HEIGHT
                readySince = readySince or now
                if now - readySince >= 0.6 then raid.combatReady = true end
            else
                raid.hoverPart = nil
                if root.Anchored then
                    raid.combatReady = false
                    readySince = nil
                else
                    readySince = readySince or now
                    if now - readySince >= 1 then raid.combatReady = true end
                end
            end

            if raid.combatReady then
                raidSay(string.format("สู้: %s • %s\nHP %.0f/%.0f • ลูกน้อง/ลูกบอลเหลือ %d • รอบที่ %d",
                    label, target.model.Name, health, target.humanoid.MaxHealth, addCount, raid.rounds + 1))
                useDuckSkill(character, root, target)
            else
                raidSay("เข้าตำแหน่งเหนือหัวเป้าหมาย: " .. target.model.Name)
            end
        else
            raid.combatReady = false
            raid.hoverPart = nil
            readySince = nil
            releaseSkillKeys()
            missingSince = missingSince or now
            raidSay("ไม่พบบอส/ลูกน้อง รอหน้า Victory...")
            if now - missingSince > 20 then break end
        end
        task.wait(0.25)
    end
    endFight()
    if not alive() then return "cancel" end

    -- 7) หน้า Victory: กดปิด
    if not victory then
        raidSay("รอหน้า Victory...")
        deadline = os.clock() + 10
        while alive() and os.clock() < deadline do
            victory = findVictoryLabel()
            if victory then break end
            task.wait(0.4)
        end
        if not alive() then return "cancel" end
    end
    if not victory then
        return "fail", "ไม่พบหน้า Victory (อาจแพ้/หมดเวลา/ตายระหว่างสู้)\nหยุด AUTO เพื่อไม่ให้เสีย Portal Gun โดยไม่จำเป็น"
    end
    raidSay("ชนะแล้ว! กำลังปิดหน้า Victory...")
    if not pause(0.8) then return "cancel" end
    if not dismissVictory(victory, pause) then
        if not alive() then return "cancel" end
        return "fail", "ปิดหน้า Victory ไม่สำเร็จ หยุด AUTO เพื่อไม่ให้เสีย Portal Gun\nปิดหน้าต่างเอง แล้วกดเริ่มใหม่"
    end
    return "done", "จบรอบ: ชนะและปิดหน้า Victory แล้ว"
end

local function startRaid(autoMode)
    if raid.running then raidStop("หยุดระบบ Raid แล้ว") return end
    if auto or duck.enabled or dungeon.running or gacha.running then
        raidStatus.Text = "ปิด AUTO เป้าหมาย / Duck / Dungeon ก่อนใช้ระบบ Raid ครับ (เปิด Flight ได้)"
        return
    end
    if not raid.promptPose or not raid.prompt then
        raidStatus.Text = "กดบันทึกจุดกด E (ข้อ 1) ก่อนครับ"
        return
    end
    if not raid.ringPose then
        raidStatus.Text = "กดบันทึกจุดกลางวงวาร์ป (ข้อ 2) ก่อนครับ"
        return
    end
    if autoMode and normalizeDuck(raidBossName.Text) == "" then
        raidStatus.Text = "กรอกชื่อบอส Raid ก่อนครับ"
        return
    end

    raid.token += 1
    local token = raid.token
    raid.running = true
    raid.auto = autoMode
    raid.rounds = 0
    if autoMode then
        raidAutoButton.Text = "RAID AUTO: ON — กดเพื่อหยุด"
        raidAutoButton.BackgroundColor3 = colors.green
    else
        raidButton.Text = "กำลังทำงาน — กดเพื่อหยุด"
        raidButton.BackgroundColor3 = colors.green
    end

    task.spawn(function()
        local ok, err = pcall(function()
            local function alive() return running and raid.running and raid.token == token end
            local function pause(seconds)
                local untilTime = os.clock() + seconds
                while alive() and os.clock() < untilTime do task.wait(0.1) end
                return alive()
            end
            local maxRounds = math.max(0, math.floor(tonumber(raidMax.Text) or 0))
            while alive() do
                local result, message = raidRound(alive, pause, autoMode)
                if result == "cancel" then return end
                if result == "fail" then raidStop(message) return end
                raid.rounds += 1
                if not autoMode then raidStop(message) return end
                if maxRounds > 0 and raid.rounds >= maxRounds then
                    raidStop("ครบ " .. raid.rounds .. " รอบตามที่ตั้งไว้ ปิด AUTO แล้ว")
                    return
                end
                raidSay("เสร็จ " .. raid.rounds .. " รอบ • เริ่มรอบถัดไปใน 3 วินาที")
                if not pause(3) then return end
            end
        end)
        endRaidHold()
        if raid.token == token then releaseSkillKeys() end
        if not ok then
            raidStop("ระบบ Raid หยุดเพราะเกิด Error ดู Console")
            warn("Raid Auto:", err)
        end
    end)
end

bindRaidPrompt.Activated:Connect(function()
    local _, root = duckCharacter()
    if not root then raidStatus.Text = "รอตัวละครพร้อม และลงจากที่นั่งก่อนครับ" return end
    local prompt, distance = findOpenRaidPrompt(root)
    if not prompt then
        raidStatus.Text = "ไม่พบปุ่ม E: Open Raid ในระยะ\nยืนให้เห็นปุ่ม Open Raid แล้วกดใหม่"
        return
    end
    raid.prompt = prompt
    raid.promptPose = root.CFrame
    bindRaidPrompt.Text = "1) บันทึกจุดกด E แล้ว — กดเพื่อบันทึกใหม่"
    raidStatus.Text = string.format("บันทึกจุดกด E แล้ว • ระยะ %.1f studs • กดค้าง %.1f วินาที",
        distance, prompt.HoldDuration)
end)

bindRaidRing.Activated:Connect(function()
    local _, root = duckCharacter()
    if not root then raidStatus.Text = "รอตัวละครพร้อม และลงจากที่นั่งก่อนครับ" return end
    raid.ringPose = root.CFrame
    bindRaidRing.Text = "2) บันทึกจุดวงแล้ว — กดเพื่อบันทึกใหม่"
    raidStatus.Text = "บันทึกจุดกลางวงวาร์ปแล้ว"
end)

raidHeight.FocusLost:Connect(function()
    raid.bossHeight = math.clamp(tonumber(raidHeight.Text) or 30, 3, 300)
    raidHeight.Text = tostring(raid.bossHeight)
end)
raidMax.FocusLost:Connect(function()
    raidMax.Text = tostring(math.max(0, math.floor(tonumber(raidMax.Text) or 0)))
end)
raidBossName.FocusLost:Connect(function()
    if raid.running then raidStop("แก้ชื่อบอสแล้ว กดเริ่มใหม่เพื่อใช้ชื่อใหม่") end
end)
raidButton.Activated:Connect(function() startRaid(false) end)
raidAutoButton.Activated:Connect(function() startRaid(true) end)

-- ปุ่มสแกน: รายงานสิ่งมีชีวิต/แถบเลือดรอบตัว คัดลอกลง Clipboard (ถ้าตัวรันรองรับ) และพิมพ์ลง Console
raidBuffButton.Activated:Connect(function()
    raid.buff = not raid.buff
    raidBuffButton.Text = raid.buff and "บัฟ J: ON" or "บัฟ J: OFF"
    raidBuffButton.BackgroundColor3 = raid.buff and colors.green or colors.active
end)
raidScanButton.Activated:Connect(function()
    local _, root = duckCharacter()
    if not root then raidStatus.Text = "รอตัวละครพร้อมก่อนสแกน" return end
    refreshTracked()
    local lines = {"== Raid scan =="}
    local rows = {}
    for humanoid in pairs(tracked) do
        local parent = humanoid.Parent
        if parent and humanoid:IsDescendantOf(workspace) and not isPlayer(parent) then
            local part = parent:IsA("BasePart") and parent or (parent:IsA("Model") and getPart(parent))
            if part then
                local d = (root.Position - part.Position).Magnitude
                if d <= 400 then
                    table.insert(rows, {d = d, text = string.format(
                        "[Humanoid] %s (%s) HP %.0f/%.0f • %.0f studs • friendly=%s",
                        parent:GetFullName(), humanoid.DisplayName, humanoid.Health, humanoid.MaxHealth, d,
                        tostring(isFriendlyModel(parent)))})
                end
            end
        end
    end
    table.sort(rows, function(a, b) return a.d < b.d end)
    for i = 1, math.min(15, #rows) do table.insert(lines, rows[i].text) end
    local bars = scanBillboardHealth()
    for i = 1, math.min(15, #bars) do
        local item = bars[i]
        table.insert(lines, string.format("[HealthBar] \"%s\" on %s • %.0f studs",
            item.label.Text, item.part:GetFullName(), (root.Position - item.part.Position).Magnitude))
    end
    local boss = findRaidBoss(root, true)
    table.insert(lines, "[Boss] " .. (boss and boss.model:GetFullName() or "ไม่พบ"))
    local report = table.concat(lines, "\n")
    print(report)
    local copied = false
    local copyFunction = setclipboard or toclipboard
    if copyFunction then copied = pcall(copyFunction, report) end
    raidStatus.Text = string.format("สแกน: Humanoid %d • แถบเลือด %d • %s",
        #rows, #bars, copied and "คัดลอกลง Clipboard แล้ว ส่งให้ผมได้" or "ดูผลใน Console (F9)")
end)
raidWarpToggle.Activated:Connect(function()
    raid.hover = not raid.hover
    raidWarpToggle.Text = raid.hover and "โหมดสู้: FULL AUTO เกาะเหนือหัวเป้าหมาย (กดเพื่อสลับ)"
        or "โหมดสู้: MANUAL ยิงสกิลอย่างเดียว บินเองได้ (กดเพื่อสลับ)"
    raidWarpToggle.BackgroundColor3 = raid.hover and colors.green or colors.active
end)
raidTab.Activated:Connect(function() showPage("raid") end)

-- ===== Dungeon Full Auto: E (Open Dungeon) -> ใส่จำนวน Orb -> Spawn -> เข้าวง -> เปิด Auto Skip -> ลอยเหนือมอนแล้วยิงสกิล =====
local hudCache, hudScanAt = {}, {}
local function findHudLabel(key, test)
    local cached = hudCache[key]
    if cached and cached.Parent and guiVisible(cached) and test(cached) then return cached end
    hudCache[key] = nil
    local now = os.clock()
    if now - (hudScanAt[key] or -math.huge) < 1 then return nil end
    hudScanAt[key] = now
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and not obj:IsDescendantOf(gui)
            and obj.Text ~= "" and guiVisible(obj) and test(obj) then
            hudCache[key] = obj
            return obj
        end
    end
    return nil
end

local function findAutoSkipLabel()
    return findHudLabel("autoskip", function(o)
        return normalizeDuck(stripRichText(o.Text)):find("autoskip", 1, true) == 1
    end)
end
local function findWaveLabel()
    return findHudLabel("wave", function(o)
        return stripRichText(o.Text):match("[Ww]ave%s*:?%s*%d+%s*/%s*%d+") ~= nil
    end)
end
local function findStartInLabel()
    return findHudLabel("startin", function(o)
        return normalizeDuck(stripRichText(o.Text)):find("startin", 1, true) == 1
    end)
end
local function autoSkipState(label)
    local text = stripRichText(label.Text)
    local c, m = text:match("%[%s*(%d+)%s*/%s*(%d+)%s*%]")
    return tonumber(c), tonumber(m)
end

local function findDungeonPrompt(root)
    local closest, distance = nil, math.huge
    for _, object in ipairs(workspace:GetDescendants()) do
        if object:IsA("ProximityPrompt") then
            local objectText = normalizeDuck(object.ObjectText)
            local actionText = normalizeDuck(object.ActionText)
            local parentText = normalizeDuck(object.Parent and object.Parent.Name or "")
            if objectText:find("opendungeon", 1, true) or actionText:find("orbdungeon", 1, true)
                or parentText:find("opendungeon", 1, true) then
                local position = duckPromptPosition(object)
                if position then
                    local d = (root.Position - position).Magnitude
                    if d <= object.MaxActivationDistance + 2 and d < distance then
                        closest, distance = object, d
                    end
                end
            end
        end
    end
    return closest, distance
end

-- หน้าต่าง Dungeon: ป้าย "Dungeon Multiplier: xN" + ช่อง Enter Amount + ปุ่ม Spawn
local function findDungeonWindow()
    for _, label in ipairs(playerGui:GetDescendants()) do
        if (label:IsA("TextLabel") or label:IsA("TextButton")) and not label:IsDescendantOf(gui)
            and guiVisible(label)
            and normalizeDuck(stripRichText(label.Text)):find("dungeonmultiplier", 1, true) == 1 then
            local scope = label.Parent
            for _ = 1, 6 do
                if not scope or scope == playerGui or scope:IsA("ScreenGui") then break end
                local box, spawnButton
                for _, obj in ipairs(scope:GetDescendants()) do
                    if obj:IsA("TextBox") and guiVisible(obj) then
                        box = box or obj
                    elseif obj:IsA("GuiButton") and guiVisible(obj)
                        and normalizeDuck(buttonText(obj)) == "spawn" then
                        spawnButton = spawnButton or obj
                    end
                end
                if box and spawnButton then
                    return {label = label, box = box, spawn = spawnButton}
                end
                scope = scope.Parent
            end
        end
    end
    return nil
end

-- ใส่จำนวน Orb แล้วตรวจว่าป้ายเปลี่ยนเป็น xN จริง
local function setDungeonAmount(win, amount, pause)
    local want = "x" .. amount
    local function done()
        local text = normalizeDuck(stripRichText(win.label.Text))
        return text:sub(-#want) == want
    end
    if done() then return true end
    local box = win.box
    local methods = {
        function()
            box:CaptureFocus()
            task.wait(0.1)
            box.Text = tostring(amount)
            task.wait(0.15)
            box:ReleaseFocus(true)
        end,
        function()
            box.Text = tostring(amount)
            if typeof(getconnections) == "function" then
                for _, signal in ipairs({box.FocusLost, box:GetPropertyChangedSignal("Text")}) do
                    pcall(function()
                        for _, connection in ipairs(getconnections(signal)) do
                            connection:Fire(true)
                        end
                    end)
                end
            end
        end,
    }
    for _, method in ipairs(methods) do
        pcall(method)
        if not pause(0.5) then return false end
        if done() then return true end
    end
    return false
end

-- กดติ๊ก Auto Skip (สี่เหลี่ยมแดง -> เขียว) จนป้ายเป็น [1/1]
local function toggleAutoSkip(label, pause)
    local function isOn()
        local c, m = autoSkipState(label)
        return c ~= nil and m ~= nil and c >= m
    end
    if isOn() then return true end
    local center = label.AbsolutePosition + label.AbsoluteSize / 2
    local candidates = {}
    local seen = {}
    local function consider(obj, isButton)
        if seen[obj] or obj == label or not obj:IsA("GuiObject") or not guiVisible(obj) then return end
        if label:IsDescendantOf(obj) or obj:IsDescendantOf(label) then return end
        if obj.AbsoluteSize.X < 6 or obj.AbsoluteSize.X > 140 or obj.AbsoluteSize.Y > 140 then return end
        local d = (obj.AbsolutePosition + obj.AbsoluteSize / 2 - center).Magnitude
        if d > 260 then return end
        seen[obj] = true
        table.insert(candidates, {obj = obj, score = d + (isButton and 0 or 70)})
    end
    -- ปุ่มจริงของเกมชื่อ AutoSkip (WaveUI.AutoSkip) อยู่ ScreenGui เดียวกับป้าย: ให้ความสำคัญสูงสุด
    local scope = label.Parent
    for _ = 1, 4 do
        if not scope or scope == playerGui then break end
        for _, obj in ipairs(scope:GetDescendants()) do
            if obj:IsA("GuiButton") then
                consider(obj, true)
            elseif obj:IsA("Frame") or obj:IsA("ImageLabel") then consider(obj, false) end
        end
        if #candidates > 0 or scope:IsA("ScreenGui") then break end
        scope = scope.Parent
    end
    for _, item in ipairs(candidates) do
        if normalizeDuck(item.obj.Name):find("autoskip", 1, true) then item.score = item.score - 5000 end
    end
    if label:IsA("GuiButton") then
        table.insert(candidates, {obj = label, score = 1000})
    end
    table.sort(candidates, function(a, b) return a.score < b.score end)

    -- สถานะที่ใช้ตรวจว่ากดติดแล้ว: ข้อความป้าย + สีของสี่เหลี่ยม (ป้ายอาจอัปเดตช้า) จะกดวิธีถัดไปก็ต่อเมื่อไม่มีอะไรเปลี่ยนเลย
    -- (กันกดซ้ำแล้วสลับกลับเป็นปิด)
    local function snapshot(obj)
        local color = obj:IsA("GuiObject") and obj.BackgroundColor3 or Color3.new()
        local image = obj:IsA("ImageLabel") and obj.ImageColor3 or Color3.new()
        return string.format("%s|%.2f,%.2f,%.2f|%.2f,%.2f,%.2f", label.Text, color.R, color.G, color.B, image.R, image.G, image.B)
    end
    local function fakeInput(obj, state)
        return {
            UserInputType = Enum.UserInputType.MouseButton1, UserInputState = state,
            KeyCode = Enum.KeyCode.Unknown,
            Position = Vector3.new(obj.AbsolutePosition.X + obj.AbsoluteSize.X / 2,
                obj.AbsolutePosition.Y + obj.AbsoluteSize.Y / 2, 0),
            Delta = Vector3.zero,
        }
    end
    local methods = {
        function(obj) pressGuiButton(obj, true) end, -- คลิกเมาส์จริงก่อน (ใกล้เคียงผู้เล่นที่สุด)
        function(obj) if obj:IsA("GuiButton") then pressGuiButton(obj, false) end end,
        function(obj)
            if typeof(firesignal) ~= "function" or not obj:IsA("GuiButton") then return end
            for _, name in ipairs({"MouseButton1Down", "MouseButton1Click", "Activated", "MouseButton1Up"}) do
                pcall(function() firesignal(obj[name]) end)
            end
        end,
        function(obj)
            if typeof(getconnections) ~= "function" then return end
            for _, pair in ipairs({{"InputBegan", Enum.UserInputState.Begin}, {"InputEnded", Enum.UserInputState.End}}) do
                pcall(function()
                    for _, connection in ipairs(getconnections(obj[pair[1]])) do
                        connection:Fire(fakeInput(obj, pair[2]), false)
                    end
                end)
            end
        end,
    }
    local log = {}
    for i = 1, math.min(6, #candidates) do
        local obj = candidates[i].obj
        for m, method in ipairs(methods) do
            local before = snapshot(obj)
            pcall(method, obj)
            -- รอให้เซิร์ฟเวอร์ตอบ/ป้ายอัปเดต (สูงสุด ~1.6 วินาที) ก่อนตัดสินว่าไม่ติด
            local changed = false
            for _ = 1, 8 do
                if not pause(0.2) then return false end
                if isOn() then changed = true break end
                if snapshot(obj) ~= before then changed = true break end
            end
            if changed then
                if not pause(0.8) then return false end
                warn(string.format("Dungeon: Auto Skip ตอบสนอง (%s ตัวที่ %d วิธี %d) ป้าย: %s",
                    obj:GetFullName(), i, m, label.Text))
                dungeon.skipLog = string.format("กดที่ %s %s วิธี %d", obj.ClassName, obj.Name, m)
                return true -- ไม่กดซ้ำ กันสลับกลับเป็นปิด
            end
        end
        table.insert(log, string.format("%s %s %dx%d", obj.ClassName, obj.Name, obj.AbsoluteSize.X, obj.AbsoluteSize.Y))
    end
    warn("Dungeon: กด Auto Skip ไม่ติด ลองแล้ว: " .. (#log > 0 and table.concat(log, " | ") or "ไม่พบปุ่ม/กรอบใกล้ป้าย"))
    dungeon.skipLog = #log > 0 and table.concat(log, "\n") or "ไม่พบปุ่ม/กรอบใกล้ป้าย Auto Skip"
    return isOn()
end

local function dungeonEnemies(root, now)
    local list = {}
    for humanoid in pairs(tracked) do
        local model = humanoid.Parent
        if model and model:IsA("Model") and humanoid.Health > 0
            and humanoid:IsDescendantOf(workspace) and not isPlayer(model)
            and not (raid.ignore[humanoid] and raid.ignore[humanoid] > now)
            and not isFriendlyModel(model) then
            local part = getPart(model)
            if part then
                local d = (root.Position - part.Position).Magnitude
                if d <= 500 then
                    table.insert(list, {model = model, humanoid = humanoid, part = part, distance = d})
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    return list
end

local function dungeonSay(text)
    dungeonStatus.Text = text .. (dungeon.note and ("\n" .. dungeon.note) or "")
end

local function dungeonCleanup()
    if dungeon.holdPart then
        pcall(function() dungeon.holdPart:Destroy() end)
        dungeon.holdPart = nil
    end
end

local function dungeonStop(message)
    dungeon.token += 1
    dungeon.running = false
    raid.fighting = false
    raid.combatReady = false
    raid.hoverPart = nil
    endRaidHold()
    if releaseSkillKeys then releaseSkillKeys() end
    dungeonCleanup()
    dungeonTestButton.Text = "ทดสอบ: E→ใส่→Spawn→เข้าวง"
    dungeonTestButton.BackgroundColor3 = colors.active
    dungeonAutoButton.Text = "DUNGEON AUTO: OFF — กดเพื่อวนลงดัน"
    dungeonAutoButton.BackgroundColor3 = colors.blue
    if message then dungeonStatus.Text = message end
end
dungeon.stop = dungeonStop
do
    local baseStop = raid.stop
    raid.stop = function(message)
        if baseStop then baseStop(message) end
        if dungeon.running then dungeonStop(message) end
    end
end

-- ปิดหน้าต่าง Dungeon อย่างปลอดภัย: กด X (สัญญาณ -> คลิกจริง) ถ้าไม่ได้ผลค่อยซ่อนกรอบนอกสุดของหน้าต่าง (จดไว้เพื่อคืนค่า)
dungeon.hidden = {}
local function restoreDungeonHidden()
    for obj in pairs(dungeon.hidden) do
        pcall(function() obj.Visible = true end)
    end
    dungeon.hidden = {}
end
dungeon.restore = restoreDungeonHidden

local function findWindowXButton(win)
    local scope = win.label.Parent
    for _ = 1, 8 do
        if not scope or scope == playerGui or scope:IsA("ScreenGui") then break end
        for _, obj in ipairs(scope:GetDescendants()) do
            if obj:IsA("GuiButton") and guiVisible(obj) then
                local name = normalizeDuck(obj.Name)
                if normalizeDuck(buttonText(obj)) == "x" or name == "x" or name == "close" or name == "exit" then
                    return obj
                end
            end
        end
        scope = scope.Parent
    end
    return nil
end

local function closeDungeonWindow(win, pause)
    local function isOpen() return win.label.Parent and guiVisible(win.label) end
    for attempt = 1, 4 do
        if not isOpen() then return true end
        local xButton = findWindowXButton(win)
        if xButton then pressGuiButton(xButton, attempt > 2) end
        if not pause(0.6) then return false end
    end
    if not isOpen() then return true end
    -- สำรอง: ซ่อนกรอบหน้าต่างนอกสุด (ไม่ใหญ่เกินไป) แล้วจดไว้คืนค่ารอบหน้า
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    local best
    local frame = win.label.Parent
    while frame and frame ~= playerGui and not frame:IsA("ScreenGui") do
        if frame:IsA("GuiObject") and frame:IsAncestorOf(win.spawn) and frame:IsAncestorOf(win.box)
            and frame.AbsoluteSize.X < viewport.X * 0.9 and frame.AbsoluteSize.Y < viewport.Y * 0.95 then
            best = frame
        end
        frame = frame.Parent
    end
    if best then
        dungeon.hidden[best] = true
        best.Visible = false
    end
    return not isOpen()
end

-- ซ่อมหน้าต่าง Dungeon ที่ถูกซ่อนจนช่องใส่จำนวนหาย: เปิดป้าย Multiplier / ช่อง Enter Amount และกรอบแม่กลับมา
local function repairDungeonWindow()
    local fixed = 0
    for _, label in ipairs(playerGui:GetDescendants()) do
        if label:IsA("TextLabel") and not label:IsDescendantOf(gui)
            and normalizeDuck(stripRichText(label.Text)):find("dungeonmultiplier", 1, true) == 1
            and not guiVisible(label) then
            local current = label
            while current and current ~= playerGui do
                if current:IsA("GuiObject") and not current.Visible then current.Visible = true fixed += 1 end
                if current:IsA("ScreenGui") and not current.Enabled then current.Enabled = true fixed += 1 end
                if current.Parent and current.Parent:IsA("GuiObject") then
                    for _, sibling in ipairs(current.Parent:GetChildren()) do
                        if sibling:IsA("TextBox") and not sibling.Visible then sibling.Visible = true fixed += 1 end
                    end
                end
                current = current.Parent
            end
        end
    end
    return fixed
end

-- หนึ่งรอบ: เปิดหน้า Dungeon -> ใส่ Orb -> Spawn -> เข้าวง -> (fight) เปิด Auto Skip -> สู้จนจบ
local function dungeonRound(alive, pause, fight)
    local function ready()
        return not (duck.enabled or auto or raid.running)
    end
    raid.ignore = {}
    raid.hoverPart = nil
    raid.fighting = false
    raid.combatReady = false
    hudCache, hudScanAt = {}, {}
    restoreDungeonHidden()

    local character, root
    local deadline = os.clock() + 20
    while alive() and os.clock() < deadline do
        character, root = duckCharacter()
        if character then break end
        dungeonSay("รอตัวละครพร้อม...")
        task.wait(0.5)
    end
    if not alive() then return "cancel" end
    if not character then return "fail", "ตัวละครไม่พร้อมภายใน 20 วินาที หยุดระบบ Dungeon" end
    if not ready() then return "fail", "หยุด Dungeon เพราะเปิด AUTO/Duck/Raid อยู่" end

    local leftover = findVictoryLabel()
    if leftover then
        dungeonSay("มีหน้า Victory ค้างอยู่ กำลังปิดก่อน...")
        dismissVictory(leftover, pause)
        if not alive() then return "cancel" end
    end

    -- 1) วาร์ปไปจุดกด E
    dungeonSay("วาร์ปไปจุด Open Dungeon...")
    raidMoveTo(character, root, dungeon.promptPose)
    if not pause(0.8) then return "cancel" end
    local prompt
    deadline = os.clock() + 6
    while alive() and os.clock() < deadline do
        character, root = duckCharacter()
        if not character then break end
        prompt = findDungeonPrompt(root)
        if prompt then break end
        task.wait(0.3)
    end
    if not alive() then return "cancel" end
    if not prompt then return "fail", "ไม่พบปุ่ม E: Open Dungeon ที่จุดที่บันทึก\nบันทึกจุดกด E ใหม่" end
    dungeon.prompt = prompt

    -- 2) กดค้าง E
    dungeonSay("กดค้าง E: Open Dungeon...")
    raid.held = prompt
    prompt:InputHoldBegin()
    if not pause(math.max(0, prompt.HoldDuration) + 0.25) then return "cancel" end
    endRaidHold()

    -- 3) รอหน้าต่าง Dungeon
    dungeonSay("รอหน้าต่าง Dungeon ขึ้น...")
    local win
    deadline = os.clock() + 8
    local repaired = false
    while alive() and os.clock() < deadline do
        win = findDungeonWindow()
        if win then break end
        if not repaired and os.clock() > deadline - 5 then
            repaired = true
            local fixed = repairDungeonWindow()
            if fixed > 0 then warn("Dungeon: ซ่อมหน้าต่างที่ถูกซ่อน " .. fixed .. " จุด") end
        end
        task.wait(0.2)
    end
    if not alive() then return "cancel" end
    if not win then
        return "fail", "ไม่พบหน้าต่าง Dungeon ภายใน 6 วินาที (Orb Dungeon หมด? หรือกด E ไม่ติด)\nกดปุ่ม \"สแกนหน้าจอ GUI\" ส่งผลมาให้ผมดูได้"
    end

    -- 4) ใส่จำนวน Orb
    local amount = math.clamp(math.floor(tonumber(dungeonAmount.Text) or 25), 1, 25)
    dungeonSay("ใส่จำนวน Orb = " .. amount .. " ...")
    while alive() and UserInputService:GetFocusedTextBox() and UserInputService:GetFocusedTextBox() ~= win.box do
        task.wait(0.2)
    end
    if not setDungeonAmount(win, amount, pause) then
        if not alive() then return "cancel" end
        return "fail", "ใส่จำนวน Orb ไม่สำเร็จ (ป้ายไม่เปลี่ยนเป็น x" .. amount .. ") หยุดเพื่อไม่ให้เสีย Orb ผิดจำนวน"
    end

    -- 5) กด Spawn แล้วปิดหน้าต่าง
    dungeonSay("กด Spawn...")
    if not pressGuiButton(win.spawn) then return "fail", "กดปุ่ม Spawn ไม่สำเร็จ ตัวรันอาจไม่รองรับ" end
    if not pause(0.6) then return "cancel" end
    if not closeDungeonWindow(win, pause) and not alive() then return "cancel" end

    -- 6) เข้าวงแดง
    dungeonSay("รอวงเปิด แล้ววาร์ปเข้าวง...")
    if not pause(1.0) then return "cancel" end
    character, root = duckCharacter()
    if not character then return "fail", "ตัวละครไม่พร้อมตอนเข้าวง" end
    raidMoveTo(character, root, dungeon.ringPose)
    if not pause(1.0) then return "cancel" end
    if not fight then return "done", "ทดสอบเสร็จ: เปิดหน้า ใส่ Orb กด Spawn และเข้าวงแล้ว (รอเวลานับถอยหลังเอง)" end

    -- 7) รอเข้าดัน (ยืนในวงจนนับถอยหลังหมด)
    local entered
    deadline = os.clock() + 75
    while alive() and os.clock() < deadline do
        character, root = duckCharacter()
        if character then
            entered = findAutoSkipLabel()
            if entered then break end
            local d = (root.Position - dungeon.ringPose.Position).Magnitude
            if d > 3 and d < 40 then raidMoveTo(character, root, dungeon.ringPose) end
        end
        local startIn = findStartInLabel()
        dungeonSay("ยืนรอในวง..." .. (startIn and ("\n" .. stripRichText(startIn.Text)) or ""))
        task.wait(0.4)
    end
    if not alive() then return "cancel" end
    if not entered then
        return "fail", "ไม่ได้เข้าดันภายใน 75 วินาที (Orb หมด/ยืนไม่ตรงวง/ชื่อป้ายไม่ตรง) หยุด AUTO\nลองปุ่มสแกนหน้าจอ GUI ระหว่างอยู่ในดัน"
    end
    dungeonSay("เข้าดันแล้ว! กำลังเปิด Auto Skip...")
    if not pause(1.5) then return "cancel" end

    -- 8) ติ๊ก Auto Skip
    local skipLabel = findAutoSkipLabel() or entered
    dungeon.note = nil
    if toggleAutoSkip(skipLabel, pause) then
        dungeon.note = "Auto Skip: เปิดแล้ว ✔"
    else
        if not alive() then return "cancel" end
        dungeon.note = "Auto Skip: ไม่สำเร็จ ✖ (กดสแกน GUI ส่งให้ผม)"
        warn("Dungeon: เปิด Auto Skip ไม่สำเร็จ (ป้ายไม่เป็น [1/1]) จะลองใหม่ระหว่างสู้")
        dungeonSay("เปิด Auto Skip ไม่สำเร็จ ลองแล้ว:\n" .. tostring(dungeon.skipLog or "-"))
    end
    local lastClick = os.clock()
    local reclicks = 0

    -- 9) ถืออาวุธ + บัฟ J
    character = duckCharacter()
    if character then equipRaidWeapon(character) end
    if raid.buff then
        if not pause(0.7) then return "cancel" end
        local waitFocus = os.clock() + 3
        while alive() and UserInputService:GetFocusedTextBox() and os.clock() < waitFocus do
            task.wait(0.2)
        end
        if not alive() then return "cancel" end
        if not tapKey(RAID_BUFF_KEY) then warn("Dungeon: กดปุ่ม " .. RAID_BUFF_KEY .. " ไม่สำเร็จ") end
        if not pause(0.6) then return "cancel" end
    end

    -- 10) สู้: ลอยเหนือมอนตัวใกล้สุด (ล็อกตัวเดิมจนตาย) แล้วยิงสกิลตามคูลดาวน์
    raid.fighting = true
    raid.combatReady = false
    raid.hoverPart = nil
    skills.nextAt = 0
    local fightDeadline = os.clock() + 1800
    local lastHud = os.clock()
    local wave, waveMax
    local victory
    local victoryArmed = (findVictoryLabel() == nil)
    local nextHud, nextRefresh, nextEquip = 0, 0, 0
    local sticky, track, readySince = nil, {hp = 0, since = 0}, nil
    local holding = false
    local function endFight()
        raid.fighting = false
        raid.combatReady = false
        raid.hoverPart = nil
        releaseSkillKeys()
    end
    while alive() do
        if not ready() then
            endFight()
            return "fail", "หยุด Dungeon เพราะเปิด AUTO/Duck/Raid อยู่"
        end
        local now = os.clock()
        if now > fightDeadline then
            endFight()
            return "fail", "อยู่ในดันเกิน 30 นาที หยุดระบบ Dungeon"
        end
        if now >= nextHud then
            nextHud = now + 1
            local hud = findAutoSkipLabel()
            if hud then
                lastHud = now
                local c, m = autoSkipState(hud)
                if c and m and c < m and now - lastClick > 8 and reclicks < 5 then
                    reclicks += 1
                    lastClick = now
                    toggleAutoSkip(hud, pause)
                end
            end
            local waveLabel = findWaveLabel()
            if waveLabel then
                local w, mw = stripRichText(waveLabel.Text):match("[Ww]ave%s*:?%s*(%d+)%s*/%s*(%d+)")
                wave, waveMax = tonumber(w), tonumber(mw)
            end
            local label = findVictoryLabel()
            if not label then
                victoryArmed = true
            elseif victoryArmed then
                victory = label
                break
            end
            if now - lastHud > 10 then break end -- หน้าจอดันหายไป = ออกจากดันแล้ว
        end
        character, root = duckCharacter()
        if not character then
            raid.combatReady = false
            raid.hoverPart = nil
            readySince = nil
            releaseSkillKeys()
            dungeonSay("รอตัวละครเกิดใหม่...")
            task.wait(0.5)
            continue
        end
        if now >= nextRefresh then
            nextRefresh = now + 3
            refreshTracked()
        end
        if now >= nextEquip then
            nextEquip = now + 1
            equipRaidWeapon(character)
        end

        local enemies = dungeonEnemies(root, now)
        if sticky and not (sticky.humanoid.Health > 0 and sticky.humanoid:IsDescendantOf(workspace)
            and not (raid.ignore[sticky.humanoid] and raid.ignore[sticky.humanoid] > now)) then
            sticky = nil
        end
        if not sticky then sticky = enemies[1] end
        local target = sticky
        if target then
            holding = false
            local health = target.humanoid.Health
            if track.humanoid ~= target.humanoid then
                track = {humanoid = target.humanoid, hp = health, since = now}
                readySince = nil
                raid.combatReady = false
                releaseSkillKeys()
            end
            if health < track.hp - 0.5 then
                track.hp = health
                track.since = now
            elseif health > track.hp then
                track.hp = health
            end
            if now - track.since > 15 then
                raid.ignore[target.humanoid] = now + 30
                warn("Dungeon: ข้ามเป้าหมายที่ไม่ลดเลือด " .. target.model.Name)
                sticky = nil
                continue
            end
            local isBoss = target.humanoid.MaxHealth >= 50000
            raid.hoverPart = target.part
            raid.hoverOffset = isBoss and raid.bossHeight or dungeon.height
            readySince = readySince or now
            if now - readySince >= 0.6 then raid.combatReady = true end
            if raid.combatReady then
                dungeonSay(string.format("สู้: %s%s\nHP %.0f/%.0f • มอนเหลือ %d • Wave %s/%s • รอบที่ %d",
                    isBoss and "[บอส] " or "", target.model.Name, health, target.humanoid.MaxHealth,
                    #enemies, tostring(wave or "?"), tostring(waveMax or "?"), dungeon.rounds + 1))
                useDuckSkill(character, root, target)
            else
                dungeonSay("เข้าตำแหน่งเหนือหัว: " .. target.model.Name)
            end
        else
            -- ไม่มีมอน: ลอยค้างที่เดิม (ไม่ยืนบนพื้น) รอเวฟถัดไป
            raid.combatReady = false
            readySince = nil
            releaseSkillKeys()
            if not dungeon.holdPart or not dungeon.holdPart.Parent then
                local part = Instance.new("Part")
                part.Anchored = true
                part.CanCollide = false
                part.CanQuery = false
                part.CanTouch = false
                part.Transparency = 1
                part.Size = Vector3.new(1, 1, 1)
                part.Parent = workspace
                dungeon.holdPart = part
                holding = false
            end
            if not holding then
                dungeon.holdPart.Position = root.Position
                holding = true
            end
            raid.hoverPart = dungeon.holdPart
            raid.hoverOffset = 0
            dungeonSay(string.format("รอเวฟถัดไป... Wave %s/%s", tostring(wave or "?"), tostring(waveMax or "?")))
        end
        task.wait(0.25)
    end
    endFight()
    dungeonCleanup()
    if not alive() then return "cancel" end

    -- 11) จบดัน
    if victory then
        dungeonSay("ชนะแล้ว! กำลังปิดหน้า Victory...")
        if not pause(0.8) then return "cancel" end
        if not dismissVictory(victory, pause) then
            if not alive() then return "cancel" end
            return "fail", "ปิดหน้า Victory ไม่สำเร็จ หยุด AUTO เพื่อกันเสีย Orb\nปิดหน้าต่างเอง แล้วกดเริ่มใหม่"
        end
    elseif not (wave and waveMax and wave >= waveMax) then
        return "fail", string.format("ออกจากดันก่อนจบ (Wave %s/%s) อาจตาย/หมดเวลา หยุด AUTO เพื่อกันเสีย Orb",
            tostring(wave or "?"), tostring(waveMax or "?"))
    end
    -- รอกลับล็อบบี้ (หน้าจอดันหาย)
    dungeonSay("รอกลับล็อบบี้...")
    deadline = os.clock() + 25
    while alive() and os.clock() < deadline do
        hudScanAt = {}
        if not findAutoSkipLabel() and duckCharacter() then break end
        task.wait(0.5)
    end
    if not alive() then return "cancel" end
    if findAutoSkipLabel() then
        return "fail", "จบดันแล้วแต่ยังไม่ออกจากดันภายใน 25 วินาที หยุด AUTO\nออกจากดันเอง แล้วกดเริ่มใหม่"
    end
    return "done", "จบรอบ: ชนะดันแล้ว"
end

local function startDungeon(autoMode)
    if dungeon.running then dungeonStop("หยุดระบบ Dungeon แล้ว") return end
    if auto or duck.enabled or raid.running or gacha.running then
        dungeonStatus.Text = "ปิด AUTO เป้าหมาย / Duck / Raid ก่อนใช้ระบบ Dungeon ครับ (เปิด Flight ได้)"
        return
    end
    if not dungeon.promptPose or not dungeon.prompt then
        dungeonStatus.Text = "กดบันทึกจุดกด E (ข้อ 1) ก่อนครับ"
        return
    end
    if not dungeon.ringPose then
        dungeonStatus.Text = "กดบันทึกจุดกลางวงแดง (ข้อ 2) ก่อนครับ"
        return
    end
    dungeon.height = math.clamp(tonumber(dungeonHeight.Text) or 15, 3, 300)
    dungeon.token += 1
    local token = dungeon.token
    dungeon.running = true
    dungeon.rounds = 0
    if autoMode then
        dungeonAutoButton.Text = "DUNGEON AUTO: ON — กดเพื่อหยุด"
        dungeonAutoButton.BackgroundColor3 = colors.green
    else
        dungeonTestButton.Text = "กำลังทำงาน — กดเพื่อหยุด"
        dungeonTestButton.BackgroundColor3 = colors.green
    end
    task.spawn(function()
        local ok, err = pcall(function()
            local function alive() return running and dungeon.running and dungeon.token == token end
            local function pause(seconds)
                local untilTime = os.clock() + seconds
                while alive() and os.clock() < untilTime do task.wait(0.1) end
                return alive()
            end
            local maxRounds = math.max(0, math.floor(tonumber(dungeonMax.Text) or 0))
            while alive() do
                local result, message = dungeonRound(alive, pause, autoMode)
                if result == "cancel" then return end
                if result == "fail" then dungeonStop(message) return end
                dungeon.rounds += 1
                if not autoMode then dungeonStop(message) return end
                if maxRounds > 0 and dungeon.rounds >= maxRounds then
                    dungeonStop("ครบ " .. dungeon.rounds .. " รอบตามที่ตั้งไว้ ปิด AUTO แล้ว")
                    return
                end
                dungeonSay("เสร็จ " .. dungeon.rounds .. " รอบ • เริ่มรอบถัดไปใน 4 วินาที")
                if not pause(4) then return end
            end
        end)
        endRaidHold()
        if dungeon.token == token then releaseSkillKeys() end
        if not ok then
            dungeonStop("ระบบ Dungeon หยุดเพราะเกิด Error ดู Console")
            warn("Dungeon Auto:", err)
        end
    end)
end

bindDunPrompt.Activated:Connect(function()
    local _, root = duckCharacter()
    if not root then dungeonStatus.Text = "รอตัวละครพร้อม และลงจากที่นั่งก่อนครับ" return end
    local prompt, distance = findDungeonPrompt(root)
    if not prompt then
        dungeonStatus.Text = "ไม่พบปุ่ม E: Open Dungeon ในระยะ\nยืนให้เห็นปุ่มแล้วกดใหม่"
        return
    end
    dungeon.prompt = prompt
    dungeon.promptPose = root.CFrame
    bindDunPrompt.Text = "1) บันทึกจุดกด E แล้ว — กดเพื่อบันทึกใหม่"
    dungeonStatus.Text = string.format("บันทึกจุดกด E แล้ว • ระยะ %.1f studs • กดค้าง %.1f วินาที",
        distance, prompt.HoldDuration)
end)
bindDunRing.Activated:Connect(function()
    local _, root = duckCharacter()
    if not root then dungeonStatus.Text = "รอตัวละครพร้อม และลงจากที่นั่งก่อนครับ" return end
    dungeon.ringPose = root.CFrame
    bindDunRing.Text = "2) บันทึกจุดวงแล้ว — กดเพื่อบันทึกใหม่"
    dungeonStatus.Text = "บันทึกจุดกลางวงแดงแล้ว"
end)
dungeonHeight.FocusLost:Connect(function()
    dungeon.height = math.clamp(tonumber(dungeonHeight.Text) or 15, 3, 300)
    dungeonHeight.Text = tostring(dungeon.height)
end)
dungeonAmount.FocusLost:Connect(function()
    dungeonAmount.Text = tostring(math.clamp(math.floor(tonumber(dungeonAmount.Text) or 25), 1, 25))
end)
dungeonMax.FocusLost:Connect(function()
    dungeonMax.Text = tostring(math.max(0, math.floor(tonumber(dungeonMax.Text) or 0)))
end)
dungeonTestButton.Activated:Connect(function() startDungeon(false) end)
dungeonAutoButton.Activated:Connect(function() startDungeon(true) end)

-- สแกนหน้าจอ: รายการข้อความ GUI ที่มองเห็น + ProximityPrompt ใกล้ตัว คัดลอกลง Clipboard
dungeonScanButton.Activated:Connect(function()
    local lines = {"== Dungeon GUI scan =="}
    local count = 0
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if not obj:IsDescendantOf(gui) and guiVisible(obj) then
            if (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
                local text = obj:IsA("TextBox") and (obj.Text ~= "" and obj.Text or ("<placeholder>" .. obj.PlaceholderText)) or obj.Text
                if text ~= "" and count < 80 then
                    count += 1
                    table.insert(lines, string.format("[%s] \"%s\" • %s", obj.ClassName, text, obj:GetFullName()))
                end
            end
        end
    end
    local skipLabel = findAutoSkipLabel()
    if skipLabel then
        table.insert(lines, "== Auto Skip neighborhood ==")
        local scope = skipLabel.Parent and skipLabel.Parent.Parent or skipLabel.Parent
        for _, obj in ipairs(scope and scope:GetDescendants() or {}) do
            if obj:IsA("GuiObject") and guiVisible(obj) then
                local color = obj.BackgroundColor3
                table.insert(lines, string.format("[%s] %s • pos %d,%d size %dx%d • bg %d,%d,%d • %s",
                    obj.ClassName, obj.Name, obj.AbsolutePosition.X, obj.AbsolutePosition.Y,
                    obj.AbsoluteSize.X, obj.AbsoluteSize.Y,
                    color.R * 255, color.G * 255, color.B * 255, obj:GetFullName()))
            end
        end
    end
    local _, root = duckCharacter()
    if root then
        for _, object in ipairs(workspace:GetDescendants()) do
            if object:IsA("ProximityPrompt") then
                local position = duckPromptPosition(object)
                if position and (root.Position - position).Magnitude <= 40 then
                    table.insert(lines, string.format("[Prompt] Object=\"%s\" Action=\"%s\" Enabled=%s • %s",
                        object.ObjectText, object.ActionText, tostring(object.Enabled), object:GetFullName()))
                end
            end
        end
    end
    local report = table.concat(lines, "\n")
    print(report)
    local copied = false
    local copyFunction = setclipboard or toclipboard
    if copyFunction then copied = pcall(copyFunction, report) end
    dungeonStatus.Text = string.format("สแกนแล้ว %d รายการ • %s", count,
        copied and "คัดลอกลง Clipboard แล้ว ส่งให้ผมได้" or "ดูผลใน Console (F9)")
end)
dungeonSkipButton.Activated:Connect(function()
    local label = findAutoSkipLabel()
    if not label then dungeonStatus.Text = "ไม่พบป้าย Auto Skip (ต้องอยู่ในดันก่อน)" return end
    dungeonStatus.Text = "กำลังทดสอบกด Auto Skip: " .. stripRichText(label.Text)
    task.spawn(function()
        local ok = toggleAutoSkip(label, function(s) task.wait(s) return true end)
        dungeonStatus.Text = (ok and "ผล: ป้ายเป็น " or "ผล: ยังไม่ติด ป้ายเป็น ") .. stripRichText(label.Text)
            .. "\n" .. tostring(dungeon.skipLog or "")
    end)
end)
dungeonTab.Activated:Connect(function() showPage("dungeon") end)

local function initGacha()
local gachaPage = makePage()
gachaPage.Visible = false
extraTabs.gachaPage = gachaPage
local gachaTab = create("TextButton", {
    LayoutOrder = 60, Size = UDim2.fromOffset(145, 34),
    Text = "Gacha / สุ่มของ", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.Gotham, TextSize = 15,
    BackgroundColor3 = colors.tab, BorderSizePixel = 0,
}, navList)
create("UICorner", {CornerRadius = UDim.new(0, 7)}, gachaTab)
extraTabs.gachaTab = gachaTab
local function gachaRow(y, text, default)
    create("TextLabel", {
        Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(290, 28),
        BackgroundTransparency = 1, TextColor3 = colors.muted,
        TextSize = 13, Text = text, TextXAlignment = Enum.TextXAlignment.Left,
    }, gachaPage)
    return create("TextBox", {
        Position = UDim2.new(1, -90, 0, y), Size = UDim2.fromOffset(90, 28),
        BackgroundColor3 = colors.active, BorderSizePixel = 0,
        TextColor3 = Color3.new(1, 1, 1), TextSize = 14,
        Text = default, ClearTextOnFocus = false,
    }, gachaPage)
end
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1,
    Text = "Gacha / สุ่มของอัตโนมัติ", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold, TextSize = 20,
    TextXAlignment = Enum.TextXAlignment.Left,
}, gachaPage)
local bindGachaPrompt = create("TextButton", {
    Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 30),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 13, Text = "1) บันทึกจุดกด E (ยืนข้างโต๊ะ Chest / Open)",
}, gachaPage)
local gachaAmount = gachaRow(70, "ปุ่มที่กด: Open x ? (5 / 10 / 15)", "15")
local gachaMax = gachaRow(102, "จำนวนครั้งสูงสุด (0 = จนกว่าเพชรหมด)", "0")
local gachaReserve = gachaRow(134, "เก็บเพชรไว้อย่างน้อย (หยุดเมื่อต่ำกว่า)", "0")
local gachaButton = create("TextButton", {
    Position = UDim2.fromOffset(0, 172), Size = UDim2.new(1, 0, 0, 36),
    BackgroundColor3 = colors.blue, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 15, Text = "GACHA AUTO: OFF — กดเพื่อสุ่มต่อเนื่อง",
}, gachaPage)
local gachaStatus = create("TextLabel", {
    Position = UDim2.fromOffset(0, 216), Size = UDim2.new(1, 0, 0, 158),
    BackgroundTransparency = 1, TextColor3 = colors.muted,
    TextSize = 13, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    Text = "วิธีตั้งค่า: ยืนข้างโต๊ะที่กด E แล้วขึ้น \"Chest / Open\" กดข้อ 1 แล้วกดปุ่มเริ่ม\nระบบจะสุ่มไปเรื่อยๆ จนเพชรหมด (อ่านจากเพชรมุมซ้ายบน) หรือกดปุ่มเดิมเพื่อหยุด",
}, gachaPage)

-- ===== Gacha auto: กด E ค้าง (Chest / Open) -> กดปุ่ม Open x15 ซ้ำจนเพชรหมด =====
local function parseAbbrev(text)
    text = stripRichText(text):gsub(",", ""):gsub("%s", "")
    local number, suffix = text:match("^([%d%.]+)([KkMmBbTt]?)")
    number = tonumber(number)
    if not number then return nil end
    local mult = {k = 1e3, m = 1e6, b = 1e9, t = 1e12}
    return number * (mult[suffix:lower()] or 1)
end

local function readDiamonds()
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Name == "DiamondText" and not obj:IsDescendantOf(gui) then
            return parseAbbrev(obj.Text), obj.Text
        end
    end
    return nil
end

local function findGachaPrompt(root)
    local closest, distance = nil, math.huge
    for _, object in ipairs(workspace:GetDescendants()) do
        if object:IsA("ProximityPrompt") and normalizeDuck(object.ObjectText) == "chest" then
            local position = duckPromptPosition(object)
            if position then
                local d = (root.Position - position).Magnitude
                if d <= object.MaxActivationDistance + 2 and d < distance then
                    closest, distance = object, d
                end
            end
        end
    end
    return closest, distance
end

local function findGachaWindow(amount)
    local wanted = "openx" .. amount
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsA("GuiButton") and not obj:IsDescendantOf(gui) and guiVisible(obj)
            and normalizeDuck(buttonText(obj)) == wanted then
            local title
            local scope = obj.Parent
            for _ = 1, 6 do
                if not scope or scope == playerGui or scope:IsA("ScreenGui") then break end
                for _, label in ipairs(scope:GetDescendants()) do
                    if label:IsA("TextLabel") and normalizeDuck(label.Text) == "randomitems" then
                        title = label
                        break
                    end
                end
                if title then break end
                scope = scope.Parent
            end
            if title then return {button = obj, label = title, scope = scope} end
        end
    end
    return nil
end

-- ลายเซ็นของหน้าต่าง (ข้อความ/รูป/จำนวนวัตถุ) ใช้ตรวจว่ากดสุ่มติดจริง
local function gachaSignature(win)
    local parts = {}
    local scope = win.scope
    if scope and scope.Parent and not scope.Parent:IsA("ScreenGui") then scope = scope.Parent end
    local count = 0
    for _, obj in ipairs(scope:GetDescendants()) do
        count += 1
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            table.insert(parts, obj.Text)
        elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
            table.insert(parts, obj.Image)
        end
    end
    return count .. "|" .. table.concat(parts, "¦")
end

local function gachaNotice()
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsA("TextLabel") and not obj:IsDescendantOf(gui) and obj.Text ~= "" and guiVisible(obj) then
            local text = normalizeDuck(stripRichText(obj.Text))
            if text:find("notenough", 1, true) or text:find("insufficient", 1, true)
                or text:find("inventoryfull", 1, true) or text:find("bagfull", 1, true) then
                return stripRichText(obj.Text)
            end
        end
    end
    return nil
end

local function gachaSay(text) gachaStatus.Text = text end
local function endGachaHold()
    local prompt = gacha.held
    gacha.held = nil
    if prompt then pcall(function() prompt:InputHoldEnd() end) end
end

local function gachaStop(message)
    gacha.token += 1
    gacha.running = false
    endGachaHold()
    gachaButton.Text = "GACHA AUTO: OFF — กดเพื่อสุ่มต่อเนื่อง"
    gachaButton.BackgroundColor3 = colors.blue
    if message then gachaStatus.Text = message end
end

local function startGacha()
    if gacha.running then gachaStop("หยุดสุ่มแล้ว (สุ่มไป " .. gacha.pulls .. " ครั้ง)") return end
    if auto or duck.enabled or raid.running or dungeon.running then
        gachaStatus.Text = "ปิด AUTO เป้าหมาย / Duck / Raid / Dungeon ก่อนใช้ระบบสุ่มครับ (เปิด Flight ได้)"
        return
    end
    if not gacha.promptPose then
        gachaStatus.Text = "กดบันทึกจุดกด E (ข้อ 1) ก่อนครับ"
        return
    end
    local amount = math.floor(tonumber(gachaAmount.Text) or 15)
    if amount ~= 5 and amount ~= 10 and amount ~= 15 then
        gachaStatus.Text = "ปุ่มที่กดต้องเป็น 5, 10 หรือ 15"
        return
    end
    local maxPulls = math.max(0, math.floor(tonumber(gachaMax.Text) or 0))
    local reserve = math.max(0, tonumber(gachaReserve.Text) or 0)
    local price = amount * 10
    gacha.token += 1
    local token = gacha.token
    gacha.running = true
    gacha.pulls = 0
    gachaButton.Text = "GACHA AUTO: ON — กดเพื่อหยุด"
    gachaButton.BackgroundColor3 = colors.green

    task.spawn(function()
        local function alive() return running and gacha.running and gacha.token == token end
        local function pause(seconds)
            local untilTime = os.clock() + seconds
            while alive() and os.clock() < untilTime do task.wait(0.1) end
            return alive()
        end
        local ok, err = pcall(function()
            local method, misses, switches, reopens = 1, 0, 0, 0
            local function openWindow()
                local character, root = duckCharacter()
                if not character then return nil, "ตัวละครไม่พร้อม" end
                gachaSay("วาร์ปไปจุดกด E ของโต๊ะสุ่ม...")
                raidMoveTo(character, root, gacha.promptPose)
                if not pause(0.8) then return nil end
                local prompt
                local deadline = os.clock() + 6
                while alive() and os.clock() < deadline do
                    local _, nowRoot = duckCharacter()
                    if nowRoot then prompt = findGachaPrompt(nowRoot) end
                    if prompt then break end
                    task.wait(0.3)
                end
                if not alive() then return nil end
                if not prompt then return nil, "ไม่พบปุ่ม E: Chest / Open ที่จุดที่บันทึก\nบันทึกจุดกด E ใหม่" end
                gachaSay("กดค้าง E: เปิดหน้าสุ่ม...")
                gacha.held = prompt
                prompt:InputHoldBegin()
                if not pause(math.max(0, prompt.HoldDuration) + 0.25) then return nil end
                endGachaHold()
                local win
                deadline = os.clock() + 6
                while alive() and os.clock() < deadline do
                    win = findGachaWindow(amount)
                    if win then break end
                    task.wait(0.2)
                end
                if not alive() then return nil end
                if not win then return nil, "ไม่พบหน้าต่างสุ่ม/ปุ่ม Open x" .. amount .. " ภายใน 6 วินาที" end
                return win
            end

            while alive() do
                if auto or duck.enabled or raid.running or dungeon.running then
                    gachaStop("หยุดสุ่มเพราะเปิด AUTO/Duck/Raid/Dungeon อยู่")
                    return
                end
                local diamonds, diamondText = readDiamonds()
                if diamonds and diamonds < price + reserve then
                    gachaStop(string.format("หยุด: เพชรเหลือ %s (ต่ำกว่าที่ต้องใช้ %d) • สุ่มไปทั้งหมด %d ครั้ง",
                        tostring(diamondText), price + reserve, gacha.pulls))
                    return
                end
                if maxPulls > 0 and gacha.pulls >= maxPulls then
                    gachaStop("ครบ " .. gacha.pulls .. " ครั้งตามที่ตั้งไว้ หยุดแล้ว")
                    return
                end
                local win = findGachaWindow(amount)
                if not win then
                    reopens += 1
                    if reopens > 4 then
                        gachaStop("หน้าต่างสุ่มปิดและเปิดใหม่ไม่ได้หลายครั้ง หยุด • สุ่มไป " .. gacha.pulls .. " ครั้ง")
                        return
                    end
                    local opened, message = openWindow()
                    if not alive() then return end
                    if not opened then gachaStop(message or "เปิดหน้าสุ่มไม่สำเร็จ") return end
                    win = opened
                end
                local before = gachaSignature(win)
                if method == 1 then pressGuiButton(win.button, false) else pressGuiButton(win.button, true) end
                local changed = false
                for _ = 1, 10 do
                    if not pause(0.2) then return end
                    if gachaSignature(win) ~= before then changed = true break end
                end
                local notice = gachaNotice()
                if notice then
                    gachaStop("หยุด: เกมแจ้ง \"" .. notice .. "\" • สุ่มไป " .. gacha.pulls .. " ครั้ง")
                    return
                end
                if changed then
                    gacha.pulls += 1
                    misses = 0
                    reopens = 0
                else
                    misses += 1
                    if misses >= 2 then
                        misses = 0
                        switches += 1
                        method = 3 - method
                        if switches >= 3 then
                            gachaStop("กดปุ่ม Open x" .. amount .. " แล้วหน้าจอไม่เปลี่ยน (เพชร/ช่องเก็บของหมด หรือกดไม่ติด) หยุด • สุ่มไป " .. gacha.pulls .. " ครั้ง")
                            return
                        end
                    end
                end
                gachaSay(string.format("กำลังสุ่ม Open x%d\nสุ่มแล้ว %d ครั้ง (%d ชิ้น) • เพชร %s\nวิธีกด: %s",
                    amount, gacha.pulls, gacha.pulls * amount, tostring(diamondText or "?"),
                    method == 1 and "สัญญาณปุ่ม" or "คลิกเมาส์จริง"))
                if not pause(0.3) then return end
            end
        end)
        endGachaHold()
        if not ok then
            gachaStop("ระบบสุ่มหยุดเพราะเกิด Error ดู Console")
            warn("Gacha Auto:", err)
        end
    end)
end

bindGachaPrompt.Activated:Connect(function()
    local _, root = duckCharacter()
    if not root then gachaStatus.Text = "รอตัวละครพร้อม และลงจากที่นั่งก่อนครับ" return end
    local prompt, distance = findGachaPrompt(root)
    if not prompt then
        gachaStatus.Text = "ไม่พบปุ่ม E: Chest / Open ในระยะ\nยืนให้เห็นปุ่มแล้วกดใหม่"
        return
    end
    gacha.prompt = prompt
    gacha.promptPose = root.CFrame
    bindGachaPrompt.Text = "1) บันทึกจุดกด E แล้ว — กดเพื่อบันทึกใหม่"
    gachaStatus.Text = string.format("บันทึกจุดกด E แล้ว • ระยะ %.1f studs • กดค้าง %.1f วินาที",
        distance, prompt.HoldDuration)
end)
gachaAmount.FocusLost:Connect(function()
    local n = math.floor(tonumber(gachaAmount.Text) or 15)
    if n ~= 5 and n ~= 10 then n = 15 end
    gachaAmount.Text = tostring(n)
end)
gachaMax.FocusLost:Connect(function()
    gachaMax.Text = tostring(math.max(0, math.floor(tonumber(gachaMax.Text) or 0)))
end)
gachaReserve.FocusLost:Connect(function()
    gachaReserve.Text = tostring(math.max(0, math.floor(tonumber(gachaReserve.Text) or 0)))
end)
gachaButton.Activated:Connect(startGacha)
gachaTab.Activated:Connect(function() showPage("gacha") end)
end
initGacha()

;(function()
local craftPage = makePage()
craftPage.Visible = false
extraTabs.craftPage = craftPage
local craftTab = create("TextButton", {
    LayoutOrder = 70, Size = UDim2.fromOffset(145, 34),
    Text = "Craft / สูตรคราฟต์", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.Gotham, TextSize = 15,
    BackgroundColor3 = colors.tab, BorderSizePixel = 0,
}, navList)
create("UICorner", {CornerRadius = UDim.new(0, 7)}, craftTab)
extraTabs.craftTab = craftTab

create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
    Text = "Craft Tracker / รายการที่ต้องคราฟต์", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold, TextSize = 18,
    TextXAlignment = Enum.TextXAlignment.Left,
}, craftPage)
create("TextLabel", {
    Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 34),
    BackgroundTransparency = 1, TextColor3 = colors.muted, TextWrapped = true,
    TextSize = 12, Text = "เปิดหน้าต่างคราฟต์ของพลัง/ไอเทมที่ต้องการในเกมค้างไว้สักครู่ ระบบจะจับข้อมูลวัตถุดิบมาโชว์ที่นี่ให้เองอัตโนมัติ",
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
}, craftPage)
local craftCaptureButton = create("TextButton", {
    Position = UDim2.fromOffset(0, 62), Size = UDim2.new(0.5, -3, 0, 26),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 12, Text = "จับข้อมูลตอนนี้",
}, craftPage)
local craftAutoButton = create("TextButton", {
    Position = UDim2.new(0.5, 3, 0, 62), Size = UDim2.new(0.5, -3, 0, 26),
    BackgroundColor3 = colors.green, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 12, Text = "จับอัตโนมัติ: ON",
}, craftPage)
local craftClearButton = create("TextButton", {
    Position = UDim2.fromOffset(0, 92), Size = UDim2.new(1, 0, 0, 24),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.Gotham,
    TextSize = 12, Text = "ล้างรายการทั้งหมด",
}, craftPage)
local craftStatus = create("TextLabel", {
    Position = UDim2.fromOffset(0, 120), Size = UDim2.new(1, 0, 0, 18),
    BackgroundTransparency = 1, TextColor3 = colors.muted,
    TextSize = 12, TextWrapped = true, Text = "ยังไม่ได้จับข้อมูล",
    TextXAlignment = Enum.TextXAlignment.Left,
}, craftPage)
local craftList = create("ScrollingFrame", {
    Position = UDim2.fromOffset(0, 142), Size = UDim2.new(1, 0, 0, 232),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 3, ScrollBarImageColor3 = colors.muted,
    CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, craftPage)
create("UIListLayout", {
    Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
}, craftList)

-- ===== Craft Tracker: จับข้อมูลหน้าต่างคราฟต์ (MATERIALS REQUIRED) มาโชว์ไว้ในเมนู ไม่ต้องเปิดเกมดูซ้ำ =====
local function richEscape(s)
    return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\"", "&quot;"))
end

local function parseCraftNumber(text)
    text = text:gsub(",", "")
    local number, suffix = text:match("^([%d%.]+)([KkMmBbTt]?)$")
    number = tonumber(number)
    if not number then return nil end
    local mult = {k = 1e3, m = 1e6, b = 1e9, t = 1e12}
    return number * (mult[(suffix or ""):lower()] or 1)
end

local CRAFT_AMOUNT_PATTERN = "^[%d,%.]+[KkMmBbTt]?/[%d,%.]+[KkMmBbTt]?$"

local function findCraftButton(scope)
    for _, obj in ipairs(scope:GetDescendants()) do
        if obj:IsA("GuiButton") and guiVisible(obj) and normalizeDuck(buttonText(obj)) == "craft" then
            return obj
        end
    end
    return nil
end

-- ไต่ขึ้นไปแค่พอให้เจอทั้งป้าย MATERIALS REQUIRED และปุ่ม Craft อยู่ในกรอบเดียวกัน (กรอบเล็กสุดที่ครอบทั้งคู่)
-- ถ้าไต่ขึ้นไปจนสุด ScreenGui (เช่น HUD หลักที่ครอบทั้งจอ รวม Health/EXP) จะทำให้จับข้อมูลอื่นที่ไม่เกี่ยวมาปนด้วย
local function findCraftWindow()
    for _, label in ipairs(playerGui:GetDescendants()) do
        if label:IsA("TextLabel") and not label:IsDescendantOf(gui) and guiVisible(label)
            and normalizeDuck(stripRichText(label.Text)) == "materialsrequired" then
            local scope = label.Parent
            for _ = 1, 6 do
                if not scope or scope == playerGui or scope:IsA("ScreenGui") then break end
                if findCraftButton(scope) then return label, scope end
                scope = scope.Parent
            end
        end
    end
    return nil
end

-- ชื่อไอเทมมักอยู่แถวเดียวกับปุ่ม Craft (ทางซ้ายมือ) เช่น "SSJ"
local function craftItemName(scope, materialsLabel, craftButton)
    if not craftButton then return nil end
    local by = craftButton.AbsolutePosition.Y + craftButton.AbsoluteSize.Y / 2
    local best, bestX
    for _, obj in ipairs(scope:GetDescendants()) do
        if obj:IsA("TextLabel") and guiVisible(obj) and obj ~= materialsLabel and stripRichText(obj.Text) ~= "" then
            local oy = obj.AbsolutePosition.Y + obj.AbsoluteSize.Y / 2
            if math.abs(oy - by) <= 16 and obj.AbsolutePosition.X < craftButton.AbsolutePosition.X then
                if not bestX or obj.AbsolutePosition.X > bestX then
                    best, bestX = obj, obj.AbsolutePosition.X
                end
            end
        end
    end
    return best and stripRichText(best.Text) or nil
end

-- จับคู่ป้ายชื่อวัตถุดิบ + ป้าย "ปัจจุบัน/ต้องการ" โดยดูว่าอยู่แถวเดียวกัน (Y ใกล้กัน) แล้วชื่ออยู่ซ้ายมือ
-- เดินไล่ GetDescendants() แค่ครั้งเดียว (เดิมเรียกซ้ำในลูปทีละแถว ทำให้กระตุกหนักเวลาหน้าต่างมีของเยอะๆ
-- เช่นหน้ากระเป๋า) แล้วแยกเป็น "ป้ายตัวเลข" กับ "ป้ายชื่อที่เป็นไปได้" ไว้ล่วงหน้า ก่อนจับคู่กัน
local function scanCraftMaterials(scope, materialsLabel)
    local amounts, nameCandidates = {}, {}
    for _, obj in ipairs(scope:GetDescendants()) do
        if obj:IsA("TextLabel") and guiVisible(obj) and obj ~= materialsLabel then
            local text = stripRichText(obj.Text)
            local trimmed = text:gsub("%s", "")
            if trimmed:match(CRAFT_AMOUNT_PATTERN) then
                table.insert(amounts, obj)
            elseif text ~= "" then
                table.insert(nameCandidates, obj)
            end
        end
    end
    local rows = {}
    for _, amountLabel in ipairs(amounts) do
        local ay = amountLabel.AbsolutePosition.Y + amountLabel.AbsoluteSize.Y / 2
        local ax = amountLabel.AbsolutePosition.X
        local nameLabel, nameX
        for _, obj in ipairs(nameCandidates) do
            local oy = obj.AbsolutePosition.Y + obj.AbsoluteSize.Y / 2
            if math.abs(oy - ay) <= 10 and obj.AbsolutePosition.X < ax then
                if not nameX or obj.AbsolutePosition.X > nameX then
                    nameLabel, nameX = obj, obj.AbsolutePosition.X
                end
            end
        end
        if nameLabel then
            local text = stripRichText(amountLabel.Text):gsub("%s", "")
            local cur, need = text:match("^(.-)/(.-)$")
            table.insert(rows, {name = stripRichText(nameLabel.Text), text = text, cur = cur, need = need, y = ay})
        end
    end
    table.sort(rows, function(a, b) return a.y < b.y end)
    return rows
end

local craftRecipes = {}
local craftOrder = {}
local rebuildCraftList -- forward declared: live-data helpers below call it; body defined further down

-- ===== แหล่งข้อมูล real-time เพิ่มเติม =====
-- 1) เงิน/เพชร: อ่านจาก HUD มุมซ้ายบนได้ตลอดเวลา ไม่ต้องเปิดหน้าต่างไหนเลย
-- 2) จำนวนไอเทมอื่นๆ: อ่านจากหน้าต่าง INVENTORY (กระเป๋า) ทุกครั้งที่เปิดค้างไว้สักครู่ (ไม่ต้องเป็นหน้าคราฟต์)
local liveCurrency = {}
local inventoryCounts = {}
local inventoryCapturedAt = -math.huge

-- อ่านค่าเงิน/เพชรแบบเบาๆ: หา label ของ HUD แค่ครั้งเดียวแล้วเก็บอ้างอิงไว้ (ไม่ไล่สแกนทั้งจอทุกครั้ง
-- ที่ทำให้กระตุก) ครั้งต่อไปแค่อ่าน .Text ตรงๆ เร็วมาก จะสแกนใหม่ก็ต่อเมื่อ label หายไป (เช่นตอนตัวละครเกิดใหม่)
local currencyLabels = nil
local function scanCurrency()
    if not currencyLabels then
        currencyLabels = {}
        for _, frame in ipairs(playerGui:GetDescendants()) do
            if frame.Name == "Currency" and not frame:IsDescendantOf(gui) and guiVisible(frame) then
                for _, child in ipairs(frame:GetChildren()) do
                    for _, label in ipairs(child:GetDescendants()) do
                        if label:IsA("TextLabel") then
                            currencyLabels[normalizeDuck(child.Name)] = label
                            break
                        end
                    end
                end
                break
            end
        end
    end
    local lost = false
    for key, label in pairs(currencyLabels) do
        if label.Parent and guiVisible(label) then
            local text = stripRichText(label.Text):gsub("%s", "")
            if text:match("^[%d%.,]+[KkMmBbTt]?$") then
                liveCurrency[key] = stripRichText(label.Text)
            end
        else
            lost = true
        end
    end
    if lost then currencyLabels = nil end
end

local function findButtonByText(scope, wanted)
    wanted = normalizeDuck(wanted)
    for _, obj in ipairs(scope:GetDescendants()) do
        if obj:IsA("GuiButton") and guiVisible(obj) and normalizeDuck(buttonText(obj)) == wanted then
            return obj
        end
    end
    return nil
end

local function findInventoryWindow()
    for _, label in ipairs(playerGui:GetDescendants()) do
        if label:IsA("TextLabel") and not label:IsDescendantOf(gui) and guiVisible(label)
            and normalizeDuck(stripRichText(label.Text)) == "inventory" then
            local scope = label.Parent
            for _ = 1, 6 do
                if not scope or scope == playerGui or scope:IsA("ScreenGui") then break end
                if findButtonByText(scope, "all") then return scope end
                scope = scope.Parent
            end
        end
    end
    return nil
end

-- จับคู่ป้ายจำนวน "xN" กับชื่อไอเทมที่อยู่ใต้ไอคอนเดียวกัน (ชื่ออยู่ใต้ป้ายจำนวน ในกรอบ X ใกล้กัน)
-- จุดที่ทำให้กระตุกหนักตอนเปิดกระเป๋า: ของเดิมเรียก scope:GetDescendants() ใหม่ทุกครั้งที่จับคู่ 1 ชิ้น
-- (กระเป๋ามีของเป็นสิบเป็นร้อยชิ้น = ไล่ทั้งต้นไม้ GUI ซ้ำเป็นร้อยรอบ) ตอนนี้ไล่ครั้งเดียวแล้วจับคู่จากรายการที่เก็บไว้
local function scanInventoryCounts(scope)
    local counts = {}
    local countLabels, nameCandidates = {}, {}
    for _, obj in ipairs(scope:GetDescendants()) do
        if obj:IsA("TextLabel") and guiVisible(obj) then
            local text = stripRichText(obj.Text)
            local trimmed = text:gsub("%s", "")
            if trimmed:match("^[Xx]%d[%d,]*$") then
                table.insert(countLabels, obj)
            elseif text ~= "" then
                table.insert(nameCandidates, obj)
            end
        end
    end
    for _, countLabel in ipairs(countLabels) do
        local cx = countLabel.AbsolutePosition.X + countLabel.AbsoluteSize.X / 2
        local cy = countLabel.AbsolutePosition.Y
        local nameLabel, bestDist
        for _, obj in ipairs(nameCandidates) do
            local ox = obj.AbsolutePosition.X + obj.AbsoluteSize.X / 2
            local oy = obj.AbsolutePosition.Y
            if oy >= cy and oy - cy < 60 and math.abs(ox - cx) < 50 then
                local dist = (oy - cy) + math.abs(ox - cx)
                if not bestDist or dist < bestDist then nameLabel, bestDist = obj, dist end
            end
        end
        if nameLabel then
            local qty = tonumber((stripRichText(countLabel.Text):gsub("[^%d]", "")))
            if qty then counts[normalizeDuck(stripRichText(nameLabel.Text))] = qty end
        end
    end
    return counts
end

local function captureInventory(manual)
    local scope = findInventoryWindow()
    if not scope then
        if manual then craftStatus.Text = "ไม่พบหน้าต่าง INVENTORY ที่เปิดอยู่ตอนนี้ (กดปุ่ม INV ในเกมค้างไว้)" end
        return false
    end
    local allButton = findButtonByText(scope, "all")
    if allButton then pressGuiButton(allButton) end
    local counts = scanInventoryCounts(scope)
    local found = 0
    for _ in pairs(counts) do found += 1 end
    if found == 0 then
        if manual then craftStatus.Text = "เจอหน้าต่าง INVENTORY แต่ยังอ่านจำนวนไอเทมไม่ได้" end
        return false
    end
    inventoryCounts = counts
    inventoryCapturedAt = os.clock()
    rebuildCraftList()
    if manual then craftStatus.Text = "อัปเดตจำนวนไอเทมจากกระเป๋าแล้ว (" .. found .. " ชนิด)" end
    return true
end


rebuildCraftList = function()
    for _, child in ipairs(craftList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for index, itemName in ipairs(craftOrder) do
        local data = craftRecipes[itemName]
        if data then
            local card = create("Frame", {
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = colors.tab, BorderSizePixel = 0, LayoutOrder = index,
            }, craftList)
            create("UICorner", {CornerRadius = UDim.new(0, 8)}, card)
            create("UIPadding", {
                PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
                PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
            }, card)
            create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2)}, card)

            local headerRow = create("Frame", {
                Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = 1,
            }, card)
            create("TextLabel", {
                Size = UDim2.new(1, -26, 1, 0), BackgroundTransparency = 1,
                Text = itemName, Font = Enum.Font.GothamBold, TextSize = 14,
                TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left,
            }, headerRow)
            local removeButton = create("TextButton", {
                AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
                Size = UDim2.fromOffset(20, 20), Text = "×", TextColor3 = Color3.new(1, 1, 1),
                BackgroundColor3 = Color3.fromRGB(140, 48, 58), BorderSizePixel = 0, TextSize = 14,
            }, headerRow)
            create("UICorner", {CornerRadius = UDim.new(0, 5)}, removeButton)
            removeButton.Activated:Connect(function()
                craftRecipes[itemName] = nil
                for i, name in ipairs(craftOrder) do
                    if name == itemName then table.remove(craftOrder, i) break end
                end
                rebuildCraftList()
            end)

            local ageSeconds = math.max(0, math.floor(os.clock() - data.capturedAt))
            local ageText = "จับสูตรเมื่อ " .. ageSeconds .. " วินาทีที่แล้ว"
            local invAge = os.clock() - inventoryCapturedAt
            if invAge < 3600 then
                ageText = ageText .. " • กระเป๋าอัปเดตเมื่อ " .. math.max(0, math.floor(invAge)) .. " วินาทีที่แล้ว"
            end
            create("TextLabel", {
                Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
                Text = ageText, Font = Enum.Font.Gotham,
                TextSize = 11, TextColor3 = colors.muted, TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 2,
            }, card)

            local missing = {}
            local lines = {}
            for _, row in ipairs(data.rows) do
                local key = normalizeDuck(row.name)
                local curText, curNum = row.cur, parseCraftNumber(row.cur)
                local liveTag = ""
                if liveCurrency[key] then
                    curText, curNum = liveCurrency[key], parseCraftNumber(liveCurrency[key])
                    liveTag = " ⚡"
                elseif inventoryCounts[key] then
                    curText, curNum = tostring(inventoryCounts[key]), inventoryCounts[key]
                    liveTag = " 🎒"
                end
                local needNum = parseCraftNumber(row.need)
                local color, satisfied
                if curNum and needNum then
                    satisfied = curNum >= needNum
                    color = satisfied and "7CE38B" or "FF8B8B"
                else
                    color = "C7CCD8"
                end
                table.insert(lines, string.format('<font color="#%s">%s  %s/%s%s</font>',
                    color, richEscape(row.name), richEscape(curText), richEscape(row.need), liveTag))
                if satisfied == false then table.insert(missing, row.name) end
            end
            create("TextLabel", {
                Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, RichText = true,
                Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true, LayoutOrder = 3,
                Text = #missing > 0
                    and ('<font color="#FF8B8B">ขาด: ' .. richEscape(table.concat(missing, ", ")) .. '</font>')
                    or '<font color="#7CE38B">วัตถุดิบครบแล้ว พร้อมคราฟต์</font>',
            }, card)
            create("TextLabel", {
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1, RichText = true, Font = Enum.Font.Gotham,
                TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
                LineHeight = 1.15, LayoutOrder = 4, Text = table.concat(lines, "\n"),
            }, card)
        end
    end
    craftStatus.Text = #craftOrder > 0
        and ("จับไว้ทั้งหมด " .. #craftOrder .. " รายการ")
        or "ยังไม่ได้จับข้อมูล เปิดหน้าต่างคราฟต์ในเกมค้างไว้สักครู่"
end

local function captureCraftWindow(manual)
    local materialsLabel, scope = findCraftWindow()
    if not materialsLabel then
        if manual then craftStatus.Text = "ไม่พบหน้าต่างคราฟต์ที่เปิดอยู่ตอนนี้ (ต้องเห็นคำว่า MATERIALS REQUIRED)" end
        return false
    end
    local craftButton = findCraftButton(scope)
    local itemName = craftItemName(scope, materialsLabel, craftButton) or "ไม่ทราบชื่อไอเทม"
    local rows = scanCraftMaterials(scope, materialsLabel)
    if #rows == 0 then
        if manual then craftStatus.Text = "เจอหน้าต่างคราฟต์ แต่ยังอ่านรายการวัตถุดิบไม่ได้ ลองปุ่มสแกนหน้าจอ GUI (ในแท็บ Dungeon) แล้วส่งให้ผมดู" end
        return false
    end
    if not craftRecipes[itemName] then table.insert(craftOrder, itemName) end
    craftRecipes[itemName] = {rows = rows, capturedAt = os.clock()}
    rebuildCraftList()
    if manual then craftStatus.Text = "จับข้อมูล \"" .. itemName .. "\" แล้ว (" .. #rows .. " วัตถุดิบ)" end
    return true
end

local craftAutoScan = true
craftCaptureButton.Activated:Connect(function()
    local gotCraft = captureCraftWindow(true)
    local gotInv = captureInventory(not gotCraft)
    if gotCraft and gotInv then craftStatus.Text = "จับข้อมูลสูตรคราฟต์ + อัปเดตกระเป๋าแล้ว" end
end)
craftAutoButton.Activated:Connect(function()
    craftAutoScan = not craftAutoScan
    craftAutoButton.Text = craftAutoScan and "จับอัตโนมัติ: ON" or "จับอัตโนมัติ: OFF"
    craftAutoButton.BackgroundColor3 = craftAutoScan and colors.green or colors.active
end)
craftClearButton.Activated:Connect(function()
    craftRecipes = {}
    craftOrder = {}
    rebuildCraftList()
end)
craftTab.Activated:Connect(function() showPage("craft") end)

-- อัปเดตอายุข้อมูล ("จับเมื่อ ... วินาทีที่แล้ว") เป็นระยะ และสแกนหาหน้าต่างคราฟต์อัตโนมัติ
task.spawn(function()
    local nextAgeRefresh = 0
    while running do
        task.wait(2)
        scanCurrency() -- เบามาก อ่านค่าที่แคชไว้แล้ว ปล่อยให้ทำงานตลอดได้ไม่กระตุก
        -- การหาหน้าต่างคราฟต์/กระเป๋าต้องไล่สแกน GUI ทั้งจอ ถ้าปล่อยให้ทำงานตลอดเวลาแม้ไม่ได้เปิดแท็บนี้ดู
        -- จะกินแรงจนเกมกระตุก จึงสแกนเฉพาะตอนเปิดแท็บ Craft ดูอยู่เท่านั้น
        if craftAutoScan and currentPage == "craft" then
            captureCraftWindow(false)
            captureInventory(false)
        end
        if os.clock() >= nextAgeRefresh and #craftOrder > 0 then
            nextAgeRefresh = os.clock() + 5
            rebuildCraftList()
        end
    end
end)

end)()

;(function()
local headPage = makePage()
headPage.Visible = false
extraTabs.headPage = headPage
local headTab = create("TextButton", {
    LayoutOrder = 80, Size = UDim2.fromOffset(145, 34),
    Text = "ยืนบนหัว / พิมพ์ชื่อ", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.Gotham, TextSize = 15,
    BackgroundColor3 = colors.tab, BorderSizePixel = 0,
}, navList)
create("UICorner", {CornerRadius = UDim.new(0, 7)}, headTab)
extraTabs.headTab = headTab

create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
    Text = "ยืนบนหัว (พิมพ์ชื่อใครก็ได้)", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold, TextSize = 18,
    TextXAlignment = Enum.TextXAlignment.Left,
}, headPage)
create("TextLabel", {
    Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 32),
    BackgroundTransparency = 1, TextColor3 = colors.muted, TextWrapped = true,
    TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    Text = "พิมพ์ชื่อผู้เล่นหรือมอน (พิมพ์แค่บางส่วนก็ได้) แล้วกดไปยืนบนหัว ถ้าหาไม่เจอ ระบบจะสแกนหาเป้าหมายรอบตัวให้อัตโนมัติ",
}, headPage)

local headName = create("TextBox", {
    Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 32),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), TextSize = 14,
    PlaceholderText = "พิมพ์ชื่อตรงนี้...", Text = "", ClearTextOnFocus = false,
    TextXAlignment = Enum.TextXAlignment.Left,
}, headPage)
create("UIPadding", {PaddingLeft = UDim.new(0, 8)}, headName)

create("TextLabel", {
    Position = UDim2.fromOffset(0, 100), Size = UDim2.fromOffset(280, 26),
    BackgroundTransparency = 1, TextColor3 = colors.muted,
    TextSize = 13, Text = "ความสูงเหนือหัว (studs)",
    TextXAlignment = Enum.TextXAlignment.Left,
}, headPage)
local headHeight = create("TextBox", {
    Position = UDim2.new(1, -90, 0, 100), Size = UDim2.fromOffset(90, 26),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), TextSize = 14,
    Text = "6", ClearTextOnFocus = false,
}, headPage)

local headGoButton = create("TextButton", {
    Position = UDim2.fromOffset(0, 132), Size = UDim2.new(1, 0, 0, 32),
    BackgroundColor3 = colors.blue, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 14, Text = "ไปยืนบนหัว (ตามชื่อ)",
}, headPage)
local headStopButton = create("TextButton", {
    Position = UDim2.fromOffset(0, 168), Size = UDim2.new(1, 0, 0, 26),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 12, Text = "หยุดยืนบนหัว",
}, headPage)

create("TextLabel", {
    Position = UDim2.fromOffset(0, 200), Size = UDim2.fromOffset(230, 20),
    BackgroundTransparency = 1, TextColor3 = colors.muted,
    TextSize = 12, Text = "สำรอง: สแกนหาเป้าหมายรอบตัว",
    TextXAlignment = Enum.TextXAlignment.Left,
}, headPage)
local headRadius = create("TextBox", {
    Position = UDim2.new(1, -60, 0, 200), Size = UDim2.fromOffset(60, 20),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), TextSize = 12,
    Text = "60", ClearTextOnFocus = false,
}, headPage)
local headScanButton = create("TextButton", {
    Position = UDim2.fromOffset(0, 224), Size = UDim2.new(1, 0, 0, 26),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 12, Text = "สแกนรอบตัว (ระยะสั้นๆ)",
}, headPage)

local headList = create("ScrollingFrame", {
    Position = UDim2.fromOffset(0, 254), Size = UDim2.new(1, 0, 0, 76),
    BackgroundColor3 = colors.tab, BackgroundTransparency = 0.4, BorderSizePixel = 0,
    ScrollBarThickness = 3, ScrollBarImageColor3 = colors.muted,
    CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, headPage)
create("UIListLayout", {
    Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder,
}, headList)

local headStatus = create("TextLabel", {
    Position = UDim2.fromOffset(0, 336), Size = UDim2.new(1, 0, 0, 38),
    BackgroundTransparency = 1, TextColor3 = colors.muted,
    TextSize = 12, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    Text = "พิมพ์ชื่อแล้วกดไปยืนบนหัว หรือกดสแกนรอบตัวเพื่อเลือกจากรายการ",
}, headPage)

-- หาเป้าหมายจากชื่อ: เทียบชื่อโมเดล + DisplayName แบบมีบางส่วนตรงก็พอ (เหมือนระบบหาบอส Raid)
local function findByName(root, query)
    local wanted = normalizeDuck(query)
    if wanted == "" then return nil end
    local tokens = {}
    for word in string.gmatch(string.lower(query), "%w+") do
        if #word >= 2 then table.insert(tokens, word) end
    end
    local function nameMatches(text)
        if text:find(wanted, 1, true) then return true end
        if #tokens == 0 then return false end
        for _, word in ipairs(tokens) do
            if not text:find(word, 1, true) then return false end
        end
        return true
    end
    local character = player.Character
    local best, bestDist = nil, math.huge
    for humanoid in pairs(tracked) do
        local model = humanoid.Parent
        if model and model:IsA("Model") and humanoid.Health > 0
            and humanoid:IsDescendantOf(workspace) and model ~= character then
            local haystack = normalizeDuck(model.Name .. " " .. humanoid.DisplayName)
            if nameMatches(haystack) then
                local part = getPart(model)
                if part then
                    local d = (root.Position - part.Position).Magnitude
                    if d < bestDist then
                        best, bestDist = {model = model, humanoid = humanoid, part = part, distance = d}, d
                    end
                end
            end
        end
    end
    return best
end

-- สำรอง: ไม่เจอชื่อ ก็สแกนหา Humanoid ทุกตัวที่อยู่ใกล้ตัวเรา (ไม่ไกลมาก) ให้เลือกเอง
local function scanNearby(root, radius)
    local character = player.Character
    local rows = {}
    for humanoid in pairs(tracked) do
        local model = humanoid.Parent
        if model and model:IsA("Model") and humanoid.Health > 0
            and humanoid:IsDescendantOf(workspace) and model ~= character then
            local part = getPart(model)
            if part then
                local d = (root.Position - part.Position).Magnitude
                if d <= radius then
                    table.insert(rows, {model = model, humanoid = humanoid, part = part, distance = d})
                end
            end
        end
    end
    table.sort(rows, function(a, b) return a.distance < b.distance end)
    return rows
end

local hs = {enabled = false, part = nil, humanoid = nil, name = "", offset = 6}

local function stopHeadstand(message)
    hs.enabled = false
    hs.part = nil
    hs.humanoid = nil
    headGoButton.Text = "ไปยืนบนหัว (ตามชื่อ)"
    headGoButton.BackgroundColor3 = colors.blue
    headStatus.Text = message or "หยุดยืนบนหัวแล้ว"
end

local function startHeadstand(entry, message)
    setAuto(false)
    if flight then stopFlight("ปิดบินเพื่อไปยืนบนหัว") end
    if stopDuck then stopDuck("หยุดเสกเป็ดเพื่อไปยืนบนหัว") end
    hs.offset = math.clamp(tonumber(headHeight.Text) or 6, 1, 150)
    headHeight.Text = tostring(hs.offset)
    hs.part = entry.part
    hs.humanoid = entry.humanoid
    hs.name = entry.model.Name
    hs.enabled = true
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root then
        root.CFrame = CFrame.new(entry.part.Position + Vector3.new(0, hs.offset, 0)) * root.CFrame.Rotation
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    headGoButton.Text = "กำลังยืนบนหัว: " .. hs.name .. " (กดหาใหม่เพื่อเปลี่ยน)"
    headGoButton.BackgroundColor3 = colors.green
    headStatus.Text = message or ("กำลังยืนบนหัว: " .. hs.name .. " • เดินตามตัวนี้ต่อเนื่องอัตโนมัติ")
end

-- ล็อกให้ตัวละครลอยอยู่เหนือหัวเป้าหมายทุกเฟรม ตามเป้าหมายที่เคลื่อนที่ (เหมือนระบบเกาะเหนือหัวบอสของ Raid)
table.insert(flightConnections, RunService.Heartbeat:Connect(function()
    if not running or not hs.enabled or not hs.part then return end
    if not hs.part.Parent or not (hs.humanoid and hs.humanoid.Parent and hs.humanoid.Health > 0) then
        stopHeadstand("เป้าหมายหายไปหรือตายแล้ว หยุดระบบยืนบนหัว")
        return
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 or humanoid.SeatPart then return end
    local target = hs.part.Position + Vector3.new(0, hs.offset, 0)
    root.CFrame = CFrame.new(target) * root.CFrame.Rotation
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    if flight and flight.root == root then flight.cf = root.CFrame end
end))

local function refreshScan()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then headStatus.Text = "รอตัวละครเกิดก่อนครับ"; return end
    for _, child in ipairs(headList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    local radius = math.clamp(tonumber(headRadius.Text) or 60, 10, 400)
    headRadius.Text = tostring(radius)
    local rows = scanNearby(root, radius)
    if #rows == 0 then
        headStatus.Text = string.format("ไม่เจอใครในระยะ %d studs เลยครับ ลองเข้าใกล้เป้าหมายแล้วสแกนใหม่", radius)
        return
    end
    for i, row in ipairs(rows) do
        if i > 20 then break end
        local rowButton = create("TextButton", {
            LayoutOrder = i, Size = UDim2.new(1, 0, 0, 24),
            BackgroundColor3 = colors.tab, BorderSizePixel = 0,
            TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.Gotham, TextSize = 12,
            Text = string.format("  %s (%s) — %.0f studs", row.model.Name, row.humanoid.DisplayName, row.distance),
            TextXAlignment = Enum.TextXAlignment.Left,
        }, headList)
        create("UICorner", {CornerRadius = UDim.new(0, 5)}, rowButton)
        rowButton.Activated:Connect(function()
            startHeadstand(row, "เลือกจากรายการสแกน: กำลังวาร์ปไปยืนบนหัว " .. row.model.Name)
        end)
    end
    headStatus.Text = string.format("เจอ %d เป้าหมายในระยะ %d studs — กดเลือกจากรายการเพื่อไปยืนบนหัว", #rows, radius)
end

headGoButton.Activated:Connect(function()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then headStatus.Text = "รอตัวละครเกิดก่อนครับ"; return end
    if raid.running or dungeon.running then
        headStatus.Text = "ปิด Raid/Dungeon AUTO ก่อนใช้ระบบนี้ครับ (ชนกันได้)"
        return
    end
    if normalizeDuck(headName.Text) == "" then
        headStatus.Text = "พิมพ์ชื่อก่อนครับ"
        return
    end
    local entry = findByName(root, headName.Text)
    if entry then
        startHeadstand(entry, string.format("เจอ %s (%s) ตามชื่อ กำลังวาร์ปไปยืนบนหัว...", entry.model.Name, entry.humanoid.DisplayName))
    else
        headStatus.Text = "ไม่เจอชื่อนี้ครับ กำลังสลับไปสแกนรอบตัวแทน..."
        refreshScan()
    end
end)
headStopButton.Activated:Connect(function() stopHeadstand("หยุดยืนบนหัวแล้ว") end)
headScanButton.Activated:Connect(refreshScan)
headHeight.FocusLost:Connect(function()
    headHeight.Text = tostring(math.clamp(tonumber(headHeight.Text) or 6, 1, 150))
end)
headRadius.FocusLost:Connect(function()
    headRadius.Text = tostring(math.clamp(tonumber(headRadius.Text) or 60, 10, 400))
end)
headTab.Activated:Connect(function() showPage("headstand") end)
end)()



local function autoStep(entries)
    if not auto then return end

    -- Removal from the client Workspace also counts as a departed target.
    -- เป้าหมายที่ล็อกไว้จะไม่เปลี่ยน จนกว่าจะตายหรือหายไปจาก Workspace
    if locked and not isAlive(locked) then
        locked = nil
        visitedCharacter = nil
        nextWarpAt = os.clock() + 1
        status.Text = "เป้าหมายตายหรือหายไป รอไปตัวถัดไป..."
    end
    if os.clock() < nextWarpAt then return end

    if not locked then
        locked = entries[1]
        visitedCharacter = nil
    end
    if not locked then
        status.Text = "AUTO: รอเป้าหมายเกิด..."
        return
    end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        visitedCharacter = nil
        status.Text = "AUTO: รอคุณเกิดใหม่..."
        return
    end

    -- Warp once per target, or return to it after the player respawns.
    -- (สำหรับเป้าหมายที่เคลื่อนที่ การวาร์ปตามต่อเนื่องทำโดย Heartbeat ด้านล่าง)
    if visitedCharacter ~= character then
        local success, message, warpedCharacter = warp(locked)
        if success then
            visitedCharacter = warpedCharacter
        else
            status.Text = message
            nextWarpAt = os.clock() + 1
            return
        end
    end

    local marker = markers[locked.model]
    status.Text = string.format(
        "AUTO: %s %s%s | HP: %.0f",
        targets[selected].follow and "ตามติด" or "รอจัดการ",
        targets[selected].label,
        marker and (" #" .. marker.id) or "",
        locked.humanoid.Health
    )
end

-- ระบบตามต่อเนื่อง: เป้าหมายที่เคลื่อนที่ (เช่น Devil Boat) จะถูกวาร์ปตามทุกเฟรม
-- เมื่อห่างเกิน FOLLOW_DISTANCE และล็อกเป้าเดิมไว้จนกว่าจะตาย/หายไป จึงค่อยเปลี่ยนไปตัวใหม่
table.insert(flightConnections, RunService.Heartbeat:Connect(function()
    if not running or not auto or not locked then return end
    if not targets[selected].follow then return end
    if flight or duck.enabled then return end
    if os.clock() < nextWarpAt then return end

    local character = player.Character
    -- ต้องให้ autoStep วาร์ปครั้งแรกเสร็จก่อน (และวาร์ปใหม่หลังเกิดใหม่)
    if not character or visitedCharacter ~= character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health <= 0 or humanoid.SeatPart then return end
    if not isAlive(locked) then return end

    local part = getPart(locked.model)
    if not part then return end
    if (root.Position - part.Position).Magnitude <= FOLLOW_DISTANCE then return end

    pcall(warp, locked)
end))

local function update()
    local entries, total, root = collectTargets()
    local visible = {}
    local name = targets[selected].label
    pageTitle.Text = name
    title.Text = name .. ": " .. total .. (auto and " [AUTO]" or "") .. (flight and " [FLY]" or "") .. (duck.enabled and " [DUCK]" or "")
    teleport.Text = "วาร์ปไป " .. name .. " ใกล้ที่สุด"

    for i, tab in ipairs(tabs) do
        tab.BackgroundColor3 = currentPage == "target" and i == selected
            and colors.active or colors.sidebar
    end

    local lines = {
        name .. " alive: " .. total,
        "Located: " .. #entries,
        "Client-loaded only", "",
    }

    for i, entry in ipairs(entries) do
        local model = entry.model
        visible[model] = true
        if not markers[model] then markers[model] = makeMarker(entry.part) end

        local marker = markers[model]
        marker.gui.Adornee = entry.part
        local distance = root and tostring(math.floor(entry.distance)) or "?"
        local current = locked and locked.model == model
        local nearest = i == 1 and root ~= nil

        marker.label.TextColor3 = current
            and Color3.fromRGB(255, 150, 60)
            or (nearest and Color3.fromRGB(255, 230, 70)
            or Color3.fromRGB(100, 255, 160))

        marker.label.Text = string.format(
            "%s #%d%s\n%s studs",
            name, marker.id,
            current and " [TARGET]" or (nearest and " [NEAREST]" or ""),
            distance
        )

        if i <= 5 then
            table.insert(lines, string.format(
                "#%d : %s studs%s", marker.id, distance,
                current and " < TARGET" or (nearest and " < closest" or "")
            ))
        end
    end

    for model, marker in pairs(markers) do
        if not visible[model] then
            marker.gui:Destroy()
            markers[model] = nil
        end
    end

    if total == 0 then table.insert(lines, "No loaded living targets.") end
    output.Text = table.concat(lines, "\n")
    autoStep(entries)
    if duck.enabled then
        local ok, err = pcall(duckStep)
        if not ok then
            stopDuck("หยุดระบบเสกเป็ดเพราะเกิด Error ดู Console")
            warn("Duck Auto:", err)
        end
    end
end

for i, tab in ipairs(tabs) do
    local index = i
    tab.Activated:Connect(function()
        if selected ~= index then
            setAuto(false)
            selected = index
            clearMarkers()
            status.Text = "เปลี่ยนประเภทแล้ว AUTO ปิดอยู่"
        end
        showPage("target")
    end)
end

autoButton.Activated:Connect(function()
    setAuto(not auto)
    status.Text = auto and "AUTO: กำลังเลือกตัวใกล้ที่สุด..."
        or "หยุด AUTO แล้ว"
end)

teleport.Activated:Connect(function()
    if auto then
        status.Text = "ปิด AUTO ก่อนใช้ปุ่มวาร์ปเองครับ"
        return
    end
    if os.clock() < nextWarpAt then return end
    nextWarpAt = os.clock() + 0.7
    if flight then stopFlight("ปิดบินเพื่อวาร์ป") end
    if stopDuck then stopDuck("หยุดเสกเป็ดเพื่อวาร์ปเอง") end

    local ok, err = pcall(function()
        local entries = collectTargets()
        if not entries[1] then
            status.Text = "ไม่พบเป้าหมายที่มีชีวิตและมีตำแหน่ง"
            return
        end
        local _, message = warp(entries[1])
        status.Text = message
    end)

    if not ok then
        status.Text = "วาร์ปไม่สำเร็จ ดู Error ใน Console"
        warn(err)
    end
end)

task.spawn(function()
    while running and gui.Parent do
        local ok, err = pcall(update)
        if not ok then
            setAuto(false)
            if stopDuck then stopDuck("หยุดเพราะตัวสแกนเกิด Error ดู Console") end
            status.Text = "เกิด Error จึงหยุด AUTO ดู Console"
            warn("Target Locator:", err)
        end
        task.wait(0.5)
    end
end)
