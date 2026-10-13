-- Auto Skill + NPC Hover + Flight v1.22 — lazy, budgeted indexing; no idle map/results scans.
-- Number-row keys only; sends inputs at the configured interval, not cooldown bypasses.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")

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
    Text = "AUTO SKILL / HOVER / FLY v1.22", TextColor3 = color.text,
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
    Position = UDim2.fromOffset(14, 49), Size = UDim2.fromOffset(49, 31),
    BackgroundColor3 = color.blue, BorderSizePixel = 0,
    Text = "Skill", TextColor3 = color.text, TextSize = 12,
}, panel)
local hoverTab = create("TextButton", {
    Position = UDim2.fromOffset(66, 49), Size = UDim2.fromOffset(49, 31),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "ตามมอน", TextColor3 = color.text, TextSize = 11,
}, panel)
local flightTab = create("TextButton", {
    Position = UDim2.fromOffset(118, 49), Size = UDim2.fromOffset(49, 31),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "บิน", TextColor3 = color.text, TextSize = 12,
}, panel)
local autoETab = create("TextButton", {
    Position = UDim2.fromOffset(170, 49), Size = UDim2.fromOffset(49, 31),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "Auto E", TextColor3 = color.text, TextSize = 12,
}, panel)
local resultsTab = create("TextButton", {
    Position = UDim2.fromOffset(222, 49), Size = UDim2.fromOffset(49, 31),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "จบรอบ", TextColor3 = color.text, TextSize = 12,
}, panel)
local routeTab = create("TextButton", {
    Position = UDim2.fromOffset(274, 49), Size = UDim2.fromOffset(49, 31),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "หิน/ทาง", TextColor3 = color.text, TextSize = 11,
}, panel)
local resultsPage, routePage
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
    BackgroundTransparency = 1, TextColor3 = color.muted, TextSize = 10,
    Text = "F1 บิน • F2 ตาม • F3 Skill • F4 E • F5 รอบ • F6 ทาง",
}, panel)
local focused, closed, collapsed = true, false, false
local keyCodes = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three}
local connections = {}
local hotkeys, autoEController, resultsController, progressController, indexer
local routeObjects = {}
local resultButtons, resultLabels = {}, {}
local autoEPrompts, autoEVisible, autoECursor = {}, {}, nil
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
    if progressController and progressController.state.busy then
        return "พักสกิลระหว่างตีหิน/เข้าจุด AREA"
    end
    if resultsController and resultsController.state.visible then
        return "พักสกิลระหว่างหน้าจอจบรอบ"
    end
    if autoEController and autoEController.state.held then
        return "พักสกิลระหว่างกด E โต้ตอบ"
    end
    if not (controller and controller.state.held) and skillAnimationBusy(humanoid) then
        return "รอแอนิเมชันสกิลจบก่อนกดตัวถัดไป"
    end
    if hoverController and hoverController.state.enabled and not hoverController.readyForSkills() then
        return "พักสกิล • รอมอนเกิดหรือรอถึงตำแหน่งที่เลือก"
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
    Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1,
    Text = "เลือกตำแหน่งตามมอน • หันหน้าเข้าหามอน",
    TextColor3 = color.muted, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
}, hoverPage)
local hoverPositionButtons = {}
for index, option in ipairs({{key = "head", label = "บนหัว"}, {key = "front", label = "ด้านหน้า"}, {key = "back", label = "ด้านหลัง"}}) do
    hoverPositionButtons[option.key] = create("TextButton", {
        Position = UDim2.fromOffset((index - 1) * 106, 26), Size = UDim2.fromOffset(100, 30),
        BackgroundColor3 = index == 1 and color.blue or color.button, BorderSizePixel = 0,
        Text = option.label, TextColor3 = color.text, TextSize = 14,
    }, hoverPage)
