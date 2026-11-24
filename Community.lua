local ADDON, ns = ...

-- Community data: loot recorded by MoldyDrops players and combined on the
-- website, as a MoldyDrops data source. It's recorded data: the tooltip uses
-- it for a mob once it has enough kills.
--
-- The data comes from two places, and the newer one is used:
--   * the snapshot bundled with this addon (Snapshot.lua, ns.SNAPSHOT), updated
--     with each release of the addon;
--   * a snapshot you pasted with /drops import (MoldyDrops hands it to Import),
--     kept in SavedVariables MoldyDropsCommunityDB.imported until a newer
--     bundled one replaces it.
-- Either way it's a parsed snapshot (MoldyDrops' Codec.ParseSnapshot):
--   npcs[npcID]    counted drop records (see Codec.Rates in MoldyDrops/Codec.lua)
--   gather[npcID]  counted skinning / herbalism / mining / engineering records (.kind 1-4)
--   pick[npcID]    counted pick pocketing records (.kind 5)
--   items[itemID] = { name, quality }, mobs[npcID] = { name }: names from the snapshot
--   generated (date), generatedAt (unix time), contributors
local api = MoldyDrops
if type(api) ~= "table" or (api.API_VERSION or 0) < 1 then return end

local function Data(community, items, mobs, bundled)
  return {
    npcs = community.npcs or {}, gather = community.gather or {}, pick = community.pick or {},
    items = items or {}, mobs = mobs or {},
    generated = community.generated, generatedAt = tonumber(community.generatedAt) or 0,
    contributors = community.contributors, bundled = bundled,
  }
end

local bundled  -- the bundled snapshot, parsed (false if there isn't one or it's damaged)
local active   -- the data in use: the imported or the bundled snapshot

local function Bundled()
  if bundled == nil then
    bundled = false
    if type(ns.SNAPSHOT) == "string" and ns.SNAPSHOT ~= "" then
      local community, items, _, mobs = api.Codec.ParseSnapshot(ns.SNAPSHOT)
      if community then
        bundled = Data(community, items, mobs, true)
      else
        geterrorhandler()("MoldyDrops_Community: the bundled snapshot is damaged: " .. tostring(items))
      end
    end
  end
  return bundled or nil
end

-- The newer of the imported and the bundled snapshot. An import older than
-- the bundled snapshot is dropped, so it doesn't take up space.
local function Active()
  if active == nil then
    local db = MoldyDropsCommunityDB
    local imported = db and type(db.imported) == "table" and db.imported or nil
    local b = Bundled()
    if imported and b and (tonumber(imported.generatedAt) or 0) < b.generatedAt then
      db.imported, imported = nil, nil
    end
    active = imported or b or false
  end
  return active or nil
end
ns.Active = Active

-- Uses a parsed snapshot (Codec.ParseSnapshot's results) from /drops import.
-- Returns false if the bundled snapshot is newer, which then stays in use.
function ns.Store(community, items, mobs)
  local data = Data(community, items, mobs, false)
  local b = Bundled()
  if b and data.generatedAt < b.generatedAt then return false end
  MoldyDropsCommunityDB = MoldyDropsCommunityDB or {}
  MoldyDropsCommunityDB.imported = data
  active = data
  api.DataChanged()
  return true
end

-- Forget what's loaded (tests, and a new bundled snapshot).
function ns.Reload()
  bundled, active = nil, nil
  api.DataChanged()
end

local Rates = api.Codec.Rates
local source = {
  id = "community",
  name = "Community data",
  label = "community",
  description = "Loot recorded by MoldyDrops players and combined on the website. Comes with this addon; "
    .. "/drops import loads a newer snapshot from the website.",
  observed = true,
  order = 20,
}

function source:Drops(npcID) local d = Active(); return d and Rates(d.npcs[npcID]) end
function source:Gather(npcID) local d = Active(); return d and Rates(d.gather[npcID]) end
function source:Pick(npcID) local d = Active(); return d and Rates(d.pick[npcID]) end

function source:ItemInfo(itemID)
  local d = Active()
  local i = d and d.items[itemID]
  if i then return i[1], i[2] end
end

function source:MobInfo(npcID)
  local d = Active()
  local m = d and d.mobs[npcID]
  if m then return m[1] end
end

function source:Npcs(section)
  local d = Active()
  if not d then return nil end
  if section == "drop" then return d.npcs end
  if section == "gather" then return d.gather end
  if section == "pick" then return d.pick end
  if section == "mob" then return d.mobs end
end

function source:Stats()
  local d = Active()
  if not d then
    return { "none yet. Update MoldyDrops_Community, or get it from the website and use /drops import." }
  end
  local n, kills = 0, 0
  for _, e in pairs(d.npcs) do n, kills = n + 1, kills + (e[0] or 0) end
  return {
    ("|cffffffff%d|r kills of |cffffffff%d|r mobs, from |cffffffff%d|r contributors, generated %s (%s)"):format(
      kills, n, d.contributors or 0, tostring(d.generated), d.bundled and "bundled" or "imported"),
  }
end

-- Takes a website snapshot from /drops import (MoldyDrops hands it to every
-- source that has Import).
function source:Import(community, items, mobs)
  if not ns.Store(community, items, mobs) then
    api.Print(("that snapshot (%s) is older than the one this addon came with (%s), so it wasn't used."):format(
      tostring(community.generated), tostring(Bundled().generated)))
  end
  return true
end

api.RegisterSource(source)
ns.source = source

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, _, name)
  if name ~= ADDON then return end
  self:UnregisterEvent("ADDON_LOADED")
  MoldyDropsCommunityDB = MoldyDropsCommunityDB or {}
  -- 0.2 kept the imported data at the top level; start fresh.
  for k in pairs(MoldyDropsCommunityDB) do
    if k ~= "imported" then MoldyDropsCommunityDB[k] = nil end
  end
  ns.Reload()
end)
