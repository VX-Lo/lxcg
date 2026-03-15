--------------------------------------------------------------------------------
-- LXCG UI_Cards.lua v0.4 — Card frames with fields, custom card backs,
-- gold revealed-in-hand borders, stat line rendering
--------------------------------------------------------------------------------
LXCG.Cards = {}
LXCG.Cards.draggingId = nil
local pool = {}

function LXCG.Cards:Acquire(parent)
    local f = table.remove(pool)
    if not f then f = self:BuildFrame(parent) end
    f:SetParent(parent); f:Show(); return f
end

function LXCG.Cards:Release(f)
    f:Hide(); f:ClearAllPoints()
    f.instanceId = nil; f.isDragging = false
    f._scale = 1; f._isOpponent = false; f._canInteract = true
    pool[#pool + 1] = f
end

function LXCG.Cards:BuildFrame(parent)
    local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
    f:SetSize(LXCG.CARD_W, LXCG.CARD_H)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1,
    })
    f:SetBackdropColor(0.12, 0.12, 0.15, 1)
    f:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.back = f:CreateTexture(nil, "ARTWORK")
    f.back:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.back:SetTexture(LXCG.CARD_BACK); f.back:Hide()
    f.nameText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.nameText:SetJustifyH("CENTER"); f.nameText:SetWordWrap(false)
    f.statsText = f:CreateFontString(nil, "OVERLAY")
    f.statsText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    f.statsText:SetTextColor(1, 1, 0.8); f.statsText:Hide()
    f.badge = f:CreateFontString(nil, "OVERLAY")
    f.badge:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    f.badge:SetTextColor(0.2, 1, 0.2); f.badge:Hide()
    f.dimOverlay = f:CreateTexture(nil, "OVERLAY", nil, 1)
    f.dimOverlay:SetColorTexture(0, 0, 0, 0.4); f.dimOverlay:Hide()
    local hl = f:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.08)
    f:SetMovable(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", function(self) LXCG.Cards:OnDragStart(self) end)
    f:SetScript("OnDragStop",  function(self) LXCG.Cards:OnDragStop(self)  end)
    f:SetScript("OnClick", function(self, button)
        if not self._canInteract then return end
        if button == "RightButton" and self.instanceId then
            LXCG.Cards:ShowContextMenu(self)
        elseif button == "LeftButton" and self.instanceId then
            local now = GetTime()
            if self._lastClick and (now - self._lastClick) < 0.3 then
                LXCG.Cards:OnDoubleClick(self); self._lastClick = nil
            else self._lastClick = now end
        end
    end)
    f:SetScript("OnEnter", function(self)
        if self.instanceId then LXCG.Cards:ShowTooltip(self) end
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f._scale = 1; f._isOpponent = false; f._canInteract = true
    return f
end

--------------------------------------------------------------------------------
function LXCG.Cards:Render(frame, instance, template, ownerView, isOpponent)
    frame.instanceId = instance.id
    frame._isOpponent = isOpponent or false
    frame._canInteract = not (isOpponent or false)
    local scale = frame._scale or 1
    local w, h = math.floor(LXCG.CARD_W * scale), math.floor(LXCG.CARD_H * scale)
    if instance.landscape then w, h = h, w end
    frame:SetSize(w, h)
    local pad = math.max(2, math.floor(3 * scale))
    local showName = math.min(w, h) >= 42
    local nameH = showName and math.max(10, math.floor(13 * scale)) or 0
    local artW = w - pad * 2
    local artH = h - pad - (showName and (pad + nameH) or pad)
    local iconSz = math.max(8, math.floor(math.min(artW, artH)))
    local showFace = instance.faceUp or ownerView
    local cardBackTex = LXCG:GetCardBack(instance.owner)

    frame.icon:SetSize(iconSz, iconSz); frame.icon:ClearAllPoints()
    frame.icon:SetPoint("TOP", frame, "TOP", 0, -pad)
    frame.back:SetSize(iconSz, iconSz); frame.back:ClearAllPoints()
    frame.back:SetPoint("TOP", frame, "TOP", 0, -pad)
    frame.back:SetTexture(cardBackTex)
    frame.dimOverlay:ClearAllPoints(); frame.dimOverlay:SetAllPoints(frame.icon)

    if showFace and template then
        frame.icon:SetTexture(template.icon)
        frame.icon:SetDesaturated(instance.dimmed)
        frame.icon:Show(); frame.back:Hide()
        if showName then
            frame.nameText:ClearAllPoints()
            frame.nameText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", pad, pad - 1)
            frame.nameText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pad, pad - 1)
            frame.nameText:SetHeight(nameH)
            frame.nameText:SetText(template.name); frame.nameText:Show()
        else frame.nameText:Hide() end
        -- Stat line from fields
        local fields = template.fields
        if fields and #fields > 0 and showName then
            local vals = {}
            for _, fld in ipairs(fields) do vals[#vals + 1] = fld.value end
            frame.statsText:ClearAllPoints()
            frame.statsText:SetPoint("BOTTOMRIGHT", frame.icon, "BOTTOMRIGHT", -1, 1)
            frame.statsText:SetText(table.concat(vals, "/"))
            frame.statsText:Show()
        else frame.statsText:Hide() end
    else
        frame.icon:Hide(); frame.back:Show()
        frame.back:SetDesaturated(instance.dimmed)
        frame.nameText:Hide(); frame.statsText:Hide()
    end
    frame.dimOverlay:SetShown(instance.dimmed)

    -- Border color: gold=revealed in hand, red=opponent, blue=mine
    local isRevealedInHand = false
    if instance.faceUp and not isOpponent then
        local s = LXCG.Data.session
        if s then
            local zone = s.zones[instance.zoneId]
            if zone and zone.vis == "private" then isRevealedInHand = true end
        end
    end
    local col
    if isRevealedInHand then col = LXCG.COLOR_REVEALED
    elseif isOpponent then col = LXCG.COLOR_OPP
    else col = LXCG.COLOR_MINE end
    local dim = instance.dimmed and 0.5 or 1
    frame:SetBackdropBorderColor(col[1] * dim, col[2] * dim, col[3] * dim, 1)

    -- Counter badge
    local cText = ""
    for k, v in pairs(instance.counters) do
        if cText ~= "" then cText = cText .. " " end
        cText = cText .. v
    end
    if cText ~= "" then
        frame.badge:ClearAllPoints()
        frame.badge:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
        frame.badge:SetText(cText); frame.badge:Show()
    else frame.badge:Hide() end
end

function LXCG.Cards:RenderBackOnly(frame, scale, cardBackTex)
    frame.instanceId = nil; frame._isOpponent = true; frame._canInteract = false
    frame._scale = scale or 0.5
    local sz = math.floor(LXCG.CARD_W * (scale or 0.5))
    frame:SetSize(sz, sz)
    frame.icon:Hide()
    frame.back:SetSize(sz - 6, sz - 6); frame.back:ClearAllPoints()
    frame.back:SetPoint("CENTER")
    frame.back:SetTexture(cardBackTex or LXCG.CARD_BACK)
    frame.back:SetDesaturated(false); frame.back:Show()
    frame.nameText:Hide(); frame.badge:Hide(); frame.dimOverlay:Hide()
    frame.statsText:Hide()
    frame:SetBackdropBorderColor(LXCG.COLOR_OPP[1], LXCG.COLOR_OPP[2], LXCG.COLOR_OPP[3], 0.6)
    frame:SetBackdropColor(0.12, 0.08, 0.08, 1)
end

--------------------------------------------------------------------------------
function LXCG.Cards:OnDragStart(frame)
    if not frame.instanceId or frame._isOpponent then return end
    local s = LXCG.Data.session
    if not s then return end
    local inst = s.instances[frame.instanceId]
    if not inst then return end
    local zone = s.zones[inst.zoneId]
    if not zone or zone.zoneType ~= "canvas" then return end
    frame.isDragging = true; self.draggingId = inst.id
    frame:StartMoving(); frame:SetFrameStrata("TOOLTIP")
end

function LXCG.Cards:OnDragStop(frame)
    if not frame.isDragging then return end
    frame.isDragging = false; frame:StopMovingOrSizing()
    frame:SetFrameStrata("MEDIUM")
    local canvas = LXCG.Table and LXCG.Table:GetMyFieldCanvas()
    if canvas and frame.instanceId then
        local cW, cH = canvas:GetWidth(), canvas:GetHeight()
        local fW, fH = frame:GetWidth(), frame:GetHeight()
        local cL, cB = canvas:GetLeft(), canvas:GetBottom()
        local fL, fB = frame:GetLeft(), frame:GetBottom()
        if cL and fL then
            local nx = math.max(0, math.min(1, (fL - cL) / math.max(cW - fW, 1)))
            local ny = math.max(0, math.min(1, (fB - cB) / math.max(cH - fH, 1)))
            LXCG.Data:SetPosition(frame.instanceId, nx, ny)
            LXCG.Data:FinalizePosition(frame.instanceId)
        end
    end
    self.draggingId = nil
    if LXCG.Table then LXCG.Table:Refresh() end
end

function LXCG.Cards:OnDoubleClick(frame)
    if frame._isOpponent then return end
    local s = LXCG.Data.session
    if not s then return end
    local inst = s.instances[frame.instanceId]
    if not inst then return end
    local player = LXCG:PlayerName()
    local handZone  = LXCG.Data:ZoneId(player, "hand")
    local fieldZone = LXCG.Data:ZoneId(player, "field")
    local deckZone  = LXCG.Data:ZoneId(player, "deck")
    if inst.zoneId == handZone then LXCG.Data:MoveCard(inst.id, fieldZone)
    elseif inst.zoneId == deckZone then LXCG.Data:DrawCards(1)
    elseif inst.zoneId == fieldZone then LXCG.Data:ToggleLandscape(inst.id) end
end

--------------------------------------------------------------------------------
function LXCG.Cards:ShowTooltip(frame)
    local s = LXCG.Data.session
    if not s then return end
    local inst = s.instances[frame.instanceId]
    if not inst then return end
    local t = LXCG.Data:GetTemplate(inst.templateId)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    local canSee = inst.faceUp or (inst.owner == LXCG:PlayerName())
    if canSee and t then
        GameTooltip:AddLine(t.name, 1, 0.82, 0)
        if t.category ~= "" then GameTooltip:AddLine(t.category, 0.6, 0.6, 0.6) end
        if t.text ~= "" then GameTooltip:AddLine(t.text, 1, 1, 1, true) end
        if t.fields then
            for _, fld in ipairs(t.fields) do
                GameTooltip:AddLine(fld.name .. ": " .. fld.value, 0.8, 0.8, 0.6)
            end
        end
    else
        GameTooltip:AddLine("Face Down", 0.5, 0.5, 0.5)
    end
    for k, v in pairs(inst.counters) do
        GameTooltip:AddLine(k .. ": " .. v, 0.3, 0.8, 1)
    end
    GameTooltip:Show()
end

--------------------------------------------------------------------------------
local ctxMenu, ctxCatcher
local function EnsureContextMenu()
    if ctxMenu then return ctxMenu end
    ctxCatcher = CreateFrame("Button", nil, UIParent)
    ctxCatcher:SetAllPoints(); ctxCatcher:SetFrameStrata("FULLSCREEN"); ctxCatcher:Hide()
    ctxCatcher:SetScript("OnClick", function(self) ctxMenu:Hide(); self:Hide() end)
    ctxMenu = CreateFrame("Frame", "LXCGCtxMenu", UIParent, "BackdropTemplate")
    ctxMenu:SetFrameStrata("FULLSCREEN_DIALOG")
    ctxMenu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1,
    })
    ctxMenu:SetBackdropColor(0.1, 0.1, 0.12, 0.95)
    ctxMenu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    ctxMenu:EnableMouse(true); ctxMenu:Hide(); ctxMenu._btns = {}
    ctxMenu:SetScript("OnHide", function() ctxCatcher:Hide() end)
    return ctxMenu
