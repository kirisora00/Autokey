-- Monter v1.02 — Fullbright (F8), monster ESP (F7) and player ESP (F6, ally green / enemy red): names, HP and
-- distance through walls, plus a list of nearby monster names to copy. Client-side; undone when closed.
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
for _, name in ipairs({"MonterWindow", "MonterESPLabels", "MonterPlayerLabels"}) do
    local old = playerGui:FindFirstChild(name)
    if old then old:Destroy() end
end

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
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 110), Size = UDim2.fromOffset(240, 360),
    BackgroundColor3 = color.background, BorderSizePixel = 0, Active = true,
}, gui)
create("UICorner", {CornerRadius = UDim.new(0, 10)}, panel)
create("UIStroke", {Color = Color3.fromRGB(68, 73, 88), Thickness = 1}, panel)
local header = create("TextLabel", {
    Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -56, 0, 40), BackgroundTransparency = 1,
    Text = "MONTER v1.02", TextColor3 = color.text, TextSize = 16, Font = Enum.Font.GothamBold,
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
local espButton = create("TextButton", {
    Position = UDim2.fromOffset(12, 88), Size = UDim2.new(1, -24, 0, 38),
    BackgroundColor3 = color.button, BorderSizePixel = 0, Font = Enum.Font.GothamBold,
    Text = "ESP มอน: OFF — F7", TextColor3 = color.text, TextSize = 15,
}, panel)
local playerEspButton = create("TextButton", {
    Position = UDim2.fromOffset(12, 132), Size = UDim2.new(1, -112, 0, 38),
    BackgroundColor3 = color.button, BorderSizePixel = 0, Font = Enum.Font.GothamBold,
    Text = "ESP ผู้เล่น: OFF — F6", TextColor3 = color.text, TextSize = 13, TextWrapped = true,
}, panel)
local allyButton = create("TextButton", {
    Position = UDim2.new(1, -94, 0, 132), Size = UDim2.fromOffset(82, 38),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "ทีมเรา: แสดง", TextColor3 = color.text, TextSize = 12,
}, panel)
local espList = create("TextLabel", {
    Position = UDim2.fromOffset(12, 176), Size = UDim2.new(1, -24, 0, 112), BackgroundTransparency = 1,
    Text = "เปิด ESP แล้วรายชื่อมอนใกล้ตัวจะขึ้นตรงนี้\nผู้เล่น: เขียว = ทีมเรา • แดง = ศัตรู • ส้ม = เกมไม่มีทีม",
    TextColor3 = color.muted, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
}, panel)
local copyButton = create("TextButton", {
    Position = UDim2.fromOffset(12, 294), Size = UDim2.new(1, -24, 0, 28),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "คัดลอกรายชื่อมอนทั้งหมด", TextColor3 = color.text, TextSize = 13,
}, panel)
create("TextLabel", {
    Position = UDim2.fromOffset(12, 328), Size = UDim2.new(1, -24, 0, 24), BackgroundTransparency = 1,
    Text = "เห็นบนจอเราคนเดียว • ปิดหน้าต่างแล้วทุกอย่างกลับเหมือนเดิม", TextColor3 = color.muted, TextSize = 11,
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
-- Monster ESP: any model with a Humanoid that is not a player's character counts as a monster, so no names
-- are needed up front. The nearest 60 in range get a label (name, HP, distance) and the nearest 18 a
-- through-wall highlight. Roblox draws at most 31 highlights at once; 12 more are kept for player ESP.
local ESP_RANGE, ESP_LABELS, ESP_HIGHLIGHTS = 1500, 60, 18
local esp = {enabled = false, models = {}, items = {}, nextAt = 0, signals = {}, folder = nil, glow = nil, inRange = {}}
local function monsterModel(model)
    return model ~= nil and model:IsA("Model") and model ~= player.Character
        and Players:GetPlayerFromCharacter(model) == nil
end
local function track(object)
    if object:IsA("Humanoid") and monsterModel(object.Parent) then esp.models[object.Parent] = object end
end
local function dropItem(model)
    local item = esp.items[model]
    if not item then return end
    esp.items[model] = nil
    pcall(function() item.billboard:Destroy() end)
    if item.highlight then pcall(function() item.highlight:Destroy() end) end
end
local function displayName(model, humanoid)
    local shown = humanoid.DisplayName
    return (shown ~= nil and shown ~= "" and shown ~= model.Name) and (shown .. " (" .. model.Name .. ")") or model.Name
end
local function glowFolder()
    -- Highlights live under the camera (local-only); a new camera means a new folder.
    local camera = workspace.CurrentCamera
    if esp.glow and esp.glow.Parent == camera then return esp.glow end
    for _, item in pairs(esp.items) do item.highlight = nil end
    if esp.glow then pcall(function() esp.glow:Destroy() end) end
    esp.glow = camera and create("Folder", {Name = "MonterESPHighlights"}, camera) or nil
    return esp.glow
end
local function updateEsp()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local list = {}
    for model, humanoid in pairs(esp.models) do
        if not model.Parent or not humanoid.Parent or not model:IsDescendantOf(workspace) then
            esp.models[model] = nil
            dropItem(model)
        elseif humanoid.Health > 0 then
            local part = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
                or model:FindFirstChildWhichIsA("BasePart", true)
            if part then
                local distance = root and (part.Position - root.Position).Magnitude or 0
                if distance <= ESP_RANGE then
                    list[#list + 1] = {model = model, humanoid = humanoid, part = part, distance = distance}
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    esp.inRange = list
    local shown, folder = {}, glowFolder()
    for index, entry in ipairs(list) do
        if index > ESP_LABELS then break end
        local model = entry.model
        shown[model] = true
        local item = esp.items[model]
        if not item then
            local billboard = create("BillboardGui", {
                Name = "MonterESP", AlwaysOnTop = true, LightInfluence = 0, MaxDistance = math.huge,
                Size = UDim2.fromOffset(200, 34), StudsOffset = Vector3.new(0, 3, 0),
            }, esp.folder)
            local label = create("TextLabel", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
                TextColor3 = Color3.fromRGB(255, 95, 95), TextStrokeTransparency = 0.3, TextSize = 13, Text = "",
            }, billboard)
            item = {billboard = billboard, label = label}
            esp.items[model] = item
        end
        item.billboard.Adornee = model:FindFirstChild("Head") or entry.part
        local humanoid = entry.humanoid
        item.label.Text = string.format("%s\nHP %s/%s • %dm", displayName(model, humanoid),
            math.floor(humanoid.Health + 0.5), math.floor(humanoid.MaxHealth + 0.5), math.floor(entry.distance))
        if index <= ESP_HIGHLIGHTS and folder then
            if not item.highlight or not item.highlight.Parent then
                item.highlight = create("Highlight", {
                    Adornee = model, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
                    FillColor = Color3.fromRGB(255, 60, 60), FillTransparency = 0.8,
                    OutlineColor = Color3.fromRGB(255, 80, 80), OutlineTransparency = 0,
                }, folder)
            end
        elseif item.highlight then
            pcall(function() item.highlight:Destroy() end)
            item.highlight = nil
        end
    end
    for model in pairs(esp.items) do
        if not shown[model] then dropItem(model) end
    end
    -- Name summary: how many of each monster are in range, nearest kinds first.
    local counts, order = {}, {}
    for _, entry in ipairs(list) do
        local name = displayName(entry.model, entry.humanoid)
        if not counts[name] then counts[name] = {count = 0, nearest = entry.distance} order[#order + 1] = name end
        counts[name].count += 1
    end
    local lines = {string.format("มอนในระยะ %d studs: %d ตัว", ESP_RANGE, #list)}
    for index, name in ipairs(order) do
        if index > 7 then lines[#lines + 1] = "... และอีก " .. (#order - 7) .. " ชื่อ (กดคัดลอกดูทั้งหมด)" break end
        lines[#lines + 1] = string.format("• %s x%d (ใกล้สุด %dm)", name, counts[name].count, math.floor(counts[name].nearest))
    end
    espList.Text = table.concat(lines, "\n")
end
local function stopEsp()
    for _, connection in ipairs(esp.signals) do pcall(function() connection:Disconnect() end) end
    table.clear(esp.signals)
    for model in pairs(esp.items) do dropItem(model) end
    table.clear(esp.models)
    table.clear(esp.inRange)
    if esp.folder then pcall(function() esp.folder:Destroy() end) esp.folder = nil end
    if esp.glow then pcall(function() esp.glow:Destroy() end) esp.glow = nil end
end
local function toggleEsp()
    esp.enabled = not esp.enabled
    if esp.enabled then
        esp.folder = create("Folder", {Name = "MonterESPLabels"}, playerGui)
        for _, object in ipairs(workspace:GetDescendants()) do track(object) end
        table.insert(esp.signals, workspace.DescendantAdded:Connect(function(object)
            if object:IsA("Humanoid") then task.defer(track, object) end -- its model may still be assembling
        end))
        table.insert(esp.signals, workspace.DescendantRemoving:Connect(function(object)
            if esp.models[object] then esp.models[object] = nil dropItem(object) end
        end))
        esp.nextAt = 0
    else
        stopEsp()
        espList.Text = "เปิด ESP แล้วรายชื่อมอนใกล้ตัวจะขึ้นตรงนี้\nผู้เล่น: เขียว = ทีมเรา • แดง = ศัตรู • ส้ม = เกมไม่มีทีม"
    end
    espButton.Text = esp.enabled and "ESP มอน: ON — F7" or "ESP มอน: OFF — F7"
    espButton.BackgroundColor3 = esp.enabled and color.green or color.button
end
espButton.Activated:Connect(toggleEsp)
table.insert(connections, RunService.Heartbeat:Connect(function()
    if closed or not esp.enabled or os.clock() < esp.nextAt then return end
    esp.nextAt = os.clock() + 0.25
    local ok, err = pcall(updateEsp)
    if not ok then warn("Monter ESP:", err) end
end))
copyButton.Activated:Connect(function()
    local counts, order = {}, {}
    for _, entry in ipairs(esp.inRange) do
        local name = displayName(entry.model, entry.humanoid)
        if not counts[name] then counts[name] = 0 order[#order + 1] = name end
        counts[name] += 1
    end
    if #order == 0 then copyButton.Text = "ยังไม่มีรายชื่อ • เปิด ESP ก่อน" return end
    local lines = {}
    for _, name in ipairs(order) do lines[#lines + 1] = name .. " x" .. counts[name] end
    local report = table.concat(lines, "\n")
    print("Monter monsters:\n" .. report)
    local copy = setclipboard or toclipboard
    local copied = type(copy) == "function" and pcall(copy, report)
    copyButton.Text = copied and ("คัดลอกแล้ว " .. #order .. " ชื่อ") or "ดูรายชื่อใน Console (F9)"
end)

-- Player ESP: other players with a label (name, HP, distance, team) and, for the nearest 12, a highlight.
-- Green = same team, red = enemy, orange = the game uses no teams so there is nothing to tell apart.
local PLAYER_RANGE, PLAYER_HIGHLIGHTS = 5000, 12
local relationColor = {
    ally = Color3.fromRGB(80, 220, 120), enemy = Color3.fromRGB(255, 80, 80), none = Color3.fromRGB(255, 170, 60),
}
local pesp = {enabled = false, showAllies = true, items = {}, nextAt = 0, folder = nil, glow = nil}
local function relation(other)
    if player.Team and other.Team then return other.Team == player.Team and "ally" or "enemy" end
    -- Some games skip Roblox Teams and tag players with an attribute instead.
    for _, key in ipairs({"Team", "TeamName", "Faction", "Side"}) do
        local mine, theirs = player:GetAttribute(key), other:GetAttribute(key)
        if mine ~= nil and theirs ~= nil then return mine == theirs and "ally" or "enemy" end
    end
    return "none"
end
local function dropPlayerItem(other)
    local item = pesp.items[other]
    if not item then return end
    pesp.items[other] = nil
    pcall(function() item.billboard:Destroy() end)
    if item.highlight then pcall(function() item.highlight:Destroy() end) end
end
local function playerGlowFolder()
    local camera = workspace.CurrentCamera
    if pesp.glow and pesp.glow.Parent == camera then return pesp.glow end
    for _, item in pairs(pesp.items) do item.highlight = nil end
    if pesp.glow then pcall(function() pesp.glow:Destroy() end) end
    pesp.glow = camera and create("Folder", {Name = "MonterPlayerHighlights"}, camera) or nil
    return pesp.glow
end
local function updatePlayerEsp()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local list, allies, enemies, teamless = {}, 0, 0, 0
    for _, other in ipairs(Players:GetPlayers()) do
        local theirs = other ~= player and other.Character
        local humanoid = theirs and theirs:FindFirstChildOfClass("Humanoid")
        local part = theirs and (theirs:FindFirstChild("HumanoidRootPart") or theirs.PrimaryPart)
        if humanoid and part and humanoid.Health > 0 then
            local kind = relation(other)
            if kind == "ally" then allies += 1 elseif kind == "enemy" then enemies += 1 else teamless += 1 end
            local distance = root and (part.Position - root.Position).Magnitude or 0
            if distance <= PLAYER_RANGE and (kind ~= "ally" or pesp.showAllies) then
                list[#list + 1] = {player = other, character = theirs, humanoid = humanoid, part = part,
                    distance = distance, kind = kind}
            end
        end
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    local shown, folder = {}, playerGlowFolder()
    for index, entry in ipairs(list) do
        local other = entry.player
        shown[other] = true
        local item = pesp.items[other]
        if not item then
            local billboard = create("BillboardGui", {
                Name = "MonterPlayerESP", AlwaysOnTop = true, LightInfluence = 0, MaxDistance = math.huge,
                Size = UDim2.fromOffset(220, 34), StudsOffset = Vector3.new(0, 3.5, 0),
            }, pesp.folder)
            local label = create("TextLabel", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
                TextStrokeTransparency = 0.3, TextSize = 13, Text = "",
            }, billboard)
            item = {billboard = billboard, label = label}
            pesp.items[other] = item
        end
        local tint = relationColor[entry.kind]
        local team = entry.kind == "ally" and "ทีมเรา" or (entry.kind == "enemy" and "ศัตรู" or "ไม่มีทีม")
        if other.Team then team = team .. " • " .. other.Team.Name end
        item.billboard.Adornee = entry.character:FindFirstChild("Head") or entry.part
        item.label.TextColor3 = tint
        item.label.Text = string.format("%s (@%s)\nHP %s/%s • %dm • %s", other.DisplayName, other.Name,
            math.floor(entry.humanoid.Health + 0.5), math.floor(entry.humanoid.MaxHealth + 0.5),
            math.floor(entry.distance), team)
        if index <= PLAYER_HIGHLIGHTS and folder then
            if not item.highlight or not item.highlight.Parent then
                item.highlight = create("Highlight", {
                    DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, FillTransparency = 0.8, OutlineTransparency = 0,
                }, folder)
            end
            -- Characters are replaced on respawn and teams can change mid-game: refresh both every tick.
            item.highlight.Adornee = entry.character
            item.highlight.FillColor, item.highlight.OutlineColor = tint, tint
        elseif item.highlight then
            pcall(function() item.highlight:Destroy() end)
            item.highlight = nil
        end
    end
    for other in pairs(pesp.items) do
        if not shown[other] then dropPlayerItem(other) end
    end
    playerEspButton.Text = (allies + enemies == 0 and teamless > 0)
        and string.format("ESP ผู้เล่น: ON — F6\nผู้เล่น %d (เกมไม่มีทีม)", teamless)
        or string.format("ESP ผู้เล่น: ON — F6\nศัตรู %d • ทีมเรา %d", enemies + teamless, allies)
end
local function stopPlayerEsp()
    for other in pairs(pesp.items) do dropPlayerItem(other) end
    if pesp.folder then pcall(function() pesp.folder:Destroy() end) pesp.folder = nil end
    if pesp.glow then pcall(function() pesp.glow:Destroy() end) pesp.glow = nil end
end
local function togglePlayerEsp()
    pesp.enabled = not pesp.enabled
    if pesp.enabled then
        pesp.folder = create("Folder", {Name = "MonterPlayerLabels"}, playerGui)
        pesp.nextAt = 0
    else
        stopPlayerEsp()
        playerEspButton.Text = "ESP ผู้เล่น: OFF — F6"
    end
    playerEspButton.BackgroundColor3 = pesp.enabled and color.green or color.button
end
playerEspButton.Activated:Connect(togglePlayerEsp)
allyButton.Activated:Connect(function()
    pesp.showAllies = not pesp.showAllies
    allyButton.Text = pesp.showAllies and "ทีมเรา: แสดง" or "ทีมเรา: ซ่อน"
    pesp.nextAt = 0
end)
table.insert(connections, RunService.Heartbeat:Connect(function()
    if closed or not pesp.enabled or os.clock() < pesp.nextAt then return end
    pesp.nextAt = os.clock() + 0.2
    local ok, err = pcall(updatePlayerEsp)
    if not ok then warn("Monter player ESP:", err) end
end))

table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
    if processed or closed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.F8 then toggleBright() end
    if input.KeyCode == Enum.KeyCode.F6 then togglePlayerEsp() end
    if input.KeyCode == Enum.KeyCode.F7 then toggleEsp() end
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
    esp.enabled = false
    stopEsp()
    pesp.enabled = false
    stopPlayerEsp()
    if sessionEnv.MonterSession == session then sessionEnv.MonterSession = nil end
    pcall(function() gui:Destroy() end)
end
sessionEnv.MonterSession = session
close.Activated:Connect(session.cleanup)
gui.Destroying:Connect(session.cleanup)
