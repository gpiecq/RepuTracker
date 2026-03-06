local _, NS = ...

local UI = {}
NS.UI = UI

------------------------------------------------------------------------
-- A. Visual constants
------------------------------------------------------------------------
local COLOURS = {
    bg       = { 0.06, 0.06, 0.06, 0.95 },
    border   = { 0.30, 0.30, 0.30, 1 },
    accent   = { 0.00, 0.80, 1.00, 1 },
    headerBg = { 0.12, 0.12, 0.12, 1 },
    rowHover = { 0.20, 0.20, 0.20, 0.50 },
    dimWhite = { 0.60, 0.60, 0.60, 1 },
    barBg    = { 0.15, 0.15, 0.15, 1 },
}

local WINDOW_WIDTH  = 520
local WINDOW_HEIGHT = 500
local HEADER_HEIGHT = 30
local FILTER_HEIGHT = 65
local ROW_HEIGHT    = 28
local SECTION_HEIGHT = 25

------------------------------------------------------------------------
-- B. ElvUI compatibility
------------------------------------------------------------------------
local function IsElvUI()
    return ElvUI and ElvUI[1] and true or false
end

local function SkinFrame(f)
    if not IsElvUI() then return end
    local E = ElvUI[1]
    local S = E and E:GetModule("Skins", true)
    if S and S.HandleFrame then
        S:HandleFrame(f)
    end
end

local function GetFont()
    if IsElvUI() then
        local E = ElvUI[1]
        local LSM = E and E.Libs and E.Libs.LSM
        if LSM then
            local font = LSM:Fetch("font", E.db and E.db.general and E.db.general.font)
            if font then return font end
        end
    end
    return "Fonts\\FRIZQT__.TTF"
end

------------------------------------------------------------------------
-- C. Minimap button
------------------------------------------------------------------------
local minimapButton

