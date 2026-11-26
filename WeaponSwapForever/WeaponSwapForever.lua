local _, addon = ...
local VALUES = addon.VALUES

local MAIN_HAND = 16
local OFF_HAND = 17
local MARKER = "# WeaponSwapForever"
local QUESTION_MARK = 134400
local menu, openMenu, refreshMenu
local database

local profiles = {
    ROGUE = {
        hint = VALUES.ROGUE_SETUP,
        roles = {
            { key = "main", label = VALUES.MAIN_HAND, slot = MAIN_HAND },
            { key = "dagger", label = VALUES.DAGGER, slot = MAIN_HAND, dagger = true },
        },
        macros = {
            { name = "WSF Sinister", legacyName = "WSF Finster", spell = 1752, before = 14251, main = "main" },
            { name = "WSF Ambush", legacyName = "WSF Hinterhalt", spell = 8676, main = "dagger" },
            { name = "WSF Backstab", legacyName = "WSF Meucheln", spell = 53, main = "dagger" },
            { name = "WSF Main Hand", legacyName = "WSF Hauptwaffe", label = VALUES.MAIN_HAND, main = "main" },
        },
    },
    WARRIOR = {
        hint = VALUES.WARRIOR_SETUP,
        roles = {
            { key = "offense", label = VALUES.OFFENSIVE_WEAPON, slot = MAIN_HAND },
            { key = "defense", label = VALUES.DEFENSIVE_WEAPON, slot = MAIN_HAND },
            { key = "shield", label = VALUES.SHIELD, slot = OFF_HAND, shield = true },
        },
        macros = {
            { name = "WSF Offense", spell = 2457, main = "offense", stance = true },
            { name = "WSF Defense", spell = 71, main = "defense", off = "shield", stance = true },
        },
    },
}

local function say(message)
    print("|cffffd100" .. VALUES.ADDON_NAME .. "|r " .. message)
end

local function getDatabase()
    if database then
        return database
    end
    WeaponSwapForeverDB = WeaponSwapForeverDB or { weapons = {}, links = {} }
    local db = WeaponSwapForeverDB
    db.assigned = db.assigned or {}
    for _, spec in ipairs(profiles.ROGUE.macros) do
        local legacy = db.assigned[spec.legacyName]
        if legacy then
            db.assigned[spec.name] = db.assigned[spec.name] or legacy
            db.assigned[spec.legacyName] = nil
        end
    end
    db.custom = db.custom or {}
    database = db
    return database
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
        return nil, VALUES.SPELL_NOT_AVAILABLE:format(spec.name)
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

local function findManagedMacro(spec)
    local index, body, conflict = findCharacterMacro(spec.name)
    if not index and not conflict and spec.legacyName then
        local legacyIndex, legacyBody = findCharacterMacro(spec.legacyName)
        return legacyIndex, legacyBody, false, legacyIndex ~= nil
    end
    return index, body, conflict, false
end

local function writeMacro(spec, body)
    local name = spec.name
    local index, currentBody, conflict, legacy = findManagedMacro(spec)
    if conflict then
        return false, VALUES.MACRO_CONFLICT:format(name)
    end
    if not legacy and currentBody == body then
        return true
    end
    if #body > 255 then
        return false, VALUES.MACRO_LIMIT:format(name)
    end

    local ok
    if index then
        ok = pcall(EditMacro, index, legacy and name or nil, nil, body)
    else
        local _, count = GetNumMacros()
        if count >= Constants.MacroConsts.MAX_CHARACTER_MACROS then
            return false, VALUES.NO_MACRO_SLOT:format(name)
        end
        ok = pcall(CreateMacro, name, QUESTION_MARK, body, true)
    end
    if ok then
        local _, actualBody = findCharacterMacro(name)
        if actualBody == body then
            return true
        end
    end
    return false, VALUES.MACRO_SAVE_FAILED:format(name)
end

