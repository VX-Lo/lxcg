--------------------------------------------------------------------------------
-- LXCG Data.lua v0.4 — Templates with fields, decks with metadata,
-- hand reveal, card back tracking
--------------------------------------------------------------------------------
LXCG.Data = {}
LXCG.Data.templates = {}
LXCG.Data.decks = {}
LXCG.Data.session = nil

--------------------------------------------------------------------------------
-- Templates
--------------------------------------------------------------------------------
function LXCG.Data:CreateTemplate(name, icon, category, text, fields)
    local t = {
        id = LXCG:NewID(), name = name or "Unnamed",
        icon = LXCG:ResolveIcon(icon), category = category or "",
        text = text or "", fields = fields or {},
    }
    self.templates[t.id] = t
    LXCG:Fire("TEMPLATES_CHANGED")
    return t
end

function LXCG.Data:UpdateTemplate(id, name, icon, category, text, fields)
    local t = self.templates[id]
    if not t then return end
    if name and name ~= "" then t.name = name end
    if icon then t.icon = LXCG:ResolveIcon(icon) end
    if category then t.category = category end
    if text then t.text = text end
    if fields then t.fields = fields end
    LXCG:Fire("TEMPLATES_CHANGED")
end

function LXCG.Data:DeleteTemplate(id)
    self.templates[id] = nil
    LXCG:Fire("TEMPLATES_CHANGED")
end

function LXCG.Data:GetTemplate(id)
    local t = self.templates[id]
    if t then return t end
    if self.session and self.session.remoteTemplates then
        return self.session.remoteTemplates[id]
    end
    return nil
end

--------------------------------------------------------------------------------
-- Decks
--------------------------------------------------------------------------------
function LXCG.Data:CreateDeck(name)
    local d = {
        id = LXCG:NewID(), name = name or "New Deck",
        icon = nil, description = "", cards = {},
    }
    self.decks[d.id] = d
    LXCG:Fire("DECKS_CHANGED")
    return d
end

function LXCG.Data:UpdateDeck(id, name, icon, description)
    local d = self.decks[id]
    if not d then return end
    if name and name ~= "" then d.name = name end
    d.icon = icon
    if description then d.description = description end
    LXCG:Fire("DECKS_CHANGED")
end

function LXCG.Data:DeleteDeck(id)
    self.decks[id] = nil
    LXCG:Fire("DECKS_CHANGED")
end

