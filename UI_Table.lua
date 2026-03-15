--------------------------------------------------------------------------------
-- LXCG UI_Table.lua v0.4 — Y-mirrored opponent field, card back config,
-- opponent hand with revealed cards
--------------------------------------------------------------------------------
LXCG.Table = {}
local tableFrame, myFieldCanvas, oppFieldCanvas, handArea, oppHandArea
local deckIcon, deckCount, discardIcon, discardCount
local oppDeckCount, oppHandCount, oppDiscCount
local activeFrames = {}
local fieldScale = 1.0
local logPanel

function LXCG.Table:Toggle()
    if not tableFrame then self:Build() end
    if tableFrame:IsShown() then tableFrame:Hide()
    else
        if not LXCG.Data.session then LXCG.Data:StartSession() end
        tableFrame:Show(); self:UpdateLayout(); self:Refresh()
    end
end

function LXCG.Table:EnsureOpen()
    if not tableFrame then self:Build() end
    if not LXCG.Data.session then LXCG.Data:StartSession() end
    tableFrame:Show(); self:UpdateLayout(); self:Refresh()
end

function LXCG.Table:GetMyFieldCanvas() return myFieldCanvas end

local function MakeBtn(parent, text, w, y, x, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, 22); b:SetPoint("TOPLEFT", x, y)
    b:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
    b:SetBackdropColor(0.15, 0.15, 0.18, 1); b:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    local l = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); l:SetAllPoints(); l:SetText(text)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(s) s:SetBackdropColor(0.25, 0.25, 0.3, 1) end)
    b:SetScript("OnLeave", function(s) s:SetBackdropColor(0.15, 0.15, 0.18, 1) end)
    return b
end

