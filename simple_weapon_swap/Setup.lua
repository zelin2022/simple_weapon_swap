local _, addon = ...

local setup
local MODIFIER_KEYS = {
    LALT = true, RALT = true, LCTRL = true, RCTRL = true,
    LSHIFT = true, RSHIFT = true, ALT = true, CTRL = true, SHIFT = true,
}

local function Text(parent, font, text, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", font)
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local function Button(parent, text, width, x, y, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function Checkbox(text, y, onClick)
    local box = CreateFrame("CheckButton", nil, setup, "UICheckButtonTemplate")
    box:SetSize(24, 24)
    box:SetPoint("TOPLEFT", 20, y)
    box:SetHitRectInsets(0, -360, 0, 0)
    box:SetScript("OnClick", onClick)

    local label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", box, "RIGHT", 4, 0)
    label:SetText(text)
    return box
end

local function SetMessage(text, isError)
    setup.message:SetText(text or "")
    if isError then
        setup.message:SetTextColor(1, 0.45, 0.35)
    else
        setup.message:SetTextColor(0.63, 0.88, 0.66)
    end
end

local function SetDraftFromSaved(section)
    local saved = addon.GetSets()[section.key]
    section.draft.main = saved and saved.main
    section.draft.off = saved and saved.off
end

local function RefreshSection(section)
    local locked = InCombatLockdown()
    local saved = addon.GetSets()[section.key]
    local main = section.draft.main
    local off = section.draft.off
    local twoHand = false
    for _, choice in ipairs(addon.GetChoices("main")) do
        if choice.id == main then
            twoHand = choice.twoHand
            break
        end
    end

    section.main:OverrideText(main and addon.GetItemName(main) or "Choose a weapon")
    section.off:OverrideText(off and addon.GetItemName(off) or "Empty")
    section.name:EnableMouse(not locked)
    if locked then
        section.name:ClearFocus()
    end
    section.main:SetEnabled(not locked)
    section.off:SetEnabled(not locked and not twoHand)
    if locked then
        section.main:CloseMenu()
        section.off:CloseMenu()
    end
    section.capture:SetEnabled(not locked)
    section.save:SetEnabled(not locked and main ~= nil)

    local savedMain = saved and saved.main
    local savedOff = saved and saved.off
    if main ~= savedMain or off ~= savedOff then
        section.state:SetText("Unsaved changes")
        section.state:SetTextColor(1, 0.77, 0.34)
    elseif savedMain then
        section.state:SetText("Saved")
        section.state:SetTextColor(0.63, 0.88, 0.66)
    else
        section.state:SetText("No set saved")
        section.state:SetTextColor(0.66, 0.68, 0.71)
    end
end

local function CreatePicker(section, hand, y)
    local dropdown = CreateFrame("DropdownButton", nil, section, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", 80, y)
    dropdown:SetSize(285, 24)

    local function IsSelected(choice)
        return section.draft[hand] == choice.id
    end

    local function Select(choice)
        if InCombatLockdown() then
            return
        end
        section.draft[hand] = choice.id
        if hand == "main" and choice.twoHand then
            section.draft.off = nil
        end
        SetMessage()
        RefreshSection(section)
    end

    dropdown:SetupMenu(function(_, menu)
        menu:SetScrollMode(225)
        if hand == "off" then
            menu:CreateRadio("Empty", IsSelected, Select, {})
        end
        local choices = addon.GetChoices(hand)
        if #choices == 0 then
            menu:CreateTitle("No matching items in your bags or equipped")
        end
        for _, choice in ipairs(choices) do
            local label = choice.name
            if choice.icon then
                label = "|T" .. choice.icon .. ":16:16|t  " .. label
            end
            if choice.equipped then
                label = label .. "  (equipped)"
            end
            local row = menu:CreateRadio(label, IsSelected, Select, choice)
            if choice.link then
                row:SetTooltip(function(tooltip, description)
                    tooltip:SetHyperlink(description:GetData().link)
                end)
            end
        end
    end)
    return dropdown
end

local function CreateNameEditor(section)
    local key = section.key
    local field = CreateFrame("EditBox", nil, section, "InputBoxTemplate")
    field:SetPoint("TOPLEFT", 80, -6)
    field:SetSize(202, 23)
    field:SetAutoFocus(false)
    field:SetMaxLetters(24)
    field:SetText(addon.GetSetName(key))
    field:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    field:SetScript("OnEscapePressed", function(self)
        self:SetText(addon.GetSetName(key))
        self:ClearFocus()
    end)
    field:SetScript("OnEditFocusLost", function(self)
        local previous = addon.GetSetName(key)
        if self:GetText() == previous then
            return
        end

        local ok, message = addon.SetSetName(key, self:GetText())
        self:SetText(addon.GetSetName(key))
        SetMessage(message or (ok and "Set name saved." or "Could not save the set name."), not ok)
    end)
    return field
end

local function CreateSection(key, y)
    local section = CreateFrame("Frame", nil, setup, "BackdropTemplate")
    section:SetPoint("TOPLEFT", 18, y)
    section:SetSize(402, 138)
    section:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    section:SetBackdropColor(0.13, 0.14, 0.17, 0.84)
    section.key = key
    section.draft = {}

    Text(section, "GameFontHighlightSmall", "Set name", 12, -13)
    section.name = CreateNameEditor(section)
    Text(section, "GameFontHighlightSmall", "Main hand", 12, -40)
    Text(section, "GameFontHighlightSmall", "Off hand", 12, -68)
    section.state = section:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    section.state:SetPoint("TOPRIGHT", -12, -12)
    section.main = CreatePicker(section, "main", -34)
    section.off = CreatePicker(section, "off", -62)
    section.capture = Button(section, "Save equipped", 110, 80, -102, function()
        local ok, message = addon.CaptureSet(key)
        if ok then
            SetDraftFromSaved(section)
        end
        SetMessage(message or (ok and (addon.GetSetName(key) .. " set saved.") or "Could not save this set."), not ok)
        RefreshSection(section)
    end)
    section.save = Button(section, "Save selections", 114, 251, -102, function()
        local ok, message = addon.SaveSet(key, section.draft.main, section.draft.off)
        if ok then
            SetDraftFromSaved(section)
        end
        SetMessage(message or (ok and (addon.GetSetName(key) .. " set saved.") or "Could not save this set."), not ok)
        RefreshSection(section)
    end)
    return section
end

local function StopKeyCapture()
    setup.listening = false
    setup:EnableKeyboard(false)
end

function addon.RefreshSetup()
    if not setup or not setup:IsShown() then
        return
    end

    local locked = InCombatLockdown()
    if locked and setup.listening then
        StopKeyCapture()
    end
    RefreshSection(setup.damage)
    RefreshSection(setup.healing)

    local key = addon.GetBinding()
    local allowActionBarOverride, passThrough = addon.GetBindingOptions()
    local bindingText = key and GetBindingText(key) or "Unbound"
    local label = "Swap key: " .. bindingText
    if key and passThrough then
        label = "Saved key: " .. bindingText
    elseif key and not addon.IsBindingActive() then
        label = "Saved key: " .. bindingText .. " (inactive)"
    end
    setup.bindingLabel:SetText(setup.listening and "Press a key. Esc cancels." or label)
    local canEditBinding = not locked and not setup.listening
    setup.bind:SetEnabled(canEditBinding)
    setup.clear:SetEnabled(canEditBinding and key ~= nil)
    setup.overrideActionBar:SetChecked(allowActionBarOverride)
    setup.overrideActionBar:SetEnabled(canEditBinding)
    setup.passThrough:SetChecked(passThrough)
    setup.passThrough:SetEnabled(canEditBinding)
    setup.combat:SetShown(locked and true or false)
end

local function SaveBindingOptions()
    local ok, message = addon.SetBindingOptions(
        not not setup.overrideActionBar:GetChecked(),
        not not setup.passThrough:GetChecked()
    )
    SetMessage(message, not ok)
    addon.RefreshSetup()
end

local function CreateSetup()
    setup = CreateFrame("Frame", "SimpleWeaponSwapSetup", UIParent, "BasicFrameTemplateWithInset")
    setup:SetSize(438, 484)
    setup:SetPoint("CENTER", 0, 36)
    setup:SetClampedToScreen(true)
    setup:SetFrameStrata("DIALOG")
    setup:EnableMouse(true)
    setup:SetMovable(true)
    setup:RegisterForDrag("LeftButton")
    setup:SetScript("OnDragStart", setup.StartMoving)
    setup:SetScript("OnDragStop", setup.StopMovingOrSizing)
    setup:Hide()
    tinsert(UISpecialFrames, setup:GetName())

    Text(setup, "GameFontHighlight", "Simple Weapon Swap", 12, -4)
    local help = Text(setup, "GameFontHighlightSmall", "Choose from equipped weapons and bags, or save what you are wearing.", 20, -38)
    help:SetWidth(398)
    help:SetJustifyH("LEFT")
    setup.damage = CreateSection("damage", -60)
    setup.healing = CreateSection("healing", -208)

    setup.bindingLabel = Text(setup, "GameFontHighlight", "", 20, -365)
    setup.bind = Button(setup, "Bind key", 78, 258, -356, function()
        if InCombatLockdown() then
            return
        end
        setup.listening = true
        setup:EnableKeyboard(true)
        setup:SetPropagateKeyboardInput(false)
        SetMessage()
        addon.RefreshSetup()
    end)
    setup.clear = Button(setup, "Clear", 70, 342, -356, function()
        local ok, message = addon.SetBinding(nil)
        SetMessage(message or (ok and "Swap key cleared." or "Could not clear the swap key."), not ok)
        addon.RefreshSetup()
    end)

    setup.overrideActionBar = Checkbox("Override an action-bar key on this character", -385, SaveBindingOptions)
    setup.passThrough = Checkbox("Pass through to the normal WoW binding", -412, SaveBindingOptions)

    setup.message = Text(setup, "GameFontHighlightSmall", "", 20, -445)
    setup.message:SetWidth(398)
    setup.message:SetJustifyH("LEFT")
    setup.combat = Text(setup, "GameFontNormalSmall", "Set editing and key changes are available out of combat.", 20, -465)
    setup.combat:SetTextColor(1, 0.77, 0.34)

    setup:SetScript("OnKeyDown", function(_, key)
        if not setup.listening or MODIFIER_KEYS[key] then
            return
        end
        StopKeyCapture()
        if key ~= "ESCAPE" then
            if IsShiftKeyDown() then key = "SHIFT-" .. key end
            if IsControlKeyDown() then key = "CTRL-" .. key end
            if IsAltKeyDown() then key = "ALT-" .. key end
            local ok, message = addon.SetBinding(key)
            SetMessage(message or (ok and "Swap key saved." or "Could not bind that key."), not ok)
        end
        addon.RefreshSetup()
    end)
    setup:HookScript("OnHide", StopKeyCapture)
end

function addon.OpenSetup()
    if not setup then
        CreateSetup()
    end
    if not setup:IsShown() then
        SetDraftFromSaved(setup.damage)
        SetDraftFromSaved(setup.healing)
        setup.damage.name:SetText(addon.GetSetName("damage"))
        setup.healing.name:SetText(addon.GetSetName("healing"))
        SetMessage()
        setup:Show()
    end
    addon.RefreshSetup()
end