end

local function CtxButton(menu, index, text, fn)
    local btn = menu._btns[index]
    if not btn then
        btn = CreateFrame("Button", nil, menu)
        btn:SetSize(140, 20)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.1)
        btn._label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn._label:SetPoint("LEFT", 6, 0); btn._label:SetJustifyH("LEFT")
        menu._btns[index] = btn
    end
    btn:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -(index - 1) * 20 - 4)
    btn._label:SetText(text)
    btn:SetScript("OnClick", function() fn(); menu:Hide() end)
    btn:Show(); return btn
end

function LXCG.Cards:ShowContextMenu(cardFrame)
    if cardFrame._isOpponent then return end
    local menu = EnsureContextMenu()
    for _, b in ipairs(menu._btns) do b:Hide() end
    local s = LXCG.Data.session
    if not s then return end
    local inst = s.instances[cardFrame.instanceId]
    if not inst then return end
    local instId, idx = inst.id, 0
    local player = LXCG:PlayerName()

    idx = idx + 1; CtxButton(menu, idx, inst.faceUp and "Conceal" or "Reveal", function() LXCG.Data:FlipCard(instId) end)
    idx = idx + 1; CtxButton(menu, idx, inst.landscape and "Turn Upright" or "Turn Sideways", function() LXCG.Data:ToggleLandscape(instId) end)
    idx = idx + 1; CtxButton(menu, idx, inst.dimmed and "Brighten" or "Dim", function() LXCG.Data:ToggleDim(instId) end)
    idx = idx + 1; CtxButton(menu, idx, "+1 Counter", function() LXCG.Data:AddCounter(instId, "C", 1) end)
    idx = idx + 1; CtxButton(menu, idx, "-1 Counter", function() LXCG.Data:AddCounter(instId, "C", -1) end)
    local moves = {
        { "hand", "> Hand" }, { "field", "> Field" },
        { "discard", "> Discard" }, { "deck", "> Deck (bottom)" },
    }
    for _, m in ipairs(moves) do
        local zid = LXCG.Data:ZoneId(player, m[1])
        if inst.zoneId ~= zid then
            idx = idx + 1; CtxButton(menu, idx, m[2], function() LXCG.Data:MoveCard(instId, zid) end)
        end
    end
    idx = idx + 1; CtxButton(menu, idx, "|cffff6666Remove|r", function() LXCG.Data:DestroyCard(instId) end)
    menu:SetSize(144, idx * 20 + 8); menu:ClearAllPoints()
    local cx, cy = GetCursorPosition()
    local sc = UIParent:GetEffectiveScale()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cx / sc, cy / sc)
    ctxCatcher:Show(); menu:Show()
end
