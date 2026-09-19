-- Autokey v2.9 (Raid AUTO loop): sidebar, flight (position-locked), targets, continuous follow (Devil Boat), Duck Boss summon loop, and Raid opener (E -> Open -> warp into portal ring)
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
local collapsed = false
local auto = false
local locked = nil
local visitedCharacter = nil
local nextWarpAt = 0
local tracked = {}
local markers = {}
local nextId = 0

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
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
    cursor = 0, nextAt = 0, lastCastAt = -math.huge, held = {}, interval = 3, quiet = 6}
local skillInput = nil
local skillInputMode = nil
skills.castTracks = {}
local raid = {prompt = nil, promptPose = nil, ringPose = nil, running = false, token = 0,
    fighting = false, combatReady = false, auto = false, rounds = 0, held = nil, stop = nil}

local colors = {
    window = Color3.fromRGB(24, 25, 30),
    sidebar = Color3.fromRGB(31, 32, 42),
    muted = Color3.fromRGB(160, 166, 182),
    active = Color3.fromRGB(51, 58, 78),
    blue = Color3.fromRGB(53, 113, 220),
    green = Color3.fromRGB(38, 140, 93),
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

local content = create("Frame", {
    Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 396),
    BackgroundTransparency = 1,
}, panel)

local sidebar = create("Frame", {
    Size = UDim2.fromOffset(165, 396),
    BackgroundColor3 = colors.sidebar, BorderSizePixel = 0,
}, content)
create("TextLabel", {
    Position = UDim2.fromOffset(16, 14), Size = UDim2.fromOffset(130, 25),
    BackgroundTransparency = 1, Text = "MENU", TextColor3 = colors.muted,
    Font = Enum.Font.GothamBold, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
}, sidebar)

local tabs = {}
for i, target in ipairs(targets) do
    tabs[i] = create("TextButton", {
        Position = UDim2.fromOffset(10, 50 + (i - 1) * 46),
        Size = UDim2.fromOffset(145, 38), Text = target.label,
        TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.Gotham,
        TextSize = 15, BackgroundColor3 = colors.sidebar, BorderSizePixel = 0,
    }, sidebar)
    create("UICorner", {CornerRadius = UDim.new(0, 7)}, tabs[i])
end
local flightTab = create("TextButton", {
    Position = UDim2.fromOffset(10, 142), Size = UDim2.fromOffset(145, 38),
    Text = "Flight / บิน", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.Gotham, TextSize = 15,
    BackgroundColor3 = colors.sidebar, BorderSizePixel = 0,
}, sidebar)
create("UICorner", {CornerRadius = UDim.new(0, 7)}, flightTab)

create("TextLabel", {
    Position = UDim2.fromOffset(15, 330), Size = UDim2.fromOffset(137, 60),
    BackgroundTransparency = 1, Text = "AUTOKEY\nv2.9 · Client\n− ยุบ   /   X ปิดระบบ",
    TextColor3 = colors.muted, Font = Enum.Font.Gotham,
    TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
}, sidebar)

local duckTab = create("TextButton", {
    Position = UDim2.fromOffset(10, 188), Size = UDim2.fromOffset(145, 38),
    Text = "Duck Boss / เป็ด", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.Gotham, TextSize = 15,
    BackgroundColor3 = colors.sidebar, BorderSizePixel = 0,
}, sidebar)
create("UICorner", {CornerRadius = UDim.new(0, 7)}, duckTab)

local skillsTab = create("TextButton", {
    Position = UDim2.fromOffset(10, 234), Size = UDim2.fromOffset(145, 38),
    Text = "Skills / สกิล", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.Gotham, TextSize = 15,
    BackgroundColor3 = colors.sidebar, BorderSizePixel = 0,
}, sidebar)
create("UICorner", {CornerRadius = UDim.new(0, 7)}, skillsTab)

