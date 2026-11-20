local frames, combat, equipped, macros = {}, false, {16, nil}, {}
local canStow, canEquipOff, printed = true, true, {}
local nativeBindings, bindingOverrides = {}, {}
local swapAction = "CLICK SimpleWeaponSwapToggle:SwapKey"
local shift, mouseDown, cursorX, cursorY = false, false, 0, 0
local dualWield = false
local functions = {}
local mt = {
    __index = function(_, key)
        return functions[key] or function() end
    end,
}

local function widget(name, parent, kind)
    local frame = setmetatable({attrs = {}, scripts = {}, name = name, parent = parent,
        kind = kind, children = {}, shown = true, focused = false}, mt)
    if name then frames[name] = frame end
    if parent then table.insert(parent.children, frame) end
    return frame
end

function functions:SetAttribute(key, value)
    assert(not combat or self.insideSecureClick, "Protected attribute changed in combat")
    self.attrs[key] = value
end
function functions:GetAttribute(key) return self.attrs[key] end
function functions:SetScript(event, callback) self.scripts[event] = callback end
function functions:HookScript(event, callback)
    assert(not self.scripts[event], "Mock assumes one callback per event")
    self.scripts[event] = callback
end
function functions:Fire(event, ...)
    local callback = self.scripts[event]
    if callback then callback(self, ...) end
end
function functions:ClearFocus()
    if self.focused then
        self.focused = false
        self:Fire("OnEditFocusLost")
    end
end
function functions:GetText() return self.text end
function functions:SetChecked(checked) self.checked = checked and true or false end
function functions:GetChecked() return rawget(self, "checked") or false end
function functions:SetEnabled(enabled) self.enabled = enabled end
function functions:Show() self.shown = true end
function functions:Hide() self.shown = false end
function functions:IsShown() return self.shown end
function functions:SetSize(width, height) self.width, self.height = width, height end
function functions:GetWidth() return self.width end
function functions:GetHeight() return self.height end
function functions:GetCenter()
    if self == UIParent then return self.width / 2, self.height / 2 end
    local point = self.anchor
    local x, y = UIParent:GetCenter()
    if point[1] == "BOTTOM" then
        return x + point[4], point[5] + self.height / 2
    end
    return x + point[4], y + point[5]
end
function functions:GetEffectiveScale() return 2 end
function functions:SetPoint(...)
    if frames.SimpleWeaponSwapToggle and self == frames.SimpleWeaponSwapToggle.parent then
        assert(not combat, "Panel moved in combat")
    end
    self.anchor = {...}
end
function functions:ClearAllPoints() self.anchor = nil end
function functions:GetName() return self.name end
function functions:CreateFontString()
    local font = widget()
    self.fonts = rawget(self, "fonts") or {}
    table.insert(self.fonts, font)
    return font
end
function functions:CreateTexture() return widget() end
function functions:SetText(value) self.text = value end

function CreateFrame(kind, name, parent)
    local frame = widget(name, parent, kind)
    frames.first = frames.first or frame
    if kind == "Frame" and not parent and frame ~= frames.first then
        frames.driver = frame
    end
    return frame
end
function SecureHandlerWrapScript(frame, script, header, body)
    assert(frame == header and script == "PreClick")
    frame.secure = assert(loadstring("return function(self, button, down) " .. body .. " end"))()
end

INVTYPE_2HWEAPON = "Two-Hand"
INVTYPE_HOLDABLE = "Held In Off-hand"
INVTYPE_WEAPON = "One-Hand"
local equipLoc = {
    [16] = "INVTYPE_2HWEAPON", [21] = "INVTYPE_WEAPON", [22] = "INVTYPE_HOLDABLE",
    [31] = "INVTYPE_2HWEAPON", [32] = "INVTYPE_2HWEAPON", [23] = "INVTYPE_WEAPON",
}
local subtype = {[16] = "Staves", [31] = "Staves", [32] = "Two-Handed Maces"}
function SecureCmdOptionParse(conditions)
    if not combat then return nil end
    for token, result in conditions:gmatch("%[combat,worn:(.-)%] (%a+)") do
        if token == _G[equipLoc[equipped[1]]] or token == _G[equipLoc[equipped[2]]] or token == subtype[equipped[1]] then
            return result
        end
    end
end
function GetInventoryItemID(_, slot) return equipped[slot - 15] end
function GetInventoryItemLink(_, slot)
    local id = GetInventoryItemID("player", slot)
    return id and ("item:" .. id)
