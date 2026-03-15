--------------------------------------------------------------------------------
-- LXCG UI_Panels.lua v0.4
--------------------------------------------------------------------------------
LXCG.Panels = {}
local logText, logScroll, myLifeText, oppLifeLabel, oppLifeText, statusText

function LXCG.Panels:CreateLog(parent)
    local c = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    c:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
    c:SetBackdropColor(0.06, 0.06, 0.08, 1); c:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    local t = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t:SetPoint("TOPLEFT", 6, -4); t:SetText("|cff999999Log|r")
    local sf = CreateFrame("ScrollFrame", nil, c, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 4, -18); sf:SetPoint("BOTTOMRIGHT", -24, 4)
    logScroll = sf
    local content = CreateFrame("Frame", nil, sf); content:SetWidth(120); content:SetHeight(1)
    sf:SetScrollChild(content)
    logText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    logText:SetPoint("TOPLEFT"); logText:SetWidth(120)
    logText:SetJustifyH("LEFT"); logText:SetJustifyV("TOP"); logText:SetSpacing(2)
    LXCG:On("LOG_CHANGED", function() LXCG.Panels:UpdateLog() end)
    return c
end

function LXCG.Panels:UpdateLog()
    if not logText then return end
    local s = LXCG.Data.session
    if not s then logText:SetText(""); return end
    local lines = {}
    local start = math.max(1, #s.log - 49)
    for i = start, #s.log do
        local e = s.log[i]; lines[#lines + 1] = "|cff666666" .. e.time .. "|r " .. e.text
    end
    logText:SetText(table.concat(lines, "\n"))
    local p = logText:GetParent()
    if p then p:SetHeight(math.max(1, logText:GetStringHeight() + 4)) end
    if logScroll then C_Timer.After(0.01, function()
        if logScroll then logScroll:SetVerticalScroll(logScroll:GetVerticalScrollRange()) end
    end) end
end

function LXCG.Panels:CreateCounterBar(parent)
    local bar = CreateFrame("Frame", nil, parent); bar:SetHeight(24)
    local ml = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ml:SetPoint("LEFT", 8, 0); ml:SetTextColor(LXCG.COLOR_MINE[1], LXCG.COLOR_MINE[2], LXCG.COLOR_MINE[3])
    ml:SetText("Life:")
    myLifeText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    myLifeText:SetPoint("LEFT", ml, "RIGHT", 3, 0); myLifeText:SetText("20")
    local function CBtn(anchor, txt, delta)
        local b = CreateFrame("Button", nil, bar); b:SetSize(18, 18)
        b:SetPoint("LEFT", anchor, "RIGHT", 2, 0)
        b:SetNormalFontObject("GameFontNormal"); b:SetHighlightFontObject("GameFontHighlight")
        b:SetText(txt); b:SetScript("OnClick", function()
            LXCG.Data:SetPlayerCounter("Life", LXCG.Data:GetPlayerCounter("Life") + delta)
        end)
        local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1,1,1,0.1)
        return b
    end
    local minus = CBtn(myLifeText, "-", -1); local plus = CBtn(minus, "+", 1)
    oppLifeLabel = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    oppLifeLabel:SetPoint("LEFT", plus, "RIGHT", 16, 0)
    oppLifeLabel:SetTextColor(LXCG.COLOR_OPP[1], LXCG.COLOR_OPP[2], LXCG.COLOR_OPP[3]); oppLifeLabel:Hide()
    oppLifeText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    oppLifeText:SetPoint("LEFT", oppLifeLabel, "RIGHT", 4, 0)
    oppLifeText:SetTextColor(LXCG.COLOR_OPP[1], LXCG.COLOR_OPP[2], LXCG.COLOR_OPP[3]); oppLifeText:Hide()
    statusText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("RIGHT", bar, "RIGHT", -4, 0); statusText:SetText("|cff888888Solo|r")
    LXCG:On("COUNTERS_CHANGED", function() LXCG.Panels:UpdateCounters() end)
    LXCG:On("SESSION_CHANGED",  function() LXCG.Panels:UpdateCounters() end)
    return bar
end

function LXCG.Panels:UpdateCounters()
    if not myLifeText then return end
    myLifeText:SetText(tostring(LXCG.Data:GetPlayerCounter("Life")))
    local opp = LXCG.Data:GetOpponent()
    if opp then
        oppLifeLabel:SetText("vs " .. opp .. ":"); oppLifeLabel:Show()
        oppLifeText:SetText(tostring(LXCG.Data:GetOpponentCounter("Life"))); oppLifeText:Show()
        statusText:SetText("|cff44cc44Connected|r")
    else oppLifeLabel:Hide(); oppLifeText:Hide(); statusText:SetText("|cff888888Solo|r") end
end

--------------------------------------------------------------------------------
local inviteFrame
function LXCG.Panels:ShowInvitePopup(sender, version)
    if not inviteFrame then
        local f = CreateFrame("Frame", "LXCGInvite", UIParent, "BackdropTemplate")
        f:SetSize(280, 90); f:SetPoint("TOP", UIParent, "TOP", 0, -120)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=2 })
        f:SetBackdropColor(0.1, 0.1, 0.14, 0.98); f:SetBackdropBorderColor(0.4, 0.6, 0.8, 1)
        f:EnableMouse(true); f:Hide()
        f._text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f._text:SetPoint("TOP", 0, -12); f._text:SetWidth(260); f._text:SetJustifyH("CENTER")
        local function PBtn(txt, xOff)
            local b = CreateFrame("Button", nil, f, "BackdropTemplate")
            b:SetSize(80, 24); b:SetPoint("BOTTOM", xOff, 10)
            b:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
            b:SetBackdropColor(0.18, 0.18, 0.22, 1); b:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
            local l = b:CreateFontString(nil, "OVERLAY", "GameFontNormal"); l:SetAllPoints(); l:SetText(txt)
            b:SetScript("OnEnter", function(s) s:SetBackdropColor(0.28, 0.28, 0.35, 1) end)
            b:SetScript("OnLeave", function(s) s:SetBackdropColor(0.18, 0.18, 0.22, 1) end)
            return b
        end
        f._accept = PBtn("Accept", -50); f._decline = PBtn("Decline", 50)
        inviteFrame = f
    end
    inviteFrame._text:SetText("|cff00ccff" .. sender .. "|r wants to play cards!")
    inviteFrame._sender = sender
    inviteFrame._accept:SetScript("OnClick", function()
        LXCG.Network:AcceptInvite(inviteFrame._sender); inviteFrame:Hide()
    end)
    inviteFrame._decline:SetScript("OnClick", function()
        C_ChatInfo.SendAddonMessage(LXCG.MSG_PREFIX, "DECLINE", "WHISPER", inviteFrame._sender)
        inviteFrame:Hide()
    end)
    inviteFrame:Show()
end

LXCG:On("NET_INVITE_RECEIVED", function(sender, version)
    LXCG.Panels:ShowInvitePopup(sender, version)
end)
