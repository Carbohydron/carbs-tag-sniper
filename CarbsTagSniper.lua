local ADDON_NAME = ...

local MACRO_NAME = "CTSnipe"
local MACRO_ICON = "INV_MISC_QUESTIONMARK" -- lets #showtooltip pick the spell's icon
local MACRO_MAX_CHARS = 255
local DEFAULT_MARK = 7

-- Instant (or near-instant) ranged abilities that put a mob in combat with you.
-- The first one the character knows wins; /cts spell overrides this.
local CLASS_SPELLS = {
    WARRIOR     = { "Heroic Throw", "Charge", "Taunt" },
    PALADIN     = { "Judgment", "Hand of Reckoning", "Avenger's Shield" },
    HUNTER      = { "Arcane Shot", "Concussive Shot", "Steady Shot", "Auto Shot" },
    ROGUE       = { "Shuriken Toss", "Throw", "Shoot" },
    PRIEST      = { "Shadow Word: Pain", "Penance", "Holy Fire", "Smite" },
    DEATHKNIGHT = { "Death Coil", "Howling Blast", "Icy Touch", "Death Grip", "Dark Command" },
    SHAMAN      = { "Flame Shock", "Earth Shock", "Frost Shock", "Lightning Bolt" },
    MAGE        = { "Fire Blast", "Ice Lance", "Frostbolt" },
    WARLOCK     = { "Corruption", "Shadowburn", "Shadow Bolt" },
    MONK        = { "Provoke", "Crackling Jade Lightning" },
    DRUID       = { "Moonfire", "Sunfire", "Wrath" },
    DEMONHUNTER = { "Throw Glaive", "Torment" },
    EVOKER      = { "Azure Strike", "Living Flame" },
}

local defaults = {
    target = nil,   -- mob name to snipe
    spell = nil,    -- manual spell override; nil means use the class table
    mark = DEFAULT_MARK, -- raid marker index 1-8, or 0 for none
    quiet = true,   -- mute error speech and clear the red error text while casting
}

local db
local pendingUpdate = false

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99CarbsTagSniper|r: " .. msg)
end

local function SpellKnown(name)
    if not (C_Spell and C_Spell.GetSpellInfo) then return nil end
    local ok, info = pcall(C_Spell.GetSpellInfo, name)
    if not ok or not info or not info.spellID then return nil end
    local id = info.spellID
    local known
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        known = C_SpellBook.IsSpellKnown(id)
    end
    if not known and IsPlayerSpell then
        known = IsPlayerSpell(id)
    end
    if known then return info.name end
    return nil
end

local function DefaultSpell()
    local _, class = UnitClass("player")
    for _, name in ipairs(CLASS_SPELLS[class] or {}) do
        local known = SpellKnown(name)
        if known then return known end
    end
    return nil
end

local function CurrentSpell()
    return db.spell or DefaultSpell()
end

local function GetCV(name)
    if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
    return GetCVar(name)
end

local function SetCV(name, value)
    if C_CVar and C_CVar.SetCVar then return C_CVar.SetCVar(name, value) end
    return SetCVar(name, value)
end

-- The player's error speech setting, captured at load so CTSPost can restore it.
local speechPref = "1"

-- Called on the macro's last line. /run code is tainted on Forever, so it
-- must only touch unprotected things (CVars, the error frame).
function CTSPost()
    if not db or not db.quiet then return end
    SetCV("Sound_EnableErrorSpeech", speechPref)
    UIErrorsFrame:Clear()
end

