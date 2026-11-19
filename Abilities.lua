local _, addon = ...
local abilities = {}
addon.Abilities = abilities

local requirements = { fart = 0, risk = 50, autofart = 150 }
local cooldowns = { risk = 1800, autofart = 3600 }

function abilities.Initialize(db)
    db.abilityTimers = db.abilityTimers or {}
    for _, name in ipairs({ "shart", "risk", "autofart", "autofartActive", "autofartNextTag" }) do
        local expiry = tonumber(db.abilityTimers[name])
        if not expiry or expiry ~= expiry or expiry == math.huge or expiry < 0 then expiry = 0 end
        db.abilityTimers[name] = expiry
    end
end

function abilities.Remaining(name)
    local db = FactionFarterDB
    if not db or not db.abilityTimers then return 0 end
    return math.max(0, (db.abilityTimers[name] or 0) - GetServerTime())
end

function abilities.Requirement(name)
    return requirements[name]
end

function abilities.BlockReason(name, score)
    if abilities.Remaining("shart") > 0 then return "shart" end
    if score < requirements[name] then return "locked" end
    if cooldowns[name] and abilities.Remaining(name) > 0 then return "cooldown" end
end

function abilities.StartCooldown(name)
    FactionFarterDB.abilityTimers[name] = GetServerTime() + cooldowns[name]
end

function abilities.StartAutofart()
    abilities.StartCooldown("autofart")
    local timers = FactionFarterDB.abilityTimers
    timers.autofartActive = GetServerTime() + 30
    timers.autofartNextTag = 0
end

function abilities.StartShartLockout()
    local timers = FactionFarterDB.abilityTimers
    timers.shart = math.max(timers.shart, GetServerTime() + 300)
    timers.autofartActive, timers.autofartNextTag = 0, 0
end

function abilities.TimeText(seconds)
    seconds = math.max(0, math.ceil(seconds))
    local minutes = math.floor(seconds / 60)
    if minutes == 0 then return seconds .. "s" end
    return ("%dm %02ds"):format(minutes, seconds % 60)
end
