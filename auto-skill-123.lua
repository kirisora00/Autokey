-- Auto Skill 1 / 2 / 3 v1.1 — selectable keyboard providers and observed input diagnostics.
-- Number-row keys only; sends inputs at the configured interval, not cooldown bypasses.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
assert(player, "Run on Client")
local playerGui = player:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("AutoSkill123Window")
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
    blue = Color3.fromRGB(48, 112, 210),
    green = Color3.fromRGB(34, 140, 89),
    text = Color3.fromRGB(235, 238, 245),
    muted = Color3.fromRGB(160, 169, 184),
}
local gui = create("ScreenGui", {
    Name = "AutoSkill123Window", ResetOnSpawn = false,
    DisplayOrder = 30, IgnoreGuiInset = true,
}, playerGui)
local panel = create("Frame", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -18, 0, 110), Size = UDim2.fromOffset(340, 410),
    BackgroundColor3 = color.background, BorderSizePixel = 0,
}, gui)
create("UICorner", {CornerRadius = UDim.new(0, 10)}, panel)
create("UIStroke", {Color = Color3.fromRGB(68, 73, 88), Thickness = 1}, panel)
local dragHeader = create("Frame", {
    Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -92, 0, 43),
    BackgroundTransparency = 1, Active = true,
}, panel)
create("TextLabel", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    Text = "AUTO SKILL 1 / 2 / 3", TextColor3 = color.text,
    TextSize = 16, Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, dragHeader)
local minimize = create("TextButton", {
    Position = UDim2.new(1, -75, 0, 7), Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "−", TextColor3 = color.text, TextSize = 21,
}, panel)
local close = create("TextButton", {
    Position = UDim2.new(1, -38, 0, 7), Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = Color3.fromRGB(145, 49, 62), BorderSizePixel = 0,
    Text = "X", TextColor3 = color.text, TextSize = 16,
}, panel)
local content = create("Frame", {
    Position = UDim2.fromOffset(14, 50), Size = UDim2.new(1, -28, 0, 346),
    BackgroundTransparency = 1,
}, panel)
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 37), BackgroundTransparency = 1,
    Text = "วนกด 1 → 2 → 3 • เลือกเปิด/ปิดแต่ละสกิลได้\nกดตามเวลา คูลดาวน์ยังเป็นไปตามระบบเกม",
    TextColor3 = color.muted, TextSize = 12, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
}, content)
local selectionButtons, testButtons = {}, {}
for index = 1, 3 do
    selectionButtons[index] = create("TextButton", {
        Position = UDim2.fromOffset((index - 1) * 106, 46),
        Size = UDim2.fromOffset(100, 40), BackgroundColor3 = color.green,
        BorderSizePixel = 0, Text = index .. ": ON",
        TextColor3 = color.text, Font = Enum.Font.GothamBold, TextSize = 17,
    }, content)
    testButtons[index] = create("TextButton", {
        Position = UDim2.fromOffset((index - 1) * 106, 94),
        Size = UDim2.fromOffset(100, 29), BackgroundColor3 = color.button,
        BorderSizePixel = 0, Text = "ลองกด " .. index,
        TextColor3 = color.text, TextSize = 13,
    }, content)
end
create("TextLabel", {
    Position = UDim2.fromOffset(0, 137), Size = UDim2.fromOffset(170, 29),
    BackgroundTransparency = 1, Text = "ห่างระหว่างสกิล (วินาที)",
    TextColor3 = color.muted, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
}, content)
local slower = create("TextButton", {
    Position = UDim2.fromOffset(178, 133), Size = UDim2.fromOffset(30, 34),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "−", TextColor3 = color.text, TextSize = 19,
}, content)
local intervalInput = create("TextBox", {
    Position = UDim2.fromOffset(214, 133), Size = UDim2.fromOffset(62, 34),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "1.00", TextColor3 = color.text, TextSize = 16, ClearTextOnFocus = false,
}, content)
local faster = create("TextButton", {
    Position = UDim2.fromOffset(282, 133), Size = UDim2.fromOffset(30, 34),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "+", TextColor3 = color.text, TextSize = 19,
}, content)
local modeButton = create("TextButton", {
    Position = UDim2.fromOffset(0, 181), Size = UDim2.new(1, 0, 0, 34),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "กำลังเตรียมช่องทางส่งปุ่ม...", TextColor3 = color.text, TextSize = 13,
}, content)
local toggle = create("TextButton", {
    Position = UDim2.fromOffset(0, 226), Size = UDim2.new(1, 0, 0, 43),
    BackgroundColor3 = color.blue, BorderSizePixel = 0,
    Text = "AUTO: OFF — กดเพื่อเริ่ม", TextColor3 = color.text,
    Font = Enum.Font.GothamBold, TextSize = 17,
}, content)
local status = create("TextLabel", {
    Position = UDim2.fromOffset(0, 280), Size = UDim2.new(1, 0, 0, 66),
    BackgroundTransparency = 1, Text = "พร้อมทดสอบ • AUTO เริ่มต้นปิดอยู่\nลากแถบชื่อเพื่อย้ายหน้าต่างได้",
    TextColor3 = color.muted, TextSize = 13, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
}, content)

