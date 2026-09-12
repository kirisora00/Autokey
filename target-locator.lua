-- Autokey v2.0: sidebar navigation, target locator, teleport, AUTO and flight
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

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local currentPage = "target"
local flight = nil
local flySpeed = 70
local flightConnections = {}
local pressed = {}
local setAuto

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
    Position = UDim2.fromOffset(15, 310), Size = UDim2.fromOffset(137, 65),
    BackgroundTransparency = 1, Text = "AUTOKEY\nv2.0 · Client\n− ยุบ   /   X ปิดระบบ",
    TextColor3 = colors.muted, Font = Enum.Font.Gotham,
    TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
}, sidebar)

local function makePage()
    return create("Frame", {
        Position = UDim2.fromOffset(181, 10),
        Size = UDim2.fromOffset(403, 374), BackgroundTransparency = 1,
    }, content)
end
local targetPage = makePage()
local flightPage = makePage()
flightPage.Visible = false

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

local function showPage(page)
    currentPage = page
    targetPage.Visible = page == "target"
    flightPage.Visible = page == "flight"
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

table.insert(flightConnections, RunService.RenderStepped:Connect(function()
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
        f.velocity.VectorVelocity = movement * flySpeed
        f.orientation.CFrame = CFrame.lookAt(Vector3.zero, forward)
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
    stopFlight()
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
    pageTitle.Text = name
    title.Text = name .. ": " .. total .. (auto and " [AUTO]" or "") .. (flight and " [FLY]" or "")
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
