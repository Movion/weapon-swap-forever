local MAIN_HAND = 16
local OFF_HAND = 17
local MARKER = "# WeaponSwapForever"
local QUESTION_MARK = 134400
local menu, openMenu, refreshMenu

local profiles = {
    ROGUE = {
        hint = "/wsf main (Hauptwaffe), /wsf dagger (Dolch)",
        roles = {
            { key = "main", label = "Hauptwaffe", slot = MAIN_HAND },
            { key = "dagger", label = "Dolch", slot = MAIN_HAND, dagger = true },
        },
        macros = {
            { name = "WSF Finster", spell = 1752, before = 14251, main = "main" },
            { name = "WSF Hinterhalt", spell = 8676, main = "dagger" },
            { name = "WSF Meucheln", spell = 53, main = "dagger" },
            { name = "WSF Hauptwaffe", main = "main" },
        },
    },
    WARRIOR = {
        hint = "/wsf offense (Offensivwaffe), /wsf defense (Einhandwaffe und Schild)",
        roles = {
            { key = "offense", label = "Offensivwaffe", slot = MAIN_HAND },
            { key = "defense", label = "Defensivwaffe", slot = MAIN_HAND },
            { key = "shield", label = "Schild", slot = OFF_HAND, shield = true },
        },
        macros = {
            { name = "WSF Offense", spell = 2457, main = "offense", stance = true },
            { name = "WSF Defense", spell = 71, main = "defense", off = "shield", stance = true },
        },
    },
}

local function say(message)
    print("|cffffd100Weapon Swap Forever|r " .. message)
end

local function getDatabase()
    WeaponSwapForeverDB = WeaponSwapForeverDB or { weapons = {}, links = {} }
    local db = WeaponSwapForeverDB
    db.assigned = db.assigned or {}
    db.custom = db.custom or {}
    return db
end

