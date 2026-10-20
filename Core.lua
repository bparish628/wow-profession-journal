local addonName, PJ = ...
_G.ProfessionJournal = PJ

PJ.GROUPS = { "crafting", "gathering", "secondary" }
PJ.professions = {}
PJ.entries = {}
PJ.zones = {}

function PJ.RegisterProfession(profession)
  PJ.professions[#PJ.professions + 1] = profession
end

-- Gathering skill-ups follow a fixed ladder above the required skill.
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
  PJ.entries[#PJ.entries + 1] = WithGatheringLadder(node)
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

function PJ.EntriesFor(professionID, query)
  query = query and query:lower() or ""
  local list = {}
  for _, entry in ipairs(PJ.entries) do
    if entry.profession == professionID
      and (query == "" or PJ.EntryName(entry):lower():find(query, 1, true)) then
      list[#list + 1] = entry
    end
  end
  table.sort(list, function(a, b) return PJ.RequiredSkill(a) < PJ.RequiredSkill(b) end)
  return list
end

function PJ.RequiredSkill(entry)
  return entry.skill or entry.yellow
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
