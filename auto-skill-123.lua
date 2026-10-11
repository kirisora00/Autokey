-- Auto Skill + NPC Hover + Flight v1.10 — hold the flight position while casting skills.
-- Number-row keys only; sends inputs at the configured interval, not cooldown bypasses.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
assert(player, "Run on Client")
local playerGui = player:WaitForChild("PlayerGui")
local sessionEnv = _G
if type(getgenv) == "function" then
    local ok, value = pcall(getgenv)
    if ok and type(value) == "table" then sessionEnv = value end
end
local previousSession = sessionEnv.AutokeySkill123Session
if type(previousSession) == "table" and type(previousSession.cleanup) == "function" then
    pcall(previousSession.cleanup)
end
local old = playerGui:FindFirstChild("AutoSkill123Window")
local previousInputMode = type(previousSession) == "table" and previousSession.inputMode or nil
if old then
    previousInputMode = old:GetAttribute("InputModeChoice")
    if not previousInputMode then
        for _, object in ipairs(old:GetDescendants()) do
            if object:IsA("TextButton") then
                local mode = object.Text:match("^ส่งปุ่ม:%s*(.-)%s*•")
                if mode then previousInputMode = mode break end
            end
        end
    end
    old:Destroy()
    task.wait() -- Let older versions finish their deferred Destroying handlers before setting up a new session.
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
    Position = UDim2.new(1, -18, 0, 110), Size = UDim2.fromOffset(340, 460),
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
    Text = "AUTO SKILL / HOVER / FLY", TextColor3 = color.text,
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
local skillTab = create("TextButton", {
    Position = UDim2.fromOffset(14, 49), Size = UDim2.fromOffset(100, 31),
    BackgroundColor3 = color.blue, BorderSizePixel = 0,
    Text = "Skill 1/2/3", TextColor3 = color.text, TextSize = 14,
}, panel)
local hoverTab = create("TextButton", {
    Position = UDim2.fromOffset(120, 49), Size = UDim2.fromOffset(100, 31),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "ยืนบนหัวมอน", TextColor3 = color.text, TextSize = 14,
}, panel)
local flightTab = create("TextButton", {
    Position = UDim2.fromOffset(226, 49), Size = UDim2.fromOffset(100, 31),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "บิน / Flight", TextColor3 = color.text, TextSize = 14,
}, panel)
local content = create("Frame", {
    Position = UDim2.fromOffset(14, 92), Size = UDim2.new(1, -28, 0, 346),
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

local hotkeyHint = create("TextLabel", {
    Position = UDim2.fromOffset(14, 438), Size = UDim2.new(1, -28, 0, 16),
    BackgroundTransparency = 1, TextColor3 = color.muted, TextSize = 11,
    Text = "F1 บิน • F2 ยืนบนหัว • F3 Auto Skill",
}, panel)
local focused, closed, collapsed = true, false, false
local keyCodes = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three}
local connections = {}
local hotkeys
local session = {disposed = false}
sessionEnv.AutokeySkill123Session = session
local function cleanupSession(destroyGui)
    if session.disposed then return end
    session.disposed, closed = true, true
    -- Disconnect first; an error while restoring physics must not leave callbacks running.
    for _, connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
    table.clear(connections)
    for _, stop in ipairs(session.stops or {}) do pcall(stop) end
    if sessionEnv.AutokeySkill123Session == session then sessionEnv.AutokeySkill123Session = nil end
    if destroyGui ~= false then pcall(function() gui:Destroy() end) end
end
session.cleanup = cleanupSession
table.insert(connections, gui.Destroying:Connect(function() cleanupSession(false) end))
local diagnostic = {last = nil, sequence = 0}
local function gameFocused()
    if type(isrbxactive) == "function" then
        local ok, value = pcall(isrbxactive)
        if ok and type(value) == "boolean" then return value end
    end
    return focused
end
local lastStatus = "พร้อมทดสอบ • AUTO เริ่มต้นปิดอยู่"

local function renderStatus()
    if closed then return end
    local line = ""
    local last = diagnostic.last
    if last then
        if not gameFocused() then
            local mode = last.mode == "Native keys" and "VirtualInputManager" or last.mode
            line = "\nเบื้องหลัง • ส่งผ่าน " .. mode
        elseif last.background then
            line = "\nล่าสุดส่งเบื้องหลังผ่าน " .. last.mode
        elseif last.received then
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
    function router.effectiveMode()
        local mode = router.mode()
        if mode == "Native keys" and deps.focused and not deps.focused() then
            -- Never send a number-key DOWN to an unrelated foreground application.
            return "VirtualInputManager"
        end
        return mode
    end
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
        local mode = down and router.effectiveMode() or activeMode[index]
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
    focused = gameFocused,
    manager = function() return game:GetService("VirtualInputManager") end,
    virtual = function() return UserInputService:CreateVirtualInput() end,
    blur = function()
        local selected = GuiService.SelectedObject
        if selected and selected:IsDescendantOf(gui) then GuiService.SelectedObject = nil end
    end,
})
local previousIndex = previousInputMode and table.find(router.modes, previousInputMode)
if previousIndex then router.modeIndex = previousIndex end
gui:SetAttribute("InputModeChoice", router.mode())
session.inputMode = router.mode()
modeButton.Text = "ส่งปุ่ม: " .. router.mode() .. " • กดเพื่อเปลี่ยน"

local function sendKey(index, down)
    if down then
        if session.captureFlightCast then session.captureFlightCast() end
        diagnostic.sequence = diagnostic.sequence + 1
        diagnostic.last = {
            id = diagnostic.sequence, index = index,
            at = os.clock(), received = false, processed = false, mode = router.effectiveMode(), background = not gameFocused(),
        }
    end
    router.send(index, down)
end
table.insert(connections, UserInputService.InputBegan:Connect(function(event, processed)
    if hotkeys then hotkeys.begin(event, processed) end
    local last = diagnostic.last
    if last and event.KeyCode == keyCodes[last.index] and os.clock() - last.at <= 0.75 then
        last.received, last.processed = true, processed
        task.defer(renderStatus)
    end
end))
local hoverController, controller
-- Read action animations at most ten times per second, shared by skills and flight.
local animationCache = {humanoid = nil, at = 0, busy = false}
local function skillAnimationBusy(humanoid)
    local now = os.clock()
    if animationCache.humanoid == humanoid and now < animationCache.at then return animationCache.busy end
    local busy = false
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            local priority = track.Priority
            if track.IsPlaying and not track.Looped and
                (priority == Enum.AnimationPriority.Action or priority == Enum.AnimationPriority.Action2
                or priority == Enum.AnimationPriority.Action3 or priority == Enum.AnimationPriority.Action4) then
                busy = true
                break
            end
        end
    end
    animationCache.humanoid, animationCache.at, animationCache.busy = humanoid, now + 0.10, busy
    return busy
