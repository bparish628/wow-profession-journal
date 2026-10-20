local _, PJ = ...

-- Blizzard's own "where to learn this" text, cached per recipe whenever the
-- player opens a profession. It covers recipes the generated data can't source.
local function CacheSourceText()
  local cache = PJ.db.sourceText
  for _, recipeID in ipairs(C_TradeSkillUI.GetAllRecipeIDs()) do
    local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
    if info and not info.learned then
      cache[recipeID] = C_TradeSkillUI.GetRecipeSourceText(recipeID) or cache[recipeID]
    end
  end
end

function PJ.BlizzardSourceText(recipe)
  return PJ.db.sourceText[recipe.spell]
end

local events = CreateFrame("Frame")
events:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
events:SetScript("OnEvent", CacheSourceText)