local focused, closed, collapsed = true, false, false
local keyCodes = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three}
local connections = {}
local diagnostic = {last = nil, sequence = 0}
local lastStatus = "พร้อมทดสอบ • AUTO เริ่มต้นปิดอยู่"

local function renderStatus()
    if closed then return end
    local line = ""
    local last = diagnostic.last
    if last then
        if last.received then
            line = "\nพบสัญญาณปุ่ม " .. last.index
                .. (last.processed and " • processed=true" or "")
        else
            line = "\nยังไม่พบสัญญาณปุ่ม " .. last.index .. " ใน Roblox"
        end
    end
    local text = lastStatus .. line
    if status.Text ~= text then status.Text = text end
end

local function buildInputRouter(deps)
    local router = {modes = {"VirtualInputManager", "VirtualInput"}, modeIndex = 1}
    local activeMode, providers = {}, {}
    if type(deps.keypress) == "function" and type(deps.keyrelease) == "function" then
        table.insert(router.modes, 1, "Native keys")
    end
    function router.mode() return router.modes[router.modeIndex] end
    function router.cycle()
        router.modeIndex = router.modeIndex % #router.modes + 1
        return router.mode()
    end
    local function dispatch(mode, index, down)
        if mode == "Native keys" then
            -- Number-row virtual keys 0x31, 0x32, 0x33 for compatible runners.
            if down then deps.keypress(48 + index) else deps.keyrelease(48 + index) end
        elseif mode == "VirtualInputManager" then
            if not providers[mode] then providers[mode] = deps.manager() end
            local provider = providers[mode]
            if not provider then error("VirtualInputManager unavailable") end
            provider:SendKeyEvent(down, deps.keyCodes[index], false, deps.layer)
        else
            if not providers[mode] then providers[mode] = deps.virtual() end
            local provider = providers[mode]
            if not provider then error("VirtualInput unavailable") end
            provider:SendKey(down, deps.keyCodes[index], false)
        end
    end
    function router.send(index, down)
        if index < 1 or index > 3 then error("Invalid skill index") end
        if not down and not activeMode[index] then return end
        local mode = down and router.mode() or activeMode[index]
        if down then
            if deps.blur then deps.blur() end
            activeMode[index] = mode
        end
        local ok, err = pcall(dispatch, mode, index, down)
        if not ok then
            if down then
                -- Clean up the failed attempt without retrying the key-down through another method.
                pcall(dispatch, mode, index, false)
                activeMode[index] = nil
            end
            error(err, 0)
        end
        if not down then activeMode[index] = nil end
    end
    return router
end

local router = buildInputRouter({
    keypress = keypress, keyrelease = keyrelease,
    keyCodes = keyCodes, layer = game,
    manager = function() return game:GetService("VirtualInputManager") end,
    virtual = function() return UserInputService:CreateVirtualInput() end,
    blur = function()
        local selected = GuiService.SelectedObject
        if selected and selected:IsDescendantOf(gui) then GuiService.SelectedObject = nil end
    end,
})
modeButton.Text = "ส่งปุ่ม: " .. router.mode() .. " • กดเพื่อเปลี่ยน"

local function sendKey(index, down)
    if down then
        diagnostic.sequence = diagnostic.sequence + 1
        diagnostic.last = {
            id = diagnostic.sequence, index = index,
            at = os.clock(), received = false, processed = false,
        }
    end
    router.send(index, down)
