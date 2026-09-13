-- Flip Coin Runner
-- Client-side test menu for an experience you own.
-- Preferred path: ReplicatedStorage.FlipCoinSystem.FlipRequest.
-- Fallback: activates an existing visible GUI button containing "FLIP" (not "AUTO").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
assert(player, "Run this script on the Client")
local playerGui = player:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("FlipCoinRunner")
if old then old:Destroy() end

local function make(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local colors = {
    background = Color3.fromRGB(24, 25, 31),
    muted = Color3.fromRGB(165, 170, 185),
    blue = Color3.fromRGB(52, 112, 220),
    green = Color3.fromRGB(38, 145, 92),
    red = Color3.fromRGB(145, 48, 60),
    button = Color3.fromRGB(55, 60, 78),
    yellow = Color3.fromRGB(255, 220, 110),
}

local gui = make("ScreenGui", {
    Name = "FlipCoinRunner",
    ResetOnSpawn = false,
    DisplayOrder = 50,
}, playerGui)

local panel = make("Frame", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -18, 0, 115),
    Size = UDim2.fromOffset(330, 310),
    BackgroundColor3 = colors.background,
    BorderSizePixel = 0,
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 12)}, panel)
make("UIStroke", {
    Color = Color3.fromRGB(70, 74, 92),
    Thickness = 1,
}, panel)

local header = make("TextLabel", {
    Position = UDim2.fromOffset(14, 0),
    Size = UDim2.new(1, -100, 0, 43),
    BackgroundTransparency = 1,
    Text = "FLIP COIN TEST",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

local collapse = make("TextButton", {
    Position = UDim2.new(1, -76, 0, 7),
    Size = UDim2.fromOffset(30, 30),
    Text = "−",
    TextSize = 21,
    TextColor3 = Color3.new(1, 1, 1),
    BackgroundColor3 = colors.button,
    BorderSizePixel = 0,
}, panel)

local close = make("TextButton", {
    Position = UDim2.new(1, -39, 0, 7),
    Size = UDim2.fromOffset(30, 30),
    Text = "X",
    TextColor3 = Color3.new(1, 1, 1),
    BackgroundColor3 = colors.red,
    BorderSizePixel = 0,
}, panel)

local content = make("Frame", {
    Position = UDim2.fromOffset(14, 48),
    Size = UDim2.new(1, -28, 0, 248),
    BackgroundTransparency = 1,
}, panel)

local resultLabel = make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 32),
    BackgroundTransparency = 1,
    Text = "พร้อมทดสอบ",
    TextColor3 = colors.muted,
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    TextXAlignment = Enum.TextXAlignment.Left,
}, content)

local targetLabel = make("TextLabel", {
    Position = UDim2.fromOffset(0, 35),
    Size = UDim2.new(1, 0, 0, 42),
    BackgroundTransparency = 1,
    Text = "ยังไม่พบช่องทาง Flip",
    TextColor3 = colors.muted,
    Font = Enum.Font.Code,
    TextSize = 13,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
}, content)

local flipButton = make("TextButton", {
    Position = UDim2.fromOffset(0, 82),
    Size = UDim2.new(1, 0, 0, 40),
    BackgroundColor3 = colors.blue,
    Text = "FLIP ONCE",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    BorderSizePixel = 0,
}, content)

local autoButton = make("TextButton", {
    Position = UDim2.fromOffset(0, 130),
    Size = UDim2.new(1, 0, 0, 40),
    BackgroundColor3 = colors.button,
    Text = "AUTO FLIP: OFF",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    BorderSizePixel = 0,
}, content)

local speedLabel = make("TextLabel", {
    Position = UDim2.fromOffset(0, 178),
    Size = UDim2.new(1, -92, 0, 30),
    BackgroundTransparency = 1,
    Text = "Interval: 0.25 s",
    TextColor3 = colors.yellow,
    Font = Enum.Font.Gotham,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
}, content)

local slower = make("TextButton", {
    Position = UDim2.new(1, -88, 0, 176),
    Size = UDim2.fromOffset(38, 34),
    BackgroundColor3 = colors.button,
    Text = "−",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 20,
    BorderSizePixel = 0,
}, content)

local faster = make("TextButton", {
    Position = UDim2.new(1, -44, 0, 176),
    Size = UDim2.fromOffset(38, 34),
    BackgroundColor3 = colors.button,
    Text = "+",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 20,
    BorderSizePixel = 0,
}, content)