end
function GetInventoryItemTexture(_, slot) return GetInventoryItemID("player", slot) end
function InCombatLockdown() return combat end
function CanDualWield() return dualWield end
function IsShiftKeyDown() return shift end
function GetCursorPosition() return cursorX, cursorY end
function IsMouseButtonDown(button) return button == "LeftButton" and mouseDown end
function GetBindingText(key) return key end
strlenutf8, tinsert = string.len, table.insert
function GetBuildInfo() return "1.60.1", "70959", "", 16001 end
function strtrim(text) return text:match("^%s*(.-)%s*$") end
function GetBindingAction(key, checkOverride)
    local override = checkOverride and bindingOverrides[key]
    return (override and override.action) or nativeBindings[key] or ""
end
function ClearOverrideBindings(frame)
    assert(not combat, "Binding override cleared in combat")
    for key, override in pairs(bindingOverrides) do
        if override.owner == frame then
            bindingOverrides[key] = nil
        end
    end
end
function SetOverrideBindingClick(frame, _, key, name, button)
    assert(not combat, "Binding override assigned in combat")
    bindingOverrides[key] = {owner = frame, action = "CLICK " .. name .. ":" .. button}
end
function GameTooltip_Hide() end
GameTooltip = widget()
function GameTooltip:AddLine(line) self.lines[#self.lines + 1] = line end
function GameTooltip:SetText(text) self.lines = {text} end
UIParent, NUM_BAG_SLOTS, SlashCmdList, format, UISpecialFrames = widget(), 4, {}, string.format, {}
UIParent:SetSize(800, 600)
DEFAULT_CHAT_FRAME = {AddMessage = function(_, text) table.insert(printed, text) end}
C_Item = {
    GetItemInfoInstant = function(id) return id, "", subtype[id] or "", equipLoc[id], id end,
    GetItemNameByID = function(id) return "Item " .. id end,
}
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 6 or 0 end,
    GetContainerItemInfo = function(_, slot)
        local id = ({16, 21, 22, 31, 32, 23})[slot]
        if id and id ~= equipped[1] and id ~= equipped[2] then
            return {itemID = id, hyperlink = "item:" .. id}
        end
    end,
}

local setupOpened = 0
local addon = {RefreshSetup = function() end, OpenSetup = function() setupOpened = setupOpened + 1 end}
local legacy = {sets = {}, key = "F8"}
FeralWeaponSwapDB = legacy
assert(loadfile("simple_weapon_swap/simple_weapon_swap.lua"))("simple_weapon_swap", addon)
local events = frames.first
local function event(name, ...)
    events.scripts.OnEvent(events, name, ...)
end
local function enterCombat()
    combat = true
    event("PLAYER_REGEN_DISABLED")
end
local function leaveCombat()
    combat = false
    event("PLAYER_REGEN_ENABLED")
end
local function Click(button, down)
    local toggle = frames.SimpleWeaponSwapToggle
    toggle.insideSecureClick = true
    toggle:secure(button or "LeftButton", down or false)
    toggle.insideSecureClick = false
    if down then return end
    local body = toggle.attrs.macrotext
    if not body then return end
    table.insert(macros, body)
    for slot, id in body:gmatch("/equipslot (%d+) item:(%d+)") do
        id, slot = tonumber(id), tonumber(slot)
        if slot == 16 and (equipLoc[id] ~= "INVTYPE_2HWEAPON" or not equipped[2] or canStow) then
            equipped[1] = id
            if equipLoc[id] == "INVTYPE_2HWEAPON" and equipped[2] then
                equipped[2] = nil
                event("PLAYER_EQUIPMENT_CHANGED", 17)
            end
            event("PLAYER_EQUIPMENT_CHANGED", 16)
        elseif slot == 17 and canEquipOff and equipLoc[equipped[1]] ~= "INVTYPE_2HWEAPON" then
            equipped[2] = id
            event("PLAYER_EQUIPMENT_CHANGED", 17)
        end
    end
end

