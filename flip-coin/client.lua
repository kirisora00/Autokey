-- Flip Coin test system (LocalScript in StarterPlayerScripts)
-- Right-side menu: manual flip, AUTO FLIP, speed control, collapse, and close.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local system = ReplicatedStorage:WaitForChild("FlipCoinSystem")
local flipRequest = system:WaitForChild("FlipRequest")
local flipResult = system:WaitForChild("FlipResult")

local old = playerGui:FindFirstChild("FlipCoinMenu")
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
    card = Color3.fromRGB(34, 36, 46),
    muted = Color3.fromRGB(165, 170, 185),
    blue = Color3.fromRGB(52, 112, 220),
    green = Color3.fromRGB(38, 145, 92),
    red = Color3.fromRGB(145, 48, 60),
    button = Color3.fromRGB(55, 60, 78),
}

local gui = make("ScreenGui", {
    Name = "FlipCoinMenu",
    ResetOnSpawn = false,
    DisplayOrder = 20,
}, playerGui)

local panel = make("Frame", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -18, 0, 115),
    Size = UDim2.fromOffset(330, 300),
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
    Text = "FLIP COIN",
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
    Size = UDim2.new(1, -28, 0, 238),
    BackgroundTransparency = 1,
}, panel)

local resultLabel = make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 35),
    BackgroundTransparency = 1,
    Text = "พร้อมพลิก",
    TextColor3 = colors.muted,
    Font = Enum.Font.GothamBold,
    TextSize = 19,
    TextXAlignment = Enum.TextXAlignment.Left,
}, content)

local balanceLabel = make("TextLabel", {
    Position = UDim2.fromOffset(0, 37),
    Size = UDim2.new(1, 0, 0, 24),
    BackgroundTransparency = 1,
    Text = "Coins: --",
    TextColor3 = Color3.fromRGB(255, 220, 110),
    Font = Enum.Font.Gotham,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
}, content)

local flipButton = make("TextButton", {
    Position = UDim2.fromOffset(0, 72),
    Size = UDim2.new(1, 0, 0, 42),
    BackgroundColor3 = colors.blue,
    Text = "FLIP COIN",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 17,
    BorderSizePixel = 0,
}, content)

local autoButton = make("TextButton", {
    Position = UDim2.fromOffset(0, 122),
    Size = UDim2.new(1, 0, 0, 42),
    BackgroundColor3 = colors.button,
    Text = "AUTO FLIP: OFF",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 17,
    BorderSizePixel = 0,
}, content)

local speedLabel = make("TextLabel", {
    Position = UDim2.fromOffset(0, 174),
    Size = UDim2.new(1, 0, 0, 28),
    BackgroundTransparency = 1,
    Text = "Auto interval: 0.25 s",
    TextColor3 = colors.muted,
    Font = Enum.Font.Gotham,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
}, content)

local slower = make("TextButton", {
    Position = UDim2.new(1, -90, 0, 170),
    Size = UDim2.fromOffset(40, 34),
    BackgroundColor3 = colors.button,
    Text = "−",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 21,
    BorderSizePixel = 0,
}, content)

local faster = make("TextButton", {
    Position = UDim2.new(1, -44, 0, 170),
    Size = UDim2.fromOffset(40, 34),
    BackgroundColor3 = colors.button,
    Text = "+",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 21,
    BorderSizePixel = 0,
}, content)

local status = make("TextLabel", {
    Position = UDim2.fromOffset(0, 211),
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundTransparency = 1,
    Text = "Server พร้อมทำงาน",
    TextColor3 = colors.muted,
    Font = Enum.Font.Gotham,
    TextSize = 13,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
}, content)

local collapsed = false
local auto = false
local interval = 0.25
local intervalOptions = {0.25, 0.50, 0.75, 1.00, 1.50, 2.00, 3.00}

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
    speedLabel.Text = string.format("Auto interval: %.2f s", interval)
    flipRequest:FireServer("SetInterval", interval)
end

collapse.Activated:Connect(function()
    collapsed = not collapsed
    content.Visible = not collapsed
    panel.Size = collapsed
        and UDim2.fromOffset(330, 43)
        or UDim2.fromOffset(330, 300)
    collapse.Text = collapsed and "+" or "−"
end)

close.Activated:Connect(function()
    flipRequest:FireServer("SetAuto", false)
    gui:Destroy()
end)

flipButton.Activated:Connect(function()
    flipRequest:FireServer("Flip")
end)

autoButton.Activated:Connect(function()
    flipRequest:FireServer("SetAuto", not auto)
end)

slower.Activated:Connect(function()
    local index = table.find(intervalOptions, interval) or 1
    setInterval(intervalOptions[math.max(1, index - 1)])
end)

faster.Activated:Connect(function()
    local index = table.find(intervalOptions, interval) or 1
    setInterval(intervalOptions[math.min(#intervalOptions, index + 1)])
end)

flipResult.OnClientEvent:Connect(function(data)
    if data.interval then
        interval = data.interval
        speedLabel.Text = string.format("Auto interval: %.2f s", interval)
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

setInterval(interval)
