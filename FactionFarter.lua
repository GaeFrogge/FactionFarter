local active = false

local panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
panel:SetSize(345, 151)
panel:SetPoint("CENTER")
panel:SetFrameStrata("DIALOG")
panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
panel:SetBackdropColor(0.07, 0.07, 0.09, 0.95)
panel:EnableMouse(true)
panel:Hide()

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
local tallyPage = CreateFrame("Frame", nil, panel)
tallyPage:SetAllPoints(panel)
local counters = tallyPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
counters:SetPoint("TOP", 0, -62)
local status = tallyPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("TOP", 0, -124)

local function readable(value)
    return not issecretvalue or not issecretvalue(value)
end

local entries, byName, baseline = {}, {}, 0
local valid = false
local function key(name)
    return name:lower():gsub("%s+", " ")
end

local function hash(data)
    local value = 5381
    for i = 1, #data do value = (value * 33 + data:byte(i)) % 2147483647 end
    return value
end

local function saveLedger()
    local fields = { tostring(baseline) }
    local db = FactionFarterDB
    fields[2], fields[3] = db.ledgerOwner, db.ledgerFaction
    for _, row in ipairs(entries) do
        for i = 1, 5 do fields[#fields + 1] = row[i] end
    end
    for i, field in ipairs(fields) do
        fields[i] = (field:gsub(".", function(c) return ("%02x"):format(c:byte()) end))
    end
    local data = table.concat(fields, ":")
    db.ledger = { version = 1, data = data, checksum = hash(data) }
end

local function loadLedger(db)
    if db.ledger then
        local envelope = db.ledger
        if type(envelope) ~= "table" or envelope.version ~= 1 or type(envelope.data) ~= "string"
            or hash(envelope.data) ~= envelope.checksum then return false end
        local fields = {}
        for field in (envelope.data .. ":"):gmatch("([^:]*):") do
            if #field % 2 ~= 0 or field:find("[^%x]") then return false end
            fields[#fields + 1] = (field:gsub("%x%x", function(pair) return string.char(tonumber(pair, 16)) end))
        end
        local score = tonumber(fields[1])
        if not score or score < 0 or score % 1 ~= 0 or #fields < 3 or (#fields - 3) % 5 ~= 0 then return false end
        local loaded, index = {}, {}
        for i = 4, #fields, 5 do
            local name = key(fields[i])
            if name == "" or index[name] or (fields[i+2] ~= "" and not tonumber(fields[i+2])) then return false end
            loaded[#loaded + 1] = { unpack(fields, i, i + 4) }
            index[name] = true
        end
        entries, byName, baseline = loaded, index, score
        db.ledgerOwner, db.ledgerFaction = fields[2], fields[3]
        return true
    end
    baseline = tonumber(db.lifetime) or 0
    if baseline < 0 or baseline % 1 ~= 0 then return false end
    local function migrate(name)
        if type(name) ~= "string" or name == "" or byName[key(name)] then return end
        entries[#entries + 1] = { name, "", "", "", "" }
        byName[key(name)] = true
    end
    for name in pairs(db.legacyNames or {}) do migrate(name) end
    for _, name in ipairs(db.history or {}) do migrate(name) end
    local first, last = UnitName("player")
    db.ledgerOwner = first and last and last ~= "" and (first .. " " .. last) or first or ""
    db.ledgerFaction = UnitFactionGroup("player") or ""
    saveLedger()
    return true
end

SLASH_FACTIONFARTERSYNCPREVIEW1 = "/ffsyncpreview"
SlashCmdList.FACTIONFARTERSYNCPREVIEW = function()
    if not valid then return end
    local db = FactionFarterDB
    print(("name=%q faction=%q"):format(db.ledgerOwner, db.ledgerFaction))
    -- Ledger rows are append-only. Their indices are stable within this character's save.
    for id, row in ipairs(entries) do
        if row[3] ~= "" then
            print(("id=%d zone=%q time=%s"):format(id, row[4], row[3]))
        end
    end
end

local function tally()
    local total = baseline
    for _, entry in ipairs(entries) do
        if entry[3] ~= "" then total = total + 1 end
    end
    return total
end

local function targetPrompt()
    local faction = UnitFactionGroup("player")
    if readable(faction) then
        if faction == "Horde" then return "Please select an Alliance player." end
        if faction == "Alliance" then return "Please select a Horde player." end
    end
    return "Please select an opposing-faction player."
end

local function updateTotal()
    if not valid then counters:SetText("Saved tally needs recovery"); return end
    local faction = UnitFactionGroup("player")
    local opposite = readable(faction) and ({ Horde = "Alliance", Alliance = "Horde" })[faction]
    counters:SetFormattedText("%s members farted on: %d", opposite or "Opposite-faction", tally())
end

local function candidate(unit)
    local player = UnitIsPlayer(unit)
    if not readable(player) or not player then return end
    local faction, ownFaction = UnitFactionGroup(unit), UnitFactionGroup("player")
    if not readable(faction) or not readable(ownFaction) then return end
    if (faction ~= "Alliance" and faction ~= "Horde") or not ownFaction or faction == ownFaction then return end
    local guid = UnitGUID(unit)
    local first, last = UnitName(unit)
    if not readable(first) or not readable(last) then return end
    if type(first) ~= "string" or first == "" then return end
    local name = last and last ~= "" and (first .. " " .. last) or first
    return readable(guid) and guid or nil, name, faction
end

local targetPortrait = tallyPage:CreateTexture(nil, "ARTWORK")
targetPortrait:SetSize(32, 32)
targetPortrait:SetPoint("TOPLEFT", 12, -82)
targetPortrait:Hide()

local targetLabel = tallyPage:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
targetLabel:SetPoint("TOPLEFT", 52, -92)
targetLabel:SetWidth(180)
targetLabel:SetJustifyH("LEFT")

local fart = CreateFrame("Button", nil, tallyPage, "UIPanelButtonTemplate")
fart:SetSize(90, 24)
fart:SetPoint("TOPRIGHT", -12, -86)
fart:SetText("Fart")

local function alreadyRecorded(guid, name)
    local db = FactionFarterDB
    return byName[key(name)] or (db.recordedPlayers and db.recordedPlayers[guid])
end

local function refresh()
    if not panel:IsShown() then return end
    local guid, name = candidate("target")
    targetLabel:SetText(name or targetPrompt())
    if name then SetPortraitTexture(targetPortrait, "target") end
    targetPortrait:SetShown(name ~= nil)
    local recorded = name and alreadyRecorded(guid, name)
    fart:SetEnabled(name ~= nil or InCombatLockdown())
    fart:SetText(recorded and "Fart Again" or "Fart")
    updateTotal()
end

local settings = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
settings:SetSize(390, 342)
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
dataTitle:SetText("Notifications")

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

local historyPanel = CreateFrame("Frame", nil, panel)
historyPanel:SetPoint("TOPLEFT", 0, -60)
historyPanel:SetPoint("BOTTOMRIGHT")
historyPanel:Hide()

local historyTitle = historyPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
historyTitle:SetPoint("TOP", 0, -10)
local scroll = CreateFrame("ScrollFrame", nil, historyPanel, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 12, -32)
scroll:SetPoint("BOTTOMRIGHT", -30, 12)
local list = CreateFrame("Frame", nil, scroll)
list:SetSize(290, 1)
scroll:SetScrollChild(list)
local rows = {}

local function refreshHistory()
    if not historyPanel:IsVisible() then return end
    historyTitle:SetText(not valid and "History unavailable" or (#entries == 0 and "No recorded players yet" or "History"))
    if not valid then return end
    for position = 1, #entries do
        local row = rows[position]
        if not row then
            row = CreateFrame("Button", nil, list)
            row:SetSize(290, 22)
            row:SetPoint("TOPLEFT", 0, -(position - 1) * 22)
            row:SetNormalFontObject(GameFontHighlight)
            row:SetScript("OnEnter", function(self)
                local name, faction, stamp, zone, subzone = unpack(self.entry)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(name)
                if stamp == "" then
                    GameTooltip:AddLine("Details were not recorded.")
                else
                    GameTooltip:AddLine(faction)
                    GameTooltip:AddLine(date("%Y-%m-%d %H:%M", tonumber(stamp)))
                    if zone ~= "" then GameTooltip:AddLine(zone) end
                    if subzone ~= "" and subzone ~= zone then GameTooltip:AddLine(subzone) end
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            rows[position] = row
        end
        row.entry = entries[#entries - position + 1]
        row:SetText(row.entry[1])
    end
    list:SetHeight(math.max(1, #entries * 22))
end

historyPanel:SetScript("OnShow", refreshHistory)
local function createTab(label, offset)
    local tab = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    tab:SetSize(84, 22)
    tab:SetPoint("TOP", offset, -33)
    tab:SetText(label)
    return tab
end

local tallyTab = createTab("Tally", -45)
local historyTab = createTab("History", 45)

local function selectPage(showHistory)
    panel:SetHeight(showHistory and 340 or 151)
    tallyPage:SetShown(not showHistory)
    historyPanel:SetShown(showHistory)
    tallyTab:SetEnabled(showHistory)
    historyTab:SetEnabled(not showHistory)
end

tallyTab:SetScript("OnClick", function() selectPage(false) end)
historyTab:SetScript("OnClick", function() selectPage(true) end)
selectPage(false)

function FactionFarter_PerformFart()
    if not FactionFarterDB then return end
    local guid, name, targetFaction = candidate("target")
    local targetExists = UnitExists("target")
    if not name and (not InCombatLockdown() or (readable(targetExists) and not targetExists)) then
        UIErrorsFrame:AddMessage(targetPrompt(), 1, 0.25, 0.25)
        refresh()
        return
    end
    local ok = pcall(DoEmote, "fart")
    if ok then
        if name and valid and not alreadyRecorded(guid, name) then
            byName[key(name)] = true
            entries[#entries + 1] = { name, targetFaction, tostring(GetServerTime()), GetRealZoneText() or "", GetSubZoneText() or "" }
            saveLedger()
            refreshHistory()
        end
        refresh()
        local style = selectedSound()
        playFartSound(style)
        local source = UnitGUID("player")
        if guid and name and readable(source) and source and IsInGroup() and not IsInRaid() then
            local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "PARTY"
            pcall(C_ChatInfo.SendAddonMessage, signalPrefix, ("party:%s:%s:%s"):format(source, guid, name), channel)
            -- Keep the original text packet readable by older clients.
            pcall(C_ChatInfo.SendAddonMessage, signalPrefix, ("partySound:%s:%s:%d"):format(source, guid, style), channel)
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
    if not FactionFarterDB then return end
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
            return
        end
        local soundSource, soundTarget, sound = message:match("^partySound:([^:]+):([^:]+):(%d)$")
        local style = tonumber(sound)
        if style and soundNames[style] and readable(ownGUID) and ownGUID
            and soundSource ~= ownGUID and soundTarget ~= ownGUID then
            playFartSound(style)
        end
    end
end

local function receiveFartEmote(message, sender)
    if not FactionFarterDB or not readable(message) or type(message) ~= "string" then return end
    local line = message:gsub("|H[^|]+|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local name = line:match("^(.+) brushes up against you and farts loudly[%.!]?$")
        or line:match("^(.+) farted on you[%.!]?$")
        or line:match("^(.+) farts on you[%.!]?$")
    if not name then return end
    if readable(sender) and type(sender) == "string" and sender ~= "" then name = sender end
    showNotification(name, 1)
end

local historyExport = CreateFrame("Frame", "FactionFarterHistoryExport", UIParent, "BackdropTemplate")
historyExport:SetSize(640, 310)
historyExport:SetPoint("CENTER")
historyExport:SetFrameStrata("DIALOG")
historyExport:SetClampedToScreen(true)
historyExport:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background" })
historyExport:Hide()
local exportTitle = historyExport:CreateFontString(nil, "OVERLAY", "GameFontNormal")
exportTitle:SetPoint("TOPLEFT", 14, -14)
exportTitle:SetText("Faction Farter History (Ctrl+C to copy)")
local exportClose = CreateFrame("Button", nil, historyExport, "UIPanelCloseButton")
exportClose:SetPoint("TOPRIGHT")
exportClose:SetScript("OnClick", function() historyExport:Hide() end)
local exportScroll = CreateFrame("ScrollFrame", nil, historyExport, "UIPanelScrollFrameTemplate")
exportScroll:SetPoint("TOPLEFT", 14, -36)
exportScroll:SetPoint("BOTTOMRIGHT", -32, 14)
local exportText = CreateFrame("EditBox", nil, exportScroll)
exportText:SetWidth(590)
exportText:SetMultiLine(true)
exportText:SetAutoFocus(false)
exportText:SetFontObject(ChatFontNormal)
exportText:SetScript("OnEscapePressed", function() historyExport:Hide() end)
historyExport:SetScript("OnHide", function() exportText:ClearFocus() end)
exportScroll:SetScrollChild(exportText)
local exportMeasure = historyExport:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
exportMeasure:Hide()
local function exportWidth(value)
    exportMeasure:SetText(value)
    return exportMeasure:GetStringWidth()
end

SLASH_FACTIONFARTERHISTORY1 = "/ffhistory"
SlashCmdList.FACTIONFARTERHISTORY = function(input)
    if not valid then print("Faction Farter: History unavailable."); return end
    input = strtrim(input or "")
    local count = input == "" and 25 or tonumber(input:match("^%d+$"))
    if not count or count < 1 then print("Usage: /ffhistory [1-25]"); return end
    local rows = { { "Target", "Date and time", "Zone", "Subzone" } }
    for index = #entries, math.max(1, #entries - math.min(count, 25) + 1), -1 do
        local row = entries[index]
        local stamp = tonumber(row[3])
        rows[#rows + 1] = { row[1], stamp and date("%Y-%m-%d %H:%M", stamp) or "", row[4], row[5] }
    end
    if #rows == 1 then print("Faction Farter: No recorded players yet."); return end
    historyExport:Show()
    local widths = { 0, 0, 0 }
    local space = math.max(1, exportWidth("x x") - exportWidth("xx"))
    local preview = {}
    for _, row in ipairs(rows) do
        for column = 1, 3 do
            widths[column] = math.max(widths[column], exportWidth(row[column]))
        end
    end
    for index, row in ipairs(rows) do
        local fields = {}
        for column = 1, 3 do
            local padding = 3 + math.floor((widths[column] - exportWidth(row[column])) / space + 0.5)
            fields[column] = row[column] .. string.rep(" ", padding)
        end
        fields[4] = row[4]
        preview[index] = table.concat(fields)
    end
    exportText:SetText(table.concat(preview, "\n"))
    exportScroll:SetVerticalScroll(0)
    exportText:SetFocus()
    exportText:HighlightText()
end

local statsChannels = { party = "PARTY", guild = "GUILD", say = "SAY" }
local statsMeasure = UIParent:CreateFontString()
statsMeasure:Hide()

SLASH_FACTIONFARTERSTATS1 = "/ffstats"
SlashCmdList.FACTIONFARTERSTATS = function(input)
    if not valid then print("Faction Farter: Stats unavailable."); return end
    local mode = strtrim(input or ""):lower()
    local channel = statsChannels[mode]
    if not channel and mode ~= "" and mode ~= "echo" then
        print("Usage: /ffstats [echo|party|guild|say]")
        return
    end
    if mode == "party" then
        if not IsInGroup() then print("Faction Farter: Join a party first."); return end
        if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then channel = "INSTANCE_CHAT" end
    elseif mode == "guild" and not IsInGuild() then
        print("Faction Farter: Join a guild first.")
        return
    end

    local counts, zones = {}, {}
    for _, row in ipairs(entries) do
        local zone = row[4]
        if zone ~= "" then
            if not counts[zone] then zones[#zones + 1] = zone end
            counts[zone] = (counts[zone] or 0) + 1
        end
    end
    table.sort(zones, function(a, b)
        if counts[a] == counts[b] then return a < b end
        return counts[a] > counts[b]
    end)
    local owner = FactionFarterDB.ledgerOwner
    if owner == "" then owner = "Current character" end
    local rows = { { owner }, { "Total farted on", tostring(tally()) }, { "" }, { "TOP ZONES" } }
    local summary = {}
    for index = 1, math.min(3, #zones) do
        local zone = zones[index]
        rows[#rows + 1] = { index .. ". " .. zone, tostring(counts[zone]) }
        summary[#summary + 1] = ("%s (%d)"):format(zone, counts[zone])
    end
    if #summary == 0 then rows[#rows + 1] = { "No zones recorded" } end
    if channel then
        local line = ("Faction Farter - %s: %d total"):format(owner, tally())
        if #summary > 0 then line = line .. " - Top zones: " .. table.concat(summary, ", ") end
        local ok = pcall(C_ChatInfo.SendChatMessage, line, channel)
        if not ok then print("Faction Farter: Could not post stats to " .. mode .. ".") end
        return
    end

    statsMeasure:SetFont(DEFAULT_CHAT_FRAME:GetFont())
    local function widthOf(value)
        statsMeasure:SetText((value:gsub("|", "||")))
        return statsMeasure:GetStringWidth()
    end
    local title = "FACTION FARTER"
    local space = math.max(1, widthOf("| |") - widthOf("||"))
    local function pad(width)
        return string.rep(" ", math.max(0, math.floor(width / space + 0.5)))
    end
    local dash = math.max(1, widthOf("--") - widthOf("-"))
    local width = widthOf("+" .. string.rep("-", 32) .. "+")
    for _, row in ipairs(rows) do
        width = math.max(width, widthOf("| " .. row[1] .. "  " .. (row[2] or "") .. " |"))
    end
    local border = "+" .. string.rep("-", math.ceil((width - widthOf("++")) / dash)) .. "+"
    width = widthOf(border)
    local titlePadding = (width - widthOf("|" .. title .. "|")) / 2
    print(border)
    print("||" .. pad(titlePadding) .. title .. pad(titlePadding) .. "||")
    print(border)
    for _, row in ipairs(rows) do
        local value = row[2] or ""
        local padding = width - widthOf("| " .. row[1] .. value .. " |")
        print("|| " .. row[1] .. pad(padding) .. value .. " ||")
    end
    print(border)
end

SLASH_FACTIONFARTERMOCK1 = "/ffmock"
SlashCmdList.FACTIONFARTERMOCK = function(input)
    local sender = strtrim(input or "")
    if sender == "" then
        local _, targetName = candidate("target")
        sender = targetName or "Test Sender"
    end
    showNotification(sender, selectedSound())
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
events:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
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
        valid = loadLedger(db)
        if not valid then print("Faction Farter: Saved data failed validation and was preserved.") end
        placeMinimapButton(FactionFarterDB.minimapAngle or math.pi / 4)
        C_ChatInfo.RegisterAddonMessagePrefix(signalPrefix)
        self:UnregisterEvent(event)
    elseif event == "CHAT_MSG_ADDON" then
        receiveSignal(addon, message, channel, sender)
        return
    elseif event == "CHAT_MSG_TEXT_EMOTE" then
        receiveFartEmote(addon, message)
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