function LXCG.Table:Build()
    local f = CreateFrame("Frame", "LXCGTable", UIParent, "BackdropTemplate")
    f:SetSize(780, 600); f:SetPoint("CENTER")
    f:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=2 })
    f:SetBackdropColor(0.05, 0.05, 0.07, 0.97); f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton"); f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local l, b = self:GetLeft(), self:GetBottom()
        if l and b then LXCG.Storage:SetPref("tableX", l); LXCG.Storage:SetPref("tableY", b) end
    end)
    f:SetFrameStrata("MEDIUM"); f:Hide(); tableFrame = f
    local prefs = LXCG.Storage:GetPrefs()
    if prefs.tableX and prefs.tableY then
        f:ClearAllPoints(); f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", prefs.tableX, prefs.tableY)
    end
    fieldScale = prefs.fieldScale or 1.0

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -8); title:SetText("|cff00ccffLXCG|r v" .. LXCG.VERSION)
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton"); closeBtn:SetPoint("TOPRIGHT", -2, -2)
    local cBar = LXCG.Panels:CreateCounterBar(f)
    cBar:SetPoint("TOPLEFT", title, "TOPRIGHT", 12, 2); cBar:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)

    local by = -28
    MakeBtn(f, "Load Deck", 68, by, 10, function() LXCG.Table:ShowDeckPicker() end)
    MakeBtn(f, "Draw", 48, by, 82, function() LXCG.Data:DrawCards(1) end)
    MakeBtn(f, "Draw 7", 48, by, 134, function() LXCG.Data:DrawCards(7) end)
    MakeBtn(f, "Shuffle", 56, by, 186, function() LXCG.Data:ShuffleDeck() end)
    MakeBtn(f, "New Game", 64, by, 246, function()
        LXCG.Network:LeaveSession(); LXCG.Data:EndSession(); LXCG.Data:StartSession()
    end)
    MakeBtn(f, "Sync", 40, by, 314, function() LXCG.Network:RequestSync() end)

    local slLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slLabel:SetPoint("TOPLEFT", 364, by - 3); slLabel:SetText("|cffaaaaaaSize:|r")
    local slider = CreateFrame("Slider", nil, f)
    slider:SetSize(70, 14); slider:SetPoint("LEFT", slLabel, "RIGHT", 4, 0)
    slider:SetOrientation("HORIZONTAL"); slider:SetMinMaxValues(0.5, 1.5)
    slider:SetValue(fieldScale); slider:SetValueStep(0.1); slider:SetObeyStepOnDrag(true); slider:EnableMouse(true)
    local slBg = slider:CreateTexture(nil, "BACKGROUND"); slBg:SetAllPoints(); slBg:SetColorTexture(0.15, 0.15, 0.18, 1)
    local thumb = slider:CreateTexture(nil, "OVERLAY"); thumb:SetSize(10, 14); thumb:SetColorTexture(0.5, 0.5, 0.6, 1)
    slider:SetThumbTexture(thumb)
    slider:SetScript("OnValueChanged", function(_, val)
        fieldScale = math.floor(val * 10 + 0.5) / 10
        LXCG.Storage:SetPref("fieldScale", fieldScale); LXCG.Table:Refresh()
    end)

    -- Sidebar
    local sb = CreateFrame("Frame", nil, f, "BackdropTemplate")
    sb:SetWidth(76); sb:SetPoint("TOPLEFT", 6, -54); sb:SetPoint("BOTTOMLEFT", 6, 106)
    sb:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
    sb:SetBackdropColor(0.08, 0.08, 0.1, 1); sb:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    self.sidebar = sb

    local dkL = sb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dkL:SetPoint("TOPLEFT", 6, -6); dkL:SetTextColor(LXCG.COLOR_MINE[1], LXCG.COLOR_MINE[2], LXCG.COLOR_MINE[3]); dkL:SetText("Deck")
    deckIcon = sb:CreateTexture(nil, "ARTWORK"); deckIcon:SetSize(48, 48); deckIcon:SetPoint("TOP", 0, -22)
    deckIcon:SetTexture(LXCG:GetCardBack()); deckIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    deckCount = sb:CreateFontString(nil, "OVERLAY"); deckCount:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    deckCount:SetPoint("CENTER", deckIcon, "CENTER"); deckCount:SetText("0")

    -- Deck click to draw, right-click to set card back
    local deckBtn = CreateFrame("Button", nil, sb)
    deckBtn:SetAllPoints(deckIcon)
    deckBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    deckBtn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if LXCG.IconPicker then
                LXCG.IconPicker:Open(function(iconId, displayText)
                    LXCG.Storage:SetPref("cardBack", displayText)
                    LXCG.Network:SendCardBack()
                    LXCG.Table:Refresh()
                end)
            end
        else LXCG.Data:DrawCards(1) end
    end)
    local dkHL = deckBtn:CreateTexture(nil, "HIGHLIGHT"); dkHL:SetAllPoints(); dkHL:SetColorTexture(1, 1, 1, 0.1)

    local dcL = sb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dcL:SetPoint("TOPLEFT", 6, -76); dcL:SetTextColor(LXCG.COLOR_MINE[1], LXCG.COLOR_MINE[2], LXCG.COLOR_MINE[3]); dcL:SetText("Discard")
    discardIcon = sb:CreateTexture(nil, "ARTWORK"); discardIcon:SetSize(48, 48); discardIcon:SetPoint("TOP", sb, "TOP", 0, -92)
    discardIcon:SetTexture(LXCG.CARD_BACK); discardIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93); discardIcon:SetDesaturated(true)
    discardCount = sb:CreateFontString(nil, "OVERLAY"); discardCount:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    discardCount:SetPoint("CENTER", discardIcon, "CENTER"); discardCount:SetText("0")

    -- Opponent sidebar info
    local oppDiv = sb:CreateTexture(nil, "ARTWORK"); oppDiv:SetSize(60, 1)
    oppDiv:SetPoint("CENTER", sb, "CENTER", 0, 10); oppDiv:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    self.oppDiv = oppDiv; oppDiv:Hide()
    local function OppLabel(anchor, yOff, txt)
        local l = sb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        l:SetPoint("TOP", anchor, "BOTTOM", 0, yOff)
        l:SetTextColor(LXCG.COLOR_OPP[1], LXCG.COLOR_OPP[2], LXCG.COLOR_OPP[3]); l:SetText(txt); l:Hide()
        local v = sb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        v:SetPoint("TOP", l, "BOTTOM", 0, -2); v:SetText("0"); v:Hide()
        return l, v
    end
    local odL, odV = OppLabel(oppDiv, -8, "Opp Deck"); oppDeckCount = odV; self._odL = odL
    local ohL, ohV = OppLabel(odV, -8, "Opp Hand"); oppHandCount = ohV; self._ohL = ohL
    local ocL, ocV = OppLabel(ohV, -8, "Opp Disc"); oppDiscCount = ocV; self._ocL = ocL

    -- Opponent hand area
    oppHandArea = CreateFrame("Frame", nil, f, "BackdropTemplate"); oppHandArea:SetHeight(36)
    oppHandArea:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
    oppHandArea:SetBackdropColor(0.1, 0.07, 0.07, 1)
    oppHandArea:SetBackdropBorderColor(LXCG.COLOR_OPP[1]*0.5, LXCG.COLOR_OPP[2]*0.5, LXCG.COLOR_OPP[3]*0.5, 1)
    oppHandArea:Hide()
    self.oppHandLabel = oppHandArea:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.oppHandLabel:SetPoint("LEFT", 6, 0)
    self.oppHandLabel:SetTextColor(LXCG.COLOR_OPP[1], LXCG.COLOR_OPP[2], LXCG.COLOR_OPP[3], 0.6)

    -- Opponent field
    oppFieldCanvas = CreateFrame("Frame", nil, f, "BackdropTemplate")
    oppFieldCanvas:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
    oppFieldCanvas:SetBackdropColor(0.09, 0.06, 0.06, 1)
    oppFieldCanvas:SetBackdropBorderColor(LXCG.COLOR_OPP[1]*0.4, LXCG.COLOR_OPP[2]*0.4, LXCG.COLOR_OPP[3]*0.4, 1)
    oppFieldCanvas:Hide()
    local ofL = oppFieldCanvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ofL:SetPoint("TOPLEFT", 6, -4); ofL:SetTextColor(0.4, 0.2, 0.2, 0.6); ofL:SetText("Opponent Field")

    -- My field
    myFieldCanvas = CreateFrame("Frame", nil, f, "BackdropTemplate")
    myFieldCanvas:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
    myFieldCanvas:SetBackdropColor(0.07, 0.09, 0.07, 1); myFieldCanvas:SetBackdropBorderColor(0.2, 0.25, 0.2, 1)
    local mfL = myFieldCanvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mfL:SetPoint("TOPLEFT", 6, -4); mfL:SetTextColor(0.3, 0.4, 0.3, 0.6); mfL:SetText("Field")

    -- My hand
    handArea = CreateFrame("Frame", nil, f, "BackdropTemplate"); handArea:SetHeight(96)
    handArea:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
    handArea:SetBackdropColor(0.08, 0.07, 0.1, 1)
    handArea:SetBackdropBorderColor(LXCG.COLOR_MINE[1]*0.4, LXCG.COLOR_MINE[2]*0.4, LXCG.COLOR_MINE[3]*0.4, 1)
    local hL = handArea:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hL:SetPoint("TOPLEFT", 6, -3); hL:SetTextColor(0.3, 0.3, 0.4, 0.6); hL:SetText("Hand")

    logPanel = LXCG.Panels:CreateLog(f)
    logPanel:SetPoint("TOPRIGHT", -6, -54); logPanel:SetPoint("BOTTOMRIGHT", -6, 6); logPanel:SetWidth(156)

    LXCG:On("CARDS_CHANGED",   function() LXCG.Table:Refresh() end)
    LXCG:On("SESSION_CHANGED", function() LXCG.Table:Refresh() end)
    LXCG:On("LAYOUT_CHANGED",  function() LXCG.Table:UpdateLayout(); LXCG.Table:Refresh() end)