local status = make("TextLabel", {
    Position = UDim2.fromOffset(0, 218),
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundTransparency = 1,
    Text = "กด Refresh เพื่อค้นหาช่องทาง",
    TextColor3 = colors.muted,
    Font = Enum.Font.Gotham,
    TextSize = 13,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
}, content)

local refresh = make("TextButton", {
    Position = UDim2.new(1, -78, 1, -31),
    Size = UDim2.fromOffset(78, 26),
    BackgroundColor3 = colors.button,
    Text = "Refresh",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 12,
    BorderSizePixel = 0,
}, panel)

local collapsed = false
local running = true
local auto = false
local interval = 0.25
local intervalOptions = {0.25, 0.50, 0.75, 1.00, 1.50, 2.00, 3.00}
local remote
local manualGuiButton
local nativeAutoButton
local sourceDescription = "none"
local autoToken = 0

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function visibleText(guiObject)
    if guiObject:IsA("TextButton") or guiObject:IsA("TextLabel") then
        return tostring(guiObject.Text or "")
    end

    for _, child in ipairs(guiObject:GetDescendants()) do
        if child:IsA("TextLabel") or child:IsA("TextButton") then
            local text = tostring(child.Text or "")
            if text ~= "" then
                return text
            end
        end
    end

    return ""
end

local function findButtons()
    local preferred, fallback, native = nil, nil, nil

    for _, object in ipairs(playerGui:GetDescendants()) do
        if object:IsA("GuiButton") and object.Visible then
            local text = lower(visibleText(object))
            local isFlip = text:find("flip", 1, true) ~= nil
            local isAuto = text:find("auto", 1, true) ~= nil

            if isFlip and isAuto and not native then
                native = object
            elseif isFlip and not isAuto then
                if text:find("flip coin", 1, true) then
                    preferred = preferred or object
                end
                fallback = fallback or object
            end
        end
    end

    return preferred or fallback, native
end

local function findSystemRemote()
    local folder = ReplicatedStorage:FindFirstChild("FlipCoinSystem")
    local request = folder and folder:FindFirstChild("FlipRequest")
    if request and request:IsA("RemoteEvent") then
        return request
    end
    return nil
end

local function refreshTargets()
    remote = findSystemRemote()
    manualGuiButton, nativeAutoButton = findButtons()

    if remote then
        sourceDescription = "RemoteEvent FlipCoinSystem.FlipRequest"
        targetLabel.Text = "Source: FlipCoinSystem.FlipRequest\nServer mode พร้อมใช้งาน"
    elseif manualGuiButton then
        sourceDescription = "GUI: " .. manualGuiButton:GetFullName()
        targetLabel.Text = "Source: ปุ่ม FLIP ในหน้าจอ\n" .. manualGuiButton:GetFullName()
    elseif nativeAutoButton then
        sourceDescription = "GUI AUTO: " .. nativeAutoButton:GetFullName()
        targetLabel.Text = "พบปุ่ม AUTO FLIP แต่ไม่พบปุ่ม FLIP ครั้งเดียว\nความเร็วจะขึ้นกับระบบของแมพ"
    else
        sourceDescription = "none"
        targetLabel.Text = "ไม่พบ RemoteEvent หรือปุ่ม FLIP\nตรวจว่าหน้าเกมโหลดเสร็จแล้ว"
    end

    status.Text = "ตรวจแล้ว: " .. sourceDescription
end

local function setAutoVisual(value)
    auto = value
    autoButton.Text = auto and "AUTO FLIP: ON — กดเพื่อหยุด"
        or "AUTO FLIP: OFF — กดเพื่อเริ่ม"
    autoButton.BackgroundColor3 = auto and colors.green or colors.button
end

local function setInterval(value)
    local best = intervalOptions[1]
    local bestDistance = math.huge
    for _, option in ipairs(intervalOptions) do
        local distance = math.abs(option - value)
        if distance < bestDistance then
            best = option
            bestDistance = distance
        end
    end

    interval = best
    speedLabel.Text = string.format("Interval: %.2f s", interval)

    if remote then
        remote:FireServer("SetInterval", interval)
    end
end