end
table.insert(connections, UserInputService.InputBegan:Connect(function(event, processed)
    local last = diagnostic.last
    if last and event.KeyCode == keyCodes[last.index] and os.clock() - last.at <= 0.75 then
        last.received, last.processed = true, processed
        task.defer(renderStatus)
    end
end))
local function paused()
    if not focused then return "พัก AUTO ระหว่างสลับออกจากเกม" end
    if UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then
        return "พัก AUTO ระหว่างพิมพ์หรือเปิดเมนู Roblox"
    end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not character or not humanoid or humanoid.Health <= 0 then
        return "พัก AUTO รอตัวละครเกิดใหม่"
    end
end

local function buildSkillController(deps)
    local controller = {}
    local state = {
        enabled = false, disposed = false, cursor = 0, interval = 1,
        selected = {true, true, true}, nextAt = 0, held = nil, sent = 0,
    }
    controller.state = state
    local function notify(message)
        deps.notify(state, message)
    end

    local release
    release = function(ticket)
        ticket = ticket or state.held
        if not ticket or state.held ~= ticket then return true end
        local ok, err = pcall(deps.send, ticket.index, false)
        if ok then
            state.held = nil
            return true
        end
        state.enabled = false
        notify("ปล่อยปุ่มไม่สำเร็จ ปิดแชต/เมนู Roblox ก่อน")
        ticket.failures = (ticket.failures or 0) + 1
        if ticket.failures < 4 and not ticket.retryScheduled then
            ticket.retryScheduled = true
            deps.delay(0.25, function()
                ticket.retryScheduled = false
                if state.held == ticket then release(ticket) end
            end)
        end
        if ticket.failures == 4 and deps.error then deps.error(err) end
        return false
    end
    controller.release = function() return release() end

    function controller.stop()
        state.enabled = false
        release()
        notify("หยุด AUTO แล้ว • ส่งปุ่มไป " .. state.sent .. " ครั้ง")
    end
    function controller.start()
        if state.disposed then return false end
        if not release() then return false end
        if not state.selected[1] and not state.selected[2] and not state.selected[3] then
            notify("เลือกสกิลอย่างน้อย 1 ปุ่มก่อนครับ")
            return false
        end
        state.enabled, state.cursor = true, 0
        state.nextAt = deps.clock() + 0.15
        notify("เริ่ม AUTO • วนกดสกิลที่เลือกตามลำดับ")
        return true
    end
    function controller.select(index, value)
        if index < 1 or index > 3 then return end
        state.selected[index] = value == true
        if state.held and state.held.index == index and not state.selected[index] then release() end
        notify("สกิล " .. index .. (state.selected[index] and " เปิดอยู่" or " ปิดอยู่"))
    end
    function controller.interval(value)
        local number = tonumber(value)
        if not number or number ~= number then number = state.interval end
        state.interval = math.max(0.20, math.min(10, number))
        if state.enabled then state.nextAt = deps.clock() + state.interval end
        notify(string.format("ช่วงห่างระหว่างสกิล: %.2f วินาที", state.interval))
    end
    local function press(index)
        if state.held then return false end
        local ticket = {index = index}
        state.held = ticket
        local ok, err = pcall(deps.send, index, true)
        if not ok then
            state.enabled = false
            release(ticket)
            notify("ส่งปุ่มไม่สำเร็จ ดู Error ใน Console")
            if deps.error then deps.error(err) end
            return false
        end
        state.sent = state.sent + 1
        state.nextAt = deps.clock() + state.interval
        deps.delay(0.15, function()
            -- An old delayed release must never release a newer key press.
            if state.held == ticket then release(ticket) end
        end)
        notify("ส่งปุ่ม " .. index .. " แล้ว • รวม " .. state.sent .. " ครั้ง")
        return true
    end
    function controller.tap(index)
        if state.disposed or index < 1 or index > 3 then return false end
        if state.enabled then notify("ปิด AUTO ก่อนทดสอบกดทีละปุ่มครับ") return false end
        if deps.clock() < state.nextAt or state.held then return false end
        local reason = deps.paused()
        if reason then notify(reason) return false end
        return press(index)
    end
    function controller.step()
        if state.disposed or not state.enabled then return end
        local reason = deps.paused()
        if reason then release() notify(reason) return end
        if state.held or deps.clock() < state.nextAt then return end
        for offset = 1, 3 do
            local index = ((state.cursor + offset - 1) % 3) + 1
            if state.selected[index] then
                if press(index) then state.cursor = index end
                return
            end
        end
        notify("เลือกสกิลอย่างน้อย 1 ปุ่ม • AUTO กำลังรอ")
    end
    function controller.dispose()
        state.enabled, state.disposed = false, true
        release()
    end
    return controller