local raidTab = create("TextButton", {
    Position = UDim2.fromOffset(10, 280), Size = UDim2.fromOffset(145, 38),
    Text = "Raid / เสกบอส", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.Gotham, TextSize = 15,
    BackgroundColor3 = colors.sidebar, BorderSizePixel = 0,
}, sidebar)
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
local skillStatus = create("TextLabel", {
    Position = UDim2.fromOffset(0, 298), Size = UDim2.new(1, 0, 0, 70),
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
    Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 46),
    BackgroundTransparency = 1, TextColor3 = colors.muted,
    TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    Text = "ตั้งค่าครั้งแรก: (1) ยืนข้างปุ่ม E Open Raid แล้วกดบันทึก (2) เปิด Raid ด้วยตัวเองให้วงวาร์ปขึ้น ยืนกลางวงแล้วกดบันทึก",
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
    Position = UDim2.fromOffset(0, 158), Size = UDim2.fromOffset(117, 28),
    BackgroundTransparency = 1, TextColor3 = colors.muted,
    TextSize = 13, Text = "ชื่อบอส Raid:",
    TextXAlignment = Enum.TextXAlignment.Left,
}, raidPage)
local raidBossName = create("TextBox", {
    Position = UDim2.fromOffset(118, 158), Size = UDim2.new(1, -118, 0, 28),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), TextSize = 14,
    Text = "Bacon of Grudge", ClearTextOnFocus = false,
}, raidPage)
create("TextLabel", {
    Position = UDim2.fromOffset(0, 192), Size = UDim2.fromOffset(280, 28),
    BackgroundTransparency = 1, TextColor3 = colors.muted,
    TextSize = 13, Text = "จำนวนรอบสูงสุด (0 = จนกว่าของหมด)",
    TextXAlignment = Enum.TextXAlignment.Left,
}, raidPage)
local raidMax = create("TextBox", {
    Position = UDim2.new(1, -97, 0, 192), Size = UDim2.fromOffset(97, 28),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), TextSize = 14,
    Text = "0", ClearTextOnFocus = false,
}, raidPage)
local raidButton = create("TextButton", {
    Position = UDim2.fromOffset(0, 226), Size = UDim2.new(1, 0, 0, 34),
    BackgroundColor3 = colors.active, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 14, Text = "เปิด + วาร์ปเข้าวง (1 ครั้ง ไม่สู้)",
}, raidPage)
local raidAutoButton = create("TextButton", {
    Position = UDim2.fromOffset(0, 266), Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = colors.blue, BorderSizePixel = 0,
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
    TextSize = 15, Text = "RAID AUTO: OFF — กดเพื่อวนต่อเนื่อง",
}, raidPage)
local raidStatus = create("TextLabel", {
    Position = UDim2.fromOffset(0, 310), Size = UDim2.new(1, 0, 0, 62),
    BackgroundTransparency = 1, TextColor3 = colors.muted,
    TextSize = 13, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    Text = "ยังไม่ได้บันทึกจุด\nAUTO: เปิด Raid → วาร์ปเข้าวง → สู้บอส → ปิดหน้า Victory → วนใหม่ • หยุดเมื่อบอสไม่เกิด (Portal Gun หมด)",
}, raidPage)

local function showPage(page)
    currentPage = page
    raidPage.Visible = page == "raid"
    raidTab.BackgroundColor3 = page == "raid" and colors.active or colors.sidebar
    targetPage.Visible = page == "target"
    flightPage.Visible = page == "flight"
    duckPage.Visible = page == "duck"
    skillsPage.Visible = page == "skills"
    skillsTab.BackgroundColor3 = page == "skills" and colors.active or colors.sidebar
    duckTab.BackgroundColor3 = page == "duck" and colors.active or colors.sidebar
    flightTab.BackgroundColor3 = page == "flight" and colors.active or colors.sidebar
    for i, tab in ipairs(tabs) do
        tab.BackgroundColor3 = page == "target" and i == selected
            and colors.active or colors.sidebar
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

