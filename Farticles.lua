local _, addon = ...

-- Each style owns its particle count and motion. Future unlocks can add styles
-- without changing the fart action or the saved colour and slider settings.
local styles = {
    jet = { count = 18, spread = 12, travel = 140, puffSize = 28 },
    cloud = { count = 14, spread = 38, travel = 18, puffSize = 46 },
}
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
            puff.texture:SetSize(size, size)
            puff.texture:SetPoint("CENTER", frame, "CENTER", x, y)
            puff.texture:SetAlpha(math.sin(progress * math.pi) * frame.opacity * 0.6)
        end
    end
end

local function playEffect(slot, x, y, settings)
    local kind = settings.style == "jet" and "jet" or "cloud"
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
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
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
        puff.texture:SetVertexColor(unpack(settings.color))
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
    if not graphics or not graphics.enabled then return end
    local x, y = UIParent:GetCenter()
    local ok, err = pcall(playEffect, slot, x + (graphics.anchorX or 0), y + (graphics.anchorY or -80), graphics[slot])
    if not ok then
        if effects[slot] then stopEffect(effects[slot]) end
        if not graphicsErrorReported then
            graphicsErrorReported = true
            print("Faction Farter graphics: " .. tostring(err))
        end
    end
end

function addon.PreviewFarticle(slot)
    if not FactionFarterDB.graphics.enabled then
        print("Faction Farter: Enable Show farticles to preview.")
        return
    end
    addon.PlayFarticle(slot)
end