end


local controller = buildSkillController({
    clock = os.clock, delay = task.delay, send = sendKey, paused = paused,
    notify = function(state, message)
        if closed then return end
        local text = state.enabled and "AUTO: ON — กดเพื่อหยุด" or "AUTO: OFF — กดเพื่อเริ่ม"
        if toggle.Text ~= text then toggle.Text = text end
        toggle.BackgroundColor3 = state.enabled and color.green or color.blue
        lastStatus = message
        renderStatus()
    end,
    error = function(err)
        if not closed then
            lastStatus = "Error: " .. tostring(err):sub(1, 120)
            renderStatus()
        end
        warn("Auto Skill 123:", err)
    end,
})

local function changeInterval(value)
    controller.interval(value)
    intervalInput.Text = string.format("%.2f", controller.state.interval)
end
for index = 1, 3 do
    local selectedIndex = index
    selectionButtons[selectedIndex].Activated:Connect(function()
        controller.select(selectedIndex, not controller.state.selected[selectedIndex])
        local selected = controller.state.selected[selectedIndex]
        selectionButtons[selectedIndex].Text = selectedIndex .. (selected and ": ON" or ": OFF")
        selectionButtons[selectedIndex].BackgroundColor3 = selected and color.green or color.button
    end)
    testButtons[selectedIndex].Activated:Connect(function()
        focused = true
        controller.tap(selectedIndex)
    end)
end
toggle.Activated:Connect(function()
    focused = true
    if controller.state.enabled then controller.stop() else controller.start() end
end)
modeButton.Activated:Connect(function()
    controller.stop()
    local mode = router.cycle()
    modeButton.Text = "ส่งปุ่ม: " .. mode .. " • กดเพื่อเปลี่ยน"
    diagnostic.last = nil
    lastStatus = "เปลี่ยนเป็น " .. mode .. "\nลองกด 1 ก่อน แล้วค่อยเปิด AUTO"
    renderStatus()
end)
intervalInput.FocusLost:Connect(function() changeInterval(intervalInput.Text) end)
-- Minus decreases the interval (faster); plus increases it (slower).
slower.Activated:Connect(function() changeInterval(controller.state.interval - 0.25) end)
faster.Activated:Connect(function() changeInterval(controller.state.interval + 0.25) end)
minimize.Activated:Connect(function()
    collapsed = not collapsed
    content.Visible = not collapsed
    panel.Size = UDim2.fromOffset(340, collapsed and 43 or 410)
    minimize.Text = collapsed and "+" or "−"
end)
close.Activated:Connect(function() gui:Destroy() end)

local dragging, dragStart, startPosition = false, nil, nil
table.insert(connections, dragHeader.InputBegan:Connect(function(event)
    if event.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = Vector2.new(event.Position.X, event.Position.Y)
        startPosition = panel.AbsolutePosition
    end
end))
table.insert(connections, UserInputService.InputEnded:Connect(function(event)
    if event.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end))
table.insert(connections, UserInputService.InputChanged:Connect(function(event)
    if not dragging or event.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local delta = Vector2.new(event.Position.X, event.Position.Y) - dragStart
    local size = panel.AbsoluteSize
    local view = camera.ViewportSize
    local position = startPosition + delta
    local x = math.clamp(position.X, 0, math.max(0, view.X - size.X))
    local y = math.clamp(position.Y, 0, math.max(0, view.Y - size.Y))
    panel.Position = UDim2.fromOffset(x + size.X, y)
end))
table.insert(connections, UserInputService.TextBoxFocused:Connect(function() controller.release() end))
table.insert(connections, GuiService.MenuOpened:Connect(function() controller.release() end))
table.insert(connections, UserInputService.WindowFocusReleased:Connect(function()
    focused, dragging = false, false
    controller.release()
end))
table.insert(connections, UserInputService.WindowFocused:Connect(function() focused = true end))
table.insert(connections, player.CharacterRemoving:Connect(function() controller.release() end))
local nextTick = 0
table.insert(connections, RunService.Heartbeat:Connect(function()
    if closed or os.clock() < nextTick then return end
    nextTick = os.clock() + 0.05
    local ok, err = pcall(controller.step)
    if not ok then controller.stop() warn("Auto Skill 123:", err) end
end))
gui.Destroying:Connect(function()
    closed, dragging = true, false
    controller.dispose()
    for _, connection in ipairs(connections) do connection:Disconnect() end
    table.clear(connections)
end)