local function CreateMinimapButton()
    if minimapButton then return end

    local btn = CreateFrame("Button", "RepuTrackerMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)

    -- Background circle
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(24, 24)
    bg:SetPoint("CENTER")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetVertexColor(0, 0, 0, 0.6)

    -- Icon
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Border overlay
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(56, 56)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- Position on minimap edge
    local function UpdatePosition(angle)
        local rad = math.rad(angle)
        local x = math.cos(rad) * 80
        local y = math.sin(rad) * 80
        btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    -- Dragging
    local isDragging = false
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function()
        isDragging = true
    end)
    btn:SetScript("OnDragStop", function()
        isDragging = false
        -- Calculate angle from minimap center
        local mx, my = Minimap:GetCenter()
        local bx, by = btn:GetCenter()
        local angle = math.deg(math.atan2(by - my, bx - mx))
        NS.db.settings.minimapPos = angle
    end)
    btn:SetScript("OnUpdate", function()
        if not isDragging then return end
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = math.deg(math.atan2(cy - my, cx - mx))
        UpdatePosition(angle)
    end)

    -- Click
    btn:SetScript("OnClick", function()
        NS:FireCallback("TOGGLE_WINDOW")
    end)

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("RepuTracker", COLOURS.accent[1], COLOURS.accent[2], COLOURS.accent[3])
        GameTooltip:AddLine("Left-click to toggle", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdatePosition(NS.db.settings.minimapPos or 220)
    minimapButton = btn
end

------------------------------------------------------------------------
-- D. Main window
------------------------------------------------------------------------
local mainFrame
local scrollChild
local headerPool = {}
local rowPool = {}
local headerPoolCount = 0
local rowPoolCount = 0

local function CreateMainWindow()
    if mainFrame then return end

    local font = GetFont()

    -- Main frame
    local f = CreateFrame("Frame", "RepuTrackerMainFrame", UIParent, "BackdropTemplate")
    f:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)

    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(unpack(COLOURS.bg))
    f:SetBackdropBorderColor(unpack(COLOURS.border))

    SkinFrame(f)

    -- ESC to close
    table.insert(UISpecialFrames, "RepuTrackerMainFrame")

    -- Draggable via header area
    local dragHeader = CreateFrame("Frame", nil, f)
    dragHeader:SetPoint("TOPLEFT", 0, 0)
    dragHeader:SetPoint("TOPRIGHT", -30, 0)
    dragHeader:SetHeight(HEADER_HEIGHT)
    dragHeader:EnableMouse(true)
    dragHeader:RegisterForDrag("LeftButton")
    dragHeader:SetScript("OnDragStart", function() f:StartMoving() end)
    dragHeader:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

    -- Header background
    local headerBg = f:CreateTexture(nil, "ARTWORK")
    headerBg:SetPoint("TOPLEFT", 0, 0)
    headerBg:SetPoint("TOPRIGHT", 0, 0)
    headerBg:SetHeight(HEADER_HEIGHT)
    headerBg:SetColorTexture(unpack(COLOURS.headerBg))

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont(font, 13, "OUTLINE")
    title:SetPoint("LEFT", headerBg, "LEFT", 10, 0)
    title:SetText("RepuTracker")
    title:SetTextColor(unpack(COLOURS.accent))

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetSize(24, 24)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    --------------------------------------------------------------------------
    -- E. Filter bar
    --------------------------------------------------------------------------
    local filterBar = CreateFrame("Frame", nil, f)
    filterBar:SetPoint("TOPLEFT", 0, -HEADER_HEIGHT)
    filterBar:SetPoint("TOPRIGHT", 0, -HEADER_HEIGHT)
    filterBar:SetHeight(FILTER_HEIGHT)

    local filterBarBg = filterBar:CreateTexture(nil, "BACKGROUND")
    filterBarBg:SetAllPoints()
    filterBarBg:SetColorTexture(0.08, 0.08, 0.08, 1)

    -- Search EditBox
    local searchBox = CreateFrame("EditBox", "RepuTrackerSearchBox", filterBar, "BackdropTemplate")
    searchBox:SetSize(280, 22)
    searchBox:SetPoint("TOPLEFT", 8, -5)
    searchBox:SetFont(font, 12, "")
    searchBox:SetTextColor(1, 1, 1)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(50)

    searchBox:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    searchBox:SetBackdropColor(0.10, 0.10, 0.10, 1)
    searchBox:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    searchBox:SetTextInsets(6, 6, 0, 0)

    -- Placeholder text
    local placeholder = searchBox:CreateFontString(nil, "ARTWORK")
    placeholder:SetFont(font, 12, "")
    placeholder:SetPoint("LEFT", 6, 0)
    placeholder:SetText("Search...")
    placeholder:SetTextColor(0.4, 0.4, 0.4, 1)

    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        placeholder:SetShown(text == "")
        NS.db.settings.filterText = text
        NS:FireCallback("FILTER_CHANGED")
    end)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- Standing dropdown button
    local dropdownBtn = CreateFrame("Button", nil, filterBar, "BackdropTemplate")
    dropdownBtn:SetSize(180, 22)
    dropdownBtn:SetPoint("LEFT", searchBox, "RIGHT", 8, 0)
    dropdownBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dropdownBtn:SetBackdropColor(0.10, 0.10, 0.10, 1)
    dropdownBtn:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

    local dropdownLabel = dropdownBtn:CreateFontString(nil, "OVERLAY")
    dropdownLabel:SetFont(font, 11, "")
    dropdownLabel:SetPoint("LEFT", 8, 0)
    dropdownLabel:SetTextColor(1, 1, 1)

    local dropdownArrow = dropdownBtn:CreateFontString(nil, "OVERLAY")
    dropdownArrow:SetFont(font, 11, "")
    dropdownArrow:SetPoint("RIGHT", -6, 0)
    dropdownArrow:SetText("v")
    dropdownArrow:SetTextColor(unpack(COLOURS.dimWhite))

    -- Dropdown menu (custom, hidden by default)
    local dropdownMenu = CreateFrame("Frame", nil, dropdownBtn, "BackdropTemplate")
    dropdownMenu:SetFrameStrata("DIALOG")
    dropdownMenu:SetPoint("TOPLEFT", dropdownBtn, "BOTTOMLEFT", 0, -2)
    dropdownMenu:SetSize(180, 10) -- height set dynamically
    dropdownMenu:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dropdownMenu:SetBackdropColor(0.08, 0.08, 0.08, 0.98)
    dropdownMenu:SetBackdropBorderColor(unpack(COLOURS.border))
    dropdownMenu:Hide()

    -- Click-outside overlay to close dropdown
    local clickOutside = CreateFrame("Button", nil, UIParent)
    clickOutside:SetAllPoints(UIParent)
    clickOutside:SetFrameStrata("DIALOG")
    clickOutside:SetFrameLevel(dropdownMenu:GetFrameLevel() - 1)
    clickOutside:Hide()
    clickOutside:SetScript("OnClick", function()
        dropdownMenu:Hide()
        clickOutside:Hide()
    end)

    -- Dropdown options
    local standingOptions = {
        { id = 0, label = "All" },
        { id = 1, label = NS.GetStandingLabel(1) },
        { id = 2, label = NS.GetStandingLabel(2) },
        { id = 3, label = NS.GetStandingLabel(3) },
        { id = 4, label = NS.GetStandingLabel(4) },
        { id = 5, label = NS.GetStandingLabel(5) },
        { id = 6, label = NS.GetStandingLabel(6) },
        { id = 7, label = NS.GetStandingLabel(7) },
        { id = 8, label = NS.GetStandingLabel(8) },
    }

    local menuButtons = {}
    for idx, opt in ipairs(standingOptions) do
        local mb = CreateFrame("Button", nil, dropdownMenu)
        mb:SetSize(176, 20)
        mb:SetPoint("TOPLEFT", 2, -2 - (idx - 1) * 20)

        local mbText = mb:CreateFontString(nil, "OVERLAY")
        mbText:SetFont(font, 11, "")
        mbText:SetPoint("LEFT", 6, 0)
        mbText:SetText(opt.label)

        if opt.id > 0 then
            local c = NS.STANDING_COLORS[opt.id]
            mbText:SetTextColor(c[1], c[2], c[3])
        else
            mbText:SetTextColor(1, 1, 1)
        end

        -- Hover highlight
        local mbHighlight = mb:CreateTexture(nil, "BACKGROUND")
        mbHighlight:SetAllPoints()
        mbHighlight:SetColorTexture(unpack(COLOURS.rowHover))
        mbHighlight:Hide()
        mb:SetScript("OnEnter", function() mbHighlight:Show() end)
        mb:SetScript("OnLeave", function() mbHighlight:Hide() end)

        mb:SetScript("OnClick", function()
            NS.db.settings.filterStanding = opt.id
            dropdownMenu:Hide()
            clickOutside:Hide()
            UI:UpdateDropdownLabel()
            NS:FireCallback("FILTER_CHANGED")
        end)

        menuButtons[idx] = mb
    end
    dropdownMenu:SetHeight(4 + #standingOptions * 20)

    dropdownBtn:SetScript("OnClick", function()
        if dropdownMenu:IsShown() then
            dropdownMenu:Hide()
            clickOutside:Hide()
        else
            dropdownMenu:Show()
            clickOutside:Show()
        end
    end)

    function UI:UpdateDropdownLabel()
        local standing = NS.db.settings.filterStanding or 0
        if standing == 0 then
            dropdownLabel:SetText("All standings")
            dropdownLabel:SetTextColor(1, 1, 1)
        else
            dropdownLabel:SetText(NS.GetStandingLabel(standing))
            local c = NS.STANDING_COLORS[standing]
            dropdownLabel:SetTextColor(c[1], c[2], c[3])
        end
    end

    --------------------------------------------------------------------------
    -- E2. Reputation multi-select dropdown (line 2 of filter bar)
    --------------------------------------------------------------------------
    local repDropBtn = CreateFrame("Button", nil, filterBar, "BackdropTemplate")
    repDropBtn:SetSize(WINDOW_WIDTH - 16, 22)
    repDropBtn:SetPoint("TOPLEFT", 8, -30)
    repDropBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    repDropBtn:SetBackdropColor(0.10, 0.10, 0.10, 1)
    repDropBtn:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

    local repDropLabel = repDropBtn:CreateFontString(nil, "OVERLAY")
    repDropLabel:SetFont(font, 11, "")
    repDropLabel:SetPoint("LEFT", 8, 0)
    repDropLabel:SetTextColor(1, 1, 1)

    local repDropArrow = repDropBtn:CreateFontString(nil, "OVERLAY")
    repDropArrow:SetFont(font, 11, "")
    repDropArrow:SetPoint("RIGHT", -6, 0)
    repDropArrow:SetText("v")
    repDropArrow:SetTextColor(unpack(COLOURS.dimWhite))

    -- The dropdown panel (scrollable)
    local repDropPanel = CreateFrame("Frame", nil, repDropBtn, "BackdropTemplate")
    repDropPanel:SetFrameStrata("DIALOG")
    repDropPanel:SetPoint("TOPLEFT", repDropBtn, "BOTTOMLEFT", 0, -2)
    repDropPanel:SetSize(WINDOW_WIDTH - 16, 200)
    repDropPanel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    repDropPanel:SetBackdropColor(0.08, 0.08, 0.08, 0.98)
    repDropPanel:SetBackdropBorderColor(unpack(COLOURS.border))
    repDropPanel:Hide()

    -- Click-outside overlay for reputation dropdown
    local repClickOutside = CreateFrame("Button", nil, UIParent)
    repClickOutside:SetAllPoints(UIParent)
    repClickOutside:SetFrameStrata("DIALOG")
    repClickOutside:SetFrameLevel(repDropPanel:GetFrameLevel() - 1)
    repClickOutside:Hide()
    repClickOutside:SetScript("OnClick", function()
        repDropPanel:Hide()
        repClickOutside:Hide()
    end)

    -- Clear button at top of panel
    local clearBtn = CreateFrame("Button", nil, repDropPanel, "BackdropTemplate")
    clearBtn:SetSize(WINDOW_WIDTH - 20, 20)
    clearBtn:SetPoint("TOPLEFT", 2, -2)
    clearBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    clearBtn:SetBackdropColor(0.15, 0.15, 0.15, 1)

    local clearText = clearBtn:CreateFontString(nil, "OVERLAY")
    clearText:SetFont(font, 10, "")
    clearText:SetPoint("CENTER")
    clearText:SetText("Clear selection")
    clearText:SetTextColor(unpack(COLOURS.accent))

    local clearHl = clearBtn:CreateTexture(nil, "BACKGROUND")
    clearHl:SetAllPoints()
    clearHl:SetColorTexture(unpack(COLOURS.rowHover))
    clearHl:Hide()
    clearBtn:SetScript("OnEnter", function() clearHl:Show() end)
    clearBtn:SetScript("OnLeave", function() clearHl:Hide() end)

    -- Scroll frame inside the panel (below the Clear button)
    local repScrollFrame = CreateFrame("ScrollFrame", "RepuTrackerRepFilterScroll", repDropPanel, "UIPanelScrollFrameTemplate")
    repScrollFrame:SetPoint("TOPLEFT", 2, -24)
    repScrollFrame:SetPoint("BOTTOMRIGHT", -22, 2)

    local repScrollChild = CreateFrame("Frame", nil, repScrollFrame)
    repScrollChild:SetWidth(WINDOW_WIDTH - 56)
    repScrollChild:SetHeight(1)
    repScrollFrame:SetScrollChild(repScrollChild)

    -- Pool of checkable row buttons
    local repOptionPool = {}
    local repOptionCount = 0

    local function GetOrCreateRepOption(idx)
        if repOptionPool[idx] then
            repOptionPool[idx]:Show()
            return repOptionPool[idx]
        end

        local btn = CreateFrame("Button", nil, repScrollChild)
        btn:SetSize(WINDOW_WIDTH - 56, 20)
        btn:SetPoint("TOPLEFT", 0, -(idx - 1) * 20)

        local checkText = btn:CreateFontString(nil, "OVERLAY")
        checkText:SetFont(font, 11, "")
        checkText:SetPoint("LEFT", 4, 0)
        checkText:SetWidth(24)
        checkText:SetJustifyH("LEFT")
        btn.checkText = checkText

        local nameText = btn:CreateFontString(nil, "OVERLAY")
        nameText:SetFont(font, 11, "")
        nameText:SetPoint("LEFT", 26, 0)
        nameText:SetTextColor(1, 1, 1)
        btn.nameText = nameText

        local hl = btn:CreateTexture(nil, "BACKGROUND")
        hl:SetAllPoints()
        hl:SetColorTexture(unpack(COLOURS.rowHover))
        hl:Hide()
        btn:SetScript("OnEnter", function() hl:Show() end)
        btn:SetScript("OnLeave", function() hl:Hide() end)

        repOptionPool[idx] = btn
        repOptionCount = math.max(repOptionCount, idx)
        return btn
    end

    -- Rebuild dropdown content and update label
    local function RebuildRepDropdown()
        -- Hide existing
        for i = 1, repOptionCount do
            if repOptionPool[i] then repOptionPool[i]:Hide() end
        end

        local allReps = NS.Data:GetAllReputationNames()
        local filterReps = NS.db.settings.filterReputations

        for i, entry in ipairs(allReps) do
            local opt = GetOrCreateRepOption(i)
            local selected = filterReps[entry.name] == true
            opt.checkText:SetText(selected and "|cff00cc00[x]|r" or "[ ]")
            opt.nameText:SetText(entry.name)
            opt:SetScript("OnClick", function()
                if filterReps[entry.name] then
                    filterReps[entry.name] = nil
                else
                    filterReps[entry.name] = true
                end
                -- Update visual
                local sel = filterReps[entry.name] == true
                opt.checkText:SetText(sel and "|cff00cc00[x]|r" or "[ ]")
                UI:UpdateRepDropLabel()
                NS:FireCallback("FILTER_CHANGED")
            end)
        end

        repScrollChild:SetHeight(math.max(#allReps * 20, 1))

        -- Adjust panel height: clear btn (24) + min(rows*20, 280) + padding
        local contentH = #allReps * 20
        local maxH = 280
        local panelH = 24 + math.min(contentH, maxH) + 4
        repDropPanel:SetHeight(panelH)
    end

    clearBtn:SetScript("OnClick", function()
        wipe(NS.db.settings.filterReputations)
        RebuildRepDropdown()
        UI:UpdateRepDropLabel()
        NS:FireCallback("FILTER_CHANGED")
    end)

    repDropBtn:SetScript("OnClick", function()
        if repDropPanel:IsShown() then
            repDropPanel:Hide()
            repClickOutside:Hide()
        else
            RebuildRepDropdown()
            repDropPanel:Show()
            repClickOutside:Show()
        end
    end)

    function UI:UpdateRepDropLabel()
        local count = 0
        for _ in pairs(NS.db.settings.filterReputations) do
            count = count + 1
        end
        if count == 0 then
            repDropLabel:SetText("All reputations")
            repDropLabel:SetTextColor(1, 1, 1)
        else
            repDropLabel:SetText(count .. " reputation(s) selected")
            repDropLabel:SetTextColor(unpack(COLOURS.accent))
        end
    end

    --------------------------------------------------------------------------
    -- F. Scroll area
    --------------------------------------------------------------------------
    local scrollAreaTop = HEADER_HEIGHT + FILTER_HEIGHT

    local scrollFrame = CreateFrame("ScrollFrame", "RepuTrackerScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 4, -scrollAreaTop - 4)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 4)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(WINDOW_WIDTH - 30)
    scrollChild:SetHeight(1) -- will be updated dynamically
    scrollFrame:SetScrollChild(scrollChild)

    mainFrame = f
    f:Hide()

    -- Restore search text if any
    searchBox:SetText(NS.db.settings.filterText or "")
    UI:UpdateDropdownLabel()
    UI:UpdateRepDropLabel()
end

------------------------------------------------------------------------
-- G. Widget pool helpers
------------------------------------------------------------------------
local function GetOrCreateHeaderRow(idx)
    if headerPool[idx] then
        headerPool[idx]:Show()
        return headerPool[idx]
    end

    local font = GetFont()
    local row = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
    row:SetHeight(SECTION_HEIGHT)
    row:SetPoint("LEFT", 0, 0)
    row:SetPoint("RIGHT", 0, 0)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(COLOURS.headerBg))

    local repName = row:CreateFontString(nil, "OVERLAY")
    repName:SetFont(font, 12, "OUTLINE")
    repName:SetPoint("LEFT", 8, 0)
    repName:SetTextColor(unpack(COLOURS.accent))
    row.repName = repName

    local headerLabel = row:CreateFontString(nil, "OVERLAY")
    headerLabel:SetFont(font, 10, "")
    headerLabel:SetPoint("RIGHT", -8, 0)
    headerLabel:SetTextColor(unpack(COLOURS.dimWhite))
    row.headerLabel = headerLabel

    headerPool[idx] = row
    headerPoolCount = math.max(headerPoolCount, idx)
    return row
end

local function GetOrCreateCharRow(idx)
    if rowPool[idx] then
        rowPool[idx]:Show()
        return rowPool[idx]
    end

    local font = GetFont()
    local row = CreateFrame("Frame", nil, scrollChild)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("LEFT", 0, 0)
    row:SetPoint("RIGHT", 0, 0)

    -- Hover highlight
    local hoverBg = row:CreateTexture(nil, "BACKGROUND")
    hoverBg:SetAllPoints()
    hoverBg:SetColorTexture(unpack(COLOURS.rowHover))
    hoverBg:Hide()
    row:EnableMouse(true)
    row:SetScript("OnEnter", function() hoverBg:Show() end)
    row:SetScript("OnLeave", function() hoverBg:Hide() end)

    -- Character name
    local charName = row:CreateFontString(nil, "OVERLAY")
    charName:SetFont(font, 11, "")
    charName:SetPoint("LEFT", 10, 0)
    charName:SetWidth(120)
    charName:SetJustifyH("LEFT")
    charName:SetWordWrap(false)
    row.charName = charName

    -- Level
    local charLevel = row:CreateFontString(nil, "OVERLAY")
    charLevel:SetFont(font, 10, "")
    charLevel:SetPoint("LEFT", 132, 0)
    charLevel:SetWidth(25)
    charLevel:SetJustifyH("LEFT")
    charLevel:SetTextColor(unpack(COLOURS.dimWhite))
    row.charLevel = charLevel

    -- Reputation bar background
    local barBg = row:CreateTexture(nil, "ARTWORK")
    barBg:SetPoint("LEFT", 162, 0)
    barBg:SetSize(180, 14)
    barBg:SetColorTexture(unpack(COLOURS.barBg))
    row.barBg = barBg

    -- Reputation bar fill
    local barFill = row:CreateTexture(nil, "ARTWORK", nil, 1)
    barFill:SetPoint("LEFT", barBg, "LEFT", 0, 0)
    barFill:SetHeight(14)
    row.barFill = barFill

    -- Bar text (centered on bar)
    local barText = row:CreateFontString(nil, "OVERLAY")
    barText:SetFont(font, 9, "")
    barText:SetPoint("CENTER", barBg, "CENTER", 0, 0)
    barText:SetTextColor(1, 1, 1, 0.9)
    row.barText = barText

    -- Standing label
    local standingText = row:CreateFontString(nil, "OVERLAY")
    standingText:SetFont(font, 10, "")
    standingText:SetPoint("LEFT", barBg, "RIGHT", 10, 0)
    standingText:SetWidth(80)
    standingText:SetJustifyH("LEFT")
    row.standingText = standingText

    rowPool[idx] = row
    rowPoolCount = math.max(rowPoolCount, idx)
    return row
end

------------------------------------------------------------------------
-- RefreshDisplay
------------------------------------------------------------------------
function UI:RefreshDisplay()
    if not mainFrame or not mainFrame:IsShown() then return end

    local data = NS.Data:GetGroupedReputations(
        NS.db.settings.filterText,
        NS.db.settings.filterStanding,
        NS.db.settings.filterReputations
    )

    -- Hide all existing pool frames
    for i = 1, headerPoolCount do
        if headerPool[i] then headerPool[i]:Hide() end
    end
    for i = 1, rowPoolCount do
        if rowPool[i] then rowPool[i]:Hide() end
    end

    local yOffset = 0
    local headerIdx = 0
    local charIdx = 0

    for _, repData in ipairs(data) do
        -- Section header
        headerIdx = headerIdx + 1
        local hRow = GetOrCreateHeaderRow(headerIdx)
        hRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
        hRow.repName:SetText(repData.name)
        hRow.headerLabel:SetText(repData.header)
        yOffset = yOffset + SECTION_HEIGHT

        -- Character rows
        for _, charInfo in ipairs(repData.characters) do
            charIdx = charIdx + 1
            local cRow = GetOrCreateCharRow(charIdx)
            cRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)

            -- Character name with class color
            local classColor = NS.CLASS_COLORS[charInfo.class] or { 1, 1, 1 }
            cRow.charName:SetText(charInfo.name)
            cRow.charName:SetTextColor(classColor[1], classColor[2], classColor[3])

            -- Level
            cRow.charLevel:SetText(charInfo.level)

            -- Bar fill
            local barRange = charInfo.barMax - charInfo.barMin
            local barCurrent = charInfo.barValue - charInfo.barMin
            local fillWidth = 0
            if barRange > 0 then
                fillWidth = (barCurrent / barRange) * 180
            end
            if fillWidth < 1 then fillWidth = 1 end

            local standingColor = NS.STANDING_COLORS[charInfo.standingID] or { 0.5, 0.5, 0.5 }
            cRow.barFill:SetWidth(fillWidth)
            cRow.barFill:SetColorTexture(standingColor[1], standingColor[2], standingColor[3], 0.85)

            -- Bar text
            cRow.barText:SetText(barCurrent .. "/" .. barRange)

            -- Standing label
            cRow.standingText:SetText(NS.GetStandingLabel(charInfo.standingID))
            cRow.standingText:SetTextColor(standingColor[1], standingColor[2], standingColor[3])

            yOffset = yOffset + ROW_HEIGHT
        end
    end

    -- Show "no results" if empty
    if headerIdx == 0 then
        headerIdx = headerIdx + 1
        local hRow = GetOrCreateHeaderRow(headerIdx)
        hRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
        hRow.repName:SetText("No reputations found.")
        hRow.repName:SetTextColor(unpack(COLOURS.dimWhite))
        hRow.headerLabel:SetText("")
        yOffset = SECTION_HEIGHT
    end

    scrollChild:SetHeight(math.max(yOffset, 1))
end

------------------------------------------------------------------------
-- H. Callbacks
------------------------------------------------------------------------
NS:RegisterCallback("ADDON_LOADED", function()
    CreateMinimapButton()
    CreateMainWindow()
end)

NS:RegisterCallback("DATA_UPDATED", function()
    UI:RefreshDisplay()
end)

NS:RegisterCallback("FILTER_CHANGED", function()
    UI:RefreshDisplay()
end)

NS:RegisterCallback("TOGGLE_WINDOW", function()
    if not mainFrame then return end
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        UI:RefreshDisplay()
    end
end)