end
local function paused()
    if UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then
        return "พัก AUTO ระหว่างพิมพ์หรือเปิดเมนู Roblox"
    end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not character or not humanoid or humanoid.Health <= 0 then
        return "พัก AUTO รอตัวละครเกิดใหม่"
    end
    if not (controller and controller.state.held) and skillAnimationBusy(humanoid) then
        return "รอแอนิเมชันสกิลจบก่อนกดตัวถัดไป"
    end
    if hoverController and hoverController.state.enabled and not hoverController.readyForSkills() then
        return "พักสกิล • รอมอนเกิดหรือรอไปอยู่เหนือหัวมอน"
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


controller = buildSkillController({
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


-- Anonymous NPC tracking: indexed once, then maintained by workspace events.
local hoverPage = create("Frame", {
    Position = UDim2.fromOffset(14, 92), Size = UDim2.new(1, -28, 0, 346),
    BackgroundTransparency = 1, Visible = false,
}, panel)
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1,
    Text = "หาตัวใกล้สุดโดยไม่ต้องรู้ชื่อ • ตามเหนือหัวจนตาย\nถ้ายังไม่มีมอน จะปล่อยให้เดินเข้าจุด Spawn ต่อได้",
    TextColor3 = color.muted, TextSize = 13, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
}, hoverPage)
create("TextLabel", {
    Position = UDim2.fromOffset(0, 57), Size = UDim2.fromOffset(205, 31),
    BackgroundTransparency = 1, Text = "ความสูงเหนือหัว (studs)",
    TextColor3 = color.muted, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
}, hoverPage)
local hoverHeight = create("TextBox", {
    Position = UDim2.new(1, -91, 0, 57), Size = UDim2.fromOffset(91, 31),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "6", TextColor3 = color.text, TextSize = 16, ClearTextOnFocus = false,
}, hoverPage)
create("TextLabel", {
    Position = UDim2.fromOffset(0, 98), Size = UDim2.fromOffset(205, 31),
    BackgroundTransparency = 1, Text = "ระยะค้นหามอน (studs)",
    TextColor3 = color.muted, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
}, hoverPage)
local hoverRadius = create("TextBox", {
    Position = UDim2.new(1, -91, 0, 98), Size = UDim2.fromOffset(91, 31),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "250", TextColor3 = color.text, TextSize = 16, ClearTextOnFocus = false,
}, hoverPage)
local hoverToggle = create("TextButton", {
    Position = UDim2.fromOffset(0, 142), Size = UDim2.new(1, 0, 0, 41),
    BackgroundColor3 = color.blue, BorderSizePixel = 0,
    Text = "ยืนบนหัว: OFF — กดเพื่อเริ่ม", TextColor3 = color.text,
    Font = Enum.Font.GothamBold, TextSize = 16,
}, hoverPage)
local hoverNext = create("TextButton", {
    Position = UDim2.fromOffset(0, 191), Size = UDim2.fromOffset(152, 31),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "เลือกเป้าถัดไป", TextColor3 = color.text, TextSize = 13,
}, hoverPage)
local hoverScan = create("TextButton", {
    Position = UDim2.fromOffset(160, 191), Size = UDim2.fromOffset(152, 31),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "สแกน + ข้อมูล", TextColor3 = color.text, TextSize = 13,
}, hoverPage)
local hoverStatus = create("TextLabel", {
    Position = UDim2.fromOffset(0, 236), Size = UDim2.new(1, 0, 0, 110),
    BackgroundTransparency = 1, TextColor3 = color.muted,
    TextSize = 13, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    Text = "v1.7 • สแกนเป็นชุดเล็ก ลดงานซ้ำ\nบอส IMMUNE: จัดการลูกน้องก่อน\nสแกน + ข้อมูล: คัดลอกข้อมูลไว้ตรวจตัวที่หาไม่เจอ",
}, hoverPage)
local flightPage = create("Frame", {
    Position = UDim2.fromOffset(14, 92), Size = UDim2.new(1, -28, 0, 346),
    BackgroundTransparency = 1, Visible = false,
}, panel)
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1,
    Text = "Flight / การบิน", TextColor3 = color.text,
    Font = Enum.Font.GothamBold, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left,
}, flightPage)
create("TextLabel", {
    Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 100),
    BackgroundTransparency = 1, TextColor3 = color.muted, TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    Text = "W / A / S / D   เคลื่อนที่ตามมุมกล้อง\nSpace   บินขึ้น\nCtrl   บินลง\nปล่อยปุ่ม   ลอยอยู่กับที่",
}, flightPage)
local flySpeedLabel = create("TextLabel", {
    Position = UDim2.fromOffset(46, 157), Size = UDim2.new(1, -92, 0, 36),
    BackgroundTransparency = 1, Text = "Speed: 70 studs/s",
    TextColor3 = color.text, TextSize = 16, Font = Enum.Font.GothamBold,
}, flightPage)
local flySlower = create("TextButton", {
    Position = UDim2.fromOffset(0, 157), Size = UDim2.fromOffset(40, 36),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "−", TextSize = 21, TextColor3 = color.text,
}, flightPage)
local flyFaster = create("TextButton", {
    Position = UDim2.new(1, -40, 0, 157), Size = UDim2.fromOffset(40, 36),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "+", TextSize = 21, TextColor3 = color.text,
}, flightPage)
local flyButton = create("TextButton", {
    Position = UDim2.fromOffset(0, 214), Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = color.blue, BorderSizePixel = 0,
    TextColor3 = color.text, Font = Enum.Font.GothamBold,
    TextSize = 17, Text = "FLIGHT: OFF — กดเพื่อบิน",
}, flightPage)
local flyStatus = create("TextLabel", {
    Position = UDim2.fromOffset(0, 271), Size = UDim2.new(1, 0, 0, 75),
    BackgroundTransparency = 1, TextColor3 = color.muted, TextSize = 13, TextWrapped = true,
    Text = "เปิดบินจะหยุดยืนบนหัวมอนและ Auto Skill\nยุบหน้าต่างแล้วบินต่อได้ • ปิดบินเพื่อเดินปกติ",
}, flightPage)

local hoverHumanoids = {} -- Humanoid, AnimationController, or health-bearing enemy model candidates
local hoverModels, modelCursor = {}, nil
local rigCache = setmetatable({}, {__mode = "k"})
local hoverScanStats = {}
local function ownCharacter()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not character or not humanoid or not root or humanoid.Health <= 0
        or not character:IsDescendantOf(workspace) then return nil end
    return character, humanoid, root
end
local function isPlayerModel(model)
    for _, other in ipairs(Players:GetPlayers()) do
        local character = other.Character
        if character and (model == character or model:IsDescendantOf(character)) then return true end
    end
    return false
end
local function bodyPart(object, model)
    return object and object:IsA("BasePart") and object:IsDescendantOf(model)
        and not object:FindFirstAncestorOfClass("Tool")
        and not object:FindFirstAncestorOfClass("Accessory")
