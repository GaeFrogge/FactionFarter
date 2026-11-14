local active = false

local panel = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate, BackdropTemplate")
panel:SetSize(345, 126)
panel:SetPoint("CENTER")
panel:SetFrameStrata("DIALOG")
panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
panel:SetBackdropColor(0.07, 0.07, 0.09, 0.95)
panel:EnableMouse(true)
panel:Hide()
panel:SetAttribute("_onstate-combat", [[
    if newstate == "combat" then self:Hide() end
]])
RegisterStateDriver(panel, "combat", "[combat] combat; peace")

local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
heading:SetPoint("TOP", 0, -12)
heading:SetText("Faction Farter")
panel:SetMovable(true)
panel:SetClampedToScreen(true)
local titleBar = CreateFrame("Frame", nil, panel)
titleBar:SetPoint("TOPLEFT")
titleBar:SetPoint("TOPRIGHT")
titleBar:SetHeight(33)
titleBar:EnableMouse(true)
titleBar:RegisterForDrag("LeftButton")

local moving = false
local function stopMoving()
    if moving then
        moving = false
        panel:StopMovingOrSizing()
        local x, y = panel:GetCenter()
        local cx, cy = UIParent:GetCenter()
        if FactionFarterDB and x and y and cx and cy then
            FactionFarterDB.windowX, FactionFarterDB.windowY = x - cx, y - cy
        end
    end
end

titleBar:SetScript("OnDragStart", function()
    if InCombatLockdown() then return end
    panel:StartMoving()
    moving = true
end)
titleBar:SetScript("OnDragStop", stopMoving)
panel:HookScript("OnHide", stopMoving)
local counters = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
counters:SetPoint("TOP", 0, -36)
local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("TOP", 0, -98)

local function readable(value)
    return not issecretvalue or not issecretvalue(value)
end

local function updateTotal()
    local faction = UnitFactionGroup("player")
    local opposite = readable(faction) and ({ Horde = "Alliance", Alliance = "Horde" })[faction]
    counters:SetFormattedText("%s members farted on: %d", opposite or "Opposite-faction", FactionFarterDB.lifetime)
end

local function candidate(unit)
    local player = UnitIsPlayer(unit)
    if not readable(player) or not player then return end
    local faction, ownFaction = UnitFactionGroup(unit), UnitFactionGroup("player")
    if not readable(faction) or not readable(ownFaction) then return end
    if (faction ~= "Alliance" and faction ~= "Horde") or not ownFaction or faction == ownFaction then return end
    local guid = UnitGUID(unit)
    local first, last = UnitName(unit)
    if not readable(guid) or not readable(first) or not readable(last) then return end
    if not guid or not first then return end
    local name = last and last ~= "" and (first .. " " .. last) or first
    return guid, name
end

local targetPortrait = panel:CreateTexture(nil, "ARTWORK")
targetPortrait:SetSize(32, 32)
targetPortrait:SetPoint("TOPLEFT", 12, -56)
targetPortrait:Hide()

local targetLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
targetLabel:SetPoint("TOPLEFT", 52, -66)
targetLabel:SetWidth(180)
targetLabel:SetJustifyH("LEFT")

local fart = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
fart:SetSize(90, 24)
fart:SetPoint("TOPRIGHT", -12, -60)
fart:SetText("Fart")

local function alreadyRecorded(guid, name)
    local db = FactionFarterDB
    return db.recordedPlayers[guid] or db.legacyNames[name]
end

local function refresh()
    if InCombatLockdown() or not panel:IsShown() then return end
    local guid, name = candidate("target")
    targetLabel:SetText(name or "Target an opposite-faction player")
    if guid then SetPortraitTexture(targetPortrait, "target") end
    targetPortrait:SetShown(guid ~= nil)
    local recorded = guid and alreadyRecorded(guid, name)
    fart:SetEnabled(guid ~= nil)
    fart:SetText(recorded and "Fart Again" or "Fart")
    updateTotal()
end

local settings = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
settings:SetSize(390, 388)
settings:SetPoint("CENTER")
settings:SetFrameStrata("DIALOG")
settings:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
settings:SetBackdropColor(0.07, 0.07, 0.09, 0.98)
settings:EnableMouse(true)
settings:Hide()
local settingsTitle = settings:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
settingsTitle:SetPoint("TOP", 0, -14)
settingsTitle:SetText("Faction Farter Settings")
local close = CreateFrame("Button", nil, settings, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT")
close:SetScript("OnClick", function() settings:Hide() end)

local function settingsButton(label, width, x, y, onClick)
    local button = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    return button
end

local mute = CreateFrame("CheckButton", nil, settings, "UICheckButtonTemplate")

local muteText = mute:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
muteText:SetPoint("LEFT", mute, "RIGHT", 2, 0)
muteText:SetText("Mute fart sounds")
mute:SetPoint("TOP", -(muteText:GetStringWidth() + 2) / 2, -100)

mute:SetScript("OnClick", function(self)
    FactionFarterDB.soundMuted = self:GetChecked() and true or false
end)

local function section(label, y)
    local title = settings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, y)
    title:SetText(label)
