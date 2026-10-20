local addonName, PJ = ...
_G.ProfessionJournal = PJ

PJ.GROUPS = { "crafting", "gathering", "secondary" }
PJ.professions = {}
PJ.entries = {}
PJ.zones = {}
PJ.categories = {}

function PJ.RegisterProfession(profession)
  PJ.professions[#PJ.professions + 1] = profession
end

-- Herbalism, mining, and skinning skill-ups follow a fixed ladder above the
-- required skill. Fishing has no such ladder.
local HERBALISM, MINING, FISHING = 182, 186, 356

local function WithGatheringLadder(entry)
  entry.yellow = entry.skill + 25
  entry.green = entry.skill + 50
  entry.grey = entry.skill + 100
  return entry
end

function PJ.RegisterRecipe(recipe)
  recipe.kind = "recipe"
  PJ.entries[#PJ.entries + 1] = recipe
end

function PJ.RegisterNode(node)
  node.kind = "node"
  if node.profession ~= FISHING then WithGatheringLadder(node) end
  PJ.entries[#PJ.entries + 1] = node
end

function PJ.RegisterWater(water)
  water.kind = "water"
  PJ.entries[#PJ.entries + 1] = water
end

function PJ.RegisterSkinningBand(band)
  band.kind = "band"
  PJ.entries[#PJ.entries + 1] = WithGatheringLadder(band)
end

function PJ.RegisterZone(zone)
  PJ.zones[#PJ.zones + 1] = zone
end

local KINDS = {
  recipe = {
    name = function(recipe) return C_Spell.GetSpellName(recipe.spell) or ("Spell " .. recipe.spell) end,
    icon = function(recipe)
      if recipe.creates then return C_Item.GetItemIconByID(recipe.creates) end
      return C_Spell.GetSpellTexture(recipe.spell)
    end,
    known = function(recipe) return IsPlayerSpell(recipe.spell) end,
  },
  node = {
    name = function(node) return node.name end,
    icon = function(node) return C_Item.GetItemIconByID(node.yields[1]) end,
  },
  band = {
    name = function(band) return ("Level %d-%d beasts"):format(band.minLevel, band.maxLevel) end,
    icon = function(band) return C_Item.GetItemIconByID(band.yields[1]) end,
  },
  water = {
    name = function(water)
      local info = C_Map.GetMapInfo(water.map)
      return info and info.name or ("Map " .. water.map)
    end,
    icon = function(water) return C_Item.GetItemIconByID(water.yields[1]) end,
  },
}

function PJ.EntryName(entry)
  return KINDS[entry.kind].name(entry)
end

function PJ.EntryIcon(entry)
  return KINDS[entry.kind].icon(entry)
end

-- Gathering entries have nothing to learn, so only recipes can be unknown.
function PJ.IsKnown(entry)
  local known = KINDS[entry.kind].known
  return known == nil or known(entry)
end

function PJ.RegisterCategory(category)
  PJ.categories[category.id] = category
end

function PJ.EntryKey(entry)
  return entry.kind .. ":" .. (entry.spell or entry.name or entry.map or entry.minLevel)
end

function PJ.IsFavorite(entry)
  return PJ.db.favorites[PJ.EntryKey(entry)] == true
end

function PJ.ToggleFavorite(entry)
  local key = PJ.EntryKey(entry)
  PJ.db.favorites[key] = not PJ.db.favorites[key] or nil
end

local FAVORITES_GROUP = { key = "favorites", name = FAVORITES or "Favorites", order = -1 }
local OTHER_GROUP = { key = "other", name = "Other", order = math.huge }
local NODE_GROUPS = {
  [HERBALISM] = { key = "nodes", name = "Herbs", order = 0 },
  [MINING] = { key = "nodes", name = "Mineral Veins", order = 0 },
  [FISHING] = { key = "nodes", name = "Fishing Pools", order = 1 },
}
local KIND_GROUPS = {
  band = { key = "bands", name = "Beasts by Level", order = 0 },
  water = { key = "waters", name = "Fishing Waters", order = 0 },
}

local function GroupOf(entry)
  if PJ.IsFavorite(entry) then return FAVORITES_GROUP end
  local category = entry.category and PJ.categories[entry.category]
  if category then return { key = category.id, name = category.name, order = category.order } end
  if entry.kind == "node" then return NODE_GROUPS[entry.profession] end
  return KIND_GROUPS[entry.kind] or OTHER_GROUP
end

local function PassesFilters(entry, filters, rank)
  local known = PJ.IsKnown(entry)
  if known and not filters.learned then return false end
  if not known and not filters.unlearned then return false end
  if filters.skillUps then
    return rank ~= nil and entry.grey ~= nil and rank >= PJ.RequiredSkill(entry) and rank < entry.grey
  end
  return true
end

-- The list the journal shows for a profession: entries matching the search
-- and filters, grouped under headers in category order. Collapsed groups keep
-- their header and hide their entries.
function PJ.ListFor(profession, query, filters, collapsed)
  query = query and query:lower() or ""
  local rank = PJ.PlayerSkill(profession)
  local groups, byKey = {}, {}
  for _, entry in ipairs(PJ.entries) do
    if entry.profession == profession.id
      and (query == "" or PJ.EntryName(entry):lower():find(query, 1, true))
      and PassesFilters(entry, filters, rank) then
      local group = GroupOf(entry)
      if not byKey[group.key] then
        byKey[group.key] = { header = group, entries = {} }
        groups[#groups + 1] = byKey[group.key]
      end
      table.insert(byKey[group.key].entries, entry)
    end
  end
  table.sort(groups, function(a, b)
    if a.header.order ~= b.header.order then return a.header.order < b.header.order end
    return a.header.name < b.header.name
  end)
  local list = {}
  for _, group in ipairs(groups) do
    local isCollapsed = collapsed[group.header.key] == true
    list[#list + 1] = { header = group.header, collapsed = isCollapsed }
    if not isCollapsed then
      table.sort(group.entries, function(a, b)
        if PJ.RequiredSkill(a) ~= PJ.RequiredSkill(b) then return PJ.RequiredSkill(a) < PJ.RequiredSkill(b) end
        if (a.minLevel or 0) ~= (b.minLevel or 0) then return (a.minLevel or 0) < (b.minLevel or 0) end
        return PJ.EntryName(a) < PJ.EntryName(b)
      end)
      for _, entry in ipairs(group.entries) do list[#list + 1] = entry end
    end
  end
  return list
end

function PJ.RequiredSkill(entry)
  return entry.skill or entry.yellow or 0
end

function PJ.HasLadder(entry)
  return entry.yellow ~= nil
end

function PJ.GreenSkill(entry)
  return entry.green or math.floor((entry.yellow + entry.grey) / 2)
end

function PJ.PlayerSkill(profession)
  for _, index in pairs({ GetProfessions() }) do
    local _, _, rank, maxRank, _, _, skillLine = GetProfessionInfo(index)
    if skillLine == profession.id or tContains(profession.tiers, skillLine) then
      return rank, maxRank
    end
  end
end

-- The difficulty an entry has at the given rank, as the default profession
-- window and gathering tooltips color it.
function PJ.Difficulty(entry, rank)
  if rank < PJ.RequiredSkill(entry) then return "impossible" end
  if not PJ.HasLadder(entry) then return nil end
  if rank < entry.yellow then return "optimal" end
  if rank < PJ.GreenSkill(entry) then return "medium" end
  if rank < entry.grey then return "easy" end
  return "trivial"
end

function PJ.ZonesForLevels(minLevel, maxLevel)
  local list = {}
  for _, zone in ipairs(PJ.zones) do
    if zone.minLevel <= maxLevel and zone.maxLevel >= minLevel then list[#list + 1] = zone end
  end
  table.sort(list, function(a, b) return a.minLevel < b.minLevel end)
  return list
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, loaded)
  if loaded ~= addonName then return end
  ProfessionJournalDB = ProfessionJournalDB or {}
  PJ.db = ProfessionJournalDB
  PJ.db.sourceText = PJ.db.sourceText or {}
  PJ.db.favorites = PJ.db.favorites or {}
  PJ.db.filters = PJ.db.filters or { learned = true, unlearned = true, skillUps = false }
  PJ.db.minimap = PJ.db.minimap or { show = true, angle = 225 }
  PJ.CreateMinimapButton()
  PJ.RegisterSettings()
  events:UnregisterEvent("ADDON_LOADED")
end)

SLASH_PROFESSIONJOURNAL1 = "/pj"
SLASH_PROFESSIONJOURNAL2 = "/professionjournal"
SlashCmdList.PROFESSIONJOURNAL = function(input)
  if input:lower():match("^%s*options") then
    PJ.OpenSettings()
  else
    PJ.ToggleJournal()
  end
end

function ProfessionJournal_OnAddonCompartmentClick()
  PJ.ToggleJournal()
end
