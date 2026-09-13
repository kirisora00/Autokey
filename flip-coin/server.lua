-- Flip Coin test system (ServerScriptService)
-- Use only in an experience you own. The server controls cooldown, rewards, and AUTO FLIP.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = {
    ManualCooldown = 0.50,
    AutoMinInterval = 0.25,
    AutoMaxInterval = 3.00,
    StartingCoins = 0,
    HeadsReward = 20,
    TailsMultiplier = 0.52,
}

local system = ReplicatedStorage:FindFirstChild("FlipCoinSystem")
if not system then
    system = Instance.new("Folder")
    system.Name = "FlipCoinSystem"
    system.Parent = ReplicatedStorage
end

local flipRequest = system:FindFirstChild("FlipRequest")
if not flipRequest then
    flipRequest = Instance.new("RemoteEvent")
    flipRequest.Name = "FlipRequest"
    flipRequest.Parent = system
end

local flipResult = system:FindFirstChild("FlipResult")
if not flipResult then
    flipResult = Instance.new("RemoteEvent")
    flipResult.Name = "FlipResult"
    flipResult.Parent = system
end

local rng = Random.new()
local stateByPlayer = {}

local function getCoinValue(player)
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then
        leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"
        leaderstats.Parent = player
    end

    local coins = leaderstats:FindFirstChild("Coins")
    if not coins then
        coins = Instance.new("IntValue")
        coins.Name = "Coins"
        coins.Value = Config.StartingCoins
        coins.Parent = leaderstats
    end

    return coins
end

local function getState(player)
    local state = stateByPlayer[player]
    if not state then
        state = {
            auto = false,
            interval = Config.AutoMinInterval,
            nextAllowed = 0,
            token = 0,
        }
        stateByPlayer[player] = state
    end
    return state
end

local function send(player, data)
    if player.Parent == Players then
        flipResult:FireClient(player, data)
    end
end

local function flipOnce(player)
    if player.Parent ~= Players then return false end

    local state = getState(player)
    local now = os.clock()
    local interval = state.auto and state.interval or Config.ManualCooldown

    if now < state.nextAllowed then
        send(player, {
            ok = false,
            reason = "Cooldown",
            remaining = state.nextAllowed - now,
            auto = state.auto,
            interval = interval,
        })
        return false
    end

    state.nextAllowed = now + interval

    local tails = rng:NextNumber() < 0.5
    local reward = tails
        and math.floor(Config.HeadsReward * Config.TailsMultiplier)
        or Config.HeadsReward

    local coins = getCoinValue(player)
    coins.Value += reward

    send(player, {
        ok = true,
        side = tails and "TAILS" or "HEADS",
        reward = reward,
        balance = coins.Value,
        auto = state.auto,
        interval = interval,
    })
    return true
end

local function stopAuto(player)
    local state = getState(player)
    state.auto = false
    state.token += 1
    send(player, {ok = true, auto = false, interval = state.interval})
end

local function startAuto(player)
    local state = getState(player)
    state.auto = true
    state.token += 1
    local token = state.token

    send(player, {ok = true, auto = true, interval = state.interval})

    task.spawn(function()
        while player.Parent == Players do
            local current = getState(player)
            if not current.auto or current.token ~= token then
                break
            end
            flipOnce(player)
            task.wait(current.interval)
        end
    end)
end

flipRequest.OnServerEvent:Connect(function(player, action, value)
    if action == "Flip" then
        flipOnce(player)
        return
    end

    if action == "SetInterval" then
        local state = getState(player)
        local number = tonumber(value)
        if number then
            state.interval = math.clamp(
                number,
                Config.AutoMinInterval,
                Config.AutoMaxInterval
            )
        end
        send(player, {
            ok = true,
            auto = state.auto,
            interval = state.interval,
        })
        return
    end

    if action == "SetAuto" then
        if value == true then
            startAuto(player)
        elseif value == false then
            stopAuto(player)
        end
    end
end)

Players.PlayerAdded:Connect(function(player)
    getState(player)
    getCoinValue(player)
end)

Players.PlayerRemoving:Connect(function(player)
    stateByPlayer[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
    getState(player)
    getCoinValue(player)
end
