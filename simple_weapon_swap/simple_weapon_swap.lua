local addonName, addon = ...

local MAIN = 16
local OFF = 17
local labels = { damage = "Damage", healing = "Healing" }
local other = { damage = "healing", healing = "damage" }
local mainTypes = {
    INVTYPE_2HWEAPON = true,
    INVTYPE_WEAPON = true,
    INVTYPE_WEAPONMAINHAND = true,
}
local offTypes = {
    INVTYPE_HOLDABLE = true,
    INVTYPE_SHIELD = true,
    INVTYPE_WEAPONOFFHAND = true,
}
local colors = {
    damage = {1, 0.72, 0.42},
    healing = {0.48, 0.86, 0.65},
    none = {0.8, 0.82, 0.86},
}

local db, toggle, status, icon
local requestedItems = {}
local SWAP_BINDING = "CLICK SimpleWeaponSwapToggle:SwapKey"

local function Message(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cffefb56fSimple Weapon Swap:|r " .. text)
end

local function Equipped()
    return GetInventoryItemID("player", MAIN), GetInventoryItemID("player", OFF)
end

local function ItemType(id)
    if id then
        local _, _, _, equipLocation = C_Item.GetItemInfoInstant(id)
        return equipLocation
    end
end

function addon.GetItemName(id)
    return C_Item.GetItemNameByID(id) or ("Item #" .. id)
end

function addon.GetSets()
    return db.sets
end

function addon.GetSetName(key)
    return (db.names and db.names[key]) or labels[key]
end

function addon.GetChoices(hand)
    local choices, seen = {}, {}
    local allowed = hand == "main" and mainTypes or offTypes
    local allowDualWield = hand == "off" and (
        (CanDualWield and CanDualWield()) or (IsPlayerSpell and IsPlayerSpell(674))
    )

    local function Add(id, link, equipped)
        if not id or seen[id] then
            return
        end
        local _, _, _, itemType, texture = C_Item.GetItemInfoInstant(id)
        if not allowed[itemType] and not (allowDualWield and itemType == "INVTYPE_WEAPON") then
            return
        end
        seen[id] = true
        local name = C_Item.GetItemNameByID(id)
        if not name and not requestedItems[id] then
            requestedItems[id] = true
            C_Item.RequestLoadItemDataByID(id)
        end
        choices[#choices + 1] = {
            id = id,
            name = name or ("Item #" .. id),
            icon = texture,
            link = link,
            equipped = equipped,
            twoHand = itemType == "INVTYPE_2HWEAPON",
        }
    end

    local slot = hand == "main" and MAIN or OFF
    local otherSlot = slot == MAIN and OFF or MAIN
    Add(GetInventoryItemID("player", slot), GetInventoryItemLink("player", slot), true)
    Add(GetInventoryItemID("player", otherSlot), GetInventoryItemLink("player", otherSlot), true)
    for bag = 0, NUM_BAG_SLOTS do
        for index = 1, C_Container.GetContainerNumSlots(bag) do
            local item = C_Container.GetContainerItemInfo(bag, index)
            if item then
                Add(item.itemID, item.hyperlink, false)
            end
        end
    end

    table.sort(choices, function(a, b)
        if a.equipped ~= b.equipped then
            return a.equipped
        end
        if a.name == b.name then
            return a.id < b.id
        end
        return a.name < b.name
    end)
    return choices
end

local function SameSet(set, main, off)
    return set and set.main == main and set.off == off
end

local function ActiveSet(main, off)
    for _, key in ipairs({"damage", "healing"}) do
        if SameSet(db.sets[key], main, off) then
            return key
        end
    end
end

local function Ready()
    return db.sets.damage ~= nil and db.sets.healing ~= nil
end

local function RefreshStatus()
    local main, off = Equipped()
    local active = ActiveSet(main, off)
    local color = colors[active or "none"]
    status:SetText(active and addon.GetSetName(active) or (Ready() and "Other weapons" or "Set up weapons"))
    status:SetTextColor(unpack(color))
    icon:SetTexture(GetInventoryItemTexture("player", MAIN) or "Interface\\Icons\\INV_Misc_QuestionMark")

    -- Combat events may refresh the display, while secure click state stays in the protected button.
    if not InCombatLockdown() then
        toggle:SetAttribute("next-set", active and other[active] or "damage")
    end
end

function addon.SetSetName(key, name)
    if InCombatLockdown() then
        return false, "Rename weapon sets after combat."
    end
    if not labels[key] then
        return false, "Unknown weapon set."
    end

    name = strtrim(name)
    if name:find("[|%c]") then
        return false, "Use plain text for the set name."
    end
    if strlenutf8(name) > 24 then
        return false, "Set names can be up to 24 characters."
    end

    db.names = db.names or {}
    db.names[key] = name ~= "" and name or nil
    RefreshStatus()
    return true
end

local function BuildMacro(set)
    local command = SLASH_EQUIP_TO_SLOT1 or "/equipslot"
    local body = format("%s %d item:%d", command, MAIN, set.main)
    if set.off then
        body = body .. format("\n%s %d item:%d", command, OFF, set.off)
    end
    return body
end

local function ConditionLabel(label)
    if type(label) == "string" and label ~= "" and not label:find("[,;/:%[%]\r\n]") then
        return label
    end
end

local function CompileSwap()
    if InCombatLockdown() then
        return
    end

    local damage, healing = db.sets.damage, db.sets.healing
    local conditional
    if damage and healing then
        local pairKey = damage.off and not healing.off and "damage"
            or healing.off and not damage.off and "healing"
        if pairKey then
            local pair = db.sets[pairKey]
            local offType = ItemType(pair.off)
            local offLabel = offType ~= "INVTYPE_WEAPON" and ConditionLabel(_G[offType])
            local twoHandLabel = ConditionLabel(INVTYPE_2HWEAPON)
            local mainLabel = ConditionLabel(_G[ItemType(pair.main)])
            if offLabel and twoHandLabel and mainLabel then
                conditional = format("[combat,worn:%s] %s; [combat,worn:%s] %s; [combat,worn:%s] %s",
                    offLabel, other[pairKey], twoHandLabel, pairKey, mainLabel, pairKey)
            end
        elseif not damage.off and not healing.off then
            local _, _, damageType = C_Item.GetItemInfoInstant(damage.main)
            local _, _, healingType = C_Item.GetItemInfoInstant(healing.main)
            damageType, healingType = ConditionLabel(damageType), ConditionLabel(healingType)
            if damageType and healingType and damageType ~= healingType then
                conditional = format("[combat,worn:%s] healing; [combat,worn:%s] damage", damageType, healingType)
            end
        end
    end
    toggle:SetAttribute("damage-macro", damage and healing and BuildMacro(damage) or nil)
    toggle:SetAttribute("healing-macro", damage and healing and BuildMacro(healing) or nil)
    toggle:SetAttribute("choose-set", conditional)
    RefreshStatus()
end

local function HasChoice(hand, id)
    for _, choice in ipairs(addon.GetChoices(hand)) do
        if choice.id == id then
            return choice
        end
    end
end

function addon.SaveSet(key, main, off)
    if InCombatLockdown() then
        return false, "Edit weapon sets after combat."
    end
    if not labels[key] then
        return false, "Unknown weapon set."
    end
    local weapon = HasChoice("main", main)
    if not weapon then
        return false, "Select a main-hand weapon from your bags or equipment."
    elseif weapon.twoHand and off then
        return false, "A two-handed weapon requires an empty off hand."
    elseif not weapon.twoHand and not off then
        return false, "Choose a two-hander or pair your main hand with an off-hand item."
    elseif off == main then
        return false, "Choose a different item for each hand."
    elseif off and not HasChoice("off", off) then
        return false, "Select an off-hand item from your bags or equipment."
    elseif SameSet(db.sets[other[key]], main, off) then
        return false, "Choose different weapons for your two sets."
    end

    db.sets[key] = {main = main, off = off}
    CompileSwap()
    return true
end

function addon.CaptureSet(key)
    local main, off = Equipped()
    return addon.SaveSet(key, main, off)
end

function addon.GetBinding()
    return db.key
end

local function BindingConflict(key)
    local action = GetBindingAction(key, true)
    return action and action ~= "" and action ~= SWAP_BINDING
end

local function ApplyBinding()
    ClearOverrideBindings(toggle)
    if db.key and not BindingConflict(db.key) then
        SetOverrideBindingClick(toggle, false, db.key, toggle:GetName(), "SwapKey")
        return true
    end
    return not db.key
end

function addon.SetBinding(key)
    if InCombatLockdown() then
        return false, "Change your swap key after combat."
    end
    if key and BindingConflict(key) then
        return false, key .. " already has a binding. Choose another key."
    end
    db.key = key
    ApplyBinding()
    return true
end

local function EnableDragging(frame)
    local driver = CreateFrame("Frame")

    local function StopDragging()
        driver:SetScript("OnUpdate", nil)
    end

    toggle:HookScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or not IsShiftKeyDown() or InCombatLockdown() then
            return
        end

        local startX, startY = GetCursorPosition()
        local frameX, frameY = frame:GetCenter()
        local parentX, parentY = UIParent:GetCenter()
        local scale = UIParent:GetEffectiveScale()
        local boundX = math.max(0, (UIParent:GetWidth() - frame:GetWidth()) / 2)
        local boundY = math.max(0, (UIParent:GetHeight() - frame:GetHeight()) / 2)
        GameTooltip:Hide()
        driver:SetScript("OnUpdate", function()
            if InCombatLockdown() or not IsMouseButtonDown("LeftButton") then
                StopDragging()
                return
            end

            local cursorX, cursorY = GetCursorPosition()
            local x = frameX - parentX + (cursorX - startX) / scale
            local y = frameY - parentY + (cursorY - startY) / scale
            x = math.max(-boundX, math.min(boundX, x))
            y = math.max(-boundY, math.min(boundY, y))
            if db.position and db.position.x == x and db.position.y == y then
                return
            end

            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
            db.position = {x = x, y = y}
        end)
    end)
    toggle:HookScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            StopDragging()
        end
    end)
    toggle:HookScript("OnHide", StopDragging)