event("ADDON_LOADED", "simple_weapon_swap")
event("PLAYER_ENTERING_WORLD")
local toggle = frames.SimpleWeaponSwapToggle
local status = toggle.fonts[2]
assert(status.text == "Set up weapons")
assert(addon.GetBinding() == "F8" and GetBindingAction("F8", true) == swapAction)
assert(addon.GetSets() == legacy.sets)
assert(#toggle.parent.children == 1)
Click()
assert(#macros == 0 and setupOpened == 0)
SlashCmdList.SIMPLEWEAPONSWAP("")
assert(setupOpened == 1)
assert(addon.CaptureSet("damage"))
assert(status.text == "Damage")
assert(not addon.SaveSet("healing", 21, nil))
assert(not addon.SaveSet("healing", 31, 22))
assert(not addon.SaveSet("healing", 16, nil))
assert(addon.SaveSet("healing", 21, 22))
Click()
assert(macros[#macros] == "/equipslot 16 item:21\n/equipslot 17 item:22")
assert(status.text == "Healing")
Click()
assert(status.text == "Damage" and equipped[2] == nil)

nativeBindings.F5 = "OPENALLBAGS"
assert(not addon.SetBinding("F5"))
assert(addon.SetBinding("F6") and GetBindingAction("F6", true) == swapAction)
enterCombat()
assert(not addon.SaveSet("damage", 31))
assert(not addon.SetBinding("F7"))
canEquipOff = false
Click()
assert(status.text == "Other weapons" and equipped[1] == 21 and equipped[2] == nil)
canEquipOff = true
Click()
assert(status.text == "Healing" and equipped[2] == 22)
canStow = false
Click()
assert(status.text == "Healing")
canStow = true
Click()
assert(status.text == "Damage" and equipped[2] == nil)
leaveCombat()

assert(addon.SaveSet("healing", 31))
enterCombat()
Click()
assert(status.text == "Healing" and equipped[1] == 31)
Click()
assert(status.text == "Damage" and equipped[1] == 16)
Click("RightButton")
assert(status.text == "Healing")
Click("MiddleButton")
assert(status.text == "Damage")
SlashCmdList.SIMPLEWEAPONSWAP("status")
assert(printed[1]:find("16001", 1, true))
assert(printed[2]:find("Equipped: Damage", 1, true))
leaveCombat()
assert(addon.SaveSet("healing", 32))
enterCombat()
equipped[1] = 32
event("PLAYER_EQUIPMENT_CHANGED", 16)
Click()
assert(status.text == "Damage" and equipped[1] == 16)
leaveCombat()
assert(addon.SetBinding(nil) and GetBindingAction("F6", true) == "")

-- A Shift-bound key still swaps while a Shift-click is reserved for movement.
assert(addon.SetBinding("SHIFT-F6"))
shift = true
Click("SwapKey")
assert(status.text == "Healing")
Click("LeftButton", true)
mouseDown = true
toggle:Fire("OnMouseDown", "LeftButton")
cursorX, cursorY = 100, 40
frames.driver:Fire("OnUpdate")
assert(legacy.position.x == 50 and legacy.position.y == -64.5)
assert(toggle.parent.anchor[4] == 50 and toggle.parent.anchor[5] == -64.5)

-- Releasing Shift before the mouse button should still consume the click.
shift, mouseDown = false, false
toggle:Fire("OnMouseUp", "LeftButton")
Click("LeftButton")
assert(status.text == "Healing" and not frames.driver.scripts.OnUpdate)
Click("LeftButton", true)
Click("LeftButton")
assert(status.text == "Damage")

-- Combat can start mid-drag. The anchor stays at the last safe location.
shift, mouseDown = true, true
Click("LeftButton", true)
toggle:Fire("OnMouseDown", "LeftButton")
enterCombat()
cursorX, cursorY = 250, 300
frames.driver:Fire("OnUpdate")
assert(legacy.position.x == 50 and legacy.position.y == -64.5)
assert(not frames.driver.scripts.OnUpdate)
shift, mouseDown = false, false
Click("LeftButton")
assert(status.text == "Damage")
leaveCombat()

-- Name edits update the HUD, tooltip, chat, and saved settings.
assert(addon.GetSetName("damage") == "Damage")
assert(addon.SetSetName("damage", "  Cat Burst  "))
assert(addon.GetSetName("damage") == "Cat Burst" and status.text == "Cat Burst")
assert(legacy.names.damage == "Cat Burst")
assert(not addon.SetSetName("damage", "|bad"))
assert(not addon.SetSetName("damage", string.rep("A", 25)))
toggle:Fire("OnEnter")
assert(table.concat(GameTooltip.lines, "\n"):find("/fws to open setup", 1, true))
assert(table.concat(GameTooltip.lines, "\n"):find("Middle-click to equip Cat Burst", 1, true))

assert(loadfile("simple_weapon_swap/Setup.lua"))("simple_weapon_swap", addon)
SlashCmdList.SIMPLEWEAPONSWAP("")
local setup = frames.SimpleWeaponSwapSetup
local field = setup.damage.name
assert(field:GetText() == "Cat Burst")
field:SetText("Arena")
field.focused = true
field:Fire("OnEnterPressed")
assert(status.text == "Arena" and legacy.names.damage == "Arena")
field:SetText("")
field.focused = true
field:Fire("OnEnterPressed")
assert(status.text == "Damage" and legacy.names.damage == nil)

assert(not addon.SaveSet("healing", 21, 23))
dualWield = true
assert(not addon.SaveSet("healing", 21, 21))
assert(addon.SaveSet("healing", 21, 23))
Click("RightButton")
assert(status.text == "Healing" and equipped[1] == 21 and equipped[2] == 23)

-- Native and addon bindings remain independent.
local actionBarSlot = "MULTIACTIONBAR1BUTTON1"
local actionBar = {[actionBarSlot] = "Druid action"}
local lastAction
local function PressKey(key)
    local action = GetBindingAction(key, true)
    if action == swapAction then
        Click("SwapKey")
    else
        lastAction = actionBar[action]
    end
end

nativeBindings.T = actionBarSlot
local allowOverride, passThrough = addon.GetBindingOptions()
assert(allowOverride == false and passThrough == false)
assert(not addon.SetBinding("T"))
assert(addon.GetBinding() == "SHIFT-F6" and GetBindingAction("T", true) == actionBarSlot)

assert(addon.SetBindingOptions(true, false))
allowOverride, passThrough = addon.GetBindingOptions()
assert(allowOverride == true and passThrough == false)
assert(not addon.SetBinding("F5") and GetBindingAction("F5", true) == "OPENALLBAGS")

local foreignOwner = widget()
SetOverrideBindingClick(foreignOwner, true, "T", "OtherAddonButton", "LeftButton")
assert(not addon.SetBinding("T"))
assert(GetBindingAction("T", true) == "CLICK OtherAddonButton:LeftButton")
assert(GetBindingAction("T") == actionBarSlot)
ClearOverrideBindings(foreignOwner)

assert(addon.SetBinding("T"))
assert(addon.GetBinding() == "T" and GetBindingAction("T", true) == swapAction)
assert(GetBindingAction("T") == actionBarSlot)
assert(GetBindingAction("SHIFT-F6", true) == "")

enterCombat()
assert(not addon.SetBindingOptions(true, true))
assert(not setup.overrideActionBar.enabled and not setup.passThrough.enabled)
assert(GetBindingAction("T", true) == swapAction)
PressKey("T")
assert(status.text == "Damage" and lastAction == nil)
leaveCombat()

-- Enabling pass-through in setup releases only the addon override.
addon.RefreshSetup()
assert(setup.overrideActionBar:GetChecked() and not setup.passThrough:GetChecked())
assert(setup.bindingLabel:GetText() == "Swap key: T")
setup.passThrough:SetChecked(true)
setup.passThrough:Fire("OnClick")
allowOverride, passThrough = addon.GetBindingOptions()
assert(allowOverride == true and passThrough == true)
assert(not addon.IsBindingActive() and setup.bindingLabel:GetText() == "Saved key: T")
assert(addon.GetBinding() == "T" and GetBindingAction("T", true) == actionBarSlot)

enterCombat()
assert(not addon.SetBindingOptions(true, false))
PressKey("T")
assert(lastAction == "Druid action" and status.text == "Damage")
leaveCombat()
event("PLAYER_ENTERING_WORLD")
assert(GetBindingAction("T", true) == actionBarSlot)

assert(addon.SetBindingOptions(true, false))
assert(addon.IsBindingActive())
assert(GetBindingAction("T") == actionBarSlot and GetBindingAction("T", true) == swapAction)
PressKey("T")
assert(status.text == "Healing")

-- Revoking permission keeps the saved key and hands T back to WoW.
assert(addon.SetBindingOptions(false, false))
assert(not addon.IsBindingActive() and addon.GetBinding() == "T")
addon.RefreshSetup()
assert(setup.bindingLabel:GetText() == "Saved key: T (inactive)")
assert(GetBindingAction("T", true) == actionBarSlot)
lastAction = nil
PressKey("T")
assert(lastAction == "Druid action" and status.text == "Healing")

-- Changing modes must respect an override acquired by another addon in the meantime.
SetOverrideBindingClick(foreignOwner, true, "T", "OtherAddonButton", "LeftButton")
assert(addon.SetBindingOptions(true, false))
assert(not addon.IsBindingActive() and addon.GetBinding() == "T")
assert(GetBindingAction("T", true) == "CLICK OtherAddonButton:LeftButton")
ClearOverrideBindings(foreignOwner)
event("PLAYER_ENTERING_WORLD")
assert(addon.IsBindingActive() and GetBindingAction("T", true) == swapAction)

-- A new character loads a separate saved profile and the same native action bar binding.
ClearOverrideBindings(toggle)
actionBar[actionBarSlot] = "Polymorph"
FeralWeaponSwapDB = {sets = {}}
local mage = {RefreshSetup = function() end}
frames.first = nil
assert(loadfile("simple_weapon_swap/simple_weapon_swap.lua"))("simple_weapon_swap", mage)
events = frames.first
event("ADDON_LOADED", "simple_weapon_swap")
event("PLAYER_ENTERING_WORLD")
allowOverride, passThrough = mage.GetBindingOptions()
assert(allowOverride == false and passThrough == false)
assert(mage.GetBinding() == nil and GetBindingAction("T", true) == actionBarSlot)
PressKey("T")
assert(lastAction == "Polymorph")
assert(GetBindingAction("F5", true) == "OPENALLBAGS")

print("Lua 5.1 smoke checks passed")