function LXCG.Data:AddToDeck(deckId, templateId, n)
    local deck = self.decks[deckId]
    if not deck then return end
    n = n or 1
    for _, e in ipairs(deck.cards) do
        if e.templateId == templateId then
            e.count = e.count + n
            LXCG:Fire("DECKS_CHANGED"); return
        end
    end
    deck.cards[#deck.cards + 1] = { templateId = templateId, count = n }
    LXCG:Fire("DECKS_CHANGED")
end

function LXCG.Data:RemoveFromDeck(deckId, templateId, n)
    local deck = self.decks[deckId]
    if not deck then return end
    n = n or 1
    for i, e in ipairs(deck.cards) do
        if e.templateId == templateId then
            e.count = e.count - n
            if e.count <= 0 then table.remove(deck.cards, i) end
            LXCG:Fire("DECKS_CHANGED"); return
        end
    end
end

function LXCG.Data:DeckSize(deckId)
    local deck = self.decks[deckId]
    if not deck then return 0 end
    local total = 0
    for _, e in ipairs(deck.cards) do total = total + e.count end
    return total
end

--------------------------------------------------------------------------------
-- Session
--------------------------------------------------------------------------------
function LXCG.Data:StartSession()
    local player = LXCG:PlayerName()
    local s = {
        host = player, nextOrder = 1, log = {},
        players = { [player] = { name = player, role = "gm", counters = { Life = 20 }, cardBack = nil } },
        zones = {}, instances = {},
        remoteTemplates = {}, remoteCounts = {},
    }
    self:CreatePlayerZones(s, player)
    s.zones["shared"] = {
        id = "shared", key = "shared", name = "Shared", owner = nil,
        zoneType = "canvas", vis = "public", faceUp = true,
    }
    self.session = s
    self:Log("Session started.")
    LXCG:Fire("SESSION_CHANGED")
    return s
end

function LXCG.Data:CreatePlayerZones(s, name)
    for _, def in ipairs(LXCG.DEFAULT_ZONES) do
        local zid = name .. "_" .. def.key
        s.zones[zid] = {
            id = zid, key = def.key, name = def.name, owner = name,
            zoneType = def.zoneType, vis = def.vis, faceUp = def.faceUp,
        }
    end
end

function LXCG.Data:EndSession()
    self.session = nil
    LXCG:Fire("SESSION_CHANGED")
    LXCG:Fire("CARDS_CHANGED")
end

function LXCG.Data:ZoneId(player, key) return player .. "_" .. key end

function LXCG.Data:AddPlayer(name)
    local s = self.session
    if not s or s.players[name] then return end
    s.players[name] = { name = name, role = "player", counters = { Life = 20 }, cardBack = nil }
    self:CreatePlayerZones(s, name)
    s.remoteCounts[name] = { deck = 0, hand = 0 }
    self:Log(name .. " joined.")
    LXCG:Fire("SESSION_CHANGED")
    LXCG:Fire("LAYOUT_CHANGED")
end

function LXCG.Data:RemovePlayer(name)
    local s = self.session
    if not s or name == LXCG:PlayerName() then return end
    -- Remove their instances
    local toRemove = {}
    for id, inst in pairs(s.instances) do
        if inst.owner == name then toRemove[#toRemove + 1] = id end
    end
    for _, id in ipairs(toRemove) do s.instances[id] = nil end
    s.players[name] = nil
    s.remoteCounts[name] = nil
    self:Log(name .. " left.")
    LXCG:Fire("SESSION_CHANGED")
    LXCG:Fire("LAYOUT_CHANGED")
end

function LXCG.Data:GetOpponent()
    local s = self.session
    if not s then return nil end
    local me = LXCG:PlayerName()
    for name in pairs(s.players) do
        if name ~= me then return name end
    end
    return nil
end

function LXCG.Data:IsHost()
    local s = self.session
    return s and s.host == LXCG:PlayerName()
end

function LXCG.Data:SetRemoteCounts(name, deck, hand)
    local s = self.session
    if not s then return end
    if not s.remoteCounts[name] then s.remoteCounts[name] = {} end
    if deck then s.remoteCounts[name].deck = deck end
    if hand then s.remoteCounts[name].hand = hand end
    LXCG:Fire("CARDS_CHANGED")
end

function LXCG.Data:SetRemotePlayerCounter(name, key, value)
    local s = self.session
    if not s or not s.players[name] then return end
    s.players[name].counters[key] = value
    LXCG:Fire("COUNTERS_CHANGED")
end

function LXCG.Data:SetRemoteCardBack(name, icon)
    local s = self.session
    if not s or not s.players[name] then return end
    s.players[name].cardBack = icon
    LXCG:Fire("CARDS_CHANGED")
end

--------------------------------------------------------------------------------
-- Serialization
--------------------------------------------------------------------------------
function LXCG.Data:SerializeSession()
    if not self.session then return nil end
    local copy = LXCG:DeepCopy(self.session)
    local me = LXCG:PlayerName()
    for name in pairs(copy.players) do
        if name ~= me then copy.players[name] = nil end
    end
    -- Remove remote instances
    for id, inst in pairs(copy.instances) do
        if inst.owner ~= me then copy.instances[id] = nil end
    end
    copy.remoteCounts = {}
    copy.remoteTemplates = {}
    return copy
end

function LXCG.Data:RestoreSession(data)
    if not data or not data.zones or not data.instances then return false end
    self.session = data
    if not self.session.log then self.session.log = {} end
    if not self.session.nextOrder then self.session.nextOrder = 1 end
    if not self.session.remoteTemplates then self.session.remoteTemplates = {} end
    if not self.session.remoteCounts then self.session.remoteCounts = {} end
    self:Log("Session restored.")
    LXCG:Fire("SESSION_CHANGED")
    LXCG:Fire("CARDS_CHANGED")
    LXCG:Fire("COUNTERS_CHANGED")
    return true
end

--------------------------------------------------------------------------------
-- Card instances
--------------------------------------------------------------------------------
function LXCG.Data:SpawnCard(templateId, zoneId)
    local s = self.session
    if not s or not s.zones[zoneId] then return nil end
    local zone = s.zones[zoneId]
    local inst = {
        id = LXCG:NewID(), templateId = templateId,
        owner = zone.owner or s.host, zoneId = zoneId,
        faceUp = zone.faceUp, landscape = false, dimmed = false,
        position = { x = 0.1 + math.random() * 0.8, y = 0.1 + math.random() * 0.8 },
        orderIndex = s.nextOrder, counters = {}, note = "",
    }
    s.nextOrder = s.nextOrder + 1
    s.instances[inst.id] = inst
    return inst
end

function LXCG.Data:SpawnRemoteCard(instId, templateId, tmplName, tmplIcon, tmplCat, tmplText, tmplFields, zoneId, owner, faceUp, landscape, dimmed, px, py, counters)
    local s = self.session
    if not s then return end
    if not s.remoteTemplates[templateId] then
        s.remoteTemplates[templateId] = {
            id = templateId, name = tmplName or "?",
            icon = LXCG:ResolveIcon(tmplIcon),
            category = tmplCat or "", text = tmplText or "",
            fields = tmplFields or {},
        }
    end
    local existing = s.instances[instId]
    if existing then
        existing.templateId = templateId
        existing.zoneId = zoneId
        existing.owner = owner or existing.owner
        existing.faceUp = faceUp ~= false
        existing.landscape = landscape == true
        existing.dimmed = dimmed == true
        existing.position = { x = tonumber(px) or 0.5, y = tonumber(py) or 0.5 }
        existing.orderIndex = s.nextOrder
        s.nextOrder = s.nextOrder + 1
        LXCG:Fire("CARDS_CHANGED")
        return existing
    end
    local inst = {
        id = instId, templateId = templateId, owner = owner or "?",
        zoneId = zoneId, faceUp = faceUp ~= false,
        landscape = landscape == true, dimmed = dimmed == true,
        position = { x = tonumber(px) or 0.5, y = tonumber(py) or 0.5 },
        orderIndex = s.nextOrder, counters = counters or {}, note = "",
    }
    s.nextOrder = s.nextOrder + 1
    s.instances[inst.id] = inst
    LXCG:Fire("CARDS_CHANGED")
    return inst
end

function LXCG.Data:MoveCard(instId, toZoneId, pos, isRemote)
    local s = self.session
    if not s then return end
    local inst = s.instances[instId]
    if not inst then return end
    local fromZone = s.zones[inst.zoneId]
    local toZone = s.zones[toZoneId]
    if not toZone then return end
    local wasVisible = (fromZone and fromZone.vis == "public") or inst.faceUp
    local nowPublic = toZone.vis == "public"
    inst.zoneId = toZoneId
    inst.faceUp = toZone.faceUp
    inst.orderIndex = s.nextOrder
    s.nextOrder = s.nextOrder + 1
    if pos then inst.position = pos
    elseif toZone.zoneType == "canvas" then
        inst.position = { x = 0.1 + math.random() * 0.8, y = 0.1 + math.random() * 0.8 }
    end
    self:Log("Moved " .. self:CardName(instId) .. " > " .. toZone.name)
    LXCG:Fire("CARDS_CHANGED")
    if not isRemote then
        if nowPublic then
            local tmpl = self:GetTemplate(inst.templateId)
            LXCG:Fire("NET_CARD_REVEALED", instId, inst, tmpl)
        elseif wasVisible then
            LXCG:Fire("NET_CARD_HIDDEN", instId)
        end
        LXCG:Fire("NET_COUNTS_CHANGED")
    end
end

function LXCG.Data:FlipCard(instId, isRemote)
    local s = self.session
    if not s then return end
    local inst = s.instances[instId]
    if not inst then return end
    inst.faceUp = not inst.faceUp
    self:Log((inst.faceUp and "Revealed " or "Concealed ") .. self:CardName(instId))
    LXCG:Fire("CARDS_CHANGED")
    if not isRemote then
        local zone = s.zones[inst.zoneId]
        if zone and zone.vis == "public" then
            LXCG:Fire("NET_CARD_FLIPPED", instId, inst.faceUp)
        elseif zone and zone.vis == "private" then
            if inst.faceUp then
                local tmpl = self:GetTemplate(inst.templateId)
                LXCG:Fire("NET_CARD_REVEALED", instId, inst, tmpl)
            else
                LXCG:Fire("NET_CARD_HIDDEN", instId)
            end
        end
    end
end

function LXCG.Data:ToggleLandscape(instId, isRemote)
    local s = self.session
    if not s then return end
    local inst = s.instances[instId]
    if not inst then return end
    inst.landscape = not inst.landscape
    self:Log("Turned " .. self:CardName(instId) .. (inst.landscape and " sideways" or " upright"))
    LXCG:Fire("CARDS_CHANGED")
    if not isRemote then LXCG:Fire("NET_CARD_LANDSCAPE", instId, inst.landscape) end
end

function LXCG.Data:ToggleDim(instId, isRemote)
    local s = self.session
    if not s then return end
    local inst = s.instances[instId]
    if not inst then return end
    inst.dimmed = not inst.dimmed
    LXCG:Fire("CARDS_CHANGED")
    if not isRemote then LXCG:Fire("NET_CARD_DIMMED", instId, inst.dimmed) end
end

function LXCG.Data:SetPosition(instId, x, y)
    local s = self.session
    if not s then return end
    local inst = s.instances[instId]
    if inst then inst.position.x = x; inst.position.y = y end
end

function LXCG.Data:FinalizePosition(instId, isRemote)
    local s = self.session
    if not s then return end
    local inst = s.instances[instId]
    if not inst then return end
    local zone = s.zones[inst.zoneId]
    if not isRemote and zone and zone.vis == "public" then
        LXCG:Fire("NET_CARD_MOVED", instId, inst.zoneId, inst.position.x, inst.position.y, inst.faceUp)
    end
end

function LXCG.Data:AddCounter(instId, name, delta, isRemote)
    local s = self.session
    if not s then return end
    local inst = s.instances[instId]
    if not inst then return end
    local val = (inst.counters[name] or 0) + (delta or 1)
    inst.counters[name] = val ~= 0 and val or nil
    LXCG:Fire("CARDS_CHANGED")
    if not isRemote then LXCG:Fire("NET_CARD_COUNTER", instId, name, inst.counters[name] or 0) end
end

function LXCG.Data:DestroyCard(instId, isRemote)
    local s = self.session
    if not s then return end
    local inst = s.instances[instId]
    if not inst then return end
    local zone = s.zones[inst.zoneId]
    self:Log("Removed " .. self:CardName(instId))
    s.instances[instId] = nil
    LXCG:Fire("CARDS_CHANGED")
    if not isRemote and zone and zone.vis == "public" then
        LXCG:Fire("NET_CARD_DESTROYED", instId)
    end
end

--------------------------------------------------------------------------------
-- Queries
--------------------------------------------------------------------------------
function LXCG.Data:CardsInZone(zoneId)
    local s = self.session
    if not s then return {} end
    local result = {}
    for _, inst in pairs(s.instances) do
        if inst.zoneId == zoneId then result[#result + 1] = inst end
    end
    table.sort(result, function(a, b) return a.orderIndex < b.orderIndex end)
    return result
end

function LXCG.Data:CountInZone(zoneId)
    local n = 0
    if not self.session then return 0 end
    for _, inst in pairs(self.session.instances) do
        if inst.zoneId == zoneId then n = n + 1 end
    end
    return n
end

function LXCG.Data:CardName(instId)
    local s = self.session
    if not s then return "?" end
    local inst = s.instances[instId]
    if not inst then return "?" end
    local t = self:GetTemplate(inst.templateId)
    return t and t.name or "?"
end

function LXCG.Data:GetMyCounts()
    local me = LXCG:PlayerName()
    return {
        deck = self:CountInZone(self:ZoneId(me, "deck")),
        hand = self:CountInZone(self:ZoneId(me, "hand")),
    }
end

function LXCG.Data:GetRemoteCounts(name)
    local s = self.session
    if not s or not s.remoteCounts[name] then return { deck = 0, hand = 0 } end
    return s.remoteCounts[name]
end

function LXCG.Data:GetPublicCards()
    local s = self.session
    if not s then return {} end
    local result = {}
    for _, inst in pairs(s.instances) do
        local zone = s.zones[inst.zoneId]
        if zone and (zone.vis == "public" or inst.faceUp) then
            result[#result + 1] = inst
        end
    end
    return result
end

--------------------------------------------------------------------------------
-- Deck operations
--------------------------------------------------------------------------------
function LXCG.Data:LoadDeck(deckId)
    local s = self.session
    if not s then return end
    local deck = self.decks[deckId]
    if not deck then return end
    local player = LXCG:PlayerName()
    local zid = self:ZoneId(player, "deck")
    local toRemove = {}
    for id, inst in pairs(s.instances) do
        if inst.owner == player then toRemove[#toRemove + 1] = id end
    end
    for _, id in ipairs(toRemove) do s.instances[id] = nil end
    for _, entry in ipairs(deck.cards) do
        for i = 1, entry.count do self:SpawnCard(entry.templateId, zid) end
    end
    self:ShuffleDeck()
    self:Log("Loaded deck: " .. deck.name .. " (" .. self:CountInZone(zid) .. " cards)")
    LXCG:Fire("CARDS_CHANGED")
    LXCG:Fire("NET_COUNTS_CHANGED")
end

function LXCG.Data:ShuffleDeck()
    local cards = self:CardsInZone(self:ZoneId(LXCG:PlayerName(), "deck"))
    for i = #cards, 2, -1 do
        local j = math.random(1, i)
        cards[i].orderIndex, cards[j].orderIndex = cards[j].orderIndex, cards[i].orderIndex
    end
    self:Log("Shuffled deck.")
    LXCG:Fire("CARDS_CHANGED")
    LXCG:Fire("NET_SHUFFLE")
end

function LXCG.Data:DrawCards(count)
    count = count or 1
    local player = LXCG:PlayerName()
    local deckZone = self:ZoneId(player, "deck")
    local handZone = self:ZoneId(player, "hand")
    local cards = self:CardsInZone(deckZone)
    local drawn = 0
    for i = 0, count - 1 do
        local card = cards[#cards - i]
        if card then
            card.zoneId = handZone
            card.faceUp = false
            card.orderIndex = self.session.nextOrder
            self.session.nextOrder = self.session.nextOrder + 1
            drawn = drawn + 1
        end
    end
    if drawn > 0 then
        self:Log("Drew " .. drawn .. " card" .. (drawn > 1 and "s" or ""))
        LXCG:Fire("CARDS_CHANGED")
        LXCG:Fire("NET_COUNTS_CHANGED")
    end
    return drawn
end

--------------------------------------------------------------------------------
-- Player counters
--------------------------------------------------------------------------------
function LXCG.Data:SetPlayerCounter(name, value, isRemote)
    local s = self.session
    if not s then return end
    local p = s.players[LXCG:PlayerName()]
    if p then p.counters[name] = value; LXCG:Fire("COUNTERS_CHANGED") end
    if not isRemote then LXCG:Fire("NET_PLAYER_COUNTER", name, value) end
end

function LXCG.Data:GetPlayerCounter(name)
    local s = self.session
    if not s then return 0 end
    local p = s.players[LXCG:PlayerName()]
    return p and p.counters[name] or 0
end

function LXCG.Data:GetOpponentCounter(counterName)
    local s = self.session
    if not s then return 0 end
    local opp = self:GetOpponent()
    if not opp or not s.players[opp] then return 0 end
    return s.players[opp].counters[counterName] or 0
end

--------------------------------------------------------------------------------
-- Log
--------------------------------------------------------------------------------
function LXCG.Data:Log(text)
    if not self.session then return end
    self.session.log[#self.session.log + 1] = { time = date("%H:%M:%S"), text = text }
    LXCG:Fire("LOG_CHANGED")
end