end
local function targetParts(model, humanoid)
    local cached = rigCache[model]
    if cached and bodyPart(cached.root, model) then
        local headOK = cached.head and cached.head:IsDescendantOf(model)
        if not cached.dirty then return cached.root, headOK and cached.head or nil end
    end
    local root = humanoid and humanoid.RootPart
    if not bodyPart(root, model) then root = model:FindFirstChild("HumanoidRootPart", true) end
    if not bodyPart(root, model) then root = model.PrimaryPart end
    if not bodyPart(root, model) then
        for _, name in ipairs({"RootPart", "Root", "Torso", "UpperTorso", "LowerTorso", "Main", "Body"}) do
            local candidate = model:FindFirstChild(name, true)
            if bodyPart(candidate, model) then root = candidate break end
        end
    end
    local descendants
    if not bodyPart(root, model) then
        descendants = model:GetDescendants()
        local volume = -1
        for _, object in ipairs(descendants) do
            if bodyPart(object, model) then
                local size = object.Size
                local v = size.X * size.Y * size.Z
                if v > volume then root, volume = object, v end
            end
        end
    end
    if not bodyPart(root, model) then return nil end
    local head, body = nil, {}
    descendants = descendants or model:GetDescendants()
    for _, object in ipairs(descendants) do
        if bodyPart(object, model) then body[#body + 1] = object end
        if object.Name == "Head" and not object:FindFirstAncestorOfClass("Tool")
            and not object:FindFirstAncestorOfClass("Accessory")
            and (object:IsA("BasePart") or object:IsA("Attachment")) then
            head = head or object
        end
    end
    rigCache[model] = {root = root, head = head, body = body, boundsAt = 0, dirty = false}
    return root, head
end
local function enemyFolderHint(model)
    local object = model.Parent
    while object and object ~= workspace do
        local name = string.lower(object.Name)
        if name == "enemy" or name == "enemies" or name == "mob" or name == "mobs"
            or name == "monster" or name == "monsters" or name == "boss" or name == "bosses" then
            return true
        end
        object = object.Parent
    end
    return false
end
local function friendlyModel(model)
    if model:GetAttribute("Friendly") == true or model:GetAttribute("IsFriendly") == true
        or model:GetAttribute("IsEnemy") == false then return true end
    local object = model.Parent
    while object and object ~= workspace do
        local name = string.lower(object.Name)
        if name == "allies" or name == "allied" or name == "pets"
            or name == "companions" or name == "friendly" then return true end
        object = object.Parent
    end
    return false
end
local function customHealthSource(model)
    for _, name in ipairs({"CurrentHealth", "CurrentHP", "Health", "HP", "health", "hp"}) do
        local value = model:GetAttribute(name)
        if type(value) == "number" and value == value then
            return {kind = "attribute", object = model, field = name, label = "Attribute." .. name}
        end
    end
    local containers = {model}
    for _, name in ipairs({"Stats", "Values", "Data", "Vitals"}) do
        local folder = model:FindFirstChild(name)
        if folder then containers[#containers + 1] = folder end
    end
    for _, container in ipairs(containers) do
        for _, name in ipairs({"CurrentHealth", "CurrentHP", "Health", "HP", "health", "hp"}) do
            local value = container:FindFirstChild(name)
            if value and (value:IsA("NumberValue") or value:IsA("IntValue")) then
                return {kind = "value", object = value, label = container.Name .. "." .. name}
            end
        end
    end
end
-- Nameplates can be parented in PlayerGui with Adornee pointing into Workspace.
local hoverBillboards = {}
local plateCache = setmetatable({}, {__mode = "k"})
local function cleanPlateText(text)
    return tostring(text or ""):gsub("<[^>]*>", ""):gsub("^%s+", ""):gsub("%s+$", "")
end
local function healthText(text)
    text = cleanPlateText(text):gsub(",", "")
    local current, maximum = text:match("(%d+%.?%d*)%s*/%s*(%d+%.?%d*)")
    if current and tonumber(maximum) > 0 then return tonumber(current), false end
    local percent = text:match("(%d+%.?%d*)%s*%%")
    if percent and tonumber(percent) <= 100 then return tonumber(percent), true end
end
local function plateVisible(object, plate)
    local cursor = object
    while cursor do
        if cursor:IsA("GuiObject") and not cursor.Visible then return false end
        if cursor == plate then return plate.Enabled end
        cursor = cursor.Parent
    end
    return false
end
local function readPlate(plate)
    if not plate.Parent or not plate.Enabled then return nil end
    local now = os.clock()
    local cached = plateCache[plate]
    if not cached then cached = {refreshAt = 0, readAt = 0} plateCache[plate] = cached end
    if not cached.labels or cached.dirty then
        cached.labels = {}
        for _, object in ipairs(plate:GetDescendants()) do
            if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                cached.labels[#cached.labels + 1] = object
            end
        end
        cached.dirty, cached.readAt = false, 0
    end
    if now < cached.readAt then return cached.snapshot end
    local snapshot = {texts = {}, immune = false}
    local best = -1
    for _, label in ipairs(cached.labels) do
        if label.Parent and plateVisible(label, plate) then
            local text = cleanPlateText(label.Text)
            if text ~= "" then
                snapshot.texts[#snapshot.texts + 1] = text
                if string.upper(text):find("IMMUNE", 1, true) then snapshot.immune = true end
                local hp, percent = healthText(text)
                if hp ~= nil then
                    local name = string.lower(label.Name)
                    local score = (name:find("health", 1, true) or name:find("hp", 1, true)) and 3 or 1
                    if text:match("^%d+%.?%d*%%$") then score = score + 1 end
                    if score > best then snapshot.health, snapshot.percent, best = hp, percent, score end
                elseif not snapshot.title and not text:match("^%d") then
                    snapshot.title = text
                end
            end
        end
    end
    cached.snapshot, cached.readAt = snapshot, now + 0.10
    return snapshot
end
local function plateActor(plate)
    local anchor = plate.Adornee or plate.Parent
    if not anchor or not anchor:IsDescendantOf(workspace) then return nil end
    if anchor:IsA("Attachment") then
        anchor = anchor.Parent
        while anchor and not anchor:IsA("BasePart") do anchor = anchor.Parent end
    end
    if not anchor then return nil end
    local model = anchor:IsA("Model") and anchor or anchor:FindFirstAncestorOfClass("Model")
    if not model or model == workspace then return nil end
    return model, anchor
end
local function sourceHealth(source)
    if not source or not source.object.Parent then return 0 end
    local value
    if source.kind == "humanoid" then value = source.object.Health
    elseif source.kind == "attribute" then value = source.object:GetAttribute(source.field)
    elseif source.kind == "nameplate" then
        local snapshot = readPlate(source.object)
        value = snapshot and snapshot.health
    else value = source.object.Value end
    return type(value) == "number" and value == value and value or 0
end
local function resolveActor(control)
    local model = control:IsA("Model") and control or control:FindFirstAncestorOfClass("Model")
    if not model then return nil end
    local humanoid = control:IsA("Humanoid") and control or model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local root = humanoid.RootPart
        if root and root:IsA("BasePart") then
            for _ = 1, 4 do
                if root:IsDescendantOf(model) then break end
                local parent = model.Parent
                if not parent or parent == workspace then break end
                local outer = parent:IsA("Model") and parent or parent:FindFirstAncestorOfClass("Model")
                if not outer then break end
                model = outer
            end
        end
        return model, humanoid, {kind = "humanoid", object = humanoid, label = "Humanoid.Health"}
    end
    -- Animated/skinned NPCs may store health on their outer model rather than a Humanoid.
    for _ = 1, 4 do
        local source = customHealthSource(model)
        if source then return model, nil, source end
        local parent = model.Parent
        if not parent or parent == workspace then break end
        model = parent:IsA("Model") and parent or parent:FindFirstAncestorOfClass("Model")
        if not model then break end
    end
    return nil
end
-- Map models are classified a few at a time; target scans only visit actual actor candidates.
local function dirtyGeometry(object)
    if object:IsA("BasePart") or object:IsA("Attachment") then
        local model = object:FindFirstAncestorOfClass("Model")
        for _ = 1, 4 do
            if not model then break end
            local cached = rigCache[model]
            if cached then cached.dirty, cached.boundsAt = true, 0 end
            model = model:FindFirstAncestorOfClass("Model")
        end
    elseif object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
        local plate = object:FindFirstAncestorOfClass("BillboardGui")
        local cached = plate and plateCache[plate]
        if cached then cached.dirty, cached.readAt = true, 0 end
    end
end
local function trackHumanoid(object)
    if object:IsA("Humanoid") or object:IsA("AnimationController") then
        hoverHumanoids[object] = true
    elseif object:IsA("Model") then
        hoverModels[object] = true
    elseif object:IsA("BillboardGui") then
        hoverBillboards[object] = true
    end
    dirtyGeometry(object)
end
local function trackPlate(object)
    if object:IsA("BillboardGui") then hoverBillboards[object] = true end
    dirtyGeometry(object)
end
local function untrack(object)
    dirtyGeometry(object)
    hoverHumanoids[object], hoverBillboards[object], hoverModels[object] = nil, nil, nil
    rigCache[object], plateCache[object] = nil, nil
    if modelCursor == object then modelCursor = nil end
end
local function refreshHoverModels()
    local started = os.clock()
    for _ = 1, 12 do
        local model = next(hoverModels, modelCursor)
        modelCursor = model
        if not model then break end
        local actor = resolveActor(model)
        hoverHumanoids[model] = actor and true or nil
        if os.clock() - started >= 0.001 then break end
    end
end
table.insert(connections, workspace.DescendantAdded:Connect(trackHumanoid))
table.insert(connections, workspace.DescendantRemoving:Connect(untrack))
table.insert(connections, playerGui.DescendantAdded:Connect(trackPlate))
table.insert(connections, playerGui.DescendantRemoving:Connect(untrack))
for _, object in ipairs(workspace:GetDescendants()) do
    -- Bootstrap only indexes classes. Geometry invalidation is for later changes.
    if object:IsA("Humanoid") or object:IsA("AnimationController") then hoverHumanoids[object] = true
    elseif object:IsA("Model") then hoverModels[object] = true
    elseif object:IsA("BillboardGui") then hoverBillboards[object] = true end
end
for _, object in ipairs(playerGui:GetDescendants()) do
    if object:IsA("BillboardGui") then hoverBillboards[object] = true end
end

local function scanHoverTargets(radius, skipped)
    local _, _, root = ownCharacter()
    if not root then return {} end
    local byPart, entries, seenModel = {}, {}, {}
    local now = os.clock()
    hoverScanStats = {outside = 0, noPart = 0, friendly = 0, noHealth = 0, plates = 0, unmapped = 0}
    local function include(model, humanoid, source, plate, snapshot)
        if not model or not model:IsDescendantOf(workspace) or isPlayerModel(model) then return end
        if model:GetAttribute("Dead") == true or model:GetAttribute("IsDead") == true then return end
        if friendlyModel(model) then hoverScanStats.friendly = hoverScanStats.friendly + 1 return end
        if sourceHealth(source) <= 0 then return end
        local part, head = targetParts(model, humanoid)
        if not part then hoverScanStats.noPart = hoverScanStats.noPart + 1 return end
        local previous = byPart[part]
        if previous then
            if plate then
                previous.nameplate = plate
                previous.displayName = snapshot.title or previous.displayName
                previous.immune = snapshot.immune
            end
            return
        end
        local key = humanoid or model
        local excludedUntil = skipped[key]
        local distance = (part.Position - root.Position).Magnitude
        if distance > radius then
            hoverScanStats.outside = hoverScanStats.outside + 1
        elseif not (excludedUntil and excludedUntil > now) then
            byPart[part] = {model = model, humanoid = key, rigHumanoid = humanoid, source = source,
                part = part, head = head, distance = distance, path = model:GetFullName(),
                hinted = enemyFolderHint(model), nameplate = plate,
                displayName = snapshot and snapshot.title or model.Name, immune = snapshot and snapshot.immune or false}
        end
    end
    for control in pairs(hoverHumanoids) do
        local model, humanoid, source = resolveActor(control)
        if not model then
            hoverScanStats.noHealth = hoverScanStats.noHealth + 1
        elseif not seenModel[model] then
            seenModel[model] = true
            include(model, humanoid, source)
        end
    end
    for plate in pairs(hoverBillboards) do
        local model, anchor = plateActor(plate)
        local near = model and not isPlayerModel(model)
        if near then
            local part = anchor:IsA("BasePart") and anchor or model.PrimaryPart
            if part and (part.Position - root.Position).Magnitude > radius then near = false end
        end
        -- Do not parse nameplates for distant map decorations or other players.
        local snapshot = near and readPlate(plate)
        if snapshot and snapshot.health ~= nil then
            hoverScanStats.plates = hoverScanStats.plates + 1
            if not model then
                hoverScanStats.unmapped = hoverScanStats.unmapped + 1
            else
                local resolved, humanoid, source = resolveActor(model)
                if resolved and anchor:IsDescendantOf(resolved) then model = resolved end
                -- An explicit zero in real health data must not be resurrected by a stale nameplate.
                source = source or {kind = "nameplate", object = plate, label = "Nameplate HP"}
                include(model, humanoid, source, plate, snapshot)
            end
        elseif not model then
            hoverScanStats.unmapped = hoverScanStats.unmapped + 1
        end
    end
    for _, entry in pairs(byPart) do entries[#entries + 1] = entry end
    table.sort(entries, function(a, b)
        if a.immune ~= b.immune then return not a.immune end
        if a.distance == b.distance and a.hinted ~= b.hinted then return a.hinted end
        return a.distance < b.distance
    end)
    return entries
end
local function targetAlive(entry)
    if entry and entry.nameplate then
        local snapshot = readPlate(entry.nameplate)
        entry.immune = snapshot and snapshot.immune or false
    end
    if not entry or not entry.model:IsDescendantOf(workspace) or sourceHealth(entry.source) <= 0
        or entry.model:GetAttribute("Dead") == true or entry.model:GetAttribute("IsDead") == true then return false end
    local part = targetParts(entry.model, entry.rigHumanoid)
    if not part then return false end
    entry.part = part
    return true
end
local function destination(entry, height)
    local root, head = targetParts(entry.model, entry.rigHumanoid)
    if not root then return nil end
    if head then
        if head:IsA("BasePart") then return head.Position + Vector3.new(0, head.Size.Y * 0.5 + height, 0) end
        return head.WorldPosition + Vector3.new(0, height, 0)
    end
    -- Headless rigs use the model top rather than a point inside their body.
    local cached = rigCache[entry.model]
    if not cached.boundsOffset or os.clock() >= cached.boundsAt then
        local top = root.Position.Y + root.Size.Y * 0.5
        for _, part in ipairs(cached.body or {}) do
            if bodyPart(part, entry.model) then
                local frame, size = part.CFrame, part.Size
                local extent = math.abs(frame.RightVector.Y) * size.X * 0.5
                    + math.abs(frame.UpVector.Y) * size.Y * 0.5
                    + math.abs(frame.LookVector.Y) * size.Z * 0.5
                top = math.max(top, part.Position.Y + extent)
            end
        end
        cached.boundsOffset = top - root.Position.Y
        cached.boundsAt = os.clock() + 0.50
    end
    return root.Position + Vector3.new(0, cached.boundsOffset + height, 0)
end
local lastHoverInfoAt, hoverReportUntil = 0, 0
local function buildHoverController(deps)
    local hover = {}
    local state = {enabled = false, target = nil, ready = false,
        height = 6, radius = 250, nextScan = 0, placedSince = nil, nextInfo = 0}
    hover.state = state
    local skipped = setmetatable({}, {__mode = "k"})
    local function notify(message) deps.notify(state, message) end
    local function clearTarget()
        state.target, state.ready, state.placedSince = nil, false, nil
    end
    function hover.stop()
        state.enabled = false
        clearTarget()
        deps.releaseSkills()
        notify("หยุดยืนบนหัวแล้ว • เดินได้ตามปกติ")
    end
    function hover.start()
        state.enabled = true
        clearTarget()
        skipped = setmetatable({}, {__mode = "k"})
        state.nextScan = 0
        deps.releaseSkills()
        notify("รอมอนเกิด • เดินเข้าจุด Spawn ในห้องได้เลย")
    end
    function hover.next()
        if state.target then skipped[state.target.humanoid] = deps.clock() + 3 end
        clearTarget()
        state.nextScan = 0
        deps.releaseSkills()
        notify("กำลังเลือกเป้าถัดไป • ข้ามตัวเดิมชั่วคราว 3 วินาที")
    end
    function hover.configure(height, radius)
        local oldHeight, oldRadius = state.height, state.radius
        local h, r = tonumber(height), tonumber(radius)
        if h and h == h then state.height = math.max(3, math.min(50, h)) end
        if r and r == r then state.radius = math.max(20, math.min(600, r)) end
        if state.height ~= oldHeight or state.radius ~= oldRadius then
            state.ready, state.placedSince = false, nil
        end
    end
    function hover.readyForSkills()
        return state.enabled and state.ready and state.target ~= nil
            and deps.alive(state.target) and deps.inPosition(state.target, state.height)
    end
    function hover.scan()
        return deps.scan(state.radius, skipped)
    end
    function hover.step()
        if not state.enabled then return end
        local ready, reason = deps.playerReady()
        if not ready then
            state.ready, state.placedSince = false, nil
            deps.releaseSkills()
            notify(reason or "รอตัวละครพร้อม...")
            return
        end
        if state.target and not deps.alive(state.target) then
            clearTarget()
            state.nextScan = 0
            deps.releaseSkills()
        end
        -- An immune boss may summon new enemies after we have already locked onto it.
        if state.target and state.target.immune and deps.clock() >= state.nextScan then
            state.nextScan = deps.clock() + 0.40
            local entries = deps.scan(state.radius, skipped)
            if entries[1] and not entries[1].immune and entries[1].model ~= state.target.model then
                state.target = entries[1]
                state.ready, state.placedSince = false, nil
                deps.releaseSkills()
            end
        end
        if not state.target then
            if deps.clock() < state.nextScan then return end
            state.nextScan = deps.clock() + 0.40
            local entries = deps.scan(state.radius, skipped)
            if not entries[1] then
                notify("ยังไม่มีมอนในระยะ • ไม่ล็อกตำแหน่งตัวละคร\nเดินเข้าห้อง/จุด Spawn ต่อได้ • ระยะ " .. state.radius .. " studs")
                return
            end
            state.target = entries[1]
            state.ready, state.placedSince = false, nil
        end
        local switched = state.placedSince == nil
        local moved, message = deps.follow(state.target, state.height, switched)
        if not moved then
            state.ready, state.placedSince = false, nil
            deps.releaseSkills()
            notify(message or "รอก่อนวาร์ป...")
            return
        end
        state.placedSince = state.placedSince or deps.clock()
        state.ready = deps.clock() - state.placedSince >= 0.30
        if deps.clock() >= state.nextInfo then
            state.nextInfo = deps.clock() + 0.25
            notify(deps.describe(state.target, state.ready))
        end
    end
    return hover
end

hoverController = buildHoverController({
    clock = os.clock, scan = scanHoverTargets, alive = targetAlive,
    releaseSkills = controller.release,
    playerReady = function()
        local _, humanoid = ownCharacter()
        if not humanoid then return false, "รอตัวละครเกิดใหม่" end
        if humanoid.SeatPart then return false, "ลงจากที่นั่งก่อนครับ" end
        return true
    end,
    inPosition = function(entry, height)
        local _, _, root = ownCharacter()
        local point = destination(entry, height)
        return root and point and (root.Position - point).Magnitude <= 8
    end,
    follow = function(entry, height, switching)
        local _, humanoid, root = ownCharacter()
        local point = destination(entry, height)
        if not root or not point then return false, "รอตำแหน่งมอนโหลด..." end
        if root.Anchored then return false, "รอเกมปลดล็อกตัวละครจากสกิล..." end
        if switching then
            local animator = humanoid:FindFirstChildOfClass("Animator")
            if animator then
                for _, animation in ipairs(animator:GetPlayingAnimationTracks()) do
                    local priority = animation.Priority
                    local action = priority == Enum.AnimationPriority.Action or priority == Enum.AnimationPriority.Action2
                        or priority == Enum.AnimationPriority.Action3 or priority == Enum.AnimationPriority.Action4
                    if action and not animation.Looped and animation.IsPlaying then
                        return false, "รอสกิลจบก่อนวาร์ปเปลี่ยนเป้าหมาย..."
                    end
                end
            end
        end
        root.CFrame = CFrame.new(point) * root.CFrame.Rotation
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        return true
    end,
    describe = function(entry, ready)
        return string.format("เป้า: %s\nHP: %.0f • %s\n%s",
            entry.displayName or entry.model.Name, sourceHealth(entry.source),
            ready and "อยู่เหนือหัวแล้ว" or "รอให้อยู่เหนือหัวนิ่งก่อนกดสกิล", entry.path)
    end,
    notify = function(state, message)
        if closed then return end
        local text = state.enabled and "ยืนบนหัว: ON — กดเพื่อหยุด" or "ยืนบนหัว: OFF — กดเพื่อเริ่ม"
        if hoverToggle.Text ~= text then hoverToggle.Text = text end
        hoverToggle.BackgroundColor3 = state.enabled and color.green or color.blue
        if (not state.enabled or os.clock() >= lastHoverInfoAt) and os.clock() >= hoverReportUntil then
            lastHoverInfoAt = os.clock() + 0.25
            if hoverStatus.Text ~= message then hoverStatus.Text = message end
        end
    end,
})
-- Flight logic: retain the same controls and speed range as target-locator.lua.
local flight, flyPressed, flySpeed = nil, {}, 70
local function stopFlight(message)
    local previous = flight
    flight = nil
    table.clear(flyPressed)
    if previous then
        -- Destroy constraints before their attachment, including partially created sessions.
        for index = #previous.objects, 1, -1 do
            pcall(function() previous.objects[index]:Destroy() end)
        end
        if previous.root.Parent then
            previous.root.AssemblyLinearVelocity = Vector3.zero
            previous.root.AssemblyAngularVelocity = Vector3.zero
        end
        if previous.humanoid.Parent then
            previous.humanoid.AutoRotate = previous.autoRotate
            previous.humanoid.PlatformStand = previous.platformStand
            if previous.humanoid.Health > 0 and not previous.platformStand then
                previous.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    end
    flyButton.Text = "FLIGHT: OFF — กดเพื่อบิน"
    flyButton.BackgroundColor3 = color.blue
    flyStatus.Text = message or "ปิดบินแล้ว • เดินได้ตามปกติ"
end
local function startFlight()
    if flight then return end
    local character, humanoid, root = ownCharacter()
    if not root then flyStatus.Text = "รอตัวละครเกิดก่อนครับ" return end
    if humanoid.SeatPart then flyStatus.Text = "ลงจากที่นั่งก่อนเปิดบินครับ" return end
    if root.Anchored then flyStatus.Text = "รอเกมปลดล็อกตัวละครก่อนเปิดบินครับ" return end
    if hoverController.state.enabled then hoverController.stop() end
    controller.stop()
    table.clear(flyPressed)
    flight = {character = character, humanoid = humanoid, root = root,
        autoRotate = humanoid.AutoRotate, platformStand = humanoid.PlatformStand, objects = {}}
    local function own(object)
        flight.objects[#flight.objects + 1] = object
        return object
    end
    local attachment = own(Instance.new("Attachment"))
    attachment.Name, attachment.Parent = "AutoSkillFlightAttachment", root
    local velocity = own(Instance.new("LinearVelocity"))
    velocity.Enabled = false
    velocity.Name = "AutoSkillFlightVelocity"
    velocity.Attachment0 = attachment
    velocity.RelativeTo = Enum.ActuatorRelativeTo.World
    velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    velocity.ForceLimitsEnabled = true
    velocity.MaxForce = math.max(root.AssemblyMass, 1) * math.max(workspace.Gravity, 1) * 4
    velocity.VectorVelocity = Vector3.zero
    velocity.Parent = root
    local orientation = own(Instance.new("AlignOrientation"))
    orientation.Enabled = false
    orientation.Name = "AutoSkillFlightOrientation"
    orientation.Attachment0 = attachment
    orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    orientation.RigidityEnabled = false
    orientation.MaxTorque = math.max(root.AssemblyMass, 1) * 4000
    orientation.MaxAngularVelocity = 8
    orientation.Responsiveness = 20
    orientation.CFrame = root.CFrame.Rotation
    orientation.Parent = root
    local support = own(Instance.new("VectorForce"))
    support.Enabled = false
    support.Name = "AutoSkillFlightCastSupport"
    support.Attachment0 = attachment
    support.RelativeTo = Enum.ActuatorRelativeTo.World
    support.ApplyAtCenterOfMass = true
    support.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity, 0)
    support.Parent = root
    flight.velocity, flight.orientation, flight.support = velocity, orientation, support
    flight.casting, flight.castFrame, flight.castPendingUntil = false, nil, 0
    humanoid.AutoRotate, humanoid.PlatformStand = false, true
    root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
    orientation.Enabled, velocity.Enabled = true, true
    flyButton.Text, flyButton.BackgroundColor3 = "FLIGHT: ON — กดเพื่อหยุด", color.green
    flyStatus.Text = "กำลังบิน • W/A/S/D + Space / Ctrl\nยุบหน้าต่างแล้วบินต่อได้"
end
local function clearFlightInput()
    table.clear(flyPressed)
    if flight and flight.velocity then flight.velocity.VectorVelocity = Vector3.zero end
end
local function captureFlightCast()
    local f = flight
    if not f or not f.root.Parent then return end
    local now = os.clock()
    if not f.casting and now >= f.castPendingUntil then f.castFrame = f.root.CFrame end
    f.castPendingUntil = now + 0.35
    table.clear(flyPressed)
    f.velocity.VectorVelocity = Vector3.zero
end
session.captureFlightCast = captureFlightCast
local function stepFlight()
    if not flight then return end
    local f = flight
    if player.Character ~= f.character or not f.root:IsDescendantOf(workspace)
        or f.humanoid.Health <= 0 or f.humanoid.SeatPart then
        stopFlight("หยุดบินแล้ว • เปิดใหม่เมื่อตัวละครพร้อมครับ")
        return
    end
    local casting = os.clock() < f.castPendingUntil or f.root.Anchored or skillAnimationBusy(f.humanoid)
    if casting ~= f.casting then
        f.casting = casting
        f.velocity.Enabled, f.orientation.Enabled = not casting, not casting
        if casting then f.humanoid.PlatformStand = f.platformStand
        else f.humanoid.PlatformStand = true end
        if casting then
            f.castFrame = f.castFrame or f.root.CFrame
            clearFlightInput()
            flyStatus.Text = "ใช้สกิลอยู่ • ล็อกตำแหน่งเดิม\nสกิลจบแล้วบินต่อได้ • F1 ปิดบิน"
        else
            f.castFrame = nil
            flyStatus.Text = "กำลังบิน • W/A/S/D + Space / Ctrl\nF1 ปิดบิน • F3 เปิด/ปิด Auto Skill"
        end
    end
    f.support.Enabled = casting and not f.root.Anchored
    if casting then
        -- Keep the saved transform; root motion must not carry the player away while casting.
        f.support.Force = Vector3.new(0, f.root.AssemblyMass * workspace.Gravity, 0)
        if f.castFrame then f.root.CFrame = f.castFrame end
        f.root.AssemblyLinearVelocity = Vector3.zero
        f.root.AssemblyAngularVelocity = Vector3.zero
        return
    end
    local camera = workspace.CurrentCamera
    if not camera then f.velocity.VectorVelocity = Vector3.zero return end
    local look = camera.CFrame.LookVector
    local forward = Vector3.new(look.X, 0, look.Z)
    if forward.Magnitude < 0.001 then
        local right = camera.CFrame.RightVector
        forward = Vector3.new(right.Z, 0, -right.X)
    end
    forward = forward.Unit
    local right, movement = Vector3.new(-forward.Z, 0, forward.X), Vector3.zero
    if gameFocused() and not UserInputService:GetFocusedTextBox() and not GuiService.MenuIsOpen then
        if flyPressed[Enum.KeyCode.W] then movement = movement + forward end
        if flyPressed[Enum.KeyCode.S] then movement = movement - forward end
        if flyPressed[Enum.KeyCode.D] then movement = movement + right end
        if flyPressed[Enum.KeyCode.A] then movement = movement - right end
        if flyPressed[Enum.KeyCode.Space] then movement = movement + Vector3.yAxis end
        if flyPressed[Enum.KeyCode.LeftControl] or flyPressed[Enum.KeyCode.RightControl] then
            movement = movement - Vector3.yAxis
        end
    end
    if movement.Magnitude > 1 then movement = movement.Unit end
    f.velocity.VectorVelocity = movement * flySpeed
    f.orientation.CFrame = CFrame.lookAt(Vector3.zero, forward)
end
-- Flight event wiring.
local function toggleFlight()
    if flight then stopFlight() return end
    local ok, err = pcall(startFlight)
    if not ok then
        stopFlight("เปิดบินไม่สำเร็จ • ดู Error ใน Console")
        warn("Auto Skill Flight:", err)
    end
end
flyButton.Activated:Connect(toggleFlight)
local function changeFlySpeed(delta)
    flySpeed = math.clamp(flySpeed + delta, 20, 200)
    flySpeedLabel.Text = "Speed: " .. flySpeed .. " studs/s"
end
flySlower.Activated:Connect(function() changeFlySpeed(-10) end)
flyFaster.Activated:Connect(function() changeFlySpeed(10) end)
table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
    if not flight or processed or not gameFocused() or GuiService.MenuIsOpen
        or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == keyCodes[1] or input.KeyCode == keyCodes[2] or input.KeyCode == keyCodes[3] then
        captureFlightCast()
    end
    flyPressed[input.KeyCode] = true
end))
table.insert(connections, UserInputService.InputEnded:Connect(function(input)
    if hotkeys then hotkeys.finish(input) end
    flyPressed[input.KeyCode] = nil
end))
table.insert(connections, RunService.RenderStepped:Connect(function()
    if closed or not flight then return end
    local ok, err = pcall(stepFlight)
    if not ok then
        stopFlight("หยุดบินเพราะ Error • ดู Console")
        warn("Auto Skill Flight:", err)
    end
end))
-- End flight logic.

local function setHoverConfig()
    hoverController.configure(hoverHeight.Text, hoverRadius.Text)
    hoverHeight.Text = tostring(hoverController.state.height)
    hoverRadius.Text = tostring(hoverController.state.radius)
end
hoverHeight.FocusLost:Connect(setHoverConfig)
hoverRadius.FocusLost:Connect(setHoverConfig)
local function toggleHover()
    focused = true
    if hoverController.state.enabled then
        hoverController.stop()
    else
        stopFlight("ปิดบินเพื่อยืนบนหัวมอน")
        setHoverConfig()
        hoverController.start()
    end
end
hoverToggle.Activated:Connect(toggleHover)
hoverNext.Activated:Connect(function()
    if hoverController.state.enabled then hoverController.next()
    else hoverStatus.Text = "เปิดยืนบนหัวก่อน แล้วค่อยเลือกตัวถัดไปครับ" end
end)
-- A bounded report is collected only when Scan is clicked, never every frame.
local function hoverDiagnostic(entries)
    local lines = {"NPC Hover v1.5", "Health-positive targets: " .. #entries,
        string.format("Nameplates: %d; unmapped: %d; no health source: %d",
            hoverScanStats.plates or 0, hoverScanStats.unmapped or 0, hoverScanStats.noHealth or 0)}
    for index = 1, math.min(15, #entries) do
        local entry = entries[index]
        lines[#lines + 1] = string.format("TARGET %s | %.0f studs | %s=%.1f | immune=%s | %s",
            entry.displayName, entry.distance, entry.source.label, sourceHealth(entry.source),
            tostring(entry.immune), entry.path)
    end
    local count = 0
    for plate in pairs(hoverBillboards) do
        local snapshot = readPlate(plate)
        if snapshot and #snapshot.texts > 0 and count < 30 then
            count = count + 1
            local model = plateActor(plate)
            local adorn = plate.Adornee
            lines[#lines + 1] = "PLATE " .. plate:GetFullName() .. " | actor=" ..
                (model and model:GetFullName() or "unmapped") .. " | adorn=" ..
                (adorn and adorn:GetFullName() or "parent") .. " | " .. table.concat(snapshot.texts, " / "):sub(1, 250)
        end
    end
    local _, _, root = ownCharacter()
    local nearby = {}
    if root then
        for model in pairs(hoverModels) do
            if model:IsA("Model") and not isPlayerModel(model) then
                -- Direct body parts only: do not traverse entire room/map container models.
                local part = model.PrimaryPart
                if not bodyPart(part, model) then
                    part = nil
                    for _, child in ipairs(model:GetChildren()) do
                        if bodyPart(child, model) then part = child break end
                    end
                end
                if part then
                    local distance = (part.Position - root.Position).Magnitude
                    if distance <= hoverController.state.radius then
                        nearby[#nearby + 1] = {model = model, part = part, distance = distance}
                    end
                end
            end
        end
    end
    table.sort(nearby, function(a, b) return a.distance < b.distance end)
    for index = 1, math.min(25, #nearby) do
        local item, details = nearby[index], {}
        for key, value in pairs(item.model:GetAttributes()) do
            local lower = string.lower(key)
            if lower:find("hp", 1, true) or lower:find("health", 1, true) or lower:find("dead", 1, true)
                or lower:find("name", 1, true) or lower:find("enemy", 1, true) then
                details[#details + 1] = key .. "=" .. tostring(value)
            end
        end
        for _, child in ipairs(item.model:GetChildren()) do
            details[#details + 1] = child.ClassName .. ":" .. child.Name
            if #details >= 18 then break end
        end
        lines[#lines + 1] = string.format("MODEL %s | %.0f studs | body=%s | %s",
            item.model:GetFullName(), item.distance, item.part.Name, table.concat(details, ", "))
    end
    -- Include relevant projected ScreenGui labels if this game does not use BillboardGui.
    count = 0
    for _, object in ipairs(playerGui:GetDescendants()) do
        if object:IsA("TextLabel") and object.Visible and not object:IsDescendantOf(gui) then
            local text = cleanPlateText(object.Text)
            local lower = string.lower(text)
            if (text:find("[LV", 1, true) or lower:find("immune", 1, true)
                or lower:find("spirit duck", 1, true) or lower:find("no-face", 1, true)) and count < 20 then
                count = count + 1
                lines[#lines + 1] = "GUI " .. object:GetFullName() .. " | " .. text:sub(1, 200)
            end
        end
    end
    return table.concat(lines, "\n"):sub(1, 14000)
end

hoverScan.Activated:Connect(function()
    setHoverConfig()
    refreshHoverModels()
    local entries = hoverController.scan()
    local lines = {string.format("พบ %d ตัว • นอกระยะ %d • ไม่มีจุดอ้างอิง %d",
        #entries, hoverScanStats.outside or 0, hoverScanStats.noPart or 0)}
    for index = 1, math.min(4, #entries) do
        local entry = entries[index]
        lines[#lines + 1] = string.format("%s • %.0f studs", entry.displayName or entry.model.Name, entry.distance)
    end
    local report = hoverDiagnostic(entries)
    local copied = false
    local copy = setclipboard or toclipboard
    if type(copy) == "function" then copied = pcall(copy, report) end
    print(report)
    lines[#lines + 1] = copied and "คัดลอกข้อมูลแล้ว • ส่งให้ผมได้ครับ" or "ดูข้อมูลสแกนใน Console (F9)"
    hoverReportUntil = os.clock() + 6
    hoverStatus.Text = table.concat(lines, "\n")
end)
local activePage = "skills"
local function showWindowPage(name)
    activePage = name
    hotkeyHint.Visible = not collapsed
    content.Visible = not collapsed and name == "skills"
    hoverPage.Visible = not collapsed and name == "hover"
    flightPage.Visible = not collapsed and name == "flight"
    skillTab.BackgroundColor3 = name == "skills" and color.blue or color.button
    hoverTab.BackgroundColor3 = name == "hover" and color.blue or color.button
    flightTab.BackgroundColor3 = name == "flight" and color.blue or color.button
end
skillTab.Activated:Connect(function() showWindowPage("skills") end)
hoverTab.Activated:Connect(function() showWindowPage("hover") end)
flightTab.Activated:Connect(function() showWindowPage("flight") end)
local nextHoverTick = 0
table.insert(connections, RunService.Heartbeat:Connect(function()
    if closed or not hoverController.state.enabled or os.clock() < nextHoverTick then return end
    nextHoverTick = os.clock() + 0.05
    local ok, err = pcall(function()
        refreshHoverModels()
        hoverController.step()
    end)
    if not ok then
        hoverController.stop()
        hoverStatus.Text = "ยืนบนหัวหยุดเพราะ Error: " .. tostring(err):sub(1, 150)
        warn("NPC Hover:", err)
    end
end))

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
local function toggleSkills()
    focused = true
    if controller.state.enabled then controller.stop() else controller.start() end
end
toggle.Activated:Connect(toggleSkills)

-- Keydown edges only: holding a shortcut must not repeatedly toggle the feature.
local function buildHotkeyController(deps)
    local held, cooldown = {}, {}
    local hotkeys = {}
    function hotkeys.begin(input, processed)
        local key = input.KeyCode
        local action = deps.actions[key]
        if not action or held[key] then return end
        held[key] = true
        if processed or deps.blocked() then return end
        local now = deps.clock()
        if cooldown[key] and now < cooldown[key] then return end
        cooldown[key] = now + 0.25
        local ok, err = pcall(action)
        if not ok then deps.error(err) end
    end
    function hotkeys.finish(input) held[input.KeyCode] = nil end
    function hotkeys.clear() table.clear(held) end
    return hotkeys
end
hotkeys = buildHotkeyController({
    clock = os.clock,
    actions = {
        [Enum.KeyCode.F1] = toggleFlight,
        [Enum.KeyCode.F2] = toggleHover,
        [Enum.KeyCode.F3] = toggleSkills,
    },
    blocked = function()
        return closed or not gameFocused() or GuiService.MenuIsOpen
            or UserInputService:GetFocusedTextBox() ~= nil
    end,
    error = function(err) warn("Auto Skill Hotkey:", err) end,
})
-- Shortcuts share the existing input handlers; no additional input listeners or polling loop.
modeButton.Activated:Connect(function()
    controller.stop()
    local mode = router.cycle()
    gui:SetAttribute("InputModeChoice", mode)
    session.inputMode = mode
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
    skillTab.Visible, hoverTab.Visible, flightTab.Visible = not collapsed, not collapsed, not collapsed
    showWindowPage(activePage)
    panel.Size = UDim2.fromOffset(340, collapsed and 43 or 460)
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
table.insert(connections, UserInputService.TextBoxFocused:Connect(function() controller.release() clearFlightInput() end))
table.insert(connections, GuiService.MenuOpened:Connect(function() controller.release() clearFlightInput() end))
table.insert(connections, UserInputService.WindowFocusReleased:Connect(function()
    focused, dragging = false, false
    hotkeys.clear()
    clearFlightInput()
    controller.release()
    renderStatus()
end))
table.insert(connections, UserInputService.WindowFocused:Connect(function()
    focused = true
    renderStatus()
end))
table.insert(connections, player.CharacterRemoving:Connect(function()
    controller.release()
    stopFlight("ตัวละครหายไป • เปิดบินใหม่หลังเกิดครับ")
end))
local nextTick = 0
table.insert(connections, RunService.Heartbeat:Connect(function()
    if closed or os.clock() < nextTick then return end
    nextTick = os.clock() + 0.05
    local ok, err = pcall(controller.step)
    if not ok then controller.stop() warn("Auto Skill 123:", err) end
end))
session.stops = {
    hotkeys.clear,
    controller.dispose,
    function() stopFlight("ปิดหน้าต่างแล้ว") end,
    function() if hoverController then hoverController.stop() end end,
    function()
        table.clear(hoverHumanoids)
        table.clear(hoverModels)
        table.clear(hoverBillboards)
    end,
}
if closed then cleanupSession() end
