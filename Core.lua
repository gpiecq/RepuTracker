local ADDON_NAME, NS = ...

------------------------------------------------------------------------
-- Version
------------------------------------------------------------------------
NS.VERSION = "1.0.0"

------------------------------------------------------------------------
-- Standing labels (multi-language)
------------------------------------------------------------------------
NS.STANDING_LABELS = {
    [1] = { enUS = "Hated",      frFR = "Hai",       deDE = "Hasserfuellt", esES = "Odiado"    },
    [2] = { enUS = "Hostile",    frFR = "Hostile",   deDE = "Feindselig",   esES = "Hostil"    },
    [3] = { enUS = "Unfriendly", frFR = "Inamical",  deDE = "Unfreundlich", esES = "Hostil"    },
    [4] = { enUS = "Neutral",    frFR = "Neutre",    deDE = "Neutral",      esES = "Neutral"   },
    [5] = { enUS = "Friendly",   frFR = "Amical",    deDE = "Freundlich",   esES = "Amistoso"  },
    [6] = { enUS = "Honored",    frFR = "Honore",    deDE = "Wohlwollend",  esES = "Honorable" },
    [7] = { enUS = "Revered",    frFR = "Revere",    deDE = "Respektiert",  esES = "Reverenciado" },
    [8] = { enUS = "Exalted",    frFR = "Exalte",    deDE = "Ehrfuerchtig", esES = "Exaltado"  },
}

------------------------------------------------------------------------
-- Standing colors (dark red → gold/purple)
------------------------------------------------------------------------
NS.STANDING_COLORS = {
    [1] = { 0.80, 0.13, 0.13 }, -- Hated — dark red
    [2] = { 0.90, 0.30, 0.20 }, -- Hostile — red-orange
    [3] = { 0.90, 0.55, 0.20 }, -- Unfriendly — orange
    [4] = { 0.90, 0.90, 0.00 }, -- Neutral — yellow
    [5] = { 0.00, 0.70, 0.00 }, -- Friendly — green
    [6] = { 0.00, 0.60, 0.75 }, -- Honored — teal
    [7] = { 0.00, 0.45, 0.95 }, -- Revered — blue
    [8] = { 0.60, 0.20, 0.90 }, -- Exalted — purple
}

------------------------------------------------------------------------
-- Class colors (standard WoW class colors)
------------------------------------------------------------------------
NS.CLASS_COLORS = {
    WARRIOR     = { 0.78, 0.61, 0.43 },
    PALADIN     = { 0.96, 0.55, 0.73 },
    HUNTER      = { 0.67, 0.83, 0.45 },
    ROGUE       = { 1.00, 0.96, 0.41 },
    PRIEST      = { 1.00, 1.00, 1.00 },
    SHAMAN      = { 0.00, 0.44, 0.87 },
    MAGE        = { 0.25, 0.78, 0.92 },
    WARLOCK     = { 0.53, 0.53, 0.93 },
    DRUID       = { 1.00, 0.49, 0.04 },
}

------------------------------------------------------------------------
-- Utilities
------------------------------------------------------------------------
function NS.DeepCopy(src)
    if type(src) ~= "table" then return src end
    local copy = {}
    for k, v in pairs(src) do
        copy[NS.DeepCopy(k)] = NS.DeepCopy(v)
    end
    return copy
end

function NS.MergeDefaults(sv, def)
    if type(def) ~= "table" then return sv end
    if type(sv) ~= "table" then return NS.DeepCopy(def) end
    for k, v in pairs(def) do
        if sv[k] == nil then
            sv[k] = NS.DeepCopy(v)
        elseif type(v) == "table" and type(sv[k]) == "table" then
            NS.MergeDefaults(sv[k], v)
        end
    end
    return sv
end

function NS.GetPlayerKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    return name .. "-" .. realm
end

------------------------------------------------------------------------
-- Get localized standing label
------------------------------------------------------------------------
function NS.GetStandingLabel(standingID)
    local entry = NS.STANDING_LABELS[standingID]
    if not entry then return "?" end
    local locale = GetLocale()
    return entry[locale] or entry.enUS
end

------------------------------------------------------------------------
-- Event bus
------------------------------------------------------------------------
local callbacks = {}

function NS:RegisterCallback(event, fn)
    if not callbacks[event] then
        callbacks[event] = {}
    end
    table.insert(callbacks[event], fn)
end

function NS:FireCallback(event, ...)
    if not callbacks[event] then return end
    for _, fn in ipairs(callbacks[event]) do
        fn(...)
    end
end

------------------------------------------------------------------------
-- SavedVariables defaults
------------------------------------------------------------------------
local DEFAULTS = {
    characters = {},
    settings = {
        minimapPos = 220,
        filterStanding = 0, -- 0 = all
        filterText = "",
        filterReputations = {}, -- empty = show all; keys = selected rep names
    },
}

------------------------------------------------------------------------
-- Init frame
------------------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(_, event, addon)
    if addon ~= ADDON_NAME then return end
    initFrame:UnregisterEvent("ADDON_LOADED")

    -- Init or merge saved variables
    if not RepuTrackerDB then
        RepuTrackerDB = NS.DeepCopy(DEFAULTS)
    else
        NS.MergeDefaults(RepuTrackerDB, DEFAULTS)
    end
    NS.db = RepuTrackerDB

    NS:FireCallback("ADDON_LOADED")
end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
SLASH_REPUTRACKER1 = "/rt"
SLASH_REPUTRACKER2 = "/reputracker"

SlashCmdList["REPUTRACKER"] = function(msg)
    msg = (msg or ""):trim():lower()

    if msg == "reset" then
        StaticPopupDialogs["REPUTRACKER_RESET"] = {
            text = "Reset ALL RepuTracker data? This cannot be undone.",
            button1 = "Yes",
            button2 = "No",
            OnAccept = function()
                RepuTrackerDB = NS.DeepCopy(DEFAULTS)
                NS.db = RepuTrackerDB
                NS:FireCallback("DATA_UPDATED")
                print("|cff00ccffRepuTracker|r: Data has been reset.")
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
        StaticPopup_Show("REPUTRACKER_RESET")
        return
    end

    -- Default: toggle window
    NS:FireCallback("TOGGLE_WINDOW")
end
