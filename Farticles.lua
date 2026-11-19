local _, addon = ...

-- Each style owns its particle count and motion. Future unlocks can add styles
-- without changing the fart action or the saved color and slider settings.
local styles = {
    jet = { count = 18, spread = 12, travel = 140, puffSize = 28 },
    cloud = { count = 14, spread = 38, travel = 18, puffSize = 46 },
    confetti = { count = 36, spread = 10, travel = 140, puffSize = 1.5 },
}
addon.FarticleStyles = { cloud = "Classic gas cloud", jet = "Classic gas jet", confetti = "Confetti bomb" }
local effects = {}
local function setting(value, default, maximum, step)
    value = tonumber(value) or default
    if value == 0 then return math.random(1, maximum / step) * step end
    return math.max(step, math.min(maximum, value))
end

local function stopEffect(frame)
    frame:SetScript("OnUpdate", nil)
    frame:Hide()
end

local function animate(frame, delta)
    if not FactionFarterDB.graphics.enabled then stopEffect(frame); return end
    if frame.partyUnit then
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, frame.partyUnit)
        if not FactionFarterDB.graphics.partyEnabled or not ok or plate ~= frame.partyPlate
            or not plate:IsVisible() or UnitGUID(frame.partyUnit) ~= frame.partyGUID then
            stopEffect(frame); return
        end
    end
    frame.elapsed = frame.elapsed + delta
    if frame.elapsed >= frame.duration then stopEffect(frame); return end
    for index = 1, frame.motion.count do
        local puff = frame.puffs[index]
        local progress = (frame.elapsed / frame.duration - puff.delay) / (1 - puff.delay)
        if progress <= 0 then
            puff.texture:SetAlpha(0)
        else
            local distance = frame.motion.travel * progress * frame.size
            local x = puff.x * frame.size
            local y = puff.y * frame.size + distance
            if frame.kind == "jet" then y = puff.y * frame.size - distance end
            local size = frame.motion.puffSize * frame.size * (0.45 + progress)
            if frame.kind == "confetti" then
                -- Spend the first 18% bursting upward, then flutter down slowly.
                local rise = math.min(progress / 0.18, 1)
                local burst = 1 - (1 - rise) * (1 - rise)
                local fall = math.max(0, (progress - 0.18) / 0.82)
                x = (puff.x + puff.vx * (0.6 * burst + 0.4 * progress)
                    + math.sin(progress * 16 + puff.phase) * 6 * progress) * frame.size
                y = (puff.y + puff.vy * 0.2 * burst - 130 * fall ^ 1.3) * frame.size
                size = frame.motion.puffSize * frame.size
                puff.texture:SetSize(size * (0.35 + 0.65 * math.abs(math.cos(progress * 18 + puff.phase))), size * 1.6)
                puff.texture:SetRotation(puff.phase + progress * puff.spin)
            else
                puff.texture:SetSize(size, size)
            end
            puff.texture:SetPoint("CENTER", frame, "CENTER", x, y)
            puff.texture:SetAlpha(frame.kind == "confetti" and frame.opacity * math.min(1, (1 - progress) * 4)
                or math.sin(progress * math.pi) * frame.opacity * 0.6)
        end
    end
end

local function playEffect(slot, x, y, settings, unit, plate)
    local kind = styles[settings.style] and settings.style or "cloud"
    local motion = styles[kind]
    local frame = effects[slot]
    if not frame then
        frame = CreateFrame("Frame", nil, UIParent)
        frame:SetSize(1, 1)
        frame:SetFrameStrata("HIGH")
        frame:EnableMouse(false)
        frame.puffs = {}
        effects[slot] = frame
    end
    frame.kind, frame.motion, frame.elapsed = kind, motion, 0
    -- Saved size is 0..200, displayed as 0..100%; zero means Random.
    frame.size = setting(settings.size, 100, 200, 10) / 50
    frame.opacity = setting(settings.opacity, 65, 100, 5) / 100
    frame.duration = setting(settings.duration, 2, 8, 0.5)
    frame:ClearAllPoints()
    frame.partyUnit, frame.partyPlate = unit, plate
    frame.partyGUID = unit and UnitGUID(unit)
    if plate then frame:SetPoint("CENTER", plate, "BOTTOM", 0, -30)
    else frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y) end
    for index = 1, motion.count do
        local puff = frame.puffs[index]
        if not puff then
            local texture = frame:CreateTexture(nil, "ARTWORK")
            texture:SetAtlas("BonusChest-CircleGlow")
            texture:SetBlendMode("BLEND")
            puff = { texture = texture }
            frame.puffs[index] = puff
        end
        puff.x = (math.random() - 0.5) * motion.spread
        puff.y = (math.random() - 0.5) * motion.spread
        puff.delay = (index - 1) / motion.count * (kind == "jet" and 0.65 or 0.35)
        if kind == "confetti" then
            puff.texture:SetTexture("Interface\\Buttons\\WHITE8X8")
            puff.delay = (index - 1) / motion.count * 0.025
            puff.vx = (math.random() - 0.5) * 230
            puff.vy = 120 + math.random() * 190
            puff.phase, puff.spin = math.random() * math.pi * 2, (math.random() - 0.5) * 24
            local r, g, b = unpack(settings.color)
            -- A half-turn in HSL hue keeps the selected saturation/lightness.
            if index % 2 == 0 then
                local sum = math.min(r, g, b) + math.max(r, g, b)
                r, g, b = sum - r, sum - g, sum - b
            end
            local tint = index % 3 == 0 and 0.3 or 0
            puff.texture:SetVertexColor(r + (1 - r) * tint, g + (1 - g) * tint, b + (1 - b) * tint)
        else
            puff.texture:SetAtlas("BonusChest-CircleGlow")
            puff.texture:SetVertexColor(unpack(settings.color))
        end
        puff.texture:SetRotation(math.random() * math.pi * 2)
        puff.texture:SetAlpha(0)
        puff.texture:Show()
    end
    for index = motion.count + 1, #frame.puffs do
        frame.puffs[index].texture:Hide()
    end
    frame:Show()
    frame:SetScript("OnUpdate", animate)