end
create("TextLabel", {
    Position = UDim2.fromOffset(0, 64), Size = UDim2.fromOffset(205, 29),
    BackgroundTransparency = 1, Text = "ความสูงบนหัว (studs)",
    TextColor3 = color.muted, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
}, hoverPage)
local hoverHeight = create("TextBox", {
    Position = UDim2.new(1, -91, 0, 64), Size = UDim2.fromOffset(91, 29),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "6", TextColor3 = color.text, TextSize = 15, ClearTextOnFocus = false,
}, hoverPage)
create("TextLabel", {
    Position = UDim2.fromOffset(0, 102), Size = UDim2.fromOffset(205, 29),
    BackgroundTransparency = 1, Text = "ระยะหน้า / หลัง (studs)",
    TextColor3 = color.muted, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
}, hoverPage)
local hoverSpacing = create("TextBox", {
    Position = UDim2.new(1, -91, 0, 102), Size = UDim2.fromOffset(91, 29),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "6", TextColor3 = color.muted, TextSize = 15, ClearTextOnFocus = false, TextEditable = false,
}, hoverPage)
create("TextLabel", {
    Position = UDim2.fromOffset(0, 140), Size = UDim2.fromOffset(205, 29),
    BackgroundTransparency = 1, Text = "ระยะค้นหามอน (studs)",
    TextColor3 = color.muted, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
}, hoverPage)
local hoverRadius = create("TextBox", {
    Position = UDim2.new(1, -91, 0, 140), Size = UDim2.fromOffset(91, 29),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "250", TextColor3 = color.text, TextSize = 15, ClearTextOnFocus = false,
}, hoverPage)
local hoverToggle = create("TextButton", {
    Position = UDim2.fromOffset(0, 180), Size = UDim2.new(1, 0, 0, 40),
    BackgroundColor3 = color.blue, BorderSizePixel = 0,
    Text = "ตามมอน: OFF — กดเพื่อเริ่ม", TextColor3 = color.text,
    Font = Enum.Font.GothamBold, TextSize = 16,
}, hoverPage)
local hoverNext = create("TextButton", {
    Position = UDim2.fromOffset(0, 228), Size = UDim2.fromOffset(152, 29),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "เลือกเป้าถัดไป", TextColor3 = color.text, TextSize = 13,
}, hoverPage)
local hoverScan = create("TextButton", {
    Position = UDim2.fromOffset(160, 228), Size = UDim2.fromOffset(152, 29),
    BackgroundColor3 = color.button, BorderSizePixel = 0,
    Text = "สแกน + ข้อมูล", TextColor3 = color.text, TextSize = 13,
}, hoverPage)
local hoverStatus = create("TextLabel", {
    Position = UDim2.fromOffset(0, 271), Size = UDim2.new(1, 0, 0, 75),
    BackgroundTransparency = 1, TextColor3 = color.muted, TextSize = 12, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    Text = "F2 เปิด/ปิดตามมอน • เลือกบนหัว/หน้า/หลัง\nระยะหน้า/หลังวัดจากขอบตัวมอน\nเปลี่ยนตำแหน่งได้ระหว่างเปิดอยู่",
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
    Text = "W / A / S / D   เคลื่อนที่ตามมุมกล้อง\nSpace   บินขึ้น\nCtrl   บินลง\nปล่อยปุ่ม   ลอยอยู่กับที่\nเปิดบินแล้วทะลุกำแพงได้",
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
local function combatTarget(model, plate, snapshot)
    if model:GetAttribute("RubbleHealth") ~= nil or model:GetAttribute("RubbleMaxHealth") ~= nil then return false end
    local title = snapshot and snapshot.title or model.Name
    if tostring(title):lower():match("^rubble") or (plate and plate.Name:lower():find("rubble", 1, true)) then return false end
    local cursor = model
    while cursor and cursor ~= workspace do
        local name = cursor.Name:lower()
        if name == "effects" or name == "effect" then return false end
        cursor = cursor.Parent
    end
    -- The verified game's combatants live in workspace.enemies. Do not treat map health objects as mobs.
    local enemies = workspace:FindFirstChild("enemies")
    if enemies and not model:IsDescendantOf(enemies) and not enemyFolderHint(model)
        and model:GetAttribute("IsEnemy") ~= true and model:GetAttribute("IsBoss") ~= true
        and not (plate and plate.Name:lower() == "enemybar") then return false end
    return true
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
local combatBars = setmetatable({}, {__mode = "k"})
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
    if source.kind == "combat" then
        local realHealth = sourceHealth(source.base)
        if realHealth <= 0 or not source.plate.Parent then return 0 end
        local owner = plateActor(source.plate)
        if not owner or (owner ~= source.model and not owner:IsDescendantOf(source.model)) then return 0 end
        local snapshot = readPlate(source.plate)
        if snapshot and snapshot.health ~= nil then return math.min(realHealth, snapshot.health) end
        -- A hidden/offscreen bar is not proof of death. Preserve real health until it reappears.
        return realHealth
    elseif source.kind == "humanoid" then value = source.object.Health
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
local function trackRouteObject(object)
    if object:IsA("Model") or object:IsA("BasePart") or object:IsA("Attachment") then
        local name = object.Name:lower():gsub("[%s_%-]", "")
        if name:find("rubble", 1, true) or name:find("area", 1, true) then routeObjects[object] = true end
    end
end
local function trackPlate(object)
    if not object:IsDescendantOf(gui) then
        if object:IsA("GuiButton") then resultButtons[object] = true end
        if object:IsA("TextLabel") or object:IsA("TextButton") then resultLabels[object] = true end
    end
    if resultsController then resultsController.dirty(object) end
    if object:IsA("BillboardGui") then hoverBillboards[object] = true end
    dirtyGeometry(object)
end
local function untrack(object)
    dirtyGeometry(object)
    hoverHumanoids[object], hoverBillboards[object], hoverModels[object] = nil, nil, nil
    rigCache[object], plateCache[object] = nil, nil
    if modelCursor == object then modelCursor = nil end
    autoEPrompts[object], autoEVisible[object], resultButtons[object], resultLabels[object] = nil, nil, nil, nil
    if resultsController then resultsController.dirty(object) end
    if autoECursor == object then autoECursor = nil end
    routeObjects[object] = nil
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
-- Indexing is dormant at startup. Each active subsystem gets only its own classes.
-- Tree traversal yields between frames, including very wide folders.
do
    local function buildBudgetWalker(deps)
        local walk = {stack = {}, seen = setmetatable({}, {__mode = "k"})}
        function walk.add(object)
            if not object or walk.seen[object] or deps.skip(object) then return end
            walk.seen[object] = true
            walk.stack[#walk.stack + 1] = {object = object, cursor = 0}
        end
        function walk.remove(object) walk.seen[object] = nil end
        function walk.clear()
            table.clear(walk.stack)
            table.clear(walk.seen)
        end
        function walk.pump(limit, deadline)
            local visits = 0
            for _ = 1, limit * 3 do
                if visits >= limit or deps.clock() >= deadline then break end
                local frame = walk.stack[#walk.stack]
                if not frame then break end
                if not frame.object.Parent and not deps.root(frame.object) then
                    walk.stack[#walk.stack] = nil
                elseif not frame.children then
                    deps.visit(frame.object)
                    -- One folder at a time; never allocate the entire descendant tree.
                    frame.children = frame.object:GetChildren()
                    visits = visits + 1
                else
                    frame.cursor = frame.cursor + 1
                    local child = frame.children[frame.cursor]
                    if child then walk.add(child)
                    else walk.stack[#walk.stack] = nil end
                end
            end
            return visits
        end
        function walk.pending() return #walk.stack > 0 end
        return walk
    end
    local wants, forced, signals = {}, {}, {}
    local worldWalk = buildBudgetWalker({
        clock = os.clock, root = function(object) return object == workspace end,
        skip = function() return false end,
        visit = function(object)
            if wants.route then trackRouteObject(object) end
            if wants.hover then
                if object:IsA("Humanoid") or object:IsA("AnimationController") then hoverHumanoids[object] = true
                elseif object:IsA("Model") then hoverModels[object] = true end
            end
            if (wants.hover or wants.route) and object:IsA("BillboardGui") then hoverBillboards[object] = true end
            if wants.e and object:IsA("ProximityPrompt") then autoEPrompts[object] = true end
            if wants.hover or wants.route then dirtyGeometry(object) end
        end,
    })
    local guiWalk = buildBudgetWalker({
        clock = os.clock, root = function(object) return object == playerGui end,
        skip = function(object) return object == gui or object:IsDescendantOf(gui) end,
        visit = function(object)
            if wants.gui then trackPlate(object) end
        end,
    })
    local function disconnect(scope)
        for _, connection in ipairs(signals[scope] or {}) do connection:Disconnect() end
        signals[scope] = nil
    end
    local function seedWorld()
        worldWalk.clear()
        worldWalk.add(workspace)
        -- Index likely actor folders first so targets can be found before decorative map parts.
        local world = workspace:FindFirstChild("World")
        for _, name in ipairs({"Enemies", "enemies", "Mobs", "NPCs", "Bosses"}) do
            worldWalk.add(workspace:FindFirstChild(name))
            if world then worldWalk.add(world:FindFirstChild(name)) end
        end
    end
    local function seedGui()
        guiWalk.clear()
        guiWalk.add(playerGui)
        for _, name in ipairs({"EndScreen", "RoundHUD", "NextAreaChip", "RubbleBar"}) do
            guiWalk.add(playerGui:FindFirstChild(name))
        end
    end
    indexer = {}
    function indexer.step()
        local now = os.clock()
        local function requested(key, controller)
            return controller and controller.state.enabled or (forced[key] or 0) > now
        end
        local nextWants = {
            hover = requested("hover", hoverController),
            e = requested("e", autoEController),
            route = requested("route", progressController),
            gui = requested("gui", resultsController),
        }
        nextWants.gui = nextWants.gui or nextWants.hover or nextWants.route
        local worldActive = nextWants.hover or nextWants.e or nextWants.route
        local rebuild = (nextWants.hover and not wants.hover) or (nextWants.e and not wants.e)
            or (nextWants.route and not wants.route)
        local rebuildGui = nextWants.gui and not wants.gui
        if wants.hover and not nextWants.hover then
            table.clear(hoverHumanoids) table.clear(hoverModels) modelCursor = nil
        end
        if wants.e and not nextWants.e then table.clear(autoEPrompts) autoECursor = nil end
        if wants.route and not nextWants.route then table.clear(routeObjects) end
        if not nextWants.hover and not nextWants.route then table.clear(hoverBillboards) end
        if wants.gui and not nextWants.gui then
            table.clear(resultButtons) table.clear(resultLabels)
        end
        wants = nextWants
        if worldActive then
            if not signals.world then
                signals.world = {
                    workspace.DescendantAdded:Connect(worldWalk.add),
                    workspace.DescendantRemoving:Connect(function(object)
                        worldWalk.remove(object) untrack(object)
                    end),
                }
            end
            if rebuild then seedWorld() end
        else
            disconnect("world")
            worldWalk.clear()
        end
        if wants.gui then
            if not signals.gui then
                signals.gui = {
                    playerGui.DescendantAdded:Connect(function(object)
                        -- Structural label changes invalidate cached captions, but traversal stays budgeted.
                        if resultsController then resultsController.dirty(object) end
                        guiWalk.add(object)
                    end),
                    playerGui.DescendantRemoving:Connect(function(object)
                        guiWalk.remove(object) untrack(object)
                    end),
                }
            end
            if rebuildGui then seedGui() end
        else
            disconnect("gui")
            guiWalk.clear()
        end
        local deadline = os.clock() + 0.001
        -- Reserve time for HUD indexing even while the world has a large backlog.
        guiWalk.pump(12, math.min(deadline, os.clock() + 0.0004))
        worldWalk.pump(24, deadline)
    end
    function indexer.scan(kind)
        forced[kind] = os.clock() + 10
        indexer.step()
        local untilTime = os.clock() + 5
        while not closed and (worldWalk.pending() or guiWalk.pending()) and os.clock() < untilTime do
            task.wait(0.05) -- Heartbeat drains the index; never block the frame to finish a manual report.
        end
        if worldWalk.pending() or guiWalk.pending() then
            warn("Autokey: index still loading; scan report may be partial. Scan again after a few seconds.")
        end
    end
    function indexer.stop()
        disconnect("world") disconnect("gui")
        worldWalk.clear() guiWalk.clear()
        table.clear(forced)
    end
end

local function scanHoverTargets(radius, skipped)
    local _, _, root = ownCharacter()
    if not root then return {} end
    local byPart, entries, seenModel, observed, mappedPlates = {}, {}, {}, {}, {}
    local now = os.clock()
    hoverScanStats = {outside = 0, noPart = 0, friendly = 0, noHealth = 0, plates = 0, unmapped = 0, nonCombat = 0}
    -- Collect live bars before admitting humanoids whose Health can remain at a placeholder 100.
    for plate in pairs(hoverBillboards) do
        local model, anchor = plateActor(plate)
        local near = model and not isPlayerModel(model)
        if near then
            local part = anchor:IsA("BasePart") and anchor or model.PrimaryPart
            if part and (part.Position - root.Position).Magnitude > radius then near = false end
        end
        local snapshot = near and readPlate(plate)
        if snapshot and snapshot.health ~= nil then
            hoverScanStats.plates = hoverScanStats.plates + 1
            local resolved, humanoid, source = resolveActor(model)
            if resolved and anchor:IsDescendantOf(resolved) then model = resolved end
            if plate.Name:lower() == "enemybar" then combatBars[model] = plate end
            local data = {model = model, humanoid = humanoid, source = source, plate = plate, snapshot = snapshot}
            local previous = observed[model]
            if not previous or plate.Name:lower() == "enemybar" then observed[model] = data end
            mappedPlates[#mappedPlates + 1] = data
        elseif not model then
            hoverScanStats.unmapped = hoverScanStats.unmapped + 1
        end
    end
    local function include(model, humanoid, source, plate, snapshot)
        if not model or not model:IsDescendantOf(workspace) or isPlayerModel(model) then return end
        local data = observed[model]
        if data then plate, snapshot = data.plate, data.snapshot end
        plate = plate or combatBars[model]
        if not combatTarget(model, plate, snapshot) then
            hoverScanStats.nonCombat = hoverScanStats.nonCombat + 1
            return
        end
        if model:GetAttribute("Dead") == true or model:GetAttribute("IsDead") == true then return end
        if friendlyModel(model) then hoverScanStats.friendly = hoverScanStats.friendly + 1 return end
        if sourceHealth(source) <= 0 or (snapshot and snapshot.health ~= nil and snapshot.health <= 0) then return end
        if plate and plate.Name:lower() == "enemybar" and source.kind ~= "nameplate" then
            source = {kind = "combat", object = source.object, base = source, plate = plate, model = model,
                label = source.label .. " + enemyBar"}
            if sourceHealth(source) <= 0 then return end
        end
        local part, head = targetParts(model, humanoid)
        if not part then hoverScanStats.noPart = hoverScanStats.noPart + 1 return end
        local previous = byPart[part]
        if previous then return end
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
    for _, data in ipairs(mappedPlates) do
        local source = data.source or {kind = "nameplate", object = data.plate, label = "Nameplate HP"}
        include(data.model, data.humanoid, source, data.plate, data.snapshot)
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
        if snapshot and snapshot.health ~= nil and snapshot.health <= 0 then return false end
        if not combatTarget(entry.model, entry.nameplate, snapshot) then return false end
    end
    if not entry or not entry.model:IsDescendantOf(workspace) or sourceHealth(entry.source) <= 0
        or entry.model:GetAttribute("Dead") == true or entry.model:GetAttribute("IsDead") == true then return false end
    local part = targetParts(entry.model, entry.rigHumanoid)
    if not part then return false end
    entry.part = part
    return true
end
local function destination(entry, height, mode, spacing)
    local root, head = targetParts(entry.model, entry.rigHumanoid)
    if not root then return nil end
    if mode == "front" or mode == "back" then
        local cached = rigCache[entry.model]
        local look = root.CFrame.LookVector
        local forward = Vector3.new(look.X, 0, look.Z)
        if forward.Magnitude < 0.001 then
            local right = root.CFrame.RightVector
            forward = Vector3.new(right.Z, 0, -right.X)
        end
        forward = forward.Unit
        if not cached.sideAt or os.clock() >= cached.sideAt then
            local front, back, bottom = 0, 0, 0
            local first = true
            for _, part in ipairs(cached.body or {}) do
                if bodyPart(part, entry.model) and (part == root or (part.Transparency or 0) < 0.95) then
                    local frame, size = part.CFrame, part.Size
                    local extent = math.abs(forward:Dot(frame.RightVector)) * size.X * 0.5
                        + math.abs(forward:Dot(frame.UpVector)) * size.Y * 0.5
                        + math.abs(forward:Dot(frame.LookVector)) * size.Z * 0.5
                    local shift = (part.Position - root.Position):Dot(forward)
                    front = math.max(front, shift + extent)
                    back = math.max(back, extent - shift)
                    local yExtent = math.abs(frame.RightVector.Y) * size.X * 0.5
                        + math.abs(frame.UpVector.Y) * size.Y * 0.5
                        + math.abs(frame.LookVector.Y) * size.Z * 0.5
                    local floorOffset = part.Position.Y - yExtent - root.Position.Y
                    if first or floorOffset < bottom then bottom = floorOffset end
                    first = false
                end
            end
            cached.frontExtent, cached.backExtent, cached.bottomOffset = front, back, bottom
            cached.sideAt = os.clock() + 0.50
        end
        local _, humanoid, playerRoot = ownCharacter()
        local playerHeight = (humanoid and humanoid.HipHeight or 0) + (playerRoot and playerRoot.Size.Y * 0.5 or 2)
        local distance = (mode == "front" and cached.frontExtent or cached.backExtent) + (spacing or 6)
        local sign = mode == "front" and 1 or -1
        local point = root.Position + forward * (distance * sign)
        return Vector3.new(point.X, root.Position.Y + cached.bottomOffset + playerHeight, point.Z)
    end
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
        height = 6, radius = 250, nextScan = 0, placedSince = nil, nextInfo = 0, mode = "head", spacing = 6}
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
        notify("หยุดตามมอนแล้ว • เดินได้ตามปกติ")
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
    function hover.configure(height, radius, mode, spacing)
        local oldHeight, oldRadius, oldMode, oldSpacing = state.height, state.radius, state.mode, state.spacing
        local h, r = tonumber(height), tonumber(radius)
        if h and h == h then state.height = math.max(3, math.min(50, h)) end
        if r and r == r then state.radius = math.max(20, math.min(600, r)) end
        if mode == "head" or mode == "front" or mode == "back" then state.mode = mode end
        local gap = tonumber(spacing)
        if gap and gap == gap then state.spacing = math.max(2, math.min(50, gap)) end
        if state.height ~= oldHeight or state.radius ~= oldRadius or state.mode ~= oldMode or state.spacing ~= oldSpacing then
            state.ready, state.placedSince, state.nextInfo = false, nil, 0
            deps.releaseSkills()
        end
    end
    function hover.suspendForRoute()
        clearTarget()
        state.nextScan = 0
        deps.releaseSkills()
    end
    function hover.readyForSkills()
        return state.enabled and state.ready and state.target ~= nil
            and deps.alive(state.target) and deps.inPosition(state.target, state.height, state.mode, state.spacing)
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
                notify("ไม่มีมอนต่อสู้ในระยะ • รอเกิดชุดใหม่\nหยุดวาร์ปแล้ว • ขยับเองได้ตามปกติ • ระยะ " .. state.radius .. " studs")
                return
            end
            state.target = entries[1]
            state.ready, state.placedSince = false, nil
        end
        local switched = state.placedSince == nil
        local moved, message = deps.follow(state.target, state.height, switched, state.mode, state.spacing)
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
            notify(deps.describe(state.target, state.ready, state.mode))
        end
    end
    return hover
end

hoverController = buildHoverController({
    clock = os.clock, scan = scanHoverTargets, alive = targetAlive,
    releaseSkills = controller.release,
    playerReady = function()
        if progressController and progressController.combatTransition and progressController.combatTransition() then
            hoverController.suspendForRoute()
            return false, "จัดการมอนครบแล้ว • รอชุดใหม่\nF2 จะไม่เลือกหินหรือจุด AREA"
        end
        local _, humanoid = ownCharacter()
        if not humanoid then return false, "รอตัวละครเกิดใหม่" end
        if humanoid.SeatPart then return false, "ลงจากที่นั่งก่อนครับ" end
        return true
    end,
    inPosition = function(entry, height, mode, spacing)
        local _, _, root = ownCharacter()
        local point = destination(entry, height, mode, spacing)
        return root and point and (root.Position - point).Magnitude <= 8
    end,
    follow = function(entry, height, switching, mode, spacing)
        local _, humanoid, root = ownCharacter()
        local point = destination(entry, height, mode, spacing)
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
        if mode == "front" or mode == "back" then
            local aim = Vector3.new(entry.part.Position.X, point.Y, entry.part.Position.Z)
            root.CFrame = CFrame.lookAt(point, aim)
            if switching then
                local camera = workspace.CurrentCamera
                local direction = aim - point
                if camera and camera.CameraType ~= Enum.CameraType.Scriptable and direction.Magnitude > 0.001 then
                    camera.CFrame = CFrame.lookAt(point - direction.Unit * 12 + Vector3.new(0, 5, 0), entry.part.Position)
                end
            end
        else
            root.CFrame = CFrame.new(point) * root.CFrame.Rotation
        end
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        return true
    end,
    describe = function(entry, ready, mode)
        local position = mode == "front" and "ด้านหน้า" or (mode == "back" and "ด้านหลัง" or "บนหัว")
        return string.format("เป้า: %s • %s\nHP: %.0f • %s\n%s",
            entry.displayName or entry.model.Name, position, sourceHealth(entry.source),
            ready and "ถึงตำแหน่งแล้ว" or "รอให้อยู่ในตำแหน่งก่อนกดสกิล", entry.path)
    end,
    notify = function(state, message)
        if closed then return end
        local text = state.enabled and "ตามมอน: ON — กดเพื่อหยุด" or "ตามมอน: OFF — กดเพื่อเริ่ม"
        if hoverToggle.Text ~= text then hoverToggle.Text = text end
        hoverToggle.BackgroundColor3 = state.enabled and color.green or color.blue
        if (not state.enabled or os.clock() >= lastHoverInfoAt) and os.clock() >= hoverReportUntil then
            lastHoverInfoAt = os.clock() + 0.25
            if hoverStatus.Text ~= message then hoverStatus.Text = message end
        end
    end,
})
-- Flight logic: retain the same controls and speed range as target-locator.lua.
-- Collision state is indexed on flight start, not by a character/map scan each frame.
local function buildFlightCollisionController(character)
    local saved, ownedConnections = {}, {}
    local active = false
    local collision = {}
    local function restore(part)
        local original = saved[part]
        saved[part] = nil
        if original ~= nil then pcall(function() part.CanCollide = original end) end
    end
    local function add(part)
        if not active or not part:IsA("BasePart") or not part:IsDescendantOf(character) then return end
        if saved[part] == nil then saved[part] = part.CanCollide end
        if part.CanCollide then part.CanCollide = false end
    end
    function collision.start()
        if active then return end
        active = true
        ownedConnections[#ownedConnections + 1] = character.DescendantAdded:Connect(add)
        ownedConnections[#ownedConnections + 1] = character.DescendantRemoving:Connect(function(part) restore(part) end)
        for _, part in ipairs(character:GetDescendants()) do add(part) end
    end
    function collision.step()
        if not active then return end
        for part in pairs(saved) do
            if not part.Parent or not part:IsDescendantOf(character) then restore(part)
            elseif part.CanCollide then part.CanCollide = false end
        end
    end
    function collision.stop()
        active = false
        for _, connection in ipairs(ownedConnections) do connection:Disconnect() end
        table.clear(ownedConnections)
        for part in pairs(saved) do restore(part) end
    end
    return collision
end

local flight, flyPressed, flySpeed = nil, {}, 70
local function stopFlight(message)
    local previous = flight
    flight = nil
    table.clear(flyPressed)
    if previous then
        if previous.collision then pcall(previous.collision.stop) end
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
    velocity.ForceLimitsEnabled = false
    velocity.VectorVelocity = Vector3.zero
    velocity.Parent = root
    local orientation = own(Instance.new("AlignOrientation"))
    orientation.Enabled = false
    orientation.Name = "AutoSkillFlightOrientation"
    orientation.Attachment0 = attachment
    orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    orientation.RigidityEnabled = true
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
    flight.collision = buildFlightCollisionController(character)
    flight.collision.start()
    humanoid.AutoRotate, humanoid.PlatformStand = false, true
    root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
    orientation.Enabled, velocity.Enabled = true, true
    flyButton.Text, flyButton.BackgroundColor3 = "FLIGHT: ON — กดเพื่อหยุด", color.green
    flyStatus.Text = "กำลังบิน • W/A/S/D + Space / Ctrl\nบินทะลุกำแพงได้ • F1 ปิดบิน"
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
    -- Only a captured skill key arms the cast lock; unrelated idle/action poses must not freeze flight.
    local casting = os.clock() < f.castPendingUntil or f.root.Anchored
        or (f.castFrame ~= nil and skillAnimationBusy(f.humanoid))
    if casting ~= f.casting then
        f.casting = casting
        f.velocity.Enabled, f.orientation.Enabled = not casting, not casting
        if casting then f.humanoid.PlatformStand = f.platformStand
        else f.humanoid.PlatformStand = true end
        if casting then
            f.castFrame = f.castFrame or f.root.CFrame
            f.velocity.VectorVelocity = Vector3.zero
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
    if progressController and progressController.state.busy then progressController.stop(false) end
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
table.insert(connections, RunService.PreSimulation:Connect(function()
    if closed or not flight or not flight.collision then return end
    if player.Character ~= flight.character or flight.humanoid.Health <= 0 then
        stopFlight("หยุดบินแล้ว • เปิดใหม่เมื่อตัวละครพร้อมครับ")
        return
    end
    local ok, err = pcall(flight.collision.step)
    if not ok then
        stopFlight("หยุดบินเพราะ Error ของการชน • ดู Console")
        warn("Auto Skill Flight collision:", err)
    end
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

local function setHoverConfig(mode)
    if type(mode) ~= "string" then mode = hoverController.state.mode end
    hoverController.configure(hoverHeight.Text, hoverRadius.Text, mode, hoverSpacing.Text)
    hoverHeight.Text = tostring(hoverController.state.height)
    hoverRadius.Text = tostring(hoverController.state.radius)
    hoverSpacing.Text = tostring(hoverController.state.spacing)
    local onHead = hoverController.state.mode == "head"
    hoverHeight.TextEditable, hoverSpacing.TextEditable = onHead, not onHead
    hoverHeight.TextColor3 = onHead and color.text or color.muted
    hoverSpacing.TextColor3 = onHead and color.muted or color.text
    for key, button in pairs(hoverPositionButtons) do
        button.BackgroundColor3 = key == hoverController.state.mode and color.blue or color.button
    end
end
hoverHeight.FocusLost:Connect(setHoverConfig)
hoverRadius.FocusLost:Connect(setHoverConfig)
hoverSpacing.FocusLost:Connect(setHoverConfig)
for key, button in pairs(hoverPositionButtons) do
    local selectedMode = key
    button.Activated:Connect(function() setHoverConfig(selectedMode) end)
end
local function toggleHover()
    if progressController and progressController.state.busy then progressController.stop(false) end
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
    local lines = {"NPC Follow v1.20", "Health-positive targets: " .. #entries,
        string.format("Nameplates: %d; unmapped: %d; no health source: %d; non-combat excluded: %d",
            hoverScanStats.plates or 0, hoverScanStats.unmapped or 0, hoverScanStats.noHealth or 0, hoverScanStats.nonCombat or 0)}
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
    indexer.scan("hover")
    if closed then return end
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
-- Auto E is prompt-based. It does not spam the keyboard or rescan the map each frame.
local autoEPage = create("Frame", {
    Position = UDim2.fromOffset(14, 92), Size = UDim2.new(1, -28, 0, 346),
    BackgroundTransparency = 1, Visible = false,
}, panel)
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 110), BackgroundTransparency = 1,
    Text = "เดินเข้าใกล้จุดที่ขึ้นปุ่ม E แล้วกดให้อัตโนมัติ\nรองรับกดค้างตามเวลาของจุดนั้น\nกดซ้ำทุก 1 วินาที ถ้ายังอยู่ใกล้และจุดนั้นพร้อม\nพักระหว่างพิมพ์หรือเปิดเมนู Roblox",
    TextColor3 = color.muted, TextSize = 14, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
}, autoEPage)
local autoEButton = create("TextButton", {
    Position = UDim2.fromOffset(0, 133), Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = color.blue, BorderSizePixel = 0,
    Text = "AUTO E: OFF — กดเพื่อเริ่ม", TextColor3 = color.text,
    Font = Enum.Font.GothamBold, TextSize = 16,
}, autoEPage)
local autoEStatus = create("TextLabel", {
    Position = UDim2.fromOffset(0, 196), Size = UDim2.new(1, 0, 0, 145),
    BackgroundTransparency = 1, TextColor3 = color.muted, TextSize = 14, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    Text = "Auto E เริ่มต้นปิดอยู่ • F4 เปิด/ปิด\nเดินเข้าใกล้จุดโต้ตอบหลังเปิดได้เลย",
}, autoEPage)
local function buildAutoEController(deps)
    local state = {enabled = false, held = nil, count = 0, nextScan = 0}
    local done = setmetatable({}, {__mode = "k"})
    local confirmed = setmetatable({}, {__mode = "k"})
    local auto = {state = state}
    local function notify(message) deps.notify(state, message) end
    local function release()
        local ticket = state.held
        state.held = nil
        if ticket then
            done[ticket.prompt] = deps.clock() + 1
            local ok, err = pcall(deps.finish, ticket.prompt)
            if not ok then deps.error(err) end
        end
    end
    function auto.stop()
        state.enabled = false
        release()
        notify("หยุด Auto E แล้ว • รวม " .. state.count .. " ครั้ง")
    end
    function auto.start()
        release()
        done = setmetatable({}, {__mode = "k"})
        confirmed = setmetatable({}, {__mode = "k"})
        state.enabled, state.nextScan = true, 0
        notify("AUTO E เปิดอยู่ • เดินเข้าใกล้จุดที่ขึ้น E ได้เลย")
    end
    function auto.hidden(prompt)
        if state.held and state.held.prompt == prompt then release() end
    end
    function auto.triggered(prompt)
        if not state.enabled then return end
        if not confirmed[prompt] then
            state.count = state.count + 1
        end
        confirmed[prompt] = true
        done[prompt] = deps.clock() + 1
        if state.held and state.held.prompt == prompt then release() end
        notify("โต้ตอบแล้ว: " .. deps.name(prompt) .. " • รวม " .. state.count .. " ครั้ง")
    end
    function auto.step()
        if not state.enabled then return end
        for prompt, untilAt in pairs(done) do
            if not deps.inRange(prompt) or (deps.clock() >= untilAt
                and not (state.held and state.held.prompt == prompt)) then
                done[prompt], confirmed[prompt] = nil, nil
            end
        end
        local reason = deps.blocked()
        if reason then
            if state.held then
                local prompt = state.held.prompt
                release()
                if not confirmed[prompt] then done[prompt] = nil end
            end
            notify(reason)
            return
        end
        if state.held then
            local ticket = state.held
            if not deps.eligible(ticket.prompt) then
                release()
            elseif deps.clock() >= ticket.untilAt then
                release()
                notify("กด E แล้ว • รอ 1 วินาทีก่อนรอบถัดไป")
            end
            return
        end
        if deps.clock() < state.nextScan then return end
        state.nextScan = deps.clock() + 0.10
        local nearest, distance
        for _, prompt in ipairs(deps.candidates()) do
            if not done[prompt] then
                local eligible, currentDistance = deps.eligible(prompt)
                if eligible and (not distance or currentDistance < distance) then
                    nearest, distance = prompt, currentDistance
                end
            end
        end
        if not nearest then notify("รอจุด E พร้อมใช้งาน/รอรอบถัดไป • รวม " .. state.count .. " ครั้ง") return end
        done[nearest], confirmed[nearest] = math.huge, nil
        state.held = {prompt = nearest, untilAt = deps.clock() + math.max(0, deps.duration(nearest)) + 0.10}
        deps.releaseSkills()
        local ok, err = pcall(deps.begin, nearest)
        if not ok then
            release()
            done[nearest] = deps.clock() + 5
            notify("กด E ไม่สำเร็จ • ดู Error ใน Console")
            deps.error(err)
        elseif state.held then
            notify("กำลังกด E: " .. deps.name(nearest))
        end
    end
    return auto
end
local function promptPosition(prompt)
    if not prompt.Parent or not prompt:IsDescendantOf(workspace) then return nil end
    local parent = prompt.Parent
    if parent:IsA("Attachment") then return parent.WorldPosition, parent.Parent end
    if parent:IsA("BasePart") then return parent.Position, parent end
    if parent:IsA("Model") then return parent:GetPivot().Position, parent end
end
local function promptRange(prompt)
    local character, _, root = ownCharacter()
    local position, object = promptPosition(prompt)
    if not root or not position then return false end
    local distance = (position - root.Position).Magnitude
    return distance <= prompt.MaxActivationDistance, distance, position, object, character
end
local function eligiblePrompt(prompt)
    if not ProximityPromptService.Enabled or not prompt.Enabled or prompt.KeyboardKeyCode ~= Enum.KeyCode.E then return false end
    local near, distance, position, object, character = promptRange(prompt)
    if not near then return false end
    if prompt.RequiresLineOfSight then
        local camera = workspace.CurrentCamera
        local origin = camera and camera.CFrame.Position or character:GetPivot().Position
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {character}
        local hit = workspace:Raycast(origin, position - origin, params)
        if hit and hit.Instance ~= object and not hit.Instance:IsDescendantOf(object) then return false end
    end
    return true, distance
end
autoEController = buildAutoEController({
    clock = os.clock, eligible = eligiblePrompt, inRange = promptRange,
    duration = function(prompt) return prompt.HoldDuration end,
    name = function(prompt)
        if prompt.ObjectText ~= "" then return prompt.ObjectText end
        if prompt.ActionText ~= "" then return prompt.ActionText end
        return prompt.Parent and prompt.Parent.Name or prompt.Name
    end,
    begin = function(prompt) prompt:InputHoldBegin() end,
    finish = function(prompt) prompt:InputHoldEnd() end,
    releaseSkills = controller.release,
    blocked = function()
        if closed then return "ปิดหน้าต่างแล้ว" end
        if not ownCharacter() then return "รอตัวละครเกิดใหม่" end
        if UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then return "พัก Auto E ระหว่างพิมพ์หรือเปิดเมนู" end
    end,
    candidates = function()
        local values, seen = {}, {}
        -- PromptShown gives the visible nearby prompts immediately.
        for prompt in pairs(autoEVisible) do values[#values + 1] = prompt seen[prompt] = true end
        -- A small fallback handles a prompt that was already shown before this script was run.
        for _ = 1, 24 do
            local prompt = next(autoEPrompts, autoECursor)
            autoECursor = prompt
            if not prompt then break end
            if not seen[prompt] then values[#values + 1] = prompt end
        end
        return values
    end,
    notify = function(state, message)
        if closed then return end
        local text = state.enabled and "AUTO E: ON — กดเพื่อหยุด" or "AUTO E: OFF — กดเพื่อเริ่ม"
        if autoEButton.Text ~= text then autoEButton.Text = text end
        local background = state.enabled and color.green or color.blue
        if autoEButton.BackgroundColor3 ~= background then autoEButton.BackgroundColor3 = background end
        if autoEStatus.Text ~= message then autoEStatus.Text = message end
    end,
    error = function(err) warn("Auto E:", err) end,
})
local function toggleAutoE()
    if autoEController.state.enabled then autoEController.stop() else autoEController.start() end
end
autoEButton.Activated:Connect(toggleAutoE)
table.insert(connections, ProximityPromptService.PromptShown:Connect(function(prompt)
    if prompt.KeyboardKeyCode == Enum.KeyCode.E then autoEVisible[prompt] = true end
end))
table.insert(connections, ProximityPromptService.PromptHidden:Connect(function(prompt)
    autoEVisible[prompt] = nil
    autoEController.hidden(prompt)
end))
table.insert(connections, ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
    if who == player and prompt.KeyboardKeyCode == Enum.KeyCode.E then autoEController.triggered(prompt) end
end))
-- End Auto E.

-- Results automation only looks for the game's visible Next Floor / Retry / Leave group.
do
    resultsPage = create("Frame", {
        Position = UDim2.fromOffset(14, 92), Size = UDim2.new(1, -28, 0, 346),
        BackgroundTransparency = 1, Visible = false,
    }, panel)
    create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1,
        Text = "กดปุ่มจบรอบให้อัตโนมัติ • F5 เปิด/ปิด\nเริ่มต้นเลือก Next Floor ปุ่มตรงกลาง",
        TextColor3 = color.muted, TextSize = 14, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    }, resultsPage)
    local nextButton = create("TextButton", {
        Position = UDim2.fromOffset(0, 76), Size = UDim2.fromOffset(152, 36),
        BackgroundColor3 = color.blue, BorderSizePixel = 0, Text = "Next Floor",
        TextColor3 = color.text, TextSize = 14,
    }, resultsPage)
    local retryButton = create("TextButton", {
        Position = UDim2.fromOffset(160, 76), Size = UDim2.fromOffset(152, 36),
        BackgroundColor3 = color.button, BorderSizePixel = 0, Text = "Retry ชั้นเดิม",
        TextColor3 = color.text, TextSize = 14,
    }, resultsPage)
    local enableButton = create("TextButton", {
        Position = UDim2.fromOffset(0, 137), Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = color.blue, BorderSizePixel = 0,
        Text = "AUTO จบรอบ: OFF — กดเพื่อเริ่ม",
        TextColor3 = color.text, TextSize = 16, Font = Enum.Font.GothamBold,
    }, resultsPage)
    local info = create("TextLabel", {
        Position = UDim2.fromOffset(0, 229), Size = UDim2.new(1, 0, 0, 108),
        BackgroundTransparency = 1, TextColor3 = color.muted, TextSize = 14, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        Text = "รอหน้าจอจบรอบ • ระบบเริ่มต้นปิดอยู่\nกดเฉพาะปุ่มที่เลือก ไม่กด Leave",
    }, resultsPage)
    local infoHoldUntil = 0
    local scanButton = create("TextButton", {
        Position = UDim2.fromOffset(0, 192), Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = color.button, BorderSizePixel = 0,
        Text = "สแกนปุ่ม + คัดลอกข้อมูล", TextColor3 = color.text, TextSize = 13,
    }, resultsPage)
    local function buildResultsController(deps)
        local state = {enabled = false, mode = "next", visible = false, target = nil,
            since = 0, nextPoll = 0, lastClick = -math.huge, attempts = 0, lastVotes = nil}
        local auto = {state = state}
        local function notify(message) deps.notify(state, message) end
        local function resetTarget(button)
            state.target, state.since, state.attempts, state.lastClick = button, deps.clock(), 0, -math.huge
            state.lastVotes = nil
        end
        function auto.stop()
            state.enabled = false
            deps.release()
            notify("หยุด Auto จบรอบแล้ว")
        end
        function auto.start()
            state.enabled, state.nextPoll = true, 0
            resetTarget(nil)
            notify("เปิด Auto จบรอบ • รอปุ่ม " .. (state.mode == "next" and "Next Floor" or "Retry"))
        end
        function auto.select(mode)
            if mode ~= "next" and mode ~= "retry" then return end
            deps.release()
            state.mode, state.nextPoll = mode, 0
            resetTarget(nil)
            notify("เลือก " .. (mode == "next" and "Next Floor" or "Retry ชั้นเดิม") .. " แล้ว")
        end
        function auto.step()
            if deps.clock() < state.nextPoll then return end
            state.nextPoll = deps.clock() + 0.25
            local button = deps.find(state.mode)
            state.visible = button ~= nil
            if button ~= state.target then resetTarget(button) end
            local votes = button and deps.voteCount and deps.voteCount(button) or nil
            if votes ~= nil then
                -- EndScreen reuses the same Button instance. A cleared vote starts a fresh round.
                if state.lastVotes and state.lastVotes > 0 and votes == 0 then resetTarget(button) end
                state.lastVotes = votes
            end
            if not state.enabled then return end
            if not button then notify("รอหน้าจอจบรอบ...") return end
            if deps.voted(button) then notify("ลงคะแนนแล้ว • รอเกมเริ่มรอบถัดไป") return end
            local blocked = deps.blocked(button)
            if blocked then notify(blocked) return end
            if deps.clock() - state.since < 0.60 or deps.clock() - state.lastClick < 2 then return end
            if state.attempts >= 1 and (votes == nil or votes > 0) then
                notify("ส่งคลิกแล้ว • รอเกมเริ่มรอบถัดไป")
                return
            end
            -- If the selected action is still 0/n, retry after the existing two-second cooldown.
            -- This also catches a hide/show transition shorter than our polling interval.
            state.attempts, state.lastClick = state.attempts + 1, deps.clock()
            local ok, err = pcall(deps.click, button)
            if not ok then
                auto.stop()
                notify("กดปุ่มไม่สำเร็จ: " .. tostring(err):sub(1, 120))
                deps.error(err)
            else
                notify("ส่งคลิก " .. (state.mode == "next" and "Next Floor" or "Retry") .. " แล้ว • รอเกมตอบรับ")
            end
        end
        function auto.toggle()
            if state.enabled then auto.stop() else auto.start() end
        end
        return auto
    end
    local captionCache = setmetatable({}, {__mode = "k"})
    local labelForControl = setmetatable({}, {__mode = "k"})
    local function normalizedText(text)
        return tostring(text or ""):gsub("<[^>]*>", ""):lower():gsub("%s+", "")
    end
    local function caption(button)
        local label = labelForControl[button]
        if label and label.Parent then return normalizedText(label.Text) end
        local function actionText(text)
            return text:match("^nextfloor") or text:match("^retry") or text == "leave"
        end
        local main, vote
        if button:IsA("TextButton") then
            local text = normalizedText(button.Text)
            if actionText(text) then main = text end
        end
        if main and main:find("/", 1, true) then return main end
        local labels = captionCache[button]
        if not labels then
            labels = {}
            for _, object in ipairs(button:GetDescendants()) do
                if object:IsA("TextLabel") then labels[#labels + 1] = object end
            end
            captionCache[button] = labels
        end
        for _, label in ipairs(labels) do
            if label.Parent and label.Visible and label.Text ~= "" then
                local text = normalizedText(label.Text)
                if actionText(text) then main = main or text end
                vote = vote or text:match("%d+/%d+")
            end
        end
        main = main or normalizedText(button.Name)
        if vote and not main:find("/", 1, true) then main = main .. ":" .. vote end
        return main
    end
    local function visible(button)
        if button:IsA("TextLabel") and button.TextTransparency >= 0.99 and button.TextStrokeTransparency >= 0.99 then return false end
        if not button.Parent or not button:IsDescendantOf(playerGui) or button:IsDescendantOf(gui) then return false end
        if button.AbsoluteSize.X <= 0 or button.AbsoluteSize.Y <= 0 then return false end
        local camera = workspace and workspace.CurrentCamera
        if camera then
            local point = button.AbsolutePosition + button.AbsoluteSize * 0.5 + GuiService:GetGuiInset()
            local view = camera.ViewportSize
            if point.X < 0 or point.Y < 0 or point.X > view.X or point.Y > view.Y then return false end
        end
        local object = button
        while object and object ~= playerGui do
            if object:IsA("GuiObject") and not object.Visible then return false end
            if object:IsA("ScreenGui") and not object.Enabled then return false end
            if object:IsA("CanvasGroup") and object.GroupTransparency >= 0.99 then return false end
            object = object.Parent
        end
        return true
    end
    local function classify(button)
        local text = caption(button)
        if text:match("^nextfloor") then return "next" end
        if text:match("^retry") then return "retry" end
        if text == "leave" then return "leave" end
    end
    local function center(object)
        return object.AbsolutePosition + object.AbsoluteSize * 0.5
    end
    local function controlForLabel(label)
        local point, selected = center(label), label
        local selectedArea = math.huge
        local function consider(object)
            if object:IsA("GuiButton") and visible(object) then
                local size = object.AbsoluteSize
                local p = object.AbsolutePosition
                if size.X <= 480 and size.Y <= 180 and point.X >= p.X and point.X <= p.X + size.X
                    and point.Y >= p.Y and point.Y <= p.Y + size.Y then
                    local area = size.X * size.Y
                    if area < selectedArea then selected, selectedArea = object, area end
                end
            end
        end
        local parent = label.Parent
        for _ = 1, 6 do
            if not parent or parent == playerGui then break end
            consider(parent)
            parent = parent.Parent
        end
        for _, hit in ipairs(playerGui:GetGuiObjectsAtPosition(point.X, point.Y)) do consider(hit) end
        -- Some games handle clicks on Frames/labels instead of using a GuiButton.
        labelForControl[selected] = label
        return selected
    end
    local function classifyText(text)
        if text:match("^nextfloor") then return "next" end
        if text:match("^retry") then return "retry" end
        if text:match("^leave") then return "leave" end
    end
    local function findResult(mode)
        -- Verified hierarchy from the user's scan. Prefer MainText over the decorative TextShadow.
        local screen = playerGui:FindFirstChild("EndScreen")
        local holder = screen and screen:FindFirstChild("Holder")
        local constrained = holder and holder:FindFirstChild("ConstraintedHolder")
        local row = constrained and constrained:FindFirstChild("ButtonsHolder")
        if row then
            local frame = row:FindFirstChild(mode == "retry" and "RetryButton" or "NextButton")
            local button = frame and frame:FindFirstChild("Button")
            local label = frame and (frame:FindFirstChild("MainText") or frame:FindFirstChild("TextShadow"))
            if button and label then
                if visible(button) and visible(label) then
                    labelForControl[button] = label
                    return button
                end
                -- The verified result screen is hidden; skip a scan of unrelated HUD labels.
                return nil
            end
        end
        local choices = {next = {}, retry = {}, leave = {}}
        local seen = {next = {}, retry = {}, leave = {}}
        local function add(kind, object)
            if kind and not seen[kind][object] then
                seen[kind][object] = true
                choices[kind][#choices[kind] + 1] = object
            end
        end
        for button in pairs(resultButtons) do
            if visible(button) then add(classifyText(caption(button)), button) end
        end
        for label in pairs(resultLabels) do
            if visible(label) then
                local kind = classifyText(normalizedText(label.Text))
                if kind then add(kind, controlForLabel(label)) end
            end
        end
        -- Recognize the horizontal Retry / Next Floor / Leave row, even across different ScreenGuis.
        for _, nextControl in ipairs(choices.next) do
            local n = center(nextControl)
            for _, retryControl in ipairs(choices.retry) do
                local r = center(retryControl)
                local tolerance = math.max(nextControl.AbsoluteSize.Y, retryControl.AbsoluteSize.Y, 24)
                if r.X < n.X and math.abs(r.Y - n.Y) <= tolerance then
                    for _, leaveControl in ipairs(choices.leave) do
                        local l = center(leaveControl)
                        if l.X > n.X and math.abs(l.Y - n.Y) <= math.max(tolerance, leaveControl.AbsoluteSize.Y) then
                            return mode == "retry" and retryControl or nextControl
                        end
                    end
                end
            end
        end
    end
    local mouseTicket, manager, virtual
    local function releaseMouse(ticket)
        ticket = ticket or mouseTicket
        if not ticket or mouseTicket ~= ticket then return end
        local ok, err = pcall(ticket.send, false)
        if ok then mouseTicket = nil else error(err, 0) end
    end
    local function clickResult(button)
        if mouseTicket then releaseMouse() end
        local active = true
        pcall(function() active = button.Interactable end)
        if active == false then error("ปุ่มยังไม่พร้อมให้กด") end
        local position = button.AbsolutePosition + button.AbsoluteSize * 0.5
        -- GUI coordinates use the inset viewport; virtual mouse input uses screen coordinates.
        local inset = GuiService:GetGuiInset()
        local screenPoint = position + inset
        local found = false
        for _, hit in ipairs(playerGui:GetGuiObjectsAtPosition(position.X, position.Y)) do
            if hit == button or hit:IsDescendantOf(button) then found = true break end
            if hit:IsA("GuiButton") or hit.Active then error("มีหน้าต่างอื่นบังปุ่มจบรอบ") end
        end
        if not found then error("ปุ่มยังไม่อยู่ในพื้นที่ที่คลิกได้") end
        controller.release()
        local ticket = {}
        if router.mode() == "VirtualInput" then
            virtual = virtual or UserInputService:CreateVirtualInput()
            ticket.send = function(down)
                virtual:SendMouseButton(screenPoint, Enum.UserInputType.MouseButton1, down, 0)
            end
        else
            manager = manager or game:GetService("VirtualInputManager")
            ticket.send = function(down)
                manager:SendMouseButtonEvent(math.floor(screenPoint.X + 0.5), math.floor(screenPoint.Y + 0.5), 0, down, game, 0)
            end
        end
        mouseTicket = ticket
        local ok, err = pcall(ticket.send, true)
        if not ok then pcall(releaseMouse, ticket) error(err, 0) end
        task.delay(0.08, function()
            if mouseTicket == ticket then
                local released, releaseError = pcall(releaseMouse, ticket)
                if not released then warn("Auto Results mouse release:", releaseError) end
            end
        end)
    end
    resultsController = buildResultsController({
        clock = os.clock, find = findResult, click = clickResult, release = releaseMouse,
        voteCount = function(button)
            return tonumber(caption(button):match(":(%d+)/"))
        end,
        voted = function(button)
            local current = caption(button):match(":(%d+)%s*/")
            local maximum = caption(button):match(":%d+/(%d+)")
            return current and maximum and tonumber(current) >= tonumber(maximum) and tonumber(maximum) > 0 or false
        end,
        blocked = function(button)
            if closed or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then
                return "พักการกดจบรอบระหว่างพิมพ์หรือเปิดเมนู Roblox"
            end
            local active = true
            pcall(function() active = button.Interactable end)
            if active == false then return "รอปุ่มจบรอบพร้อมให้กด..." end
        end,
        notify = function(state, message)
            if closed then return end
            local text = state.enabled and "AUTO จบรอบ: ON — กดเพื่อหยุด" or "AUTO จบรอบ: OFF — กดเพื่อเริ่ม"
            if enableButton.Text ~= text then enableButton.Text = text end
            local background = state.enabled and color.green or color.blue
            if enableButton.BackgroundColor3 ~= background then enableButton.BackgroundColor3 = background end
            nextButton.BackgroundColor3 = state.mode == "next" and color.blue or color.button
            retryButton.BackgroundColor3 = state.mode == "retry" and color.blue or color.button
            if os.clock() >= infoHoldUntil and info.Text ~= message then info.Text = message end
        end,
        error = function(err) warn("Auto Results:", err) end,
    })
    function resultsController.monitor()
        local screen = playerGui:FindFirstChild("EndScreen")
        local holder = screen and screen:FindFirstChild("Holder")
        local constrained = holder and holder:FindFirstChild("ConstraintedHolder")
        local row = constrained and constrained:FindFirstChild("ButtonsHolder")
        local frame = row and row:FindFirstChild("NextButton")
        local button = frame and frame:FindFirstChild("Button")
        resultsController.state.visible = button ~= nil and visible(button)
    end
    function resultsController.dirty(object)
        if object:IsA("GuiButton") then captionCache[object] = nil return end
        if object:IsA("TextLabel") then
            local parent = object.Parent
            for _ = 1, 6 do
                if not parent then break end
                if parent:IsA("GuiButton") then captionCache[parent] = nil break end
                parent = parent.Parent
            end
        end
    end
    scanButton.Activated:Connect(function()
        indexer.scan("gui")
        if closed then return end
        local found = findResult(resultsController.state.mode)
        local lines = {"Auto Results v1.16", "Found selected control: " .. (found and found:GetFullName() or "none")}
        lines[#lines + 1] = string.format("Mode=%s attempts=%d votes=%s visible=%s",
            resultsController.state.mode, resultsController.state.attempts,
            tostring(resultsController.state.lastVotes), tostring(resultsController.state.visible))
        if found then lines[#lines + 1] = "Current caption: " .. caption(found) end
        local count = 0
        for label in pairs(resultLabels) do
            if visible(label) then
                local text = normalizedText(label.Text)
                if text:find("next", 1, true) or text:find("retry", 1, true) or text:find("leave", 1, true)
                    or text:find("victory", 1, true) or text:find("defeat", 1, true) then
                    count = count + 1
                    if count <= 30 then
                        local p, size = label.AbsolutePosition, label.AbsoluteSize
                        lines[#lines + 1] = string.format("%s | %s | '%s' | %.0f,%.0f %.0fx%.0f | parent=%s",
                            label.ClassName, label:GetFullName(), label.Text:sub(1, 150),
                            p.X, p.Y, size.X, size.Y, label.Parent and label.Parent.ClassName or "nil")
                    end
                end
            end
        end
        lines[#lines + 1] = "Matching visible labels: " .. count
        local report = table.concat(lines, "\n")
        print(report)
        local copy, copied = setclipboard or toclipboard, false
        if type(copy) == "function" then copied = pcall(copy, report) end
        infoHoldUntil = os.clock() + 6
        info.Text = (found and "พบปุ่มแล้ว" or "ยังไม่พบชุดปุ่มจบรอบ") ..
            (copied and " • คัดลอกข้อมูลแล้ว ส่งให้ผมได้ครับ" or " • ดูข้อมูลใน Console (F9)")
    end)

    nextButton.Activated:Connect(function() resultsController.select("next") end)
    retryButton.Activated:Connect(function() resultsController.select("retry") end)
    enableButton.Activated:Connect(resultsController.toggle)
end
-- End results automation.

-- Rubble / AREA progression. World labels and linked instances are required for a destination.
do
    routePage = create("Frame", {
        Position = UDim2.fromOffset(14, 92), Size = UDim2.new(1, -28, 0, 346),
        BackgroundTransparency = 1, Visible = false,
    }, panel)
    create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 85), BackgroundTransparency = 1,
        Text = "จัดการมอน → วาร์ปหน้าหิน → คลิกซ้ายจนแตก\nหินแตก → วาร์ปไปจุด AREA ที่เรืองแสง\nF6 เปิด/ปิดระบบทางผ่าน",
        TextColor3 = color.muted, TextSize = 13, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    }, routePage)
    local enable = create("TextButton", {
        Position = UDim2.fromOffset(0, 98), Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = color.blue, BorderSizePixel = 0,
        Text = "AUTO ทางผ่าน: OFF — กดเพื่อเริ่ม",
        TextColor3 = color.text, TextSize = 15, Font = Enum.Font.GothamBold,
    }, routePage)
    local scan = create("TextButton", {
        Position = UDim2.fromOffset(0, 155), Size = UDim2.new(1, 0, 0, 29),
        BackgroundColor3 = color.button, BorderSizePixel = 0,
        Text = "สแกนหิน / จุด AREA + คัดลอก", TextColor3 = color.text, TextSize = 13,
    }, routePage)
    local info = create("TextLabel", {
        Position = UDim2.fromOffset(0, 199), Size = UDim2.new(1, 0, 0, 147),
        BackgroundTransparency = 1, TextColor3 = color.muted, TextSize = 13, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        Text = "เริ่มต้นปิดอยู่ • F6 เปิด/ปิด\nระบบจะรอข้อความ Break the rubble / Enter area",
    }, routePage)
    local function buildProgressController(deps)
        local state = {enabled = false, busy = false, phase = "idle", target = nil,
            nextTick = 0, nextAttack = 0, enteredAt = 0, restore = nil, entryAttempts = 0}
        local auto = {state = state}
        local function notify(message) deps.notify(state, message) end
        local function finish(resume)
            deps.release()
            local restore = state.restore
            state.busy, state.restore, state.target, state.phase, state.placed = false, nil, nil, "idle", false
            if restore then restore(resume ~= false) end
        end
        local function own()
            if not state.busy then
                state.busy = true
                state.restore = deps.takeControl()
            end
        end
        function auto.start()
            state.enabled, state.nextTick = true, 0
            notify("เปิดทางผ่านแล้ว • รอจัดการมอนจนหินพร้อมให้ตี")
        end
        function auto.stop(resume)
            state.enabled = false
            finish(resume)
            notify("หยุดระบบทางผ่านแล้ว")
        end
        function auto.toggle()
            if state.enabled then auto.stop() else auto.start() end
        end
        function auto.step()
            if not state.enabled or deps.clock() < state.nextTick then return end
            state.nextTick = deps.clock() + 0.20
            local ready, reason, reset = deps.ready()
            if not ready then
                deps.release()
                if reset then finish(false) end
                notify(reason or "รอตัวละครพร้อม...")
                return
            end
            local phase, area = deps.objective()
            if phase == "rubble" then
                if state.phase == "waiting_area" then
                    notify("หินแตกแล้ว • รอจุด AREA ปรากฏ")
                    return
                end
                if state.target and state.phase == "rubble" and not deps.alive(state.target) then
                    deps.release()
                    state.phase, state.target = "waiting_area", nil
                    notify("หินแตกแล้ว • รอจุด AREA")
                    return
                end
                if state.phase ~= "rubble" then
                    local target = deps.rubble()
                    if not target then notify("ยังหาตำแหน่ง Rubble ไม่เจอ • กดสแกนหินเพื่อส่งข้อมูลได้ครับ") return end
                    own()
                    deps.release()
                    state.phase, state.target, state.placed = "rubble", target, false
                    notify("พบหินแล้ว • รอท่าปัจจุบันจบก่อนวาร์ป")
                    return
                end
                if deps.motionReady and not deps.motionReady() then notify("รอท่าตี/สกิลจบ...") return end
                if not state.placed then
                    deps.front(state.target)
                    state.placed, state.nextAttack = true, deps.clock() + 0.35
                    notify("ถึงหน้าหินแล้ว • เตรียมคลิกซ้าย")
                    return
                end
                if deps.clock() >= state.nextAttack then
                    state.nextAttack = deps.clock() + 0.60
                    deps.attack(state.target)
                    notify("กำลังตี Rubble ด้วยคลิกซ้าย • รอหินแตก")
                end
            elseif phase == "area" then
                deps.release()
                if state.phase == "entered" and (not area or state.target.area == area) then
                    if deps.clock() - state.enteredAt < 2 then notify("กำลังเข้าวง AREA • รอเกมยืนยัน") return end
                    local marker = deps.marker(area)
                    if not marker then notify("ยังไม่เข้าห้อง • รอหาตำแหน่งวง AREA ใหม่") return end
                    if deps.motionReady and not deps.motionReady() then return end
                    state.target, state.enteredAt = marker, deps.clock()
                    state.entryAttempts = state.entryAttempts + 1
                    deps.enter(marker)
                    notify("เกมยังให้เข้า AREA • ลองเข้าวงอีกครั้ง " .. state.entryAttempts)
                    return
                end
                local marker = deps.marker(area)
                if not marker then
                    notify("รอจุด AREA " .. tostring(area or "") .. " • ถ้ายังหาไม่เจอ กดสแกนเพื่อส่งข้อมูล")
                    return
                end
                own()
                if deps.motionReady and not deps.motionReady() then notify("รอท่าตีจบก่อนเข้าจุด AREA") return end
                state.phase, state.target, state.enteredAt, state.entryAttempts = "entered", marker, deps.clock(), 1
                deps.enter(marker)
                notify("กำลังเข้าวง AREA " .. tostring(marker.area or area or "") .. " • รอข้อความห้องเปลี่ยน")
            else
                if state.busy then finish(true) end
                notify("รอจัดการมอน / ข้อความทางผ่านของห้องถัดไป")
            end
        end
        return auto
    end
    local objectiveLabel, objectiveNext, objectivePhase, objectiveArea = nil, 0, nil, nil
    local function shown(object)
        if not object or not object.Parent then return false end
        local cursor = object
        while cursor and cursor ~= playerGui and cursor ~= workspace do
            if cursor:IsA("GuiObject") and not cursor.Visible then return false end
            if cursor:IsA("ScreenGui") and not cursor.Enabled then return false end
            if cursor:IsA("CanvasGroup") and cursor.GroupTransparency >= 0.99 then return false end
            cursor = cursor.Parent
        end
        return true
    end
    local function parseObjective(text)
        text = cleanPlateText(text):lower():gsub("%s+", "")
        if text:find("breaktherubble", 1, true) then return "rubble" end
        local area = text:match("enterarea(%d+)")
        if area then return "area", tonumber(area) end
    end
    local function objective()
        local hud = playerGui:FindFirstChild("RoundHUD")
        local container = hud and hud:FindFirstChild("Container")
        local top = container and container:FindFirstChild("TopPart")
        local remaining = top and top:FindFirstChild("RemainingFrame")
        local label = remaining and remaining:FindFirstChild("EnemyCount")
        if label and shown(label) then
            objectiveLabel = label
            return parseObjective(label.Text)
        end
        if resultsController and resultsController.state.visible then return "end" end
        if objectiveLabel and shown(objectiveLabel) then return parseObjective(objectiveLabel.Text) end
        if os.clock() < objectiveNext then return objectivePhase, objectiveArea end
        objectiveNext = os.clock() + 0.50
        objectivePhase, objectiveArea, objectiveLabel = nil, nil, nil
        for label in pairs(resultLabels) do
            if shown(label) then
                local phase, area = parseObjective(label.Text)
                if phase then
                    local lower = label.Name:lower()
                    if not lower:find("shadow", 1, true) and not lower:find("echo", 1, true) then
                        objectiveLabel, objectivePhase, objectiveArea = label, phase, area
                        break
                    end
                end
            end
        end
        return objectivePhase, objectiveArea
    end
    local function worldPosition(object)
        if not object or not object.Parent or not object:IsDescendantOf(workspace) then return nil end
        if object:IsA("Attachment") then return object.WorldPosition end
        if object:IsA("BasePart") then return object.Position end
        if object:IsA("Model") then return object:GetPivot().Position end
    end
    local function plateAnchor(plate)
        local object = plate.Adornee or plate.Parent
        if worldPosition(object) then return object end
    end
    local function plateText(plate)
        local snapshot = readPlate(plate)
        if not snapshot then return "" end
        return table.concat(snapshot.texts, " "), snapshot
    end
    local function safeAreaObject(object)
        if not worldPosition(object) then return false end
        local cursor = object
        while cursor and cursor ~= workspace do
            if cursor.Name:lower() == "tpback" then return false end
            cursor = cursor.Parent
        end
        local _, _, root = ownCharacter()
        return root and math.abs(worldPosition(object).Y - root.Position.Y) <= 80
    end
    local function ground(point, exclude)
        local character = player.Character
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {character}
        if exclude then params.FilterDescendantsInstances = {character, exclude} end
        params.RespectCanCollide = true
        local hit = workspace:Raycast(point + Vector3.new(0, 16, 0), Vector3.new(0, -100, 0), params)
        return hit and hit.Position or nil
    end
    local previousGoal, previousArea
    local function rayDistancePoint(origin, direction, playerPosition, distance, prior)
        local offset = origin - playerPosition
        local a = direction:Dot(direction)
        local b = 2 * offset:Dot(direction)
        local c = offset:Dot(offset) - distance * distance
        local discriminant = b * b - 4 * a * c
        if a <= 0 or discriminant < 0 then return nil end
        local root = math.sqrt(discriminant)
        local near, far = (-b - root) / (2 * a), (-b + root) / (2 * a)
        local first = near > 0 and origin + direction * near or nil
        local second = far > 0 and origin + direction * far or nil
        if prior and first and second then
            return (first - prior).Magnitude < (second - prior).Magnitude and first or second
        end
        return second or first
    end
    local function chipMarker(requestedArea)
        local chip = playerGui:FindFirstChild("NextAreaChip")
        local frame = chip and chip:FindFirstChild("Frame")
        local title = frame and frame:FindFirstChild("Title")
        if not frame or not title or not shown(title) then return nil end
        local area = tonumber(cleanPlateText(title.Text):upper():match("AREA%s*(%d+)"))
        if requestedArea and area ~= requestedArea then return nil end
        local descendants = chip:GetDescendants()
        -- Prefer an actual world instance referenced by the indicator.
        for _, child in ipairs(descendants) do
            if child:IsA("ObjectValue") and child.Value and safeAreaObject(child.Value) then
                return {object = child.Value, position = worldPosition(child.Value), area = area, label = "NextAreaChip reference"}
            end
        end
        local distance
        for _, child in ipairs(descendants) do
            if child:IsA("TextLabel") or child:IsA("TextButton") then
                local text = cleanPlateText(child.Text):lower()
                local number = text:match("(%d+%.?%d*)%s*stud")
                if number then distance = tonumber(number) break end
            end
        end
        local _, _, root = ownCharacter()
        local camera = workspace.CurrentCamera
        if not distance or not root or not camera then return nil end
        if area ~= previousArea then previousGoal, previousArea = nil, area end
        if distance <= 6 and previousGoal then
            return {position = previousGoal, area = area, estimated = true, label = "NextAreaChip projected ground"}
        end
        -- The UI's anchor is the projected marker. Distance constrains its world position.
        local pixel = frame.AbsolutePosition + Vector2.new(frame.AbsoluteSize.X * frame.AnchorPoint.X,
            frame.AbsoluteSize.Y * frame.AnchorPoint.Y)
        local ray = camera:ScreenPointToRay(pixel.X, pixel.Y, 0)
        local position = rayDistancePoint(ray.Origin, ray.Direction, root.Position, distance + 0.5, previousGoal)
        if not position or math.abs(position.Y - root.Position.Y) > math.max(8, distance * 0.3) then return nil end
        local floor = ground(position)
        if not floor then return nil end
        previousGoal = floor
        return {position = floor, area = area, estimated = true, label = "NextAreaChip projected ground"}
    end

    local function nearest(kind, requestedArea)
        local _, _, root = ownCharacter()
        if not root then return nil end
        local projectedMarker
        if kind == "area" then
            local chip = chipMarker(requestedArea)
            if chip and not chip.estimated then return chip end
            projectedMarker = chip
        end
        if kind == "rubble" then
            local bar = playerGui:FindFirstChild("RubbleBar")
            local text, snapshot = bar and plateText(bar) or "", nil
            if bar then text, snapshot = plateText(bar) end
            local anchor = bar and plateAnchor(bar)
            if anchor then
                if text:lower():find("locked", 1, true) then return nil end
                local blocker = anchor:IsA("Attachment") and anchor.Parent or anchor
                local border = blocker:FindFirstAncestorOfClass("Model")
                local health = border and border:GetAttribute("RubbleHealth")
                if type(health) == "number" then
                    if health <= 0 then return nil end
                    return {object = blocker, border = border, source = {kind = "attribute", object = border,
                        field = "RubbleHealth", label = "RubbleHealth"}, label = text, position = worldPosition(blocker)}
                end
            end
        end
        local best, bestDistance
        local function add(object, source, area, label)
            local position = worldPosition(object)
            if not position or isPlayerModel(object) then return end
            if kind == "area" and (not safeAreaObject(object) or (requestedArea and area ~= requestedArea)) then return end
            if source and sourceHealth(source) <= 0 then return end
            local distance = (position - root.Position).Magnitude
            if distance > 1500 then return end
            if not bestDistance or distance < bestDistance then
                bestDistance = distance
                best = {object = object, source = source, area = area, label = label, position = position}
            end
        end
        for plate in pairs(hoverBillboards) do
            local text, snapshot = plateText(plate)
            local lower = text:lower()
            local anchor = plateAnchor(plate)
            if anchor and kind == "rubble" and lower:find("rubble", 1, true) and not lower:find("locked", 1, true) and snapshot.health ~= nil then
                add(anchor, {kind = "nameplate", object = plate, label = "Rubble HP"}, nil, text)
            elseif anchor and kind == "area" then
                local area = text:upper():match("AREA%s*(%d+)")
                if area then add(anchor, nil, tonumber(area), text) end
            end
        end
        -- Only explicit Rubble / numbered AREA names are accepted as a fallback.
        if not best then
            for object in pairs(routeObjects) do
                local name = object.Name:lower():gsub("[%s_%-]", "")
                if kind == "rubble" and (name == "rubble" or name == "rubblehitbox" or name == "rubblebarrier") then
                    local source = customHealthSource(object)
                    add(object, source, nil, object.Name)
                elseif kind == "area" then
                    local area = name:match("^area(%d+)$") or name:match("^area(%d+)entry$") or name:match("^area(%d+)marker$")
                    if area and (object:IsA("BasePart") or object:IsA("Attachment")) then
                        add(object, nil, tonumber(area), object.Name)
                    end
                end
            end
        end
        return best or projectedMarker
    end
    local mouseTicket, manager, virtual
    local function releaseMouse()
        local ticket = mouseTicket
        if not ticket then return end
        mouseTicket = nil
        pcall(ticket.send, false)
    end
    local function attack()
        if mouseTicket then return end
        local camera = workspace.CurrentCamera
        if not camera then return end
        local point = camera.ViewportSize * 0.5
        local ticket = {}
        if router.mode() == "VirtualInput" then
            virtual = virtual or UserInputService:CreateVirtualInput()
            ticket.send = function(down) virtual:SendMouseButton(point, Enum.UserInputType.MouseButton1, down, 0) end
        else
            manager = manager or game:GetService("VirtualInputManager")
            ticket.send = function(down) manager:SendMouseButtonEvent(point.X, point.Y, 0, down, game, 0) end
        end
        mouseTicket = ticket
        local ok, err = pcall(ticket.send, true)
        if not ok then releaseMouse() error(err, 0) end
        task.delay(0.08, function() if mouseTicket == ticket then releaseMouse() end end)
    end
    local function takeControl()
        local wasFlying = flight ~= nil
        if wasFlying then stopFlight("พักบินเพื่อตีหิน/เข้าจุด AREA") end
        controller.release()
        hoverController.suspendForRoute()
        local _, humanoid = ownCharacter()
        local autoRotate = humanoid and humanoid.AutoRotate
        if humanoid then humanoid.AutoRotate = false end
        return function(resumeFlight)
            if humanoid and humanoid.Parent then humanoid.AutoRotate = autoRotate end
            if resumeFlight ~= false and wasFlying and not closed then
                local wantedSkills = controller.state.enabled
                startFlight()
                if wantedSkills then controller.start() end
            end
        end
    end
    local function front(target)
        local _, humanoid, root = ownCharacter()
        local object = target.object
        local position = worldPosition(object)
        if not root or not position then error("ตำแหน่งหินหายไป") end
        local frame, size
        if object:IsA("Model") then frame, size = object:GetBoundingBox()
        elseif object:IsA("BasePart") then frame, size = object.CFrame, object.Size
        elseif object:IsA("Attachment") and object.Parent:IsA("BasePart") then frame, size = object.Parent.CFrame, object.Parent.Size end
        local center = frame and frame.Position or position
        local direction = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
        if direction.Magnitude < 0.01 then direction = Vector3.new(0, 0, -1) end
        direction = direction.Unit
        local extent = 3
        if size and math.max(size.X, size.Z) <= 200 then
            extent = math.abs(direction:Dot(frame.RightVector)) * size.X * 0.5
                + math.abs(direction:Dot(frame.LookVector)) * size.Z * 0.5
        end
        local bottom = center.Y - (size and size.Y * 0.5 or 0)
        local height = humanoid.HipHeight + root.Size.Y * 0.5
        local point = Vector3.new(center.X, bottom + height, center.Z) + direction * (extent + 3)
        local floor = ground(Vector3.new(point.X, root.Position.Y, point.Z), target.border or object)
        if floor then point = floor + Vector3.new(0, height, 0) end
        root.CFrame = CFrame.lookAt(point, Vector3.new(center.X, point.Y, center.Z))
        local camera = workspace.CurrentCamera
        if camera and camera.CameraType ~= Enum.CameraType.Scriptable then
            camera.CFrame = CFrame.lookAt(point + direction * 12 + Vector3.new(0, 6, 0), center)
        end
        root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
    end
    local function enter(marker)
        local _, humanoid, root = ownCharacter()
        local point = marker.object and worldPosition(marker.object) or marker.position
        if not root or not point then error("ตำแหน่ง AREA หายไป") end
        if marker.object and not safeAreaObject(marker.object) then error("ปฏิเสธจุด TpBack/จุดที่ไม่ใช่วงบนแผนที่") end
        local floor = ground(point)
        if not floor then error("ไม่พบพื้นบริเวณวง AREA • กดสแกนส่งข้อมูลได้ครับ") end
        local height = humanoid.HipHeight + root.Size.Y * 0.5
        local direction = Vector3.new(floor.X - root.Position.X, 0, floor.Z - root.Position.Z)
        if direction.Magnitude < 0.01 then direction = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z) end
        if direction.Magnitude < 0.01 then direction = Vector3.new(0, 0, -1) end
        direction = direction.Unit
        -- Arrive just before the ring and physically walk across it to trigger room entry.
        local start = floor - direction * 4 + Vector3.new(0, height, 0)
        root.CFrame = CFrame.lookAt(start, start + direction)
        root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
        humanoid:MoveTo(floor + direction * 3 + Vector3.new(0, height, 0))
    end
    local infoUntil = 0
    progressController = buildProgressController({
        clock = os.clock, objective = objective, rubble = function() return nearest("rubble") end,
        marker = function(area) return nearest("area", area) end,
        front = front, enter = enter, attack = attack, release = releaseMouse, takeControl = takeControl,
        motionReady = function()
            local _, humanoid, root = ownCharacter()
            return root and not root.Anchored and not skillAnimationBusy(humanoid)
        end,
        alive = function(target)
            if not worldPosition(target.object) then return false end
            if target.object:GetAttribute("Destroyed") == true or target.object:GetAttribute("Dead") == true then return false end
            -- Invisible hitboxes are valid targets. A rounded 0% nameplate is not proof of destruction.
            if target.source and target.source.kind ~= "nameplate" and sourceHealth(target.source) <= 0 then return false end
            return true
        end,
        ready = function()
            local _, humanoid, root = ownCharacter()
            if not root then return false, "รอตัวละครเกิดใหม่", true end
            if closed or UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then return false, "พักทางผ่านระหว่างพิมพ์/เปิดเมนู" end
            return true
        end,
        notify = function(state, message)
            if closed then return end
            local text = state.enabled and "AUTO ทางผ่าน: ON — กดเพื่อหยุด" or "AUTO ทางผ่าน: OFF — กดเพื่อเริ่ม"
            if enable.Text ~= text then enable.Text = text end
            enable.BackgroundColor3 = state.enabled and color.green or color.blue
            if os.clock() >= infoUntil and info.Text ~= message then info.Text = message end
        end,
    })
    function progressController.combatTransition()
        local phase = objective()
        return phase == "rubble" or phase == "area" or phase == "end"
    end
    enable.Activated:Connect(progressController.toggle)
    scan.Activated:Connect(function()
        indexer.scan("route")
        if closed then return end
        local phase, area = objective()
        local rubble, marker = nearest("rubble"), nearest("area", area)
        local lines = {"Rubble / AREA scan v1.21", "Objective: " .. tostring(phase) .. " area=" .. tostring(area),
            "Objective label: " .. (objectiveLabel and objectiveLabel:GetFullName() or "none")}
        for _, item in ipairs({{name = "Rubble", target = rubble}, {name = "AREA", target = marker}}) do
            local t = item.target
            lines[#lines + 1] = item.name .. ": " .. (t and (t.object and t.object:GetFullName() or t.label) or "not located")
            if t then lines[#lines + 1] = "  point=" .. tostring(t.position) .. " estimated=" .. tostring(t.estimated) end
        end
        local _, humanoid, root = ownCharacter()
        lines[#lines + 1] = "Route phase=" .. progressController.state.phase ..
            " root=" .. tostring(root and root.Position) .. " anchored=" .. tostring(root and root.Anchored) ..
            " animationBusy=" .. tostring(humanoid and skillAnimationBusy(humanoid))
        local chip = playerGui:FindFirstChild("NextAreaChip")
        if chip then
            lines[#lines + 1] = "NextAreaChip class=" .. chip.ClassName
            for _, child in ipairs(chip:GetDescendants()) do
                if child:IsA("TextLabel") or child:IsA("ObjectValue") then
                    lines[#lines + 1] = "CHIP " .. child:GetFullName() .. " | " ..
                        (child:IsA("TextLabel") and child.Text or tostring(child.Value))
                end
            end
        end
        local count = 0
        for plate in pairs(hoverBillboards) do
            local text = plateText(plate)
            local lower = text:lower()
            if lower:find("rubble", 1, true) or lower:find("area", 1, true) then
                count = count + 1
                if count <= 25 then
                    local anchor = plateAnchor(plate)
                    lines[#lines + 1] = "PLATE " .. plate:GetFullName() .. " | " .. text:sub(1, 180) ..
                        " | world=" .. (anchor and anchor:GetFullName() or "no world anchor")
                end
            end
        end
        count = 0
        for label in pairs(resultLabels) do
            local text = cleanPlateText(label.Text)
            if shown(label) and (text:lower():find("rubble", 1, true) or text:lower():find("area", 1, true)) then
                count = count + 1
                if count <= 25 then lines[#lines + 1] = "GUI " .. label:GetFullName() .. " | " .. text:sub(1, 150) end
            end
        end
        count = 0
        for object in pairs(routeObjects) do
            count = count + 1
            if count <= 25 then
                local p = worldPosition(object)
                lines[#lines + 1] = "WORLD " .. object.ClassName .. " " .. object:GetFullName() ..
                    " | position=" .. (p and tostring(p) or "none")
            end
        end
        local report = table.concat(lines, "\n")
        print(report)
        local copy, copied = setclipboard or toclipboard, false
        if type(copy) == "function" then copied = pcall(copy, report) end
        infoUntil = os.clock() + 6
        info.Text = copied and "คัดลอกข้อมูลแล้ว • ส่งให้ผมถ้าตำแหน่งยังไม่เจอครับ" or "ดูข้อมูลสแกนใน Console (F9)"
    end)
end
-- End rubble / AREA progression.

local activePage = "skills"
local function showWindowPage(name)
    activePage = name
    hotkeyHint.Visible = not collapsed
    content.Visible = not collapsed and name == "skills"
    hoverPage.Visible = not collapsed and name == "hover"
    flightPage.Visible = not collapsed and name == "flight"
    autoEPage.Visible = not collapsed and name == "autoE"
    resultsPage.Visible = not collapsed and name == "results"
    routePage.Visible = not collapsed and name == "route"
    skillTab.BackgroundColor3 = name == "skills" and color.blue or color.button
    hoverTab.BackgroundColor3 = name == "hover" and color.blue or color.button
    flightTab.BackgroundColor3 = name == "flight" and color.blue or color.button
    autoETab.BackgroundColor3 = name == "autoE" and color.blue or color.button
    resultsTab.BackgroundColor3 = name == "results" and color.blue or color.button
    routeTab.BackgroundColor3 = name == "route" and color.blue or color.button
end
skillTab.Activated:Connect(function() showWindowPage("skills") end)
hoverTab.Activated:Connect(function() showWindowPage("hover") end)
flightTab.Activated:Connect(function() showWindowPage("flight") end)
autoETab.Activated:Connect(function() showWindowPage("autoE") end)
resultsTab.Activated:Connect(function() showWindowPage("results") end)
routeTab.Activated:Connect(function() showWindowPage("route") end)
local nextHoverTick = 0
table.insert(connections, RunService.Heartbeat:Connect(function()
    if closed or not hoverController.state.enabled or os.clock() < nextHoverTick then return end
    if progressController and progressController.state.busy then return end
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
        [Enum.KeyCode.F4] = toggleAutoE,
        [Enum.KeyCode.F5] = resultsController.toggle,
        [Enum.KeyCode.F6] = progressController.toggle,
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
    skillTab.Visible, hoverTab.Visible, flightTab.Visible, autoETab.Visible, resultsTab.Visible, routeTab.Visible = not collapsed, not collapsed, not collapsed, not collapsed, not collapsed, not collapsed
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
    if autoEController then autoEController.hidden(autoEController.state.held and autoEController.state.held.prompt) end
    stopFlight("ตัวละครหายไป • เปิดบินใหม่หลังเกิดครับ")
end))
local nextTick = 0
table.insert(connections, RunService.Heartbeat:Connect(function()
    if closed or os.clock() < nextTick then return end
    nextTick = os.clock() + 0.05
    if not indexer.failed then
        local okIndex, errIndex = pcall(indexer.step)
        if not okIndex then
            indexer.failed = true
            indexer.stop()
            warn("Autokey indexing stopped:", errIndex)
        end
    end
    local active = controller.state.enabled or hoverController.state.enabled
        or autoEController.state.enabled or resultsController.state.enabled or progressController.state.enabled
    if not active then
        resultsController.state.visible = false
        return
    end
    if progressController.state.enabled then
        local okRoute, errRoute = pcall(progressController.step)
        if not okRoute then progressController.stop() warn("Auto Route:", errRoute) end
    end
    if resultsController.state.enabled then
        local okResult, errResult = pcall(resultsController.step)
        if not okResult then resultsController.stop() warn("Auto Results:", errResult) end
    else
        -- Combat only needs the known screen's visibility, not button discovery or caption scans.
        resultsController.monitor()
    end
    if autoEController.state.enabled then
        local okE, errE = pcall(autoEController.step)
        if not okE then autoEController.stop() warn("Auto E:", errE) end
    end
    if controller.state.enabled then
        local ok, err = pcall(controller.step)
        if not ok then controller.stop() warn("Auto Skill 123:", err) end
    end
end))
session.stops = {
    indexer.stop,
    hotkeys.clear,
    controller.dispose,
    autoEController.stop,
    resultsController.stop,
    function() progressController.stop(false) end,
    function() stopFlight("ปิดหน้าต่างแล้ว") end,
    function() if hoverController then hoverController.stop() end end,
    function()
        table.clear(hoverHumanoids)
        table.clear(hoverModels)
        table.clear(hoverBillboards)
        table.clear(autoEPrompts)
        table.clear(autoEVisible)
        table.clear(resultButtons)
        table.clear(resultLabels)
        table.clear(routeObjects)
    end,
}
if closed then cleanupSession() end