minimize.Activated:Connect(function()
    collapsed = not collapsed
    content.Visible = not collapsed
    panel.Size = collapsed and UDim2.fromOffset(330, 44) or UDim2.fromOffset(600, 440)
    minimize.Text = collapsed and "+" or "−"
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

local function useDuckSkill(character, root, boss)
    if not skills.enabled then return end
    if UserInputService:GetFocusedTextBox() then
        skillStatus.Text = "พักสกิลระหว่างพิมพ์ข้อความ"
        return
    end
    local inDuck = duck.enabled and duck.phase == "FIGHT" and duck.combatReady and not duck.deathSeen
    local inRaid = raid.fighting and raid.combatReady
    if not (inDuck or inRaid) or boss.humanoid.Health <= 0 then return end
    if os.clock() < skills.nextAt or next(skills.held) then return end
    if root.Anchored or actionAnimationPlaying(character) then
        skillStatus.Text = "รอสกิลก่อนหน้าจบ..."
        return
    end
    local key
    for _ = 1, #skillOrder do
        skills.cursor = skills.cursor % #skillOrder + 1
        local candidate = skillOrder[skills.cursor]
        if skills.selected[candidate] then key = candidate break end
    end
    if not key then skillStatus.Text = "ยังไม่ได้เลือกปุ่มสกิล" return end

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
    skillStatus.Text = "ส่งสกิล " .. key .. " แล้ว • รอสกิลก่อนหน้าจบ"
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

-- ปิดหน้าต่าง Raid Boss หลังกด Open: กดปุ่ม X ของหน้าต่างนั้น ถ้าไม่พบจะซ่อนกรอบหน้าต่างแทน
local function closeRaidWindow(label, press)
    if not label or not label.Parent then return true end
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
    -- สำรอง: ซ่อนกรอบหน้าต่าง (ขนาดพอดีหน้าต่าง ไม่ใช่ทั้งจอ)
    local frame = label.Parent
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    while frame and frame ~= playerGui and not frame:IsA("ScreenGui") do
        if frame:IsA("GuiObject") and frame.AbsoluteSize.X >= 300 and frame.AbsoluteSize.Y >= 200
            and frame.AbsoluteSize.X < viewport.X * 0.8 and frame.AbsoluteSize.Y < viewport.Y * 0.9 then
            frame.Visible = false
            return true
        end
        frame = frame.Parent
    end
    return false
end

local function pressGuiButton(btn)
    local fired = false
    if typeof(getconnections) == "function" then
        for _, signal in ipairs({btn.Activated, btn.MouseButton1Click}) do
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
    endRaidHold()
    if releaseSkillKeys then releaseSkillKeys() end
    raidButton.Text = "เปิด + วาร์ปเข้าวง (1 ครั้ง ไม่สู้)"
    raidButton.BackgroundColor3 = colors.active
    raidAutoButton.Text = "RAID AUTO: OFF — กดเพื่อวนต่อเนื่อง"
    raidAutoButton.BackgroundColor3 = colors.blue
    if message then raidStatus.Text = message end
end
raid.stop = raidStop

local function raidSay(text) raidStatus.Text = text end

-- หาบอส Raid ตามชื่อ (ตรงบางส่วนก็ได้ เช่น "bacon of grudge")
local function findRaidBoss(root)
    local wanted = normalizeDuck(raidBossName.Text)
    if wanted == "" then return nil end
    local best, nearest = nil, math.huge
    for humanoid in pairs(tracked) do
        local model = humanoid.Parent
        if model and model:IsA("Model") and humanoid.Health > 0
            and humanoid:IsDescendantOf(workspace) and not isPlayer(model) then
            local modelName = normalizeDuck(model.Name)
            local displayName = normalizeDuck(humanoid.DisplayName)
            if modelName:find(wanted, 1, true) or displayName:find(wanted, 1, true) then
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
    end
    return best
end

local function findVictoryLabel()
    for _, label in ipairs(playerGui:GetDescendants()) do
        if label:IsA("TextLabel") and not label:IsDescendantOf(gui)
            and normalizeDuck(label.Text) == "victory" and guiVisible(label) then
            return label
        end
    end
    return nil
end

-- หนึ่งรอบ: เปิด Raid -> เข้าวง -> (ถ้า fight) สู้บอส -> ปิดหน้า Victory
-- คืนค่า "done" | "cancel" | "fail", ข้อความ
local function raidRound(alive, pause, fight)
    local function ready()
        if flight or duck.enabled or auto then return false end
        return true
    end

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
    if not ready() then return "fail", "หยุด Raid เพราะเปิดระบบอื่นอยู่" end

    -- 1) วาร์ปไปจุดกด E แล้วหาปุ่ม (ปุ่มอาจถูกสร้างใหม่หลังจบรอบ)
    raidSay("วาร์ปไปจุด Open Raid...")
    raidMoveTo(character, root, raid.promptPose)
    if not pause(0.8) then return "cancel" end
    local prompt
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
    local button, windowLabel
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
    while alive() and os.clock() < spawnDeadline do
        character, root = duckCharacter()
        if character then
            boss = findRaidBoss(root)
            if boss then break end
        end
        raidSay(string.format("รอบอสเกิด... เหลือ %.0f วินาที", math.max(0, spawnDeadline - os.clock())))
        task.wait(0.4)
    end
    if not alive() then return "cancel" end
    if not boss then
        return "fail", "บอสไม่เกิดภายใน 35 วินาที\nอาจวาร์ปไม่สำเร็จหรือ Portal Gun หมด จึงปิด AUTO"
    end

    -- 6) สู้บอส: วาร์ปเข้าหา + ส่งสกิล (ใช้ปุ่ม/เวลาจากแท็บ Skills)
    raid.fighting = true
    raid.combatReady = false
    skills.nextAt = 0
    local fightDeadline = os.clock() + 1500
    local missingSince, stableSince, victory
    local lastWarp, nextVictory = 0, 0
    while alive() do
        if not ready() then
            raid.fighting = false
            releaseSkillKeys()
            return "fail", "หยุด Raid เพราะเปิดระบบอื่นอยู่"
        end
        local now = os.clock()
        if now > fightDeadline then
            raid.fighting = false
            releaseSkillKeys()
            return "fail", "สู้บอสเกิน 25 นาที หยุดระบบ Raid"
        end
        if now >= nextVictory then
            nextVictory = now + 1
            victory = findVictoryLabel()
            if victory then break end
        end
        character, root = duckCharacter()
        if not character then
            raid.combatReady = false
            stableSince = nil
            releaseSkillKeys()
            raidSay("รอตัวละครเกิดใหม่...")
            task.wait(0.5)
            continue
        end
        boss = findRaidBoss(root)
        if boss then
            missingSince = nil
            local distance = (root.Position - boss.part.Position).Magnitude
            if distance > 35 then
                raid.combatReady = false
                stableSince = nil
                releaseSkillKeys()
                if now >= lastWarp and not root.Anchored then
                    warp(boss)
                    lastWarp = now + 2.5
                    raidSay("วาร์ปเข้าหาบอส...")
                end
            elseif root.Anchored or root.AssemblyLinearVelocity.Magnitude > 25 then
                raid.combatReady = false
                stableSince = nil
                raidSay("พักสกิล: รอให้ตัวนิ่งใกล้บอส...")
            else
                if not raid.combatReady then
                    if actionAnimationPlaying(character) then
                        stableSince = nil
                    else
                        stableSince = stableSince or now
                        if now - stableSince >= 1 then raid.combatReady = true end
                    end
                end
                if raid.combatReady then
                    raidSay(string.format("สู้บอส: %s\nHP: %.0f • รอบที่ %d",
                        boss.model.Name, boss.humanoid.Health, raid.rounds + 1))
                    useDuckSkill(character, root, boss)
                end
            end
        else
            raid.combatReady = false
            releaseSkillKeys()
            missingSince = missingSince or now
            raidSay("บอสหายไป รอหน้า Victory...")
            if now - missingSince > 20 then break end
        end
        task.wait(0.25)
    end
    raid.fighting = false
    raid.combatReady = false
    releaseSkillKeys()
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
    if victory then
        raidSay("ชนะแล้ว! กำลังปิดหน้า Victory...")
        if not pause(0.8) then return "cancel" end
        for _ = 1, 4 do
            if not victory.Parent or not guiVisible(victory) then break end
            closeRaidWindow(victory, pressGuiButton)
            if not pause(0.5) then return "cancel" end
        end
    end
    return "done", victory and "จบรอบ: ชนะและปิดหน้า Victory แล้ว" or "จบรอบ (ไม่พบหน้า Victory)"
end

local function startRaid(autoMode)
    if raid.running then raidStop("หยุดระบบ Raid แล้ว") return end
    if auto or flight or duck.enabled then
        raidStatus.Text = "ปิด AUTO / Flight / Duck ก่อนใช้ระบบ Raid ครับ"
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

raidMax.FocusLost:Connect(function()
    raidMax.Text = tostring(math.max(0, math.floor(tonumber(raidMax.Text) or 0)))
end)
raidBossName.FocusLost:Connect(function()
    if raid.running then raidStop("แก้ชื่อบอสแล้ว กดเริ่มใหม่เพื่อใช้ชื่อใหม่") end
end)
raidButton.Activated:Connect(function() startRaid(false) end)
raidAutoButton.Activated:Connect(function() startRaid(true) end)
raidTab.Activated:Connect(function() showPage("raid") end)

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