end

local anchor
local function positionAnchor()
    local graphics = FactionFarterDB.graphics
    anchor:ClearAllPoints()
    anchor:SetPoint("CENTER", UIParent, "CENTER", graphics.anchorX or 0, graphics.anchorY or -80)
end

function addon.SetFarticleAnchorEditing(editing)
    if not anchor then
        if not editing then return end
        anchor = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        anchor:SetSize(150, 52)
        anchor:SetFrameStrata("DIALOG")
        anchor:SetClampedToScreen(true)
        anchor:SetMovable(true)
        anchor:EnableMouse(true)
        anchor:RegisterForDrag("LeftButton")
        anchor:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
        })
        anchor:SetBackdropColor(0.07, 0.1, 0.06, 0.9)
        anchor:SetBackdropBorderColor(0.5, 0.85, 0.25, 1)
        local label = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("CENTER")
        label:SetText("+ Farticle origin\nDrag to position")
        anchor:SetScript("OnDragStart", function(self) self:StartMoving() end)
        local function savePosition(self)
            self:StopMovingOrSizing()
            local x, y = self:GetCenter()
            local cx, cy = UIParent:GetCenter()
            FactionFarterDB.graphics.anchorX = x - cx
            FactionFarterDB.graphics.anchorY = y - cy
        end
        anchor:SetScript("OnDragStop", savePosition)
        anchor:SetScript("OnHide", savePosition)
    end
    if editing then positionAnchor() end
    anchor:SetShown(editing)
end

function addon.ResetFarticleAnchor()
    local graphics = FactionFarterDB.graphics
    graphics.anchorX, graphics.anchorY = nil, nil
    if anchor then positionAnchor() end
end

local graphicsErrorReported = false
function addon.PlayFarticle(slot)
    local graphics = FactionFarterDB and FactionFarterDB.graphics
    if not graphics then return end
    local selected = graphics[slot]
    local resolved = {
        style = styles[selected.style] and selected.style or "cloud",
        color = { unpack(selected.color) },
        size = setting(selected.size, 100, 200, 10),
        opacity = setting(selected.opacity, 65, 100, 5),
        duration = setting(selected.duration, 2, 8, 0.5),
    }
    if not graphics.enabled then return resolved end
    local x, y = UIParent:GetCenter()
    local ok, err = pcall(playEffect, slot, x + (graphics.anchorX or 0), y + (graphics.anchorY or -80), resolved)
    if not ok then
        if effects[slot] then stopEffect(effects[slot]) end
        if not graphicsErrorReported then
            graphicsErrorReported = true
            print("Faction Farter graphics: " .. tostring(err))
        end
    end
    return resolved
end

function addon.PlayPartyFarticle(unit, settings)
    local graphics = FactionFarterDB.graphics
    if not graphics.enabled or not graphics.partyEnabled or not C_NamePlate then return end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate then return end
    pcall(function()
        if plate:IsForbidden() or not plate:IsVisible() then return end
        playEffect(unit, 0, 0, settings, unit, plate)
    end)
end

function addon.PreviewFarticle(slot)
    if not FactionFarterDB.graphics.enabled then
        print("Faction Farter: Enable Show farticles to preview.")
        return
    end
    addon.PlayFarticle(slot)
end

local shartFrame
local function animateShart(frame, elapsed)
    local db = FactionFarterDB
    if not db.graphics.enabled or (db.abilityTimers.shart or 0) <= GetServerTime() then
        stopEffect(frame)
        return
    end
    frame.elapsed = frame.elapsed + elapsed
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", db.graphics.anchorX or 0, db.graphics.anchorY or -80)
    for index, drop in ipairs(frame.drops) do
        local age = (frame.elapsed + index * 0.19) % 1.8
        drop.texture:SetPoint("CENTER", frame, "CENTER", drop.x, -85 * age * age)
        drop.texture:SetAlpha(math.sin(age / 1.8 * math.pi) * 0.85)
    end
end

function addon.RefreshShartEffect()
    local db = FactionFarterDB
    local active = db and db.graphics and db.graphics.enabled and db.abilityTimers
        and (db.abilityTimers.shart or 0) > GetServerTime()
    if not active then
        if shartFrame then stopEffect(shartFrame) end
        return
    end
    if not shartFrame then
        shartFrame = CreateFrame("Frame", nil, UIParent)
        shartFrame:SetSize(1, 1)
        shartFrame:SetFrameStrata("HIGH")
        shartFrame:EnableMouse(false)
        shartFrame.elapsed = 0
        shartFrame.drops = {}
        for index = 1, 12 do
            local texture = shartFrame:CreateTexture(nil, "ARTWORK")
            texture:SetAtlas("BonusChest-CircleGlow")
            texture:SetBlendMode("BLEND")
            texture:SetVertexColor(0.32, 0.14, 0.035)
            local size = 6 + index % 4 * 2
            texture:SetSize(size, size * 2.5)
            texture:SetAlpha(0)
            shartFrame.drops[index] = { texture = texture, x = math.random(-28, 28) }
        end
    end
    animateShart(shartFrame, 0)
    shartFrame:Show()
    shartFrame:SetScript("OnUpdate", animateShart)
end
