-- SWNPCompat.lua  — SuperWoW + Nampower helpers for 1.12.1 (Lua 5.0 safe)

local SWNP = {}

-- Feature flags
SWNP.hasSW = (type(SUPERWOW_VERSION) == "string") or (type(SpellInfo) == "function")
SWNP.hasNP = (type(GetNampowerVersion) == "function")

-- Cache player GUID lazily (SuperWoW: UnitExists returns exists,guid)
local _player_guid_cached
function SWNP.PlayerGUID()
  if _player_guid_cached then return _player_guid_cached end
  if type(UnitExists) == "function" then
    local _, g = UnitExists("player")
    if type(g) == "string" and g ~= "" then
      _player_guid_cached = g
      return g
    end
  end
end

-- "Name (Rank X)" from spell id
function SWNP.LabelForId(id)
  if type(GetSpellNameAndRankForId) == "function" then
    local n, r = GetSpellNameAndRankForId(id)
    if n then return r and (n .. " (" .. r .. ")") or n end
  end
  if type(SpellInfo) == "function" then
    local n, r = SpellInfo(id)
    if n then return r and (n .. " (" .. r .. ")") or n end
  end
  if type(GetSpellName) == "function" then
    local n, r = GetSpellName(id, BOOKTYPE_SPELL)
    if r == "" then r = nil end
    if n then return r and (n .. " (" .. r .. ")") or n end
  end
  return tostring(id)
end

-- GUID helpers
local function _looks_like_guid(s)
  return type(s) == "string" and (string.find(s, "^0x") or string.find(s, "^[%x]+$"))
end

function SWNP.UnitGUID(unit_or_guid)
  if _looks_like_guid(unit_or_guid) then return unit_or_guid end
  if type(UnitExists) == "function" and unit_or_guid then
    local _, g = UnitExists(unit_or_guid)
    if type(g) == "string" and g ~= "" then return g end
  end
end

-- Cast by id directly to unit (uses NP no-queue when available)
function SWNP.CastByIdOnUnit(id, unit_or_guid)
  local label = SWNP.LabelForId(id)
  if SWNP.hasSW and type(CastSpellByName) == "function" then
    if SWNP.hasNP and type(CastSpellByNameNoQueue) == "function" then
      return CastSpellByNameNoQueue(label, unit_or_guid)
    else
      return CastSpellByName(label, unit_or_guid)
    end
  end
  -- Vanilla fallback: target mode
  if type(SpellIsTargeting) == "function" and SpellIsTargeting() then SpellStopTargeting() end
  CastSpell(id, BOOKTYPE_SPELL)
  if type(SpellIsTargeting) == "function" and SpellIsTargeting() then
    if type(SpellCanTargetUnit) ~= "function" or SpellCanTargetUnit(unit_or_guid) then
      SpellTargetUnit(unit_or_guid)
    else
      SpellStopTargeting()
    end
  end
end

-- Range / usability
function SWNP.IsInRange(id, unit)
  if type(IsSpellInRange) == "function" then
    local r = IsSpellInRange(id, unit)  -- 1=in, 0=out, -1=n/a
    return r ~= 0
  end
  return true
end

function SWNP.IsUsable(id)
  if type(IsSpellUsable) == "function" then
    local usable = IsSpellUsable(id)
    return usable == 1
  end
  return true
end

-- Temporary mouseover wrapper (SuperWoW)
function SWNP.WithMouseover(unit, fn)
  if type(SetMouseoverUnit) == "function" and unit then SetMouseoverUnit(unit) end
  local ok, err = pcall(fn)
  if type(SetMouseoverUnit) == "function" then SetMouseoverUnit() end
  if not ok then error(err) end
end

-- Event wiring (AceEvent-2.0 if present, else vanilla frame)
-- handlers: { EVENT = "MethodName" or function(...) end }
-- bucket:   { EVENT = seconds }  -- only used if AceEvent bucket is available
function SWNP.WireEvents(addon, handlers, bucket)
  handlers = handlers or {}
  bucket = bucket or {}

  if AceLibrary and AceLibrary:HasInstance("AceEvent-2.0") then
    local AceEvent = AceLibrary("AceEvent-2.0")
    for ev, cb in pairs(handlers) do
      if bucket[ev] and AceEvent.RegisterBucketEvent then
        AceEvent:RegisterBucketEvent(ev, bucket[ev], cb)
      else
        AceEvent:RegisterEvent(ev, cb)
      end
    end
    return
  end

  -- Vanilla 1.12 fallback (Lua 5.0): use global event/arg1..argN
  local f = CreateFrame("Frame")
  for ev in pairs(handlers) do f:RegisterEvent(ev) end
  f:SetScript("OnEvent", function()
    local ev = event                 -- global in 1.12
    local cb = handlers[ev]
    if type(cb) == "function" then
      cb(ev, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10)
    elseif type(addon) == "table" and type(addon[cb]) == "function" then
      addon[cb](addon, ev, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10)
    end
  end)
end

_G.SWNP = SWNP