end

function LXCG.Table:UpdateLayout()
    if not tableFrame then return end
    local opp = LXCG.Data:GetOpponent()
    handArea:ClearAllPoints()
    handArea:SetPoint("BOTTOMLEFT", tableFrame, "BOTTOMLEFT", 86, 6)
    handArea:SetPoint("BOTTOMRIGHT", tableFrame, "BOTTOMRIGHT", -166, 6)
    if opp then
        oppHandArea:ClearAllPoints()
        oppHandArea:SetPoint("TOPLEFT", self.sidebar, "TOPRIGHT", 4, 0)
        oppHandArea:SetPoint("RIGHT", logPanel, "LEFT", -4, 0); oppHandArea:Show()
        oppFieldCanvas:ClearAllPoints()
        oppFieldCanvas:SetPoint("TOPLEFT", oppHandArea, "BOTTOMLEFT", 0, -2)
        oppFieldCanvas:SetPoint("RIGHT", logPanel, "LEFT", -4, 0)
        local totalH = tableFrame:GetHeight() - 54 - 36 - 2 - 96 - 6 - 4
        oppFieldCanvas:SetHeight(math.floor(totalH / 2)); oppFieldCanvas:Show()
        myFieldCanvas:ClearAllPoints()
        myFieldCanvas:SetPoint("TOPLEFT", oppFieldCanvas, "BOTTOMLEFT", 0, -2)
        myFieldCanvas:SetPoint("RIGHT", logPanel, "LEFT", -4, 0)
        myFieldCanvas:SetPoint("BOTTOM", handArea, "TOP", 0, 2)
        self.oppDiv:Show(); self._odL:Show(); oppDeckCount:Show()
        self._ohL:Show(); oppHandCount:Show(); self._ocL:Show(); oppDiscCount:Show()
    else
        oppHandArea:Hide(); oppFieldCanvas:Hide()
        myFieldCanvas:ClearAllPoints()
        myFieldCanvas:SetPoint("TOPLEFT", self.sidebar, "TOPRIGHT", 4, 0)
        myFieldCanvas:SetPoint("RIGHT", logPanel, "LEFT", -4, 0)
        myFieldCanvas:SetPoint("BOTTOM", handArea, "TOP", 0, 2)
        self.oppDiv:Hide(); self._odL:Hide(); oppDeckCount:Hide()
        self._ohL:Hide(); oppHandCount:Hide(); self._ocL:Hide(); oppDiscCount:Hide()
    end
