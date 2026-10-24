-- Monter v1.00 — Fullbright: client-side daylight with no fog, shadows or dark tint (F8 or the button).
-- The game's own lighting is saved and put back when it is turned off or the window is closed.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
assert(player, "Run on Client")
local playerGui = player:WaitForChild("PlayerGui")

-- Re-running the script replaces the previous window and restores its lighting first.
local sessionEnv = _G
if type(getgenv) == "function" then
    local ok, value = pcall(getgenv)
    if ok and type(value) == "table" then sessionEnv = value end
end
if type(sessionEnv.MonterSession) == "table" and type(sessionEnv.MonterSession.cleanup) == "function" then
    pcall(sessionEnv.MonterSession.cleanup)
end
local old = playerGui:FindFirstChild("MonterWindow")
if old then old:Destroy() end

local function create(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props) do object[key] = value end
    object.Parent = parent
    return object
end

local color = {
    background = Color3.fromRGB(24, 25, 31),
    button = Color3.fromRGB(52, 57, 73),
    green = Color3.fromRGB(34, 140, 89),
    text = Color3.fromRGB(235, 238, 245),
    muted = Color3.fromRGB(160, 169, 184),
}
local gui = create("ScreenGui", {Name = "MonterWindow", ResetOnSpawn = false, DisplayOrder = 30}, playerGui)
local panel = create("Frame", {
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 110), Size = UDim2.fromOffset(240, 120),
    BackgroundColor3 = color.background, BorderSizePixel = 0, Active = true,
}, gui)
create("UICorner", {CornerRadius = UDim.new(0, 10)}, panel)
create("UIStroke", {Color = Color3.fromRGB(68, 73, 88), Thickness = 1}, panel)
local header = create("TextLabel", {
    Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -56, 0, 40), BackgroundTransparency = 1,
    Text = "MONTER v1.00", TextColor3 = color.text, TextSize = 16, Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left, Active = true,
}, panel)
local close = create("TextButton", {
    Position = UDim2.new(1, -38, 0, 6), Size = UDim2.fromOffset(30, 28),
    BackgroundColor3 = Color3.fromRGB(145, 49, 62), BorderSizePixel = 0,
    Text = "X", TextColor3 = color.text, TextSize = 15,
}, panel)
local brightButton = create("TextButton", {
    Position = UDim2.fromOffset(12, 44), Size = UDim2.new(1, -24, 0, 38),
    BackgroundColor3 = color.button, BorderSizePixel = 0, Font = Enum.Font.GothamBold,
    Text = "แมพสว่าง: OFF — F8", TextColor3 = color.text, TextSize = 15,
}, panel)
create("TextLabel", {
    Position = UDim2.fromOffset(12, 88), Size = UDim2.new(1, -24, 0, 24), BackgroundTransparency = 1,
    Text = "เห็นบนจอเราคนเดียว • ปิดแล้วแสงกลับเหมือนเดิม", TextColor3 = color.muted, TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
}, panel)

local connections = {}
local closed = false

-- Re-applied twice a second because areas and events change the lighting as you play.
local bright = {enabled = false, props = {}, effects = setmetatable({}, {__mode = "k"}), nextAt = 0}
local brightTargets = {
    Brightness = 2, ClockTime = 14, FogStart = 0, FogEnd = 100000, GlobalShadows = false,
    Ambient = Color3.fromRGB(180, 180, 180), OutdoorAmbient = Color3.fromRGB(180, 180, 180),
    ExposureCompensation = 0,
}
local function brightEffect(object)
    local saved = bright.effects[object]
    if object:IsA("Atmosphere") then
        if not saved then bright.effects[object] = {Density = object.Density, Haze = object.Haze} end
        if object.Density ~= 0 then object.Density = 0 end
        if object.Haze ~= 0 then object.Haze = 0 end
    elseif object:IsA("ColorCorrectionEffect") or object:IsA("BlurEffect") or object:IsA("DepthOfFieldEffect") then
        if not saved then bright.effects[object] = {Enabled = object.Enabled} end
        if object.Enabled then object.Enabled = false end
    end
end
local function applyBright()
    for name, value in pairs(brightTargets) do
        if bright.props[name] == nil then bright.props[name] = Lighting[name] end
        if Lighting[name] ~= value then Lighting[name] = value end
    end
    for _, object in ipairs(Lighting:GetChildren()) do brightEffect(object) end
    local camera = workspace.CurrentCamera
    if camera then
        for _, object in ipairs(camera:GetChildren()) do brightEffect(object) end
    end
end
local function restoreBright()
    for name, value in pairs(bright.props) do pcall(function() Lighting[name] = value end) end
    for object, values in pairs(bright.effects) do
        if object.Parent then
            for name, value in pairs(values) do pcall(function() object[name] = value end) end
        end
    end
    table.clear(bright.props)
    table.clear(bright.effects)
end
local function toggleBright()
    bright.enabled = not bright.enabled
    if bright.enabled then pcall(applyBright) else restoreBright() end
    brightButton.Text = bright.enabled and "แมพสว่าง: ON — F8" or "แมพสว่าง: OFF — F8"
    brightButton.BackgroundColor3 = bright.enabled and color.green or color.button
end
brightButton.Activated:Connect(toggleBright)
table.insert(connections, RunService.Heartbeat:Connect(function()
    if closed or not bright.enabled or os.clock() < bright.nextAt then return end
    bright.nextAt = os.clock() + 0.5
    pcall(applyBright)
end))
table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
    if processed or closed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.F8 then toggleBright() end
end))

-- Drag the window by its title.
local dragStart, startPosition
table.insert(connections, header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragStart, startPosition = input.Position, panel.Position
    end
end))
table.insert(connections, UserInputService.InputChanged:Connect(function(input)
    if dragStart and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X,
            startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
    end
end))
table.insert(connections, UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragStart = nil
    end
end))

local session = {}
function session.cleanup()
    if closed then return end
    closed = true
    for _, connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
    table.clear(connections)
    if bright.enabled then
        bright.enabled = false
        restoreBright()
    end
    if sessionEnv.MonterSession == session then sessionEnv.MonterSession = nil end
    pcall(function() gui:Destroy() end)
end
sessionEnv.MonterSession = session
close.Activated:Connect(session.cleanup)
gui.Destroying:Connect(session.cleanup)
