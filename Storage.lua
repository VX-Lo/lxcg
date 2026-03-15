--------------------------------------------------------------------------------
-- LXCG Storage.lua v0.4
--------------------------------------------------------------------------------
LXCG.Storage = {}

function LXCG.Storage:Init()
    if not LXCG_AccountDB then
        LXCG_AccountDB = { templates = {}, decks = {}, version = LXCG.VERSION }
    end
    if not LXCG_CharDB then
        LXCG_CharDB = { version = LXCG.VERSION, prefs = {} }
    end
    if not LXCG_CharDB.prefs then LXCG_CharDB.prefs = {} end
    LXCG.Data.templates = LXCG_AccountDB.templates
    LXCG.Data.decks     = LXCG_AccountDB.decks
    if LXCG_CharDB.session then
        LXCG.Data:RestoreSession(LXCG_CharDB.session)
    end
end

function LXCG.Storage:Save()
    LXCG_AccountDB.templates = LXCG.Data.templates
    LXCG_AccountDB.decks     = LXCG.Data.decks
    LXCG_AccountDB.version   = LXCG.VERSION
    LXCG_CharDB.session      = LXCG.Data:SerializeSession()
    LXCG_CharDB.version      = LXCG.VERSION
end

function LXCG.Storage:GetPrefs()
    return LXCG_CharDB and LXCG_CharDB.prefs or {}
end

function LXCG.Storage:SetPref(key, val)
    if not LXCG_CharDB then LXCG_CharDB = { prefs = {} } end
    if not LXCG_CharDB.prefs then LXCG_CharDB.prefs = {} end
    LXCG_CharDB.prefs[key] = val
end
