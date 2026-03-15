--------------------------------------------------------------------------------
-- LXCG Network.lua v0.4 — Multiplayer with hand reveal, card back sync,
-- template fields in messages
--------------------------------------------------------------------------------
LXCG.Network = {}
LXCG.Network.peer = nil

local function Send(target, msg)
    if not target then return end
    C_ChatInfo.SendAddonMessage(LXCG.MSG_PREFIX, msg, "WHISPER", target)
end

local function BoolStr(b) return b and "1" or "0" end
local function StrBool(s) return s == "1" end
local function SafeStr(s)
    if s == nil then return "" end
    return tostring(s):gsub("|", "!"):gsub(";", ",")
end
local function NumStr(n) return tostring(n or 0) end

local function SerializeFields(fields)
    if not fields or #fields == 0 then return "" end
    local parts = {}
    for _, f in ipairs(fields) do
        parts[#parts + 1] = SafeStr(f.name) .. "=" .. SafeStr(f.value)
    end
    return table.concat(parts, ";")
end

local function DeserializeFields(str)
    if not str or str == "" then return {} end
    local fields = {}
    for pair in str:gmatch("[^;]+") do
        local n, v = pair:match("^(.-)=(.*)$")
        if n and n ~= "" then fields[#fields + 1] = { name = n, value = v or "" } end
    end
    return fields
end

--------------------------------------------------------------------------------
function LXCG.Network:Init()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:SetScript("OnEvent", function(_, _, prefix, msg, channel, sender)
        if prefix ~= LXCG.MSG_PREFIX then return end
        local name = LXCG:NormalizeName(sender)
        if name == LXCG:PlayerName() then return end
        LXCG.Network:OnMessage(msg, name)
    end)

    LXCG:On("NET_CARD_REVEALED", function(instId, inst, tmpl)
        LXCG.Network:BroadcastReveal(instId, inst, tmpl)
    end)
    LXCG:On("NET_CARD_MOVED", function(instId, zoneId, px, py, faceUp)
        LXCG.Network:BroadcastAction("MOVE", instId .. "|" .. zoneId .. "|" .. NumStr(px) .. "|" .. NumStr(py) .. "|" .. BoolStr(faceUp))
    end)
    LXCG:On("NET_CARD_HIDDEN", function(instId)
        LXCG.Network:BroadcastAction("HIDE", instId)
    end)
    LXCG:On("NET_CARD_FLIPPED", function(instId, faceUp)
        LXCG.Network:BroadcastAction("FLIP", instId .. "|" .. BoolStr(faceUp))
    end)
    LXCG:On("NET_CARD_LANDSCAPE", function(instId, landscape)
        LXCG.Network:BroadcastAction("LAND", instId .. "|" .. BoolStr(landscape))
    end)
    LXCG:On("NET_CARD_DIMMED", function(instId, dimmed)
        LXCG.Network:BroadcastAction("DIM", instId .. "|" .. BoolStr(dimmed))
    end)
    LXCG:On("NET_CARD_COUNTER", function(instId, cName, cVal)
        LXCG.Network:BroadcastAction("CNT", instId .. "|" .. SafeStr(cName) .. "|" .. NumStr(cVal))
    end)
    LXCG:On("NET_CARD_DESTROYED", function(instId)
        LXCG.Network:BroadcastAction("DESTROY", instId)
    end)
    LXCG:On("NET_COUNTS_CHANGED", function()
        local c = LXCG.Data:GetMyCounts()
        LXCG.Network:BroadcastAction("COUNTS", NumStr(c.deck) .. "|" .. NumStr(c.hand))
    end)
    LXCG:On("NET_PLAYER_COUNTER", function(cName, cVal)
        LXCG.Network:BroadcastAction("PCNT", SafeStr(cName) .. "|" .. NumStr(cVal))
    end)
    LXCG:On("NET_SHUFFLE", function()
        LXCG.Network:BroadcastAction("SHUFFLE", "")
    end)
end

function LXCG.Network:BroadcastAction(actionType, payload)
    if not self.peer then return end
    Send(self.peer, "ACT_" .. actionType .. "|" .. (payload or ""))
end

function LXCG.Network:BroadcastReveal(instId, inst, tmpl)
    if not self.peer or not tmpl then return end
    local fields = tmpl.fields or {}
    local msg = "ACT_REVEAL|" .. instId .. "|" .. SafeStr(tmpl.id) .. "|"
        .. SafeStr(tmpl.name) .. "|" .. SafeStr(tmpl.icon) .. "|"
        .. SafeStr(tmpl.category) .. "|" .. SafeStr(tmpl.text) .. "|"
        .. SerializeFields(fields) .. "|"
        .. inst.zoneId .. "|" .. SafeStr(inst.owner) .. "|"
        .. BoolStr(inst.faceUp) .. "|" .. BoolStr(inst.landscape) .. "|"
        .. BoolStr(inst.dimmed) .. "|"
        .. NumStr(inst.position.x) .. "|" .. NumStr(inst.position.y)
    Send(self.peer, msg)
end

function LXCG.Network:SendCardBack()
    if not self.peer then return end
    local prefs = LXCG.Storage:GetPrefs()
    local cb = prefs.cardBack or ""
    Send(self.peer, "CARDBACK|" .. SafeStr(cb))
end

--------------------------------------------------------------------------------
function LXCG.Network:InvitePlayer(target)
    if self.peer then
        print("|cff00ccffLXCG:|r Already connected to " .. self.peer .. ". /lxcg leave first.")
        return
    end
    if not LXCG.Data.session then LXCG.Data:StartSession() end
    Send(target, "INVITE|" .. LXCG.VERSION)
    print("|cff00ccffLXCG:|r Invite sent to " .. target)
end

function LXCG.Network:AcceptInvite(from)
    if self.peer then Send(from, "DECLINE"); return end
    self.peer = from
    if not LXCG.Data.session then LXCG.Data:StartSession() end
    LXCG.Data:AddPlayer(from)
    Send(from, "ACCEPT|" .. LXCG.VERSION)
    self:SendCardBack()
    print("|cff00ccffLXCG:|r Connected to " .. from)
    Send(from, "SYNC_REQ")
end

function LXCG.Network:LeaveSession()
    if self.peer then
        Send(self.peer, "LEAVE")
        local opp = self.peer
        self.peer = nil
        LXCG.Data:RemovePlayer(opp)
        print("|cff00ccffLXCG:|r Disconnected from " .. opp)
    end
end

function LXCG.Network:RequestSync()
    if self.peer then
        Send(self.peer, "SYNC_REQ")
        print("|cff00ccffLXCG:|r Sync requested.")
    end
end

function LXCG.Network:SendFullSync(target)
    local s = LXCG.Data.session
    if not s then return end
    Send(target, "SYNC_START")
    self:SendCardBack()
    local me = LXCG:PlayerName()
    local myP = s.players[me]
    if myP then
        for k, v in pairs(myP.counters) do
            Send(target, "SYNC_PCNT|" .. SafeStr(k) .. "|" .. NumStr(v))
        end
    end
    local c = LXCG.Data:GetMyCounts()
    Send(target, "SYNC_COUNTS|" .. NumStr(c.deck) .. "|" .. NumStr(c.hand))
    local pubCards = LXCG.Data:GetPublicCards()
    for _, inst in ipairs(pubCards) do
        local tmpl = LXCG.Data:GetTemplate(inst.templateId)
        if tmpl then
            local fields = tmpl.fields or {}
            local msg = "SYNC_CARD|" .. inst.id .. "|" .. SafeStr(tmpl.id) .. "|"
                .. SafeStr(tmpl.name) .. "|" .. SafeStr(tmpl.icon) .. "|"
                .. SafeStr(tmpl.category) .. "|" .. SafeStr(tmpl.text) .. "|"
                .. SerializeFields(fields) .. "|"
                .. inst.zoneId .. "|" .. SafeStr(inst.owner) .. "|"
                .. BoolStr(inst.faceUp) .. "|" .. BoolStr(inst.landscape) .. "|"
                .. BoolStr(inst.dimmed) .. "|"
                .. NumStr(inst.position.x) .. "|" .. NumStr(inst.position.y)
            Send(target, msg)
        end
    end
    Send(target, "SYNC_END")
end

--------------------------------------------------------------------------------
function LXCG.Network:OnMessage(msg, sender)
    local parts = { strsplit("|", msg) }
    local mt = parts[1]

    if mt == "INVITE" then
        LXCG:Fire("NET_INVITE_RECEIVED", sender, parts[2] or "?"); return
    elseif mt == "ACCEPT" then
        self.peer = sender
        LXCG.Data:AddPlayer(sender)
        self:SendCardBack()
        self:SendFullSync(sender)
        print("|cff00ccffLXCG:|r " .. sender .. " connected!")
        if LXCG.Table then LXCG.Table:EnsureOpen() end
        return
    elseif mt == "DECLINE" then
        print("|cff00ccffLXCG:|r " .. sender .. " declined."); return
    elseif mt == "LEAVE" then
        if sender == self.peer then
            self.peer = nil; LXCG.Data:RemovePlayer(sender)
            print("|cff00ccffLXCG:|r " .. sender .. " left.")
        end
        return
    elseif mt == "SYNC_REQ" then
        if sender == self.peer then self:SendFullSync(sender) end; return
    elseif mt == "CARDBACK" then
        LXCG.Data:SetRemoteCardBack(sender, parts[2] or ""); return
    end

    if mt == "SYNC_START" then
        local s = LXCG.Data.session
        if s then
            local toRemove = {}
            for id, inst in pairs(s.instances) do
                if inst.owner == sender then
                    local zone = s.zones[inst.zoneId]
                    if zone and (zone.vis == "public" or inst.faceUp) then
                        toRemove[#toRemove + 1] = id
                    end
                end
            end
            for _, id in ipairs(toRemove) do s.instances[id] = nil end
        end
        LXCG.Data:Log("Syncing from " .. sender); return
    elseif mt == "SYNC_CARD" then
        self:HandleSyncCard(parts, sender); return
    elseif mt == "SYNC_COUNTS" then
        LXCG.Data:SetRemoteCounts(sender, tonumber(parts[2]) or 0, tonumber(parts[3]) or 0); return
    elseif mt == "SYNC_PCNT" then
        LXCG.Data:SetRemotePlayerCounter(sender, parts[2] or "Life", tonumber(parts[3]) or 0); return
    elseif mt == "SYNC_END" then
        LXCG.Data:Log("Sync complete.")
        LXCG:Fire("CARDS_CHANGED")
        if LXCG.Table then LXCG.Table:EnsureOpen() end; return
    end

    if sender ~= self.peer then return end

    if mt == "ACT_REVEAL" then self:HandleReveal(parts, sender)
    elseif mt == "ACT_MOVE" then self:HandleMove(parts)
    elseif mt == "ACT_HIDE" then self:HandleHide(parts)
    elseif mt == "ACT_FLIP" then self:HandleFlip(parts)
    elseif mt == "ACT_LAND" then self:HandleLandscape(parts)
    elseif mt == "ACT_DIM" then self:HandleDim(parts)
    elseif mt == "ACT_CNT" then self:HandleCounter(parts)
    elseif mt == "ACT_DESTROY" then self:HandleDestroy(parts)
    elseif mt == "ACT_COUNTS" then
        LXCG.Data:SetRemoteCounts(sender, tonumber(parts[2]) or 0, tonumber(parts[3]) or 0)
    elseif mt == "ACT_PCNT" then
        LXCG.Data:SetRemotePlayerCounter(sender, parts[2] or "Life", tonumber(parts[3]) or 0)
    elseif mt == "ACT_SHUFFLE" then
        LXCG.Data:Log(sender .. " shuffled their deck.")
    end
end

-- SYNC_CARD and ACT_REVEAL share format:
-- [1]=type [2]=instId [3]=tmplId [4]=name [5]=icon [6]=cat [7]=text [8]=fields [9]=zoneId [10]=owner [11]=faceUp [12]=land [13]=dim [14]=px [15]=py
function LXCG.Network:HandleSyncCard(parts, sender)
    LXCG.Data:SpawnRemoteCard(
        parts[2], parts[3], parts[4], parts[5], parts[6], parts[7],
        DeserializeFields(parts[8]),
        parts[9], parts[10],
        StrBool(parts[11]), StrBool(parts[12]), StrBool(parts[13]),
        parts[14], parts[15])
end

function LXCG.Network:HandleReveal(parts, sender)
    self:HandleSyncCard(parts, sender)
end

function LXCG.Network:HandleMove(parts)
    local instId = parts[2]
    local s = LXCG.Data.session
    if not s or not s.instances[instId] then return end
    LXCG.Data:MoveCard(instId, parts[3],
        { x = tonumber(parts[4]) or 0.5, y = tonumber(parts[5]) or 0.5 }, true)
    local inst = s.instances[instId]
    if inst then inst.faceUp = StrBool(parts[6]) end
    LXCG:Fire("CARDS_CHANGED")
end

function LXCG.Network:HandleHide(parts)
    local s = LXCG.Data.session
    if s and s.instances[parts[2]] then
        s.instances[parts[2]] = nil
        LXCG:Fire("CARDS_CHANGED")
    end
end

function LXCG.Network:HandleFlip(parts)
    local s = LXCG.Data.session
    if not s then return end
    local inst = s.instances[parts[2]]
    if inst then inst.faceUp = StrBool(parts[3]); LXCG:Fire("CARDS_CHANGED") end
end

function LXCG.Network:HandleLandscape(parts)
    local s = LXCG.Data.session
    if not s then return end
    local inst = s.instances[parts[2]]
    if inst then inst.landscape = StrBool(parts[3]); LXCG:Fire("CARDS_CHANGED") end
end

function LXCG.Network:HandleDim(parts)
    local s = LXCG.Data.session
    if not s then return end
    local inst = s.instances[parts[2]]
    if inst then inst.dimmed = StrBool(parts[3]); LXCG:Fire("CARDS_CHANGED") end
end

function LXCG.Network:HandleCounter(parts)
    local s = LXCG.Data.session
    if not s then return end
    local inst = s.instances[parts[2]]
    if inst then
        local val = tonumber(parts[4]) or 0
        inst.counters[parts[3] or "C"] = val ~= 0 and val or nil
        LXCG:Fire("CARDS_CHANGED")
    end
end

function LXCG.Network:HandleDestroy(parts)
    local s = LXCG.Data.session
    if s then s.instances[parts[2]] = nil; LXCG:Fire("CARDS_CHANGED") end
end
