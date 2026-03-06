local _, NS = ...

local Data = {}
NS.Data = Data

------------------------------------------------------------------------
-- Throttle for UPDATE_FACTION
------------------------------------------------------------------------
local scanPending = false
local THROTTLE_INTERVAL = 1

------------------------------------------------------------------------
-- ScanReputations — main scan function
------------------------------------------------------------------------
function Data:ScanReputations()
    if not NS.db then return end

    local playerKey = NS.GetPlayerKey()
    local _, englishClass = UnitClass("player")
    local level = UnitLevel("player")
    local faction = UnitFactionGroup("player")

    -- 1. Save expanded/collapsed state of each header
    local headerState = {}
    local numFactions = GetNumFactions()
    for i = 1, numFactions do
        local name, _, _, _, _, _, _, _, isHeader, isCollapsed = GetFactionInfo(i)
        if isHeader then
            headerState[name] = isCollapsed
        end
    end

    -- 2. Expand ALL collapsed headers so we can see all child factions
    local changed = true
    while changed do
        changed = false
        numFactions = GetNumFactions()
        for i = numFactions, 1, -1 do
            local _, _, _, _, _, _, _, _, isHeader, isCollapsed = GetFactionInfo(i)
            if isHeader and isCollapsed then
                ExpandFactionHeader(i)
                changed = true
            end
        end
    end

    -- 3. Iterate all factions and collect reputation data
    local reputations = {}
    local currentHeader = "Other"
    numFactions = GetNumFactions()

    for i = 1, numFactions do
        local name, _, standingID, barMin, barMax, barValue, _, _, isHeader, _, _, _, _, factionID = GetFactionInfo(i)

        if isHeader then
            currentHeader = name
        else
            if name and standingID then
                reputations[name] = {
                    name       = name,
                    header     = currentHeader,
                    standingID = standingID,
                    barMin     = barMin,
                    barMax     = barMax,
                    barValue   = barValue,
                    factionID  = factionID,
                }
            end
        end
    end

    -- 4. Restore original header collapsed state
    -- First collapse everything, then re-expand what was expanded
    numFactions = GetNumFactions()
    for i = numFactions, 1, -1 do
        local name, _, _, _, _, _, _, _, isHeader = GetFactionInfo(i)
        if isHeader then
            if headerState[name] then
                CollapseFactionHeader(i)
            end
        end
    end

    -- 5. Store data
    NS.db.characters[playerKey] = {
        name        = UnitName("player"),
        class       = englishClass,
        level       = level,
        faction     = faction,
        lastUpdate  = time(),
        reputations = reputations,
    }

    -- 6. Fire update
    NS:FireCallback("DATA_UPDATED")
end

------------------------------------------------------------------------
-- GetAllReputationNames — collect all unique reputation names across chars
------------------------------------------------------------------------
function Data:GetAllReputationNames()
    local seen = {}
    local list = {}

    for _, charData in pairs(NS.db.characters or {}) do
        if charData.reputations then
            for repName, repInfo in pairs(charData.reputations) do
                if not seen[repName] then
                    seen[repName] = true
                    table.insert(list, { name = repName, header = repInfo.header })
                end
            end
        end
    end

    -- Sort by header then by name
    table.sort(list, function(a, b)
        if a.header ~= b.header then
            return a.header < b.header
        end
        return a.name < b.name
    end)

    return list
end

------------------------------------------------------------------------
-- GetGroupedReputations — group by faction across all characters
------------------------------------------------------------------------
function Data:GetGroupedReputations(filterText, filterStanding, filterReputations)
    filterText = (filterText or ""):lower()
    filterStanding = filterStanding or 0
    filterReputations = filterReputations or {}

    -- Check if reputation name filter is active
    local hasRepFilter = next(filterReputations) ~= nil

    -- Build a table keyed by reputation name
    local repMap = {} -- repName → { name, header, characters = { ... } }

    for charKey, charData in pairs(NS.db.characters or {}) do
        if charData.reputations then
            for repName, repInfo in pairs(charData.reputations) do
                -- Text filter: match reputation name
                local passText = (filterText == "") or repName:lower():find(filterText, 1, true)

                -- Reputation name filter
                local passRep = (not hasRepFilter) or filterReputations[repName]

                if passText and passRep then
                    -- Standing filter: check if this character has the required standing
                    local passStanding = (filterStanding == 0) or (repInfo.standingID == filterStanding)

                    if passStanding then
                        if not repMap[repName] then
                            repMap[repName] = {
                                name   = repName,
                                header = repInfo.header,
                                characters = {},
                            }
                        end

                        table.insert(repMap[repName].characters, {
                            key        = charKey,
                            name       = charData.name,
                            class      = charData.class,
                            level      = charData.level,
                            faction    = charData.faction,
                            standingID = repInfo.standingID,
                            barMin     = repInfo.barMin,
                            barMax     = repInfo.barMax,
                            barValue   = repInfo.barValue,
                        })
                    end
                end
            end
        end
    end

    -- Convert to sorted list
    local result = {}
    for _, repData in pairs(repMap) do
        -- Sort characters: by standingID desc, then by name asc
        table.sort(repData.characters, function(a, b)
            if a.standingID ~= b.standingID then
                return a.standingID > b.standingID
            end
            return a.name < b.name
        end)
        table.insert(result, repData)
    end

    -- Sort reputations: by header then by name
    table.sort(result, function(a, b)
        if a.header ~= b.header then
            return a.header < b.header
        end
        return a.name < b.name
    end)

    return result
end

------------------------------------------------------------------------
-- WoW events
------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UPDATE_FACTION")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Delay initial scan to let UI fully load
        C_Timer.After(2, function()
            Data:ScanReputations()
        end)
    elseif event == "UPDATE_FACTION" then
        -- Throttled re-scan
        if not scanPending then
            scanPending = true
            C_Timer.After(THROTTLE_INTERVAL, function()
                scanPending = false
                Data:ScanReputations()
            end)
        end
    end
end)
