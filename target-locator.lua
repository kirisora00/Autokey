-- Target Locator: Villain / Devil Boat
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

local targets = {
    {label = "Villain", model = "Bacon Thief"},
    {label = "Devil Boat", model = "DevilBoat"},
}
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

local gui = create("ScreenGui", {
    Name = "TargetLocator", ResetOnSpawn = false, DisplayOrder = 10,
}, playerGui)

local panel = create("Frame", {
    Size = UDim2.fromOffset(330, 435),
    Position = UDim2.new(1, -345, 0, 100),
    BackgroundColor3 = Color3.fromRGB(24, 27, 35),
    BorderSizePixel = 0,
}, gui)

create("UICorner", {CornerRadius = UDim.new(0, 10)}, panel)

local title = create("TextLabel", {
    Position = UDim2.fromOffset(10, 0),
    Size = UDim2.new(1, -90, 0, 40),
    BackgroundTransparency = 1,
    Text = "Target Locator",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

local minimize = create("TextButton", {
    Position = UDim2.new(1, -74, 0, 5),
    Size = UDim2.fromOffset(32, 30),
    Text = "−", TextSize = 22,
    TextColor3 = Color3.new(1, 1, 1),
    BackgroundColor3 = Color3.fromRGB(55, 65, 85),
}, panel)

local close = create("TextButton", {
    Position = UDim2.new(1, -37, 0, 5),
    Size = UDim2.fromOffset(32, 30),
    Text = "X", TextColor3 = Color3.new(1, 1, 1),
    BackgroundColor3 = Color3.fromRGB(150, 45, 45),
}, panel)

local content = create("Frame", {
    Position = UDim2.fromOffset(0, 40),
    Size = UDim2.new(1, 0, 0, 395),
    BackgroundTransparency = 1,
}, panel)

local tabs = {}
for i, target in ipairs(targets) do
    tabs[i] = create("TextButton", {
        Position = UDim2.fromOffset(10 + (i - 1) * 160, 5),
        Size = UDim2.fromOffset(150, 34),
        Text = target.label, TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold, TextSize = 15,
        BackgroundColor3 = Color3.fromRGB(55, 65, 85),
    }, content)
end

local output = create("TextLabel", {
    Position = UDim2.fromOffset(12, 48),
    Size = UDim2.new(1, -24, 0, 205),
    BackgroundTransparency = 1,
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.Code, TextSize = 15, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    Text = "Scanning...",
}, content)

local teleport = create("TextButton", {
    Position = UDim2.fromOffset(10, 255),
    Size = UDim2.new(1, -20, 0, 40),
    BackgroundColor3 = Color3.fromRGB(35, 125, 190),
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold, TextSize = 16,
    Text = "วาร์ปไปตัวใกล้ที่สุด",
}, content)

local autoButton = create("TextButton", {
    Position = UDim2.fromOffset(10, 302),
    Size = UDim2.new(1, -20, 0, 40),
    BackgroundColor3 = Color3.fromRGB(70, 75, 85),
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold, TextSize = 16,
    Text = "AUTO: OFF",
}, content)

local status = create("TextLabel", {
    Position = UDim2.fromOffset(10, 348),
    Size = UDim2.new(1, -20, 0, 42),
    BackgroundTransparency = 1,
    TextColor3 = Color3.fromRGB(220, 220, 220),
    TextSize = 14, TextWrapped = true,
    Text = "เลือกเป้าหมาย แล้วกดวาร์ปหรือเปิด AUTO",
}, content)

local function clearMarkers()
    for _, marker in pairs(markers) do marker.gui:Destroy() end
    table.clear(markers)
end

local function setAuto(enabled)
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
    panel.Size = UDim2.fromOffset(330, collapsed and 40 or 435)
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

local function autoStep(entries)
    if not auto then return end

    -- Removal from the client Workspace also counts as a departed target.
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
        "AUTO: รอจัดการ %s%s | HP: %.0f",
        targets[selected].label,
        marker and (" #" .. marker.id) or "",
        locked.humanoid.Health
    )
end

local function update()
    local entries, total, root = collectTargets()
    local visible = {}
    local name = targets[selected].label

    title.Text = name .. ": " .. total .. (auto and " [AUTO]" or "")
    teleport.Text = "วาร์ปไป " .. name .. " ใกล้ที่สุด"

    for i, tab in ipairs(tabs) do
        tab.BackgroundColor3 = i == selected
            and Color3.fromRGB(35, 125, 190) or Color3.fromRGB(55, 65, 85)
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
end

for i, tab in ipairs(tabs) do
    local index = i
    tab.Activated:Connect(function()
        if selected == index then return end
        setAuto(false)
        selected = index
        clearMarkers()
        status.Text = "เปลี่ยนประเภทแล้ว AUTO ปิดอยู่"
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
            status.Text = "เกิด Error จึงหยุด AUTO ดู Console"
            warn("Target Locator:", err)
        end
        task.wait(0.5)
    end
end)