local function macroSpecs(profile, db)
    local specs = {}
    for _, spec in ipairs(profile.macros) do
        specs[#specs + 1] = spec
    end
    for _, spec in ipairs(db.custom) do
        specs[#specs + 1] = spec
    end
    return specs
end

local function equip(slot, itemID)
    return ("/equipslot %d item:%d"):format(slot, itemID)
end

local function buildMacro(spec, db)
    local assigned = db.assigned[spec.name]
    local main = assigned and assigned.id or db.weapons[spec.main]
    local off = db.weapons[spec.off]
    if not main or (spec.off and not off) then
        return
    end

    local spell = spec.spell and C_Spell.GetSpellName(spec.spell)
    local before = spec.before and C_Spell.GetSpellName(spec.before)
    if spec.spell and not spell then
        return nil, "Fähigkeit für " .. spec.name .. " konnte nicht geladen werden."
    end

    local tooltip = spell or ("item:%d"):format(main)
    local lines = { "#showtooltip " .. tooltip, MARKER }
    if spec.stance then
        lines[#lines + 1] = "/cast " .. spell
    end
    lines[#lines + 1] = equip(MAIN_HAND, main)
    if off then
        lines[#lines + 1] = equip(OFF_HAND, off)
    end
    if before then
        lines[#lines + 1] = "/cast " .. before
    end
    if spell and not spec.stance then
        lines[#lines + 1] = "/cast " .. spell
    end
    return table.concat(lines, "\n")
end

local function findCharacterMacro(name)
    local _, count = GetNumMacros()
    local base = Constants.MacroConsts.MAX_ACCOUNT_MACROS
    local found, body
    for index = base + 1, base + count do
        local currentName, _, currentBody = GetMacroInfo(index)
        if currentName and currentName:lower() == name:lower() then
            if found or currentName ~= name or not currentBody or not currentBody:find("\n" .. MARKER .. "\n", 1, true) then
                return nil, nil, true
            end
            found, body = index, currentBody
        end
    end
    return found, body
end

local function writeMacro(name, body)
    local index, currentBody, conflict = findCharacterMacro(name)
    if conflict then
        return false, name .. " ist bereits belegt. Benenne das vorhandene Charaktermakro um."
    end
    if currentBody == body then
        return true
    end
    if #body > 255 then
        return false, name .. " überschreitet das Makrolimit."
    end

    local ok, writtenIndex
    if index then
        ok, writtenIndex = pcall(EditMacro, index, nil, nil, body)
        writtenIndex = writtenIndex or index
    else
        local _, count = GetNumMacros()
        if count >= Constants.MacroConsts.MAX_CHARACTER_MACROS then
            return false, "Kein freier Platz für " .. name .. "."
        end
        ok, writtenIndex = pcall(CreateMacro, name, QUESTION_MARK, body, true)
    end
    if ok and type(writtenIndex) == "number" then
        local actualName, _, actualBody = GetMacroInfo(writtenIndex)
        if actualName == name and actualBody == body then
            return true
        end
    end
    return false, name .. " konnte nicht gespeichert werden."
end

local function sync(profile, db)
    local ready, failed = 0, 0
    local specs = macroSpecs(profile, db)
    for _, spec in ipairs(specs) do
        local body, message = buildMacro(spec, db)
        if body then
            local ok
            ok, message = writeMacro(spec.name, body)
            if ok then
                ready = ready + 1
            end
        end
        if message then
            say(message)
            failed = failed + 1
        end
    end
    say(("%d/%d Makros aktuell."):format(ready, #specs))
    if failed > 0 then
        say("Nach der Korrektur /wsf sync ausführen.")
    elseif ready < #specs then
        say(profile.hint)
    end
    if refreshMenu then
        refreshMenu()
    end
end

local function getEquipmentType(itemID)
    local _, _, _, location, _, class, subclass = C_Item.GetItemInfoInstant(itemID)
    return location, class, subclass
end

local function readEquipped(role)
    local itemID = GetInventoryItemID("player", role.slot)
    if not itemID then
        return nil, ("Für %s zuerst einen Gegenstand in Slot %d anlegen."):format(role.label, role.slot)
    end

    local location, class, subclass = getEquipmentType(itemID)
    if role.shield then
        if location ~= "INVTYPE_SHIELD" then
            return nil, "Lege einen Schild in der Nebenhand an."
        end
    elseif class ~= Enum.ItemClass.Weapon then
        return nil, "Lege eine Waffe in der Haupthand an."
    elseif role.dagger and subclass ~= Enum.ItemWeaponSubclass.Dagger then
        return nil, "Lege einen Dolch in der Haupthand an."
    end

    return { id = itemID, link = GetInventoryItemLink("player", role.slot) }
end

local function capture(profile, command, db)
    local selection = {}
    for _, role in ipairs(profile.roles) do
        if role.key == command or (command == "defense" and role.key == "shield") then
            local item, message = readEquipped(role)
            if not item then
                say(message)
                return
            end
            selection[role.key] = item
        end
    end
    for key, item in pairs(selection) do
        db.weapons[key], db.links[key] = item.id, item.link
    end
    say("Ausrüstung gespeichert.")
    sync(profile, db)
end

local EQUIPMENT_PROMPT = "WEAPON_SWAP_FOREVER_EQUIPMENT"
local WARRIOR_PROMPT = "WEAPON_SWAP_FOREVER_WARRIOR_WEAPON"
local activePrompt

local function closePrompt()
    if activePrompt then
        StaticPopup_Hide(activePrompt)
        activePrompt = nil
    end
end

local function acceptEquipment(proposal, role)
    if InCombatLockdown() then
        say("Bestätige die Auswahl nach dem Kampf.")
        return true
    end
    if GetInventoryItemID("player", MAIN_HAND) ~= proposal.main
        or (proposal.warrior and GetInventoryItemID("player", OFF_HAND) ~= proposal.off) then
        say("Deine Ausrüstung hat sich inzwischen geändert.")
        return
    end
    capture(proposal.profile, role, getDatabase())
end

StaticPopupDialogs[EQUIPMENT_PROMPT] = {
    text = "%s wurde angelegt. Als %s für deine Waffenwechsel-Makros übernehmen?",
    button1 = "Übernehmen",
    button2 = CANCEL,
    button3 = "Menü",
    timeout = 0,
    hideOnEscape = true,
    OnAccept = function(_, proposal)
        return acceptEquipment(proposal, proposal.role)
    end,
    OnAlt = function(_, proposal)
        openMenu(proposal.profile)
    end,
}

StaticPopupDialogs[WARRIOR_PROMPT] = {
    text = "%s wurde angelegt. Für welches Makro möchtest du die Waffe übernehmen? Für Defense wird auch %s übernommen.",
    button1 = "Offense",
    button2 = CANCEL,
    button3 = "Defense",
    button4 = "Menü",
    timeout = 0,
    hideOnEscape = true,
    selectCallbackByIndex = true,
    OnAccept = function(_, proposal)
        return acceptEquipment(proposal, "offense")
    end,
    OnButton3 = function(_, proposal)
        return acceptEquipment(proposal, "defense")
    end,
    OnButton4 = function(_, proposal)
        openMenu(proposal.profile)
    end,
}

local function showEquipmentPrompt(profile, warrior, main, off, mainChanged, offChanged)
    local db = getDatabase()
    local weapons = db.weapons
    local proposal = { profile = profile, warrior = warrior, main = main, off = off }
    local mainKnown = main == weapons.main or main == weapons.dagger
        or main == weapons.offense or main == weapons.defense
    if mainChanged and main and not mainKnown then
        for _, assigned in pairs(db.assigned) do
            if assigned.id == main then
                mainKnown = true
                break
            end
        end
    end
    local location, itemClass, subclass
    if mainChanged and main and not mainKnown then
        location, itemClass, subclass = getEquipmentType(main)
    end
    local shield = warrior and off and getEquipmentType(off) == "INVTYPE_SHIELD"
    if itemClass == Enum.ItemClass.Weapon and subclass ~= Enum.ItemWeaponSubclass.Fishingpole then
        local name = GetInventoryItemLink("player", MAIN_HAND) or ("Gegenstand %d"):format(main)
        if shield and location ~= "INVTYPE_2HWEAPON" then
            local shieldName = GetInventoryItemLink("player", OFF_HAND) or ("Schild %d"):format(off)
            activePrompt = WARRIOR_PROMPT
            StaticPopup_Show(activePrompt, name, shieldName, proposal)
            return
        end
        local dagger = subclass == Enum.ItemWeaponSubclass.Dagger
        proposal.role = warrior and "offense" or (dagger and "dagger" or "main")
        local label = warrior and "Offensivwaffe" or (dagger and "Dolch" or "Hauptwaffe")
        activePrompt = EQUIPMENT_PROMPT
        StaticPopup_Show(activePrompt, name, label, proposal)
    elseif offChanged and shield and off ~= weapons.shield then
        proposal.role = "shield"
        local name = GetInventoryItemLink("player", OFF_HAND) or ("Gegenstand %d"):format(off)
        activePrompt = EQUIPMENT_PROMPT
        StaticPopup_Show(activePrompt, name, "Schild", proposal)
    end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    local _, class = UnitClass("player")
    local profile = profiles[class]
    if not profile then
        return
    end
    local warrior = class == "WARRIOR"
    local previousMain = GetInventoryItemID("player", MAIN_HAND)
    local previousOff = warrior and GetInventoryItemID("player", OFF_HAND)
    local scheduled, pending

    local function checkEquipment()
        scheduled = false
        if InCombatLockdown() then
            pending = true
            return
        end
        pending = false
        local main = GetInventoryItemID("player", MAIN_HAND)
        local off = warrior and GetInventoryItemID("player", OFF_HAND)
        local mainChanged, offChanged = main ~= previousMain, off ~= previousOff
        previousMain, previousOff = main, off
        if mainChanged or offChanged then
            closePrompt()
            if not menu or not menu:IsShown() then
                showEquipmentPrompt(profile, warrior, main, off, mainChanged, offChanged)
            end
        end
    end

    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:SetScript("OnEvent", function(_, event, slot)
        local equipmentChanged = event == "PLAYER_EQUIPMENT_CHANGED"
            and (slot == MAIN_HAND or (warrior and slot == OFF_HAND))
        if not scheduled and (equipmentChanged or (event == "PLAYER_REGEN_ENABLED" and pending)) then
            scheduled = true
            C_Timer.After(0, checkEquipment)
        end
    end)
end)

SLASH_WEAPONSWAPFOREVER1 = "/wsf"
SlashCmdList.WEAPONSWAPFOREVER = function(input)
    local _, class = UnitClass("player")
    local profile = profiles[class]
    if not profile then
        say("Verfügbar für Schurken und Krieger.")
        return
    end

    local db = getDatabase()
    local command = input:match("^%s*(.-)%s*$"):lower()
    if command == "status" then
        for _, role in ipairs(profile.roles) do
            local id = db.weapons[role.key]
            local item = db.links[role.key] or (id and ("item:%d"):format(id)) or "noch nicht gewählt"
            say(role.label .. " – " .. item)
        end
        return
    end

    if command == "" or command == "menu" then
        closePrompt()
        openMenu(profile)
        return
    end

    if command == "sync" then
        if InCombatLockdown() then
            say("Makros lassen sich außerhalb des Kampfes aktualisieren.")
            return
        end
        sync(profile, db)
        return
    end

    for _, role in ipairs(profile.roles) do
        if command == role.key then
            if InCombatLockdown() then
                say("Speichere deine Ausrüstung außerhalb des Kampfes.")
                return
            end
            closePrompt()
            capture(profile, command, db)
            return
        end
    end
    say(profile.hint)
    if class == "ROGUE" then
        say("WSF Hauptwaffe wechselt zur normalen Hauptwaffe.")
    else
        say("/wsf shield übernimmt nur den Schild.")
    end
    say("/wsf status zeigt deine Auswahl. /wsf sync aktualisiert die Makros.")
end

local function createButton(parent, label, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    return button
end

local function assignWeapon(profile, spec)
    if InCombatLockdown() then
        say("Ändere diese Zuweisung außerhalb des Kampfes.")
        return
    end
    local item, message = readEquipped({
        slot = MAIN_HAND, label = "diese Fähigkeit", dagger = spec.main == "dagger",
    })
    if not item then
        say(message)
        return
    end
    if spec.off and getEquipmentType(item.id) == "INVTYPE_2HWEAPON" then
        say("Wähle für dieses Makro eine Einhandwaffe, damit du den Schild anlegen kannst.")
        return
    end
    local db = getDatabase()
    db.assigned[spec.name] = item
    sync(profile, db)
end

local function createRow(parent, profile, spec, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * 44)
    row:SetSize(544, 44)

    local skill = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    skill:SetPoint("TOPLEFT", 0, -4)
    skill:SetWidth(270)
    skill:SetJustifyH("LEFT")
    skill:SetWordWrap(false)
    skill:SetText((spec.spell and C_Spell.GetSpellName(spec.spell)) or spec.name)

    row.weapon = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.weapon:SetPoint("TOPLEFT", skill, "BOTTOMLEFT", 0, -4)
    row.weapon:SetWidth(270)
    row.weapon:SetJustifyH("LEFT")
    row.weapon:SetWordWrap(false)

    local assign = createButton(row, "Waffe setzen", 100, function()
        assignWeapon(profile, spec)
    end)
    assign:SetPoint("LEFT", 275, 0)

    row.reset = createButton(row, "Standard", 75, function()
        if InCombatLockdown() then
            say("Ändere diese Zuweisung außerhalb des Kampfes.")
            return
        end
        local db = getDatabase()
        db.assigned[spec.name] = nil
        sync(profile, db)
    end)
    row.reset:SetPoint("LEFT", assign, "RIGHT", 4, 0)

    row.pickup = createButton(row, "Makro", 75, function()
        if InCombatLockdown() then
            say("Platziere das Makro außerhalb des Kampfes.")
            return
        end
        local macroIndex = findCharacterMacro(spec.name)
        if macroIndex then
            PickupMacro(macroIndex)
        end
    end)
    row.pickup:SetPoint("LEFT", row.reset, "RIGHT", 4, 0)
    return row
end

local function addAbility(profile, input)
    if InCombatLockdown() then
        say("Füge Fähigkeiten außerhalb des Kampfes hinzu.")
        return
    end
    local identifier = input:GetText():match("^%s*(.-)%s*$")
    local spell = identifier ~= "" and C_Spell.GetSpellInfo(tonumber(identifier) or identifier)
    if not spell or C_Spell.IsSpellPassive(spell.spellID)
        or not C_SpellBook.FindSpellBookSlotForSpell(spell.spellID) then
        say("Gib den Namen oder die ID einer erlernten aktiven Fähigkeit ein.")
        return
    end
    local db = getDatabase()
    for _, spec in ipairs(macroSpecs(profile, db)) do
        local name = spec.spell and C_Spell.GetSpellName(spec.spell)
        if name == spell.name then
            say(spell.name .. " steht bereits im Menü. Nutze dort „Waffe setzen“.")
            return
        end
    end

    local item, message = readEquipped({ slot = MAIN_HAND, label = spell.name })
    if not item then
        say(message)
        return
    end
    local spec = { name = "WSF " .. spell.spellID, spell = spell.spellID }
    db.assigned[spec.name] = item
    local body, errorMessage = buildMacro(spec, db)
    local saved
    if body then
        saved, errorMessage = writeMacro(spec.name, body)
    end
    if not saved then
        db.assigned[spec.name] = nil
        say(errorMessage or "Das Makro konnte nicht gespeichert werden.")
        return
    end
    db.custom[#db.custom + 1] = spec
    input:SetText("")
    input:ClearFocus()
    refreshMenu()
end

openMenu = function(profile)
    if not menu then
        menu = CreateFrame("Frame", "WeaponSwapForeverMenu", UIParent, "ButtonFrameTemplate")
        menu:SetSize(602, 360)
        menu:SetPoint("CENTER")
        menu:SetFrameStrata("DIALOG")
        menu:EnableMouse(true)
        menu:SetMovable(true)
        menu:SetClampedToScreen(true)
        ButtonFrameTemplate_HidePortrait(menu)
        menu.TitleContainer.TitleText:SetText("Weapon Swap Forever")
        tinsert(UISpecialFrames, menu:GetName())

        local dragHandle = CreateFrame("Frame", nil, menu.TitleContainer)
        dragHandle:SetPoint("TOPLEFT")
        dragHandle:SetPoint("BOTTOMRIGHT", -32, 0)
        dragHandle:EnableMouse(true)
        dragHandle:RegisterForDrag("LeftButton")
        dragHandle:SetScript("OnDragStart", function() menu:StartMoving() end)
        dragHandle:SetScript("OnDragStop", function() menu:StopMovingOrSizing() end)
        menu:HookScript("OnHide", menu.StopMovingOrSizing)

        local instructions = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        instructions:SetPoint("TOPLEFT", 16, -35)
        instructions:SetText("Waffe in der Haupthand anlegen und zuweisen. Mit „Makro“ auf die Aktionsleiste ziehen.")

        local scroll = CreateFrame("ScrollFrame", nil, menu, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 16, -55)
        scroll:SetPoint("BOTTOMRIGHT", -36, 54)
        scroll.ScrollBar:Hide()
        scroll:HookScript("OnScrollRangeChanged", function(self, _, verticalRange)
            self.ScrollBar:SetShown(verticalRange > 0)
        end)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetWidth(544)
        scroll:SetScrollChild(content)

        local label = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("BOTTOMLEFT", 16, 20)
        label:SetText("Fähigkeit oder Zauber-ID")
        local input = CreateFrame("EditBox", nil, menu, "InputBoxTemplate")
        input:SetSize(240, 22)
        input:SetPoint("LEFT", label, "RIGHT", 14, 0)
        input:SetAutoFocus(false)
        input:SetMaxLetters(100)
        input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        input:SetScript("OnEnterPressed", function(self) addAbility(profile, self) end)
        local add = createButton(menu, "Hinzufügen", 100, function() addAbility(profile, input) end)
        add:SetPoint("LEFT", input, "RIGHT", 8, 0)

        local rows = {}
        refreshMenu = function()
            if not menu:IsShown() then
                return
            end
            local db = getDatabase()
            local specs = macroSpecs(profile, db)
            for index, spec in ipairs(specs) do
                local row = rows[index] or createRow(content, profile, spec, index)
                rows[index] = row
                local assigned = db.assigned[spec.name]
                local default = db.weapons[spec.main]
                local itemID = assigned and assigned.id or default
                local link = assigned and assigned.link or (not assigned and db.links[spec.main])
                local text = link or (itemID and ("Gegenstand %d"):format(itemID)) or "Keine Waffe gewählt"
                row.weapon:SetText(text .. (default and not assigned and " (Standard)" or ""))
                row.reset:SetEnabled(assigned ~= nil and default ~= nil and (not spec.off or db.weapons[spec.off] ~= nil))
                row.reset:SetShown(spec.main ~= nil)
                row.pickup:SetEnabled(findCharacterMacro(spec.name) ~= nil)
            end
            local contentHeight = math.max(1, #specs * 44)
            content:SetHeight(contentHeight)
            scroll.ScrollBar:SetShown(contentHeight > scroll:GetHeight())
        end
    end
    menu:Show()
    refreshMenu()
end
