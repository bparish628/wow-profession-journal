local addonName, PJ = ...
_G.ProfessionJournal = PJ

PJ.professions = {}
PJ.recipes = {}

function PJ.RegisterProfession(profession)
  PJ.professions[#PJ.professions + 1] = profession
end

function PJ.RegisterRecipe(recipe)
  PJ.recipes[#PJ.recipes + 1] = recipe
end

function PJ.RecipesFor(professionID, query)
  query = query and query:lower() or ""
  local list = {}
  for _, recipe in ipairs(PJ.recipes) do
    if recipe.profession == professionID
      and (query == "" or (PJ.RecipeName(recipe):lower():find(query, 1, true))) then
      list[#list + 1] = recipe
    end
  end
  table.sort(list, function(a, b) return PJ.RequiredSkill(a) < PJ.RequiredSkill(b) end)
  return list
end

function PJ.RequiredSkill(recipe)
  return recipe.skill or recipe.yellow
end

function PJ.GreenSkill(recipe)
  return math.floor((recipe.yellow + recipe.grey) / 2)
end

function PJ.PlayerSkill(profession)
  for _, index in pairs({ GetProfessions() }) do
    local _, _, rank, maxRank, _, _, skillLine = GetProfessionInfo(index)
    if skillLine == profession.id or tContains(profession.tiers, skillLine) then
      return rank, maxRank
    end
  end
end

-- The trade skill difficulty a recipe has at the given rank, as the default
-- profession window colors it.
function PJ.Difficulty(recipe, rank)
  if rank < PJ.RequiredSkill(recipe) then return "impossible" end
  if rank < recipe.yellow then return "optimal" end
  if rank < PJ.GreenSkill(recipe) then return "medium" end
  if rank < recipe.grey then return "easy" end
  return "trivial"
end

function PJ.RecipeName(recipe)
  return C_Spell.GetSpellName(recipe.spell) or ("Spell " .. recipe.spell)
end

function PJ.RecipeIcon(recipe)
  if recipe.creates then
    return C_Item.GetItemIconByID(recipe.creates)
  end
  return C_Spell.GetSpellTexture(recipe.spell)
end

function PJ.IsKnown(recipe)
  return IsPlayerSpell(recipe.spell)
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
