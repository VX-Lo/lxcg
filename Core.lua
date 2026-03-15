--------------------------------------------------------------------------------
-- LXCG Core.lua v0.4
--------------------------------------------------------------------------------
LXCG = {}
LXCG.VERSION = "0.4.0"
LXCG.MSG_PREFIX = "LXCG"

LXCG.ZONE_TYPE_STACK  = "stack"
LXCG.ZONE_TYPE_FAN    = "fan"
LXCG.ZONE_TYPE_CANVAS = "canvas"
LXCG.VIS_PUBLIC  = "public"
LXCG.VIS_PRIVATE = "private"

LXCG.DEFAULT_ZONES = {
    { key = "deck",    name = "Deck",    zoneType = "stack",  vis = "private", faceUp = false },
    { key = "hand",    name = "Hand",    zoneType = "fan",    vis = "private", faceUp = false },
    { key = "field",   name = "Field",   zoneType = "canvas", vis = "public",  faceUp = true  },
    { key = "discard", name = "Discard", zoneType = "stack",  vis = "public",  faceUp = true  },
}

LXCG.CARD_BACK = "Interface\\Icons\\INV_Misc_QuestionMark"
LXCG.CARD_W = 64
LXCG.CARD_H = 90
LXCG.COLOR_MINE     = { 0.3, 0.5, 0.8 }
LXCG.COLOR_OPP      = { 0.8, 0.3, 0.3 }
LXCG.COLOR_REVEALED = { 0.8, 0.7, 0.2 }

--------------------------------------------------------------------------------
LXCG._listeners = {}
function LXCG:On(event, fn)
    if not self._listeners[event] then self._listeners[event] = {} end
    self._listeners[event][#self._listeners[event] + 1] = fn
end
function LXCG:Fire(event, ...)
    local list = self._listeners[event]
    if list then for i = 1, #list do list[i](...) end end
end

--------------------------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGOUT")
boot:SetScript("OnEvent", function(_, ev, arg1)
    if ev == "ADDON_LOADED" and arg1 == "LXCG" then
        LXCG.Storage:Init()
        C_ChatInfo.RegisterAddonMessagePrefix(LXCG.MSG_PREFIX)
        LXCG.Network:Init()
        if math.randomseed then
            math.randomseed(GetTime() * 10000 + time())
        else
            math.random()
        end
        print("|cff00ccffLXCG|r v" .. LXCG.VERSION .. " loaded. |cff00ccff/lxcg help|r")
    elseif ev == "PLAYER_LOGOUT" then
        LXCG.Storage:Save()
    end
end)

--------------------------------------------------------------------------------
SLASH_LXCG1 = "/lxcg"
SlashCmdList["LXCG"] = function(msg)
    local args = { strsplit(" ", strtrim(msg or "")) }
    local cmd = strlower(args[1] or "")
    if cmd == "" or cmd == "table" then
        LXCG.Table:Toggle()
    elseif cmd == "builder" or cmd == "deck" then
        LXCG.Builder:Toggle()
    elseif cmd == "invite" and args[2] then
        LXCG.Network:InvitePlayer(args[2])
    elseif cmd == "leave" then
        LXCG.Network:LeaveSession()
    elseif cmd == "sync" then
        LXCG.Network:RequestSync()
    elseif cmd == "cardback" and args[2] then
        LXCG.Storage:SetPref("cardBack", args[2])
        print("|cff00ccffLXCG:|r Card back set.")
    elseif cmd == "reset" then
        LXCG.Network:LeaveSession()
        LXCG.Data:EndSession()
        LXCG_CharDB.session = nil
        print("|cff00ccffLXCG:|r Session cleared.")
    elseif cmd == "help" then
        print("|cff00ccffLXCG:|r /lxcg - Toggle table")
        print("|cff00ccffLXCG:|r /lxcg builder - Deck builder")
        print("|cff00ccffLXCG:|r /lxcg invite <name> - Invite player")
        print("|cff00ccffLXCG:|r /lxcg leave - Leave session")
        print("|cff00ccffLXCG:|r /lxcg sync - Resync")
        print("|cff00ccffLXCG:|r /lxcg cardback <icon> - Set card back")
        print("|cff00ccffLXCG:|r /lxcg reset - Clear session")
    else
        print("|cff00ccffLXCG:|r Unknown command. /lxcg help")
    end
end

--------------------------------------------------------------------------------
local _idc = 0
function LXCG:NewID()
    _idc = _idc + 1
    return format("id_%x_%x", time(), _idc)
end

function LXCG:DeepCopy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = self:DeepCopy(v) end
    return c
end

function LXCG:PlayerName()
    return UnitName("player")
end

function LXCG:NormalizeName(name)
    if not name then return nil end
    if Ambiguate then return Ambiguate(name, "none") end
    return name:match("^([^%-]+)") or name
end

function LXCG:ResolveIcon(input)
    if type(input) == "number" then return input end
    if not input or input == "" then return self.CARD_BACK end
    local num = tonumber(input)
    if num then return num end
    if not input:find("\\") then return "Interface\\Icons\\" .. input end
    return input
end

function LXCG:GetCardBack(playerName)
    if not playerName or playerName == self:PlayerName() then
        local prefs = self.Storage and self.Storage:GetPrefs() or {}
        if prefs.cardBack then return self:ResolveIcon(prefs.cardBack) end
        return self.CARD_BACK
    end
    local s = self.Data and self.Data.session
    if s and s.players[playerName] and s.players[playerName].cardBack then
        return self:ResolveIcon(s.players[playerName].cardBack)
    end
    return self.CARD_BACK
end