local function flipOnce()
    if remote then
        remote:FireServer("Flip")
        status.Text = "ส่งคำขอ Flip ไปที่ Server"
        return true
    end

    if manualGuiButton and manualGuiButton.Parent then
        manualGuiButton:Activate()
        status.Text = "กดปุ่ม FLIP ของแมพแล้ว"
        return true
    end

    status.Text = "ไม่พบช่องทาง FLIP กด Refresh ใหม่"
    return false
end

local function stopAuto()
    autoToken += 1
    if remote then
        remote:FireServer("SetAuto", false)
    elseif nativeAutoButton and nativeAutoButton.Parent then
        -- Only click native AUTO when this runner explicitly started it.
        if sourceDescription:find("native-auto-on", 1, true) then
            nativeAutoButton:Activate()
        end
    end
    setAutoVisual(false)
end

local function startAuto()
    if not remote and not manualGuiButton and not nativeAutoButton then
        status.Text = "ไม่พบช่องทาง FLIP กด Refresh ใหม่"
        return
    end

    autoToken += 1
    local token = autoToken

    if remote then
        remote:FireServer("SetInterval", interval)
        remote:FireServer("SetAuto", true)
        setAutoVisual(true)
        status.Text = "AUTO FLIP ทำงานผ่าน Server"
        return
    end

    if manualGuiButton then
        setAutoVisual(true)
        status.Text = "AUTO FLIP กำลังกดปุ่ม FLIP ทุก " .. interval .. " วินาที"
        task.spawn(function()
            while running and auto and autoToken == token do
                flipOnce()
                task.wait(interval)
            end
        end)
        return
    end

    -- A map with only a native Auto button cannot be sped up safely.
    nativeAutoButton:Activate()
    sourceDescription = sourceDescription .. " native-auto-on"
    setAutoVisual(true)
    status.Text = "เปิด AUTO ของแมพแล้ว ความเร็วถูกควบคุมโดยแมพ"
end

collapse.Activated:Connect(function()
    collapsed = not collapsed
    content.Visible = not collapsed
    refresh.Visible = not collapsed
    panel.Size = collapsed
        and UDim2.fromOffset(330, 43)
        or UDim2.fromOffset(330, 310)
    collapse.Text = collapsed and "+" or "−"
end)

close.Activated:Connect(function()
    stopAuto()
    running = false
    gui:Destroy()
end)

flipButton.Activated:Connect(function()
    flipOnce()
end)

autoButton.Activated:Connect(function()
    if auto then
        stopAuto()
    else
        startAuto()
    end
end)

slower.Activated:Connect(function()
    local index = table.find(intervalOptions, interval) or 1
    setInterval(intervalOptions[math.max(1, index - 1)])
end)

faster.Activated:Connect(function()
    local index = table.find(intervalOptions, interval) or 1
    setInterval(intervalOptions[math.min(#intervalOptions, index + 1)])
end)

refresh.Activated:Connect(function()
    refreshTargets()
end)

local resultConnection = nil
local function connectResult()
    if resultConnection then resultConnection:Disconnect() end
    if not remote then return end

    local folder = ReplicatedStorage:FindFirstChild("FlipCoinSystem")
    local result = folder and folder:FindFirstChild("FlipResult")
    if not result or not result:IsA("RemoteEvent") then return end

    resultConnection = result.OnClientEvent:Connect(function(data)
        if data.interval then
            interval = data.interval
            speedLabel.Text = string.format("Interval: %.2f s", interval)
        end
        if data.auto ~= nil then
            setAutoVisual(data.auto)
        end
        if data.ok and data.side then
            resultLabel.Text = string.format(
                "%s   +%d",
                data.side,
                data.reward or 0
            )
            resultLabel.TextColor3 = data.side == "HEADS"
                and Color3.fromRGB(110, 220, 255)
                or Color3.fromRGB(255, 210, 100)
            if data.balance ~= nil then
                balanceLabel.Text = "Coins: " .. tostring(data.balance)
            end
            status.Text = "พลิกสำเร็จ"
        elseif not data.ok and data.reason == "Cooldown" then
            status.Text = string.format(
                "รอคูลดาวน์ %.2f วินาที",
                data.remaining or 0
            )
        end
    end)
end

refreshTargets()
connectResult()

task.spawn(function()
    while running and gui.Parent do
        if (not remote and not manualGuiButton and not nativeAutoButton)
            or (manualGuiButton and not manualGuiButton.Parent)
        then
            refreshTargets()
        end
        task.wait(2)
    end
end)