end
section("Sound", -43)
section("Incoming popup", -140)
local dataTitle = settings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dataTitle:SetPoint("TOP", 0, -278)
dataTitle:SetText("Character data")

local soundNames = { "Wet Fart", "Quick Fart", "Long Fart" }

local function selectedSound()
    local db = FactionFarterDB
    return db.randomSound and math.random(#soundNames) or db.soundStyle
end

local function playFartSound(style)
    local db = FactionFarterDB
    if db and not db.soundMuted then
        style = style or selectedSound()
        local file = ("Interface\\AddOns\\FactionFarter\\Sounds\\Recorded%d.mp3"):format(style)
        PlaySoundFile(file, "SFX")
    end
end

local soundChoice = CreateFrame("DropdownButton", nil, settings, "WowStyle1DropdownTemplate")
soundChoice:SetPoint("TOPLEFT", 53, -65)
soundChoice:SetSize(187, 24)
soundChoice:SetupMenu(function(_, root)
    local db = FactionFarterDB
    if not db then return end
    local function isSelected(style)
        if style == 0 then return db.randomSound end
        return not db.randomSound and db.soundStyle == style
    end
    local function selectSound(style)
        db.randomSound = style == 0
        if style ~= 0 then db.soundStyle = style end
    end
    for style, name in ipairs(soundNames) do
        root:CreateRadio(name, isSelected, selectSound, style)
    end
    root:CreateRadio("Random each time", isSelected, selectSound, 0)
end)
settingsButton("Preview", 88, 249, -65, function() playFartSound() end)

local pendingDeliveryErrors = {}
local function filterDeliveryError(_, _, message)
    if not readable(message) then return false end
    local pending = pendingDeliveryErrors[message]
    if not pending then return false end
    return GetTime() <= pending
end

local function sendSignal(prefix, guid, name, style)
    if ERR_CHAT_PLAYER_NOT_FOUND_S then
        local errorText = ERR_CHAT_PLAYER_NOT_FOUND_S:format(name)
        local expires = GetTime() + 3
        pendingDeliveryErrors[errorText] = expires
        C_Timer.After(3, function()
            if pendingDeliveryErrors[errorText] == expires then
                pendingDeliveryErrors[errorText] = nil
            end
        end)
    end
    pcall(C_ChatInfo.SendAddonMessage, prefix, ("fart:%s:%d"):format(guid, style), "WHISPER", name)
end

local signalPrefix = "FactionFarter"
local notification = CreateFrame("Frame", nil, UIParent)
notification:SetSize(420, 48)
notification:SetPoint("TOP", 0, -150)
notification:SetFrameStrata("HIGH")
notification:Hide()
local notificationText = notification:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
notificationText:SetPoint("CENTER")
notificationText:SetText("You got farted on!")
local notificationTimer
local placingAlert = false

local senderPortrait = notification:CreateTexture(nil, "ARTWORK")
senderPortrait:SetSize(30, 30)
senderPortrait:SetPoint("RIGHT", notificationText, "LEFT", -8, 0)
senderPortrait:Hide()

local function findSenderUnit(sender)
    local function matches(unit)
        local first, last = UnitName(unit)
        if not readable(first) or not first or not readable(last) then return false end
        local name = last and last ~= "" and (first .. " " .. last) or first
        return name == sender
    end
    for _, unit in ipairs({ "target", "focus", "mouseover" }) do
        if matches(unit) then return unit end
    end
    for index = 1, 40 do
        local unit = "nameplate" .. index
        if matches(unit) then return unit end
    end
end

local function showNotification(sender, style, partyTarget)
    local hasSender = readable(sender) and type(sender) == "string" and sender ~= ""
    notificationText:SetText(hasSender and ("You got farted on by %s!"):format(sender) or "You got farted on!")
    if partyTarget then notificationText:SetText(("%s farted on %s!"):format(sender, partyTarget)) end
    local unit = hasSender and findSenderUnit(sender)
    senderPortrait:SetShown(not not unit)
    if unit then SetPortraitTexture(senderPortrait, unit) end
    notificationText:SetPoint("CENTER", unit and 19 or 0, 0)
    if notificationTimer then notificationTimer:Cancel() end
    notification:Show()
    if not partyTarget then playFartSound(style) end
    if placingAlert then return end
    notificationTimer = C_Timer.NewTimer(3, function()
        notification:Hide()
        notificationTimer = nil
    end)
end

local colorPreview, swatchFill
local function applyAlertColor()
    local color = FactionFarterDB.alertColor
    notificationText:SetTextColor(unpack(color))
    colorPreview:SetTextColor(unpack(color))
    swatchFill:SetColorTexture(color[1], color[2], color[3], 1)
end

notification:SetMovable(true)
notification:SetClampedToScreen(true)
notification:RegisterForDrag("LeftButton")
local draggingAlert = false
notification:SetScript("OnDragStart", function(self)
    if not settings:IsShown() then return end
    draggingAlert = true
    self:StartMoving()
end)
notification:SetScript("OnDragStop", function(self)
    if not draggingAlert then return end
    draggingAlert = false
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    local cx, cy = UIParent:GetCenter()
    if x and y and cx and cy then
        FactionFarterDB.alertX, FactionFarterDB.alertY = x - cx, y - cy
    end
end)

local moveAlert
moveAlert = settingsButton("Move popup", 110, 23, -165, function()
    placingAlert = not placingAlert
    if notificationTimer then notificationTimer:Cancel(); notificationTimer = nil end
    notification:EnableMouse(placingAlert)
    notification:SetShown(placingAlert)
    moveAlert:SetText(placingAlert and "Done moving" or "Move popup")
end)
settings:HookScript("OnHide", function()
    if placingAlert then
        notification:GetScript("OnDragStop")(notification)
        placingAlert = false
        notification:EnableMouse(false)
        notification:Hide()
        moveAlert:SetText("Move popup")
    end
end)
settingsButton("Reset position", 110, 140, -165, function()
    FactionFarterDB.alertX, FactionFarterDB.alertY = nil, nil
    notification:ClearAllPoints()
    notification:SetPoint("TOP", UIParent, "TOP", 0, -150)
end)
colorPreview = settings:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
colorPreview:SetPoint("TOP", 0, -204)
colorPreview:SetText("You got farted on!")

local colorSwatch = settingsButton("", 32, 18, -230, function()
    local color = FactionFarterDB.alertColor
    local function update(r, g, b)
        FactionFarterDB.alertColor = { r, g, b }
        applyAlertColor()
    end
    ColorPickerFrame:SetupColorPickerAndShow({
        r = color[1], g = color[2], b = color[3],
        swatchFunc = function() update(ColorPickerFrame:GetColorRGB()) end,
        cancelFunc = function() update(unpack(color)) end,
    })
end)
swatchFill = colorSwatch:CreateTexture(nil, "ARTWORK")
swatchFill:SetPoint("TOPLEFT", 5, -5)
swatchFill:SetPoint("BOTTOMRIGHT", -5, 5)
local colorLabel = settings:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
colorLabel:SetPoint("LEFT", colorSwatch, "RIGHT", 8, 0)
colorLabel:SetText("Popup text color")
colorSwatch:ClearAllPoints()
colorSwatch:SetPoint("TOP", -(colorLabel:GetStringWidth() + 8) / 2, -230)

settingsButton("Test popup", 110, 257, -165, function() showNotification() end)

StaticPopupDialogs.FACTION_FARTER_RESET = {
    text = "Reset your tally and forget all previously counted players for this character?",
    button1 = "Reset", button2 = "Cancel",
    timeout = 0, hideOnEscape = true, whileDead = true,
    OnAccept = function()
        local db = FactionFarterDB
        db.lifetime = 0
        db.recordedPlayers, db.legacyNames = {}, {}
        refresh()
    end,
}
local resetData = settingsButton("Reset tally and history", 175, 18, -329, function()
    StaticPopup_Show("FACTION_FARTER_RESET")
end)
resetData:ClearAllPoints()
resetData:SetPoint("TOP", 0, -338)

local partyAlerts = CreateFrame("CheckButton", nil, settings, "UICheckButtonTemplate")

local partyLabel = partyAlerts:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
partyLabel:SetPoint("LEFT", partyAlerts, "RIGHT", 4, 0)
partyLabel:SetText("Show party alerts")
partyAlerts:SetPoint("TOP", -(partyLabel:GetStringWidth() + 4) / 2, -299)
partyAlerts:SetScript("OnClick", function(self)
    FactionFarterDB.partyAlerts = not not self:GetChecked()
end)

local factionEmotes = { Horde = "forthehorde", Alliance = "forthealliance" }
local factionMessages = {
    Horde = {
        "Fart well. Fart Horde.",
        "For the Horde!",
        "Lok'tar Ogar! Downwind!",
        "The Horde leaves an impression.",
    },
    Alliance = {
        "Fart well. Fart Alliance.",
        "For the Alliance!",
        "For Stormwind! Mind the breeze.",
        "Stand united. Preferably upwind.",
    },
}

function FactionFarter_PerformFart()
    if not FactionFarterDB or InCombatLockdown() then return end
    local guid, name = candidate("target")
    if not guid then
        refresh()
        return
    end
    local ok = pcall(DoEmote, "fart")
    if ok then
        if not alreadyRecorded(guid, name) then
            local db = FactionFarterDB
            db.recordedPlayers[guid] = true
            db.lifetime = db.lifetime + 1
        end
        refresh()
        local style = selectedSound()
        playFartSound(style)
        sendSignal(signalPrefix, guid, name, style)
        if IsInGroup() and not IsInRaid() then
            local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "PARTY"
            pcall(C_ChatInfo.SendAddonMessage, signalPrefix, ("party:%s:%s:%s"):format(UnitGUID("player"), guid, name), channel)
        end
        local faction = UnitFactionGroup("player")
        local messages = readable(faction) and factionMessages[faction]
        if not messages then return end
        status:SetText(messages[math.random(#messages)])
        pcall(DoEmote, factionEmotes[faction])
    else
        status:SetText("The client rejected the emote.")
    end
end
fart:SetScript("OnClick", FactionFarter_PerformFart)

SLASH_FACTIONFARTERFART1 = "/fffart"
SlashCmdList.FACTIONFARTERFART = FactionFarter_PerformFart

local function toggle()
    if not FactionFarterDB or InCombatLockdown() then return end
    active = not active
    if active then
        status:SetText("")
        panel:Show()
        refresh()
    else
        settings:Hide()
        panel:Hide()
    end
end

local minimap = CreateFrame("Button", "FactionFarterMinimapButton", Minimap)
minimap:SetSize(31, 31)
minimap:SetFrameLevel(Minimap:GetFrameLevel() + 8)
local icon = minimap:CreateTexture(nil, "ARTWORK")
icon:SetSize(19, 19)
icon:SetPoint("CENTER", minimap, "CENTER", 1, 0.5)
icon:SetTexture("Interface\\Icons\\Spell_Nature_AbolishMagic")
icon:SetVertexColor(0.64, 1, 0.16)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
icon:AddMaskTexture((function()
    local mask = minimap:CreateMaskTexture()
    mask:SetAllPoints(icon)
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    return mask
end)())
local border = minimap:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
minimap:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local function placeMinimapButton(angle)
    local radius = Minimap:GetWidth() / 2 + 6
    minimap:ClearAllPoints()
    minimap:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

placeMinimapButton(math.pi / 4)
Minimap:HookScript("OnSizeChanged", function()
    placeMinimapButton(FactionFarterDB and FactionFarterDB.minimapAngle or math.pi / 4)
end)
minimap:RegisterForDrag("LeftButton")
minimap:SetScript("OnDragStart", function(self)
    if not FactionFarterDB then return end
    GameTooltip:Hide()
    self:SetScript("OnUpdate", function()
        local x, y = GetCursorPosition()
        local centerX, centerY = Minimap:GetCenter()
        local scale = Minimap:GetEffectiveScale()
        local angle = math.atan2(y / scale - centerY, x / scale - centerX)
        FactionFarterDB.minimapAngle = angle
        placeMinimapButton(angle)
    end)
end)
minimap:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)
minimap:SetScript("OnHide", function(self)
    self:SetScript("OnUpdate", nil)
end)
minimap:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimap:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
        if not FactionFarterDB then return end
        settings:SetShown(not settings:IsShown())
        if settings:IsShown() then settings:Raise() end
    else
        toggle()
    end
end)
minimap:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Faction Farter")
    GameTooltip:AddLine("Left click: Open main panel", 1, 1, 1)
    GameTooltip:AddLine("Right click: Open settings", 1, 1, 1)
    GameTooltip:Show()
end)
minimap:SetScript("OnLeave", function() GameTooltip:Hide() end)

SLASH_FACTIONFARTER1 = "/factionfarter"
SlashCmdList.FACTIONFARTER = toggle
SLASH_FACTIONFARTERTEST1 = "/fftest"
SlashCmdList.FACTIONFARTERTEST = function() showNotification() end
local function receiveSignal(prefix, message, channel, sender)
    if readable(prefix) and prefix == signalPrefix and readable(channel)
        and (channel == "PARTY" or channel == "INSTANCE_CHAT")
        and FactionFarterDB and FactionFarterDB.partyAlerts and not IsInRaid()
        and readable(message) and type(message) == "string"
        and readable(sender) and type(sender) == "string" and sender ~= "" then
        local source, target, name = message:match("^party:([^:]+):([^:]+):([^:]+)$")
        local ownGUID = UnitGUID("player")
        if name and readable(ownGUID) and ownGUID and source ~= ownGUID and target ~= ownGUID then
            showNotification(sender, nil, name)
        end
        return
    end
    if readable(prefix) and readable(message) and readable(channel)
        and prefix == signalPrefix and channel == "WHISPER" then
        local guid = UnitGUID("player")
        if not readable(guid) or not guid or type(message) ~= "string" then return end
        if message == "fart:" .. guid then
            showNotification(sender)
            return
        end
        local recipient, sound = message:match("^fart:([^:]+):(%d)$")
        local style = tonumber(sound)
        if recipient == guid and style and soundNames[style] then
            showNotification(sender, style)
        end
    end
end

SLASH_FACTIONFARTERMOCK1 = "/ffmock"
SlashCmdList.FACTIONFARTERMOCK = function(input)
    local guid = UnitGUID("player")
    if not readable(guid) or not guid then return end
    local sender = strtrim(input or "")
    if sender == "" then
        local _, targetName = candidate("target")
        sender = targetName or "Test Sender"
    end
    receiveSignal(signalPrefix, ("fart:%s:%d"):format(guid, selectedSound()), "WHISPER", sender)
end

BINDING_HEADER_FACTIONFARTER = "Faction Farter"
BINDING_NAME_FACTIONFARTER_FART = "Fart / Fart Again"

local bindingOwner = CreateFrame("Frame")
local function updateDefaultBinding()
    if InCombatLockdown() then return end
    ClearOverrideBindings(bindingOwner)
    if GetBindingKey("FACTIONFARTER_FART") then return end
    local key = "CTRL-ALT-F"
    if GetBindingAction(key, true) == "" then
        SetOverrideBinding(bindingOwner, false, key, "FACTIONFARTER_FART")
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("UNIT_PORTRAIT_UPDATE")
events:RegisterEvent("CHAT_MSG_ADDON")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("UPDATE_BINDINGS")
events:SetScript("OnEvent", function(self, event, addon, message, channel, sender)
    if event == "ADDON_LOADED" then
        if addon ~= "FactionFarter" then return end
        FactionFarterDB = FactionFarterDB or { lifetime = 0 }
        local db = FactionFarterDB
        db.soundStyle = db.soundStyle or 1
        soundChoice:GenerateMenu()
        db.alertColor = db.alertColor or { 1, 0.82, 0 }
        applyAlertColor()
        if db.alertX and db.alertY then
            notification:ClearAllPoints()
            notification:SetPoint("CENTER", UIParent, "CENTER", db.alertX, db.alertY)
        end
        mute:SetChecked(db.soundMuted)
        partyAlerts:SetChecked(db.partyAlerts)
        if db.windowX and db.windowY then
            panel:ClearAllPoints()
            panel:SetPoint("CENTER", UIParent, "CENTER", db.windowX, db.windowY)
        end
        if not db.recordedPlayers then
            db.recordedPlayers = {}
            db.legacyNames = {}
            for _, name in ipairs(db.history or {}) do
                db.legacyNames[name] = true
            end
        end
        db.history, db.daily, db.day = nil, nil, nil
        placeMinimapButton(FactionFarterDB.minimapAngle or math.pi / 4)
        C_ChatInfo.RegisterAddonMessagePrefix(signalPrefix)
        local addFilter = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
        if addFilter then addFilter("CHAT_MSG_SYSTEM", filterDeliveryError) end
        self:UnregisterEvent(event)
    elseif event == "CHAT_MSG_ADDON" then
        receiveSignal(addon, message, channel, sender)
        return
    elseif event == "UNIT_PORTRAIT_UPDATE" then
        if addon ~= "target" then return end
    elseif event == "PLAYER_TARGET_CHANGED" then
        status:SetText("")
    elseif event == "PLAYER_LOGIN" or event == "UPDATE_BINDINGS" then
        updateDefaultBinding()
    elseif event == "PLAYER_REGEN_ENABLED" then
        updateDefaultBinding()
        if active then panel:Show() end
    end
    refresh()
end)
