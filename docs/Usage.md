### Server data updated immutably
```lua
local gameStats = {
    round = 0,
    playerCount = 0,
}
local lastSent = gameStats

local function incrementRound()
    gameStats = Sift.Dictionary.merge(gameStats, {
        round = gameStats.round + 1,
    })
end

local function onPlayerAdded(player: Player)
    -- When a new player joins, we can send them a diff between nil and gameStats.
    local initialDiff = DeltaCompress.diff(nil, gameStats)

    ReplicatedStorage.RoundInfoUpdateRemote:FireClient(initialDiff)
end

RunService.Heartbeat:Connect(function()
    if lastSent == gameStats then
        -- gameStats hasn't changed.
        return
    end

    -- Since data is update immutably, there should always be a diff.
    local diff = DeltaCompress.diff(lastSent, gameStats)

    lastSent = gameStats

    ReplicatedStorage.RoundInfoUpdateRemote:FireAllClients(diff)
end)
```

### Server data updated mutably
```lua
local gameStats = {
    round = 0,
    playerCount = 0,
}
local lastSent = deepCopy(gameStats)

local function incrementRound()
    gameStats.round += 1
end

local function onPlayerAdded(player: Player)
    -- When a new player joins, we can send them a diff between nil and gameStats.
    local initialDiff = DeltaCompress.diff(nil, gameStats)

    ReplicatedStorage.RoundInfoUpdateRemote:FireClient(initialDiff)
end

RunService.Heartbeat:Connect(function()
    local diff = DeltaCompress.diff(lastSent, gameStats)

    if diff == nil then
        -- gameStats hasn't changed.
        return
    end

    lastSent = deepCopy(gameStats)

    ReplicatedStorage.RoundInfoUpdateRemote:FireAllClients(diff)
end)
```

### Client
```lua
local gameStats = nil

ReplicatedStorage.RoundInfoUpdateRemote.OnClientEvent(function(diff)
    -- The diff can be applied immutably or mutably depending on your usecase!
    gameStats = DeltaCompress.applyImmutable(gameStats, diff)
end)