-- Builds the macro text. Optional lines are dropped
-- (#showtooltip first, then the raid mark) if long names pass the 255 char cap.
local function BuildBody(target, spell)
    local function lines(withTooltip, withMark)
        local out = {}
        if withTooltip then out[#out + 1] = "#showtooltip" end
        -- Clear first so a stale target can never be hit when the mob is not up.
        out[#out + 1] = "/cleartarget"
        out[#out + 1] = "/targetexact " .. target
        out[#out + 1] = "/stopmacro [noexists][dead]"
        if withMark and db.mark and db.mark > 0 then
            -- /run is force-tainted on Forever (no loadstring_untainted), so the
            -- protected SetRaidTarget must go through the secure /tm command.
            out[#out + 1] = "/tm " .. db.mark
        end
        if db.quiet then out[#out + 1] = "/console Sound_EnableErrorSpeech 0" end
        if spell then out[#out + 1] = "/cast " .. spell end
        out[#out + 1] = "/startattack"
        if db.quiet then out[#out + 1] = "/run CTSPost()" end
        return table.concat(out, "\n")
    end

    local body = lines(true, true)
    if #body > MACRO_MAX_CHARS then body = lines(false, true) end
    if #body > MACRO_MAX_CHARS then
        body = lines(false, false)
        if #body <= MACRO_MAX_CHARS and db.mark and db.mark > 0 then
            Print("names are long, so the raid mark line was left out of the macro.")
        end
    end
    if #body > MACRO_MAX_CHARS then return nil end
    return body
end

local function UpdateMacro(verbose)
    if not db.target then
        if verbose then Print("no mob set. Use /cts target <mob name> (or target it and type /cts target).") end
        return
    end
    if InCombatLockdown() then
        pendingUpdate = true
        if verbose then Print("in combat; the macro will update when combat ends.") end
        return
    end
    pendingUpdate = false

    local spell = CurrentSpell()
    local body = BuildBody(db.target, spell)
    if not body then
        Print("mob and spell names are too long to fit in a macro (255 characters).")
        return
    end

    local index = GetMacroIndexByName(MACRO_NAME)
    if index and index > 0 then
        local _, _, oldBody = GetMacroInfo(index)
        if oldBody == body then
            if verbose then Print("macro " .. MACRO_NAME .. " is already up to date.") end
            return
        end
        local ok, err = pcall(EditMacro, index, MACRO_NAME, MACRO_ICON, body)
        if not ok then Print("could not edit macro: " .. tostring(err)) return end
        if verbose then Print("updated macro " .. MACRO_NAME .. ".") end
    else
        local ok, result = pcall(CreateMacro, MACRO_NAME, MACRO_ICON, body, true)
        if not ok or not result then
            Print("could not create macro (character macro slots may be full): " .. tostring(result))
            return
        end
        Print("created character macro " .. MACRO_NAME .. ". Drag it from /macro to a bar or bind it.")
    end
    if not spell then
        Print("no tagging spell found for your class; the macro only targets. Set one with /cts spell <name>.")
    end
end

local function Status()
    Print(("mob: %s | spell: %s%s | mark: %s | quiet: %s"):format(
        db.target or "|cffff6060not set|r",
        CurrentSpell() or "|cffff6060none|r",
        db.spell and " (manual)" or " (class default)",
        (db.mark and db.mark > 0) and tostring(db.mark) or "off",
        db.quiet and "on" or "off"))
end

local function Help()
    Print("commands:")
    Print("  /cts target <mob name>  set the mob to snipe (no name = your current target)")
    Print("  /cts spell <spell name> set the tag spell (/cts spell reset = class default)")
    Print("  /cts mark <1-8|off>     raid marker to put on the mob")
    Print("  /cts quiet <on|off>     mute error speech/text while spamming")
    Print("  /cts update             rebuild the macro now")
    Print("  /cts show               print the macro text")
    Status()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("SPELLS_CHANGED")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        CarbsTagSniperDB = CarbsTagSniperDB or {}
        db = CarbsTagSniperDB
        for k, v in pairs(defaults) do
            if db[k] == nil then db[k] = v end
        end
        speechPref = GetCV("Sound_EnableErrorSpeech") or "1"
        self:UnregisterEvent("ADDON_LOADED")
    elseif not db then
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingUpdate then UpdateMacro(false) end
    else
        -- Login, zoning, or learning a spell can change the class default spell.
        UpdateMacro(false)
    end
end)

SLASH_CARBSTAGSNIPER1 = "/cts"
SLASH_CARBSTAGSNIPER2 = "/carbstagsniper"
SlashCmdList["CARBSTAGSNIPER"] = function(msg)
    if not db then return end
    local cmd, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    rest = strtrim(rest)

    if cmd == "target" or cmd == "mob" then
        if rest == "" then
            rest = UnitExists("target") and UnitName("target") or ""
            if rest == "" then Print("target the mob first, or use /cts target <mob name>.") return end
        end
        db.target = rest
        Print("sniping " .. rest .. ".")
        UpdateMacro(true)
    elseif cmd == "spell" then
        if rest == "" then
            Print("spell: " .. (CurrentSpell() or "none"))
        elseif rest:lower() == "reset" or rest:lower() == "default" then
            db.spell = nil
            Print("using class default: " .. (DefaultSpell() or "none found"))
            UpdateMacro(true)
        else
            db.spell = SpellKnown(rest) or rest
            if not SpellKnown(rest) then Print("note: " .. rest .. " does not look like a spell you know; using it anyway.") end
            UpdateMacro(true)
        end
    elseif cmd == "mark" then
        local n = tonumber(rest)
        if rest:lower() == "off" or n == 0 then
            db.mark = 0
        elseif n and n >= 1 and n <= 8 then
            db.mark = math.floor(n)
        else
            Print("usage: /cts mark <1-8|off> (1 star, 2 circle, 3 diamond, 4 triangle, 5 moon, 6 square, 7 cross, 8 skull)")
            return
        end
        Print("raid mark " .. (db.mark > 0 and tostring(db.mark) or "off") .. ".")
        UpdateMacro(true)
    elseif cmd == "quiet" then
        if rest:lower() == "on" then db.quiet = true
        elseif rest:lower() == "off" then db.quiet = false
        else db.quiet = not db.quiet end
        Print("quiet " .. (db.quiet and "on" or "off") .. ".")
        UpdateMacro(true)
    elseif cmd == "update" then
        UpdateMacro(true)
    elseif cmd == "show" then
        local index = GetMacroIndexByName(MACRO_NAME)
        if index and index > 0 then
            local _, _, body = GetMacroInfo(index)
            Print(MACRO_NAME .. ":")
            for line in (body or ""):gmatch("[^\n]+") do DEFAULT_CHAT_FRAME:AddMessage("  " .. line) end
        else
            Print("macro not created yet.")
        end
    else
        Help()
    end
end