end

local function CreateToggle()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetSize(167, 51)
    if db.position then
        frame:SetPoint("CENTER", UIParent, "CENTER", db.position.x, db.position.y)
    else
        frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 190)
    end
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("MEDIUM")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.045, 0.05, 0.06, 0.94)
    frame:SetBackdropBorderColor(0.32, 0.30, 0.25)

    toggle = CreateFrame("Button", "SimpleWeaponSwapToggle", frame, "SecureActionButtonTemplate")
    toggle:SetPoint("TOPLEFT", 1, -1)
    toggle:SetPoint("BOTTOMRIGHT", -1, 1)
    toggle:RegisterForClicks("AnyUp", "LeftButtonDown")
    toggle:SetAttribute("useOnKeyDown", false)
    toggle:SetAttribute("type", "macro")
    toggle:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    SecureHandlerWrapScript(toggle, "PreClick", toggle, [[
        if down then
            if button == "LeftButton" then
                self:SetAttribute("move-click", IsShiftKeyDown())
            end
            return
        end

        local key
        if button == "RightButton" then
            key = "healing"
        elseif button == "MiddleButton" then
            key = "damage"
        elseif button == "LeftButton" or button == "SwapKey" then
            if button == "LeftButton" then
                local moveClick = self:GetAttribute("move-click")
                self:SetAttribute("move-click", nil)
                if moveClick or IsShiftKeyDown() then
                    self:SetAttribute("macrotext", nil)
                    return
                end
            end
            local condition = self:GetAttribute("choose-set")
            key = (condition and SecureCmdOptionParse(condition)) or self:GetAttribute("next-set") or "damage"
        else
            self:SetAttribute("macrotext", nil)
            return
        end
        local body = self:GetAttribute(key .. "-macro")
        self:SetAttribute("macrotext", body)
        if body then
            self:SetAttribute("next-set", key == "damage" and "healing" or "damage")
        end
    ]])

    icon = toggle:CreateTexture(nil, "ARTWORK")
    icon:SetSize(30, 30)
    icon:SetPoint("LEFT", 9, 0)
    icon:SetTexCoord(0.075, 0.925, 0.075, 0.925)

    local caption = toggle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    caption:SetPoint("TOPLEFT", 47, -9)
    caption:SetText("Equipped")

    status = toggle:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    status:SetPoint("TOPLEFT", caption, "BOTTOMLEFT", 0, -3)
    status:SetWidth(110)
    status:SetWordWrap(false)
    status:SetJustifyH("LEFT")

    toggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Simple Weapon Swap")
        local main, off = Equipped()
        if main then
            GameTooltip:AddLine(addon.GetItemName(main), 1, 1, 1)
        end
        if off then
            GameTooltip:AddLine(addon.GetItemName(off), 1, 1, 1)
        end
        GameTooltip:AddLine(" ")
        local key = db.key and GetBindingAction(db.key, true) == SWAP_BINDING and db.key
        GameTooltip:AddLine(key and ("Left-click or " .. key .. " to swap sets") or "Left-click to swap sets", 1, 1, 1)
        GameTooltip:AddLine("Right-click to equip " .. addon.GetSetName("healing"), 0.78, 0.8, 0.84, true)
        GameTooltip:AddLine("Middle-click to equip " .. addon.GetSetName("damage"), 0.78, 0.8, 0.84, true)
        GameTooltip:AddLine("Shift + left-drag to move out of combat", 0.78, 0.8, 0.84)
        GameTooltip:AddLine("/fws to open setup", 0.78, 0.8, 0.84)
        GameTooltip:Show()
    end)
    toggle:SetScript("OnLeave", GameTooltip_Hide)
    EnableDragging(frame)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= addonName then
            return
        end
        -- The legacy global also lets a copied FeralWeaponSwap.lua retain its settings.
        FeralWeaponSwapDB = FeralWeaponSwapDB or {sets = {}}
        db = FeralWeaponSwapDB
        CreateToggle()
        CompileSwap()
        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not InCombatLockdown() and not ApplyBinding() then
            Message("Your saved swap key is in use. Choose another key in /fws.")
        end
        CompileSwap()
    elseif event == "PLAYER_REGEN_ENABLED" then
        ApplyBinding()
        CompileSwap()
        addon.RefreshSetup()
    elseif event == "PLAYER_REGEN_DISABLED" then
        addon.RefreshSetup()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        local slot = ...
        if slot == MAIN or slot == OFF then
            RefreshStatus()
        end
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        addon.RefreshSetup()
    end
end)

SLASH_SIMPLEWEAPONSWAP1 = "/fws"
SlashCmdList.SIMPLEWEAPONSWAP = function(args)
    if strtrim(args):lower() == "status" then
        local main, off = Equipped()
        local active = ActiveSet(main, off)
        local version, build, _, interface = GetBuildInfo()
        Message(format("WoW %s (build %s, interface %s).", version, build, interface))
        Message(format("Equipped: %s | Main hand: %s | Off hand: %s",
            (active and addon.GetSetName(active)) or "Other weapons", main or "-", off or "-"))
        for _, key in ipairs({"damage", "healing"}) do
            local set = db.sets[key]
            Message(format("%s: %s / %s", addon.GetSetName(key), set and set.main or "-", set and set.off or "-"))
        end
    else
        addon.OpenSetup()
    end
end