local function sync(profile, db)
    local ready, failed = 0, 0
    local specs = macroSpecs(profile, db)
    for _, spec in ipairs(specs) do
        local body, message = buildMacro(spec, db)
        if body then
            local ok
            ok, message = writeMacro(spec, body)
            if ok then
                ready = ready + 1
            end
        end
        if message then
            say(message)
            failed = failed + 1
        end
    end
    say(VALUES.MACROS_CURRENT:format(ready, #specs))
    if failed > 0 then
        say(VALUES.RETRY_SYNC)
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

local function readEquipped(role, sourceSlot)
    local slot = sourceSlot or role.slot
    local itemID = GetInventoryItemID("player", slot)
    if not itemID then
        return nil, VALUES.EQUIP_ITEM_FIRST:format(role.label, slot)
    end

    local location, class, subclass = getEquipmentType(itemID)
    if role.shield then
        if location ~= "INVTYPE_SHIELD" then
            return nil, VALUES.EQUIP_SHIELD
        end
    elseif class ~= Enum.ItemClass.Weapon then
        return nil, VALUES.EQUIP_MAIN_HAND
    elseif role.dagger and subclass ~= Enum.ItemWeaponSubclass.Dagger then
        return nil, VALUES.EQUIP_DAGGER
    elseif role.dagger and location == "INVTYPE_WEAPONOFFHAND" then
        return nil, VALUES.OFF_HAND_ONLY_DAGGER
    end

    return { id = itemID, link = GetInventoryItemLink("player", slot) }
end

local function capture(profile, command, db, sourceSlot)
    local selection = {}
    for _, role in ipairs(profile.roles) do
        if role.key == command or (command == "defense" and role.key == "shield") then
            local item, message = readEquipped(role, role.key == command and sourceSlot or nil)
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
    say(VALUES.EQUIPMENT_SAVED)
    sync(profile, db)
end

local EQUIPMENT_PROMPT = "WEAPON_SWAP_FOREVER_EQUIPMENT"
local WARRIOR_PROMPT = "WEAPON_SWAP_FOREVER_WARRIOR_WEAPON"
local activePrompt

local function closePrompt()
    if activePrompt then
        local dialog = activePrompt.dialog
        activePrompt = nil
        StaticPopup_Hide(dialog)
    end
end

local function clearPrompt(_, proposal)
    if activePrompt == proposal then
        activePrompt = nil
    end
end

local function presentPrompt(proposal, dialog, name, label)
    closePrompt()
    proposal.dialog = dialog
    activePrompt = proposal
    if not StaticPopup_Show(dialog, name, label, proposal) then
        activePrompt = nil
    end
end

local function acceptEquipment(proposal, role)
    if InCombatLockdown() then
        say(VALUES.COMBAT_CONFIRM)
        return true
    end
    if GetInventoryItemID("player", proposal.slot) ~= proposal.id
        or (role == "defense" and GetInventoryItemID("player", OFF_HAND) ~= proposal.shield) then
        say(VALUES.EQUIPMENT_CHANGED)
        return
    end
    capture(proposal.profile, role, getDatabase(), proposal.slot)
end

StaticPopupDialogs[EQUIPMENT_PROMPT] = {
    text = VALUES.EQUIPMENT_PROMPT,
    button1 = VALUES.USE_EQUIPMENT,
    button2 = VALUES.CANCEL,
    button3 = VALUES.MENU,
    timeout = 0,
    hideOnEscape = true,
    OnHide = clearPrompt,
    OnAccept = function(_, proposal)
        return acceptEquipment(proposal, proposal.role)
    end,
    OnAlt = function(_, proposal)
        openMenu(proposal.profile)
    end,
}

StaticPopupDialogs[WARRIOR_PROMPT] = {
    text = VALUES.WARRIOR_EQUIPMENT_PROMPT,
    button1 = VALUES.OFFENSE,
    button2 = VALUES.CANCEL,
    button3 = VALUES.DEFENSE,
    button4 = VALUES.MENU,
    timeout = 0,
    hideOnEscape = true,
    OnHide = clearPrompt,
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

local function isKnownWeapon(db, itemID)
    local weapons = db.weapons
    if itemID == weapons.main or itemID == weapons.dagger
        or itemID == weapons.offense or itemID == weapons.defense then
        return true
    end
    for _, assigned in pairs(db.assigned) do
        if assigned.id == itemID then
            return true
        end
    end
    return false
end

local function showEquipmentPrompt(profile, warrior, main, off, mainChanged, offChanged)
    local db = getDatabase()
    local location, itemClass, subclass
    if mainChanged and main and not isKnownWeapon(db, main) then
        location, itemClass, subclass = getEquipmentType(main)
    end
    local shield = warrior and off and getEquipmentType(off) == "INVTYPE_SHIELD"
    if itemClass == Enum.ItemClass.Weapon and subclass ~= Enum.ItemWeaponSubclass.Fishingpole then
        local proposal = { profile = profile, slot = MAIN_HAND, id = main }
        local name = GetInventoryItemLink("player", MAIN_HAND) or VALUES.ITEM_NUMBER:format(main)
        if shield and location ~= "INVTYPE_2HWEAPON" then
            local shieldName = GetInventoryItemLink("player", OFF_HAND) or VALUES.SHIELD_NUMBER:format(off)
            proposal.shield = off
            presentPrompt(proposal, WARRIOR_PROMPT, name, shieldName)
            return
        end
        local dagger = subclass == Enum.ItemWeaponSubclass.Dagger
        proposal.role = warrior and "offense" or (dagger and "dagger" or "main")
        local label = warrior and VALUES.OFFENSIVE_WEAPON or (dagger and VALUES.DAGGER or VALUES.MAIN_HAND)
        presentPrompt(proposal, EQUIPMENT_PROMPT, name, label)
        return
    end

    if activePrompt or not offChanged or not off then
        return
    end
    local role, label
    if warrior then
        if shield and off ~= db.weapons.shield then
            role, label = "shield", VALUES.SHIELD
        end
    elseif not isKnownWeapon(db, off) then
        local offLocation, offClass, offSubclass = getEquipmentType(off)
        if offClass == Enum.ItemClass.Weapon and offSubclass == Enum.ItemWeaponSubclass.Dagger
            and offLocation == "INVTYPE_WEAPON" then
            role, label = "dagger", VALUES.DAGGER_FOR_MAIN_HAND
        end
    end
    if role then
        local name = GetInventoryItemLink("player", OFF_HAND) or VALUES.ITEM_NUMBER:format(off)
        presentPrompt({ profile = profile, slot = OFF_HAND, id = off, role = role }, EQUIPMENT_PROMPT, name, label)
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
    local previousOff = GetInventoryItemID("player", OFF_HAND)
    local scheduled, pending

    local function checkEquipment()
        scheduled = false
        if InCombatLockdown() then
            pending = true
            return
        end
        pending = false
        local main = GetInventoryItemID("player", MAIN_HAND)
        local off = GetInventoryItemID("player", OFF_HAND)
        local mainChanged, offChanged = main ~= previousMain, off ~= previousOff
        previousMain, previousOff = main, off
        if mainChanged or offChanged then
            if activePrompt then
                local sameItem = (activePrompt.slot == MAIN_HAND and main == activePrompt.id)
                    or (activePrompt.slot == OFF_HAND and off == activePrompt.id)
                if not sameItem then
                    closePrompt()
                elseif activePrompt.shield and off ~= activePrompt.shield then
                    closePrompt()
                    mainChanged = true
                end
            end
            showEquipmentPrompt(profile, warrior, main, off, mainChanged, offChanged)
        end
    end

    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:SetScript("OnEvent", function(_, event, slot)
        local equipmentChanged = event == "UNIT_INVENTORY_CHANGED"
            or (event == "PLAYER_EQUIPMENT_CHANGED" and (slot == MAIN_HAND or slot == OFF_HAND))
        if not scheduled and (equipmentChanged or (event == "PLAYER_REGEN_ENABLED" and pending)) then
            scheduled = true
            C_Timer.After(0.1, checkEquipment)
        end
    end)
end)

SLASH_WEAPONSWAPFOREVER1 = "/wsf"
SlashCmdList.WEAPONSWAPFOREVER = function(input)
    local _, class = UnitClass("player")
    local profile = profiles[class]
    if not profile then
        say(VALUES.CLASS_SUPPORT)
        return
    end

    local db = getDatabase()
    local command = input:match("^%s*(.-)%s*$"):lower()
    if command == "status" then
        for _, role in ipairs(profile.roles) do
            local id = db.weapons[role.key]
            local item = db.links[role.key] or (id and ("item:%d"):format(id)) or VALUES.NOT_SELECTED
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
            say(VALUES.COMBAT_SYNC)
            return
        end
        sync(profile, db)
        return
    end

    for _, role in ipairs(profile.roles) do
        if command == role.key then
            if InCombatLockdown() then
                say(VALUES.COMBAT_CAPTURE)
                return
            end
            closePrompt()
            capture(profile, command, db)
            return
        end
    end
    say(profile.hint)
    if class == "ROGUE" then
        say(VALUES.HELP_ROGUE)
    else
        say(VALUES.HELP_WARRIOR)
    end
    say(VALUES.HELP_COMMON)
end

function WeaponSwapForever_OnCompartmentClick()
    SlashCmdList.WEAPONSWAPFOREVER("menu")
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
        say(VALUES.ASSIGNMENT_OUT_OF_COMBAT)
        return
    end
    local item, message = readEquipped({
        slot = MAIN_HAND, label = VALUES.THIS_ABILITY, dagger = spec.main == "dagger",
    })
    if not item then
        say(message)
        return
    end
    if spec.off and getEquipmentType(item.id) == "INVTYPE_2HWEAPON" then
        say(VALUES.EQUIP_ONE_HAND)
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
    skill:SetText((spec.spell and C_Spell.GetSpellName(spec.spell)) or spec.label or spec.name)

    row.weapon = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.weapon:SetPoint("TOPLEFT", skill, "BOTTOMLEFT", 0, -4)
    row.weapon:SetWidth(270)
    row.weapon:SetJustifyH("LEFT")
    row.weapon:SetWordWrap(false)

    local assign = createButton(row, VALUES.SET_WEAPON, 100, function()
        assignWeapon(profile, spec)
    end)
    assign:SetPoint("LEFT", 275, 0)

    row.reset = createButton(row, VALUES.DEFAULT, 75, function()
        if InCombatLockdown() then
            say(VALUES.ASSIGNMENT_OUT_OF_COMBAT)
            return
        end
        local db = getDatabase()
        db.assigned[spec.name] = nil
        sync(profile, db)
    end)
    row.reset:SetPoint("LEFT", assign, "RIGHT", 4, 0)

    row.pickup = createButton(row, VALUES.MACRO, 75, function()
        if InCombatLockdown() then
            say(VALUES.COMBAT_PLACE_MACRO)
            return
        end
        local macroIndex = findManagedMacro(spec)
        if macroIndex then
            PickupMacro(macroIndex)
        end
    end)
    row.pickup:SetPoint("LEFT", row.reset, "RIGHT", 4, 0)
    return row
end

local function addAbility(profile, input)
    if InCombatLockdown() then
        say(VALUES.COMBAT_ADD_ABILITY)
        return
    end
    local identifier = input:GetText():match("^%s*(.-)%s*$")
    local spell = identifier ~= "" and C_Spell.GetSpellInfo(tonumber(identifier) or identifier)
    if not spell or C_Spell.IsSpellPassive(spell.spellID)
        or not C_SpellBook.FindSpellBookSlotForSpell(spell.spellID) then
        say(VALUES.SPELL_NOT_LEARNED)
        return
    end
    local db = getDatabase()
    for _, spec in ipairs(macroSpecs(profile, db)) do
        local name = spec.spell and C_Spell.GetSpellName(spec.spell)
        if name == spell.name then
            say(VALUES.ALREADY_IN_MENU:format(spell.name))
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
        saved, errorMessage = writeMacro(spec, body)
    end
    if not saved then
        db.assigned[spec.name] = nil
        say(errorMessage or VALUES.MACRO_SAVE_FALLBACK)
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
        menu.TitleContainer.TitleText:SetText(VALUES.ADDON_NAME)
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
        instructions:SetText(VALUES.MENU_INSTRUCTIONS)

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
        label:SetText(VALUES.SPELL_INPUT)
        local input = CreateFrame("EditBox", nil, menu, "InputBoxTemplate")
        input:SetSize(240, 22)
        input:SetPoint("LEFT", label, "RIGHT", 14, 0)
        input:SetAutoFocus(false)
        input:SetMaxLetters(100)
        input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        input:SetScript("OnEnterPressed", function(self) addAbility(profile, self) end)
        local add = createButton(menu, VALUES.ADD_ABILITY, 100, function() addAbility(profile, input) end)
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
                local text = link or (itemID and VALUES.ITEM_NUMBER:format(itemID)) or VALUES.NO_WEAPON
                row.weapon:SetText(text .. (default and not assigned and VALUES.DEFAULT_SUFFIX or ""))
                row.reset:SetEnabled(assigned ~= nil and default ~= nil and (not spec.off or db.weapons[spec.off] ~= nil))
                row.reset:SetShown(spec.main ~= nil)
                row.pickup:SetEnabled(findManagedMacro(spec) ~= nil)
            end
            local contentHeight = math.max(1, #specs * 44)
            content:SetHeight(contentHeight)
            scroll.ScrollBar:SetShown(contentHeight > scroll:GetHeight())
        end
    end
    menu:Show()
    refreshMenu()
end