end

function LXCG.Table:Refresh()
    if not tableFrame or not tableFrame:IsShown() then return end
    local s = LXCG.Data.session
    if not s then return end
    for i = #activeFrames, 1, -1 do
        local af = activeFrames[i]
        if af.instanceId ~= LXCG.Cards.draggingId then
            LXCG.Cards:Release(af); table.remove(activeFrames, i)
        end
    end
    local me = LXCG:PlayerName()
    local opp = LXCG.Data:GetOpponent()
    local myBack = LXCG:GetCardBack()
    deckIcon:SetTexture(myBack)
    deckCount:SetText(tostring(LXCG.Data:CountInZone(LXCG.Data:ZoneId(me, "deck"))))
    local discZone = LXCG.Data:ZoneId(me, "discard")
    discardCount:SetText(tostring(LXCG.Data:CountInZone(discZone)))
    local dc = LXCG.Data:CardsInZone(discZone)
    if #dc > 0 then
        local tmpl = LXCG.Data:GetTemplate(dc[#dc].templateId)
        if tmpl then discardIcon:SetTexture(tmpl.icon); discardIcon:SetDesaturated(false) end
    else discardIcon:SetTexture(myBack); discardIcon:SetDesaturated(true) end
    if opp then
        local rc = LXCG.Data:GetRemoteCounts(opp)
        oppDeckCount:SetText(tostring(rc.deck)); oppHandCount:SetText(tostring(rc.hand))
        oppDiscCount:SetText(tostring(LXCG.Data:CountInZone(LXCG.Data:ZoneId(opp, "discard"))))
    end
    self:RenderHand(me)
    self:RenderField(me, myFieldCanvas, false)
    if opp then
        self:RenderOpponentHand(opp)
        self:RenderField(opp, oppFieldCanvas, true)
    end
    LXCG.Panels:UpdateLog(); LXCG.Panels:UpdateCounters()
end

function LXCG.Table:RenderHand(player)
    local zoneId = LXCG.Data:ZoneId(player, "hand")
    local cards = LXCG.Data:CardsInZone(zoneId)
    if #cards == 0 then return end
    local areaW = handArea:GetWidth() - 12
    local cardW = LXCG.CARD_W
    local count = #cards
    local spacing = math.min(cardW + 4, areaW / count)
    local totalW = spacing * (count - 1) + cardW
    local startX = (areaW - totalW) / 2 + 6
    for i, inst in ipairs(cards) do
        if inst.id ~= LXCG.Cards.draggingId then
            local frame = LXCG.Cards:Acquire(handArea); frame._scale = 1
            LXCG.Cards:Render(frame, inst, LXCG.Data:GetTemplate(inst.templateId), true, false)
            frame:ClearAllPoints()
            frame:SetPoint("BOTTOMLEFT", handArea, "BOTTOMLEFT", startX + (i - 1) * spacing, 4)
            frame:SetFrameLevel(handArea:GetFrameLevel() + i + 1)
            activeFrames[#activeFrames + 1] = frame
        end
    end
end

function LXCG.Table:RenderOpponentHand(oppName)
    if not oppHandArea:IsShown() then return end
    local rc = LXCG.Data:GetRemoteCounts(oppName)
    local totalHand = rc.hand or 0
    local oppHandZone = LXCG.Data:ZoneId(oppName, "hand")
    local revealed = LXCG.Data:CardsInZone(oppHandZone)
    local revCount = #revealed
    local backCount = math.max(0, totalHand - revCount)
    local count = backCount + revCount
    self.oppHandLabel:SetText("Opponent Hand (" .. totalHand .. ")")
    if count <= 0 then return end
    local oppBack = LXCG:GetCardBack(oppName)
    local areaW = oppHandArea:GetWidth() - 110
    local cardSz = 28
    local shown = math.min(count, math.floor(areaW / (cardSz + 2)))
    local spacing = math.min(cardSz + 2, areaW / math.max(shown, 1))
    local startX, idx = 110, 0
    for i = 1, math.min(backCount, shown) do
        idx = idx + 1
        local frame = LXCG.Cards:Acquire(oppHandArea)
        LXCG.Cards:RenderBackOnly(frame, 0.44, oppBack)
        frame:ClearAllPoints()
        frame:SetPoint("LEFT", oppHandArea, "LEFT", startX + (idx - 1) * spacing, 0)
        frame:SetFrameLevel(oppHandArea:GetFrameLevel() + idx + 1)
        activeFrames[#activeFrames + 1] = frame
    end
    for _, inst in ipairs(revealed) do
        if idx >= shown then break end
        idx = idx + 1
        local frame = LXCG.Cards:Acquire(oppHandArea); frame._scale = 0.44
        LXCG.Cards:Render(frame, inst, LXCG.Data:GetTemplate(inst.templateId), false, true)
        frame:ClearAllPoints()
        frame:SetPoint("LEFT", oppHandArea, "LEFT", startX + (idx - 1) * spacing, 0)
        frame:SetFrameLevel(oppHandArea:GetFrameLevel() + idx + 1)
        activeFrames[#activeFrames + 1] = frame
    end
end

function LXCG.Table:RenderField(player, canvas, isOpponent)
    if not canvas or not canvas:IsShown() then return end
    local zoneId = LXCG.Data:ZoneId(player, "field")
    local cards = LXCG.Data:CardsInZone(zoneId)
    if #cards == 0 then return end
    local cW, cH = canvas:GetWidth(), canvas:GetHeight()
    for _, inst in ipairs(cards) do
        if inst.id ~= LXCG.Cards.draggingId then
            local frame = LXCG.Cards:Acquire(canvas); frame._scale = fieldScale
            LXCG.Cards:Render(frame, inst, LXCG.Data:GetTemplate(inst.templateId), false, isOpponent)
            local fW, fH = frame:GetSize()
            local px = (inst.position.x or 0.5) * math.max(cW - fW, 1)
            local py = (inst.position.y or 0.5)
            if isOpponent then py = 1 - py end
            py = py * math.max(cH - fH, 1)
            frame:ClearAllPoints()
            frame:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", px, py)
            frame:SetFrameLevel(canvas:GetFrameLevel() + (inst.orderIndex or 1))
            activeFrames[#activeFrames + 1] = frame
        end
    end
end

--------------------------------------------------------------------------------
local pickerFrame
function LXCG.Table:ShowDeckPicker()
    if not pickerFrame then
        local pf = CreateFrame("Frame", nil, tableFrame, "BackdropTemplate")
        pf:SetSize(240, 260); pf:SetPoint("CENTER", tableFrame, "CENTER"); pf:SetFrameStrata("DIALOG")
        pf:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=2 })
        pf:SetBackdropColor(0.1, 0.1, 0.12, 0.98); pf:SetBackdropBorderColor(0.4, 0.4, 0.4, 1); pf:EnableMouse(true)
        local t = pf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("TOP", 0, -10); t:SetText("Select Deck")
        local cb = CreateFrame("Button", nil, pf, "UIPanelCloseButton"); cb:SetPoint("TOPRIGHT", -2, -2)
        cb:SetScript("OnClick", function() pf:Hide() end)
        local sf = CreateFrame("ScrollFrame", nil, pf, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 8, -32); sf:SetPoint("BOTTOMRIGHT", -28, 8)
        local content = CreateFrame("Frame", nil, sf); content:SetWidth(196); content:SetHeight(1)
        sf:SetScrollChild(content)
        pf.content = content; pf._btns = {}; pickerFrame = pf
    end
    for _, b in ipairs(pickerFrame._btns) do b:Hide() end
    if pickerFrame._empty then pickerFrame._empty:Hide() end
    local idx = 0
    for deckId, deck in pairs(LXCG.Data.decks) do
        idx = idx + 1
        local btn = pickerFrame._btns[idx]
        if not btn then
            btn = CreateFrame("Button", nil, pickerFrame.content, "BackdropTemplate")
            btn:SetSize(196, 26)
            btn:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
            btn:SetBackdropColor(0.15, 0.15, 0.18, 1); btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            btn._icon = btn:CreateTexture(nil, "ARTWORK"); btn._icon:SetSize(20, 20)
            btn._icon:SetPoint("LEFT", 3, 0); btn._icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            btn._label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn._label:SetPoint("LEFT", btn._icon, "RIGHT", 4, 0); btn._label:SetJustifyH("LEFT")
            btn:SetScript("OnEnter", function(s) s:SetBackdropColor(0.25, 0.25, 0.3, 1) end)
            btn:SetScript("OnLeave", function(s) s:SetBackdropColor(0.15, 0.15, 0.18, 1) end)
            pickerFrame._btns[idx] = btn
        end
        btn:SetPoint("TOPLEFT", 0, -(idx - 1) * 28)
        btn._icon:SetTexture(deck.icon and LXCG:ResolveIcon(deck.icon) or LXCG:GetCardBack())
        local size = LXCG.Data:DeckSize(deckId)
        btn._label:SetText(deck.name .. "  |cff888888(" .. size .. ")|r")
        local did = deckId
        btn:SetScript("OnClick", function() LXCG.Data:LoadDeck(did); pickerFrame:Hide() end)
        btn:Show()
    end
    pickerFrame.content:SetHeight(math.max(1, idx * 28))
    if idx == 0 then
        if not pickerFrame._empty then
            pickerFrame._empty = pickerFrame.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            pickerFrame._empty:SetPoint("TOP", 0, -8)
        end
        pickerFrame._empty:SetText("|cff888888No decks. /lxcg builder|r"); pickerFrame._empty:Show()
    end
    pickerFrame:Show()
end
