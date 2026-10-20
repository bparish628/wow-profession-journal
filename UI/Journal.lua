local _, PJ = ...

local LIST_WIDTH = 260
local ROW_HEIGHT = 36
local SOURCE_KINDS = {
  trainer = { label = "Trainer", icon = "Interface\\Icons\\INV_Misc_Book_09" },
  drop = { label = "Drop", icon = "Interface\\Icons\\INV_Misc_Bag_10" },
  worlddrop = { label = "World drop", icon = "Interface\\Icons\\INV_Misc_Bag_10" },
  vendor = { label = "Vendor", icon = "Interface\\Icons\\INV_Misc_Coin_01" },
  quest = { label = "Quest", icon = "Interface\\Icons\\INV_Misc_Note_01" },
  object = { label = "Container", icon = "Interface\\Icons\\INV_Box_01" },
  unknown = { label = "Source unknown", icon = "Interface\\Icons\\INV_Misc_QuestionMark" },
}
local UNKNOWN_SOURCE = { kind = "unknown" }

local journal, selectedProfession, selectedRecipe

local function ResetRow(row)
  row:Hide()
  row:ClearAllPoints()
  row.Border:Hide()
  row.Count:SetText("")
  row:SetScript("OnClick", nil)
  row:SetScript("OnEnter", nil)
  row:SetScript("OnLeave", GameTooltip_Hide)
end

local function CreateRow(parent, height)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(height)
  row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  row.Icon = row:CreateTexture(nil, "ARTWORK")
  row.Icon:SetSize(height - 6, height - 6)
  row.Icon:SetPoint("LEFT", 4, 0)
  row.Border = row:CreateTexture(nil, "OVERLAY")
  row.Border:SetTexture("Interface\\Common\\WhiteIconFrame")
  row.Border:SetAllPoints(row.Icon)
  row.Count = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  row.Count:SetPoint("RIGHT", -8, 0)
  row.Text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  row.Text:SetPoint("LEFT", row.Icon, "RIGHT", 8, 0)
  row.Text:SetPoint("RIGHT", row.Count, "LEFT", -8, 0)
  row.Text:SetJustifyH("LEFT")
  row.Text:SetWordWrap(false)
  ResetRow(row)
  return row
end

local function ShowTextTooltip(owner, text)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(text, nil, nil, nil, nil, true)
  GameTooltip:Show()
end

local function ItemLabel(itemID)
  local name = C_Item.GetItemNameByID(itemID)
  if not name then
    C_Item.RequestLoadItemDataByID(itemID)
    return RETRIEVING_ITEM_INFO
  end
  local quality = C_Item.GetItemQualityByID(itemID)
  local color = quality and ITEM_QUALITY_COLORS[quality]
  return color and color.color:WrapTextInColorCode(name) or name
end

local function HandleLinkClick(link)
  return IsModifiedClick() and link ~= nil and HandleModifiedItemClick(link)
end

-- Shift-click links the item in chat and ctrl-click previews it, as anywhere
-- in the default UI. A plain click runs the row's own action.
local function SetItemRow(row, itemID, onClick)
  row.Icon:SetTexture(C_Item.GetItemIconByID(itemID))
  local quality = C_Item.GetItemQualityByID(itemID)
  if quality and quality > Enum.ItemQuality.Common then
    row.Border:SetVertexColor(ITEM_QUALITY_COLORS[quality].color:GetRGB())
    row.Border:Show()
  end
  row.Text:SetText(ItemLabel(itemID))
  row:SetScript("OnClick", function()
    if not HandleLinkClick(select(2, C_Item.GetItemInfo(itemID))) then onClick() end
  end)
  row:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(itemID)
    GameTooltip:Show()
  end)
end

local function SourceText(source)
  local text = SOURCE_KINDS[source.kind].label
  local who = source.npc or source.quest or source.object
  if who then text = text .. ": " .. who end
  if source.chance then text = text .. (" (%s%%)"):format(source.chance) end
  local area = source.area and C_Map.GetAreaInfo(source.area)
  if area then text = text .. " |cffffffff- " .. area .. "|r" end
  return text
end

local function SkillText(recipe)
  local green = math.floor((recipe.yellow + recipe.grey) / 2)
  local required = recipe.skill and ("Requires %d  "):format(recipe.skill) or ""
  return required .. ORANGE_FONT_COLOR:WrapTextInColorCode(recipe.skill or "?") .. " "
    .. YELLOW_FONT_COLOR:WrapTextInColorCode(recipe.yellow) .. " "
    .. GREEN_FONT_COLOR:WrapTextInColorCode(green) .. " "
    .. GRAY_FONT_COLOR:WrapTextInColorCode(recipe.grey)
end

local function RecipeLink(recipe)
  if recipe.creates then return select(2, C_Item.GetItemInfo(recipe.creates)) end
  return C_Spell.GetSpellLink(recipe.spell)
end

local function RenderDetail()
  local detail = journal.Detail
  detail.rows:ReleaseAll()
  local recipe = selectedRecipe
  detail:SetShown(recipe ~= nil)
  if not recipe then return end

  detail.Icon:SetTexture(PJ.RecipeIcon(recipe))
  detail.Name:SetText(recipe.creates and ItemLabel(recipe.creates) or PJ.RecipeName(recipe))
  local status = PJ.IsKnown(recipe) and GREEN_FONT_COLOR:WrapTextInColorCode("Known")
    or GRAY_FONT_COLOR:WrapTextInColorCode("Not learned")
  detail.Skill:SetText(SkillText(recipe) .. "  " .. status)

  local anchor = detail.SourcesHeader
  local function Place(region, gap)
    region:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(gap or 4))
    region:SetPoint("RIGHT", detail, "RIGHT", -8, 0)
    region:Show()
    anchor = region
  end

  if recipe.recipeItem then
    local row = detail.rows:Acquire()
    SetItemRow(row, recipe.recipeItem, function() PJ.SearchAuctionHouse(recipe.recipeItem) end)
    Place(row)
  end

  local blizzardText = PJ.BlizzardSourceText(recipe)
  local sources = recipe.sources
  if #sources == 0 and not blizzardText then sources = { UNKNOWN_SOURCE } end
  for _, source in ipairs(sources) do
    local row = detail.rows:Acquire()
    row.Text:SetText(SourceText(source))
    if source.map then
      row.Icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
      row:SetScript("OnClick", function() PJ.ShowSourceOnMap(source) end)
      row:SetScript("OnEnter", function(self)
        ShowTextTooltip(self, ("Click to pin %.1f, %.1f on the world map"):format(source.x, source.y))
      end)
    else
      row.Icon:SetTexture(SOURCE_KINDS[source.kind].icon)
    end
    Place(row)
  end

  detail.BlizzardSource:SetShown(blizzardText ~= nil)
  if blizzardText then
    detail.BlizzardSource:SetText(blizzardText)
    Place(detail.BlizzardSource, 8)
  end

  detail.ReagentsHeader:ClearAllPoints()
  Place(detail.ReagentsHeader, 16)
  for _, reagent in ipairs(recipe.reagents) do
    local row = detail.rows:Acquire()
    SetItemRow(row, reagent.item, function() PJ.SearchAuctionHouse(reagent.item) end)
    local have = C_Item.GetItemCount(reagent.item, true)
    local color = have >= reagent.count and GREEN_FONT_COLOR or RED_FONT_COLOR
    row.Count:SetText(color:WrapTextInColorCode(("%d/%d"):format(have, reagent.count)))
    Place(row)
  end
  detail.AuctionHint:SetShown(PJ.IsAuctionHouseOpen())
end

local function RenderList()
  local recipes = PJ.RecipesFor(selectedProfession.id, journal.SearchBox:GetText())
  journal.ScrollBox:SetDataProvider(CreateDataProvider(recipes), ScrollBoxConstants.RetainScrollPosition)
  journal:SetTitle(("Profession Journal - %s"):format(selectedProfession.name))
  journal:SetPortraitToAsset(selectedProfession.icon)
  for _, tab in ipairs(journal.Tabs) do
    tab:SetChecked(tab.profession == selectedProfession)
  end
end

local function SelectProfession(profession)
  selectedProfession = profession
  selectedRecipe = nil
  RenderList()
  RenderDetail()
end

local function SelectRecipe(recipe)
  selectedRecipe = recipe
  journal.ScrollBox:ForEachFrame(function(row) row.Selected:SetShown(row:GetElementData() == recipe) end)
  RenderDetail()
end

local function InitRecipeRow(row, recipe)
  if not row.Icon then
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.Selected = row:CreateTexture(nil, "BACKGROUND")
    row.Selected:SetAllPoints()
    row.Selected:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.Selected:SetBlendMode("ADD")
    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(ROW_HEIGHT - 6, ROW_HEIGHT - 6)
    row.Icon:SetPoint("LEFT", 4, 0)
    row.Name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.Name:SetPoint("TOPLEFT", row.Icon, "TOPRIGHT", 8, -2)
    row.Name:SetPoint("RIGHT", -6, 0)
    row.Name:SetJustifyH("LEFT")
    row.Name:SetWordWrap(false)
    row.Sub = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Sub:SetPoint("BOTTOMLEFT", row.Icon, "BOTTOMRIGHT", 8, 2)
    row:SetScript("OnClick", function(self)
      local data = self:GetElementData()
      if not HandleLinkClick(RecipeLink(data)) then SelectRecipe(data) end
    end)
  end
  row.Icon:SetTexture(PJ.RecipeIcon(recipe))
  row.Icon:SetDesaturated(not PJ.IsKnown(recipe))
  row.Name:SetText(PJ.RecipeName(recipe))
  row.Sub:SetText(("Skill %d"):format(PJ.RequiredSkill(recipe)))
  row.Selected:SetShown(recipe == selectedRecipe)
end

local function CreateProfessionTab(frame, profession, index)
  local tab = CreateFrame("CheckButton", nil, frame)
  tab:SetSize(32, 32)
  tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -40 - (index - 1) * 44)
  tab:SetNormalTexture(profession.icon)
  tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  tab:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
  local border = tab:CreateTexture(nil, "BACKGROUND")
  border:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
  border:SetSize(64, 64)
  border:SetPoint("TOPLEFT", -3, 11)
  tab.profession = profession
  tab:SetScript("OnClick", function() SelectProfession(profession) end)
  tab:SetScript("OnEnter", function(self) ShowTextTooltip(self, profession.name) end)
  tab:SetScript("OnLeave", GameTooltip_Hide)
  return tab
end

local function CreateDetail(frame)
  local detail = CreateFrame("Frame", nil, frame.Inset)
  detail:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", LIST_WIDTH + 34, -10)
  detail:SetPoint("BOTTOMRIGHT", frame.Inset, "BOTTOMRIGHT", -10, 10)

  local iconButton = CreateFrame("Button", nil, detail)
  iconButton:SetSize(40, 40)
  iconButton:SetPoint("TOPLEFT")
  iconButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if selectedRecipe.creates then
      GameTooltip:SetItemByID(selectedRecipe.creates)
    else
      GameTooltip:SetSpellByID(selectedRecipe.spell)
    end
    GameTooltip:Show()
  end)
  iconButton:SetScript("OnLeave", GameTooltip_Hide)
  iconButton:SetScript("OnClick", function() HandleLinkClick(RecipeLink(selectedRecipe)) end)
  detail.Icon = iconButton:CreateTexture(nil, "ARTWORK")
  detail.Icon:SetAllPoints()

  detail.Name = detail:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  detail.Name:SetPoint("TOPLEFT", iconButton, "TOPRIGHT", 10, -2)
  detail.Name:SetPoint("RIGHT")
  detail.Name:SetJustifyH("LEFT")
  detail.Skill = detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  detail.Skill:SetPoint("BOTTOMLEFT", iconButton, "BOTTOMRIGHT", 10, 2)
  detail.SourcesHeader = detail:CreateFontString(nil, "ARTWORK", "GameFontNormalMed2")
  detail.SourcesHeader:SetPoint("TOPLEFT", iconButton, "BOTTOMLEFT", 0, -18)
  detail.SourcesHeader:SetText("Sources")
  detail.BlizzardSource = detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  detail.BlizzardSource:SetJustifyH("LEFT")
  detail.BlizzardSource:SetSpacing(2)
  detail.ReagentsHeader = detail:CreateFontString(nil, "ARTWORK", "GameFontNormalMed2")
  detail.ReagentsHeader:SetText("Reagents")
  detail.AuctionHint = detail:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  detail.AuctionHint:SetPoint("BOTTOMLEFT")
  detail.AuctionHint:SetText("Click an item to search the auction house. Shift-click to link it.")
  detail.rows = CreateObjectPool(function() return CreateRow(detail, 28) end, function(_, row) ResetRow(row) end)
  return detail
end

local function CreateJournal()
  local frame = CreateFrame("Frame", "ProfessionJournalFrame", UIParent, "ButtonFrameTemplate")
  frame:SetSize(720, 520)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:Hide()
  ButtonFrameTemplate_HideButtonBar(frame)
  tinsert(UISpecialFrames, frame:GetName())

  frame.Tabs = {}
  for i, profession in ipairs(PJ.professions) do
    frame.Tabs[i] = CreateProfessionTab(frame, profession, i)
  end

  local search = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
  search:SetSize(LIST_WIDTH - 16, 20)
  search:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", 12, -8)
  search:HookScript("OnTextChanged", RenderList)
  frame.SearchBox = search

  local scrollBox = CreateFrame("Frame", nil, frame, "WowScrollBoxList")
  scrollBox:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", 4, -34)
  scrollBox:SetPoint("BOTTOMLEFT", frame.Inset, "BOTTOMLEFT", 4, 4)
  scrollBox:SetWidth(LIST_WIDTH)
  local scrollBar = CreateFrame("EventFrame", nil, frame, "MinimalScrollBar")
  scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
  scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)
  local view = CreateScrollBoxListLinearView()
  view:SetElementExtent(ROW_HEIGHT)
  view:SetElementInitializer("Button", InitRecipeRow)
  ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
  frame.ScrollBox = scrollBox

  local divider = frame.Inset:CreateTexture(nil, "ARTWORK")
  divider:SetColorTexture(1, 0.82, 0, 0.25)
  divider:SetWidth(1)
  divider:SetPoint("TOP", frame.Inset, "TOPLEFT", LIST_WIDTH + 22, -6)
  divider:SetPoint("BOTTOM", frame.Inset, "BOTTOMLEFT", LIST_WIDTH + 22, 6)

  frame.Detail = CreateDetail(frame)

  frame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
  frame:RegisterEvent("AUCTION_HOUSE_SHOW")
  frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
  frame:RegisterEvent("BAG_UPDATE_DELAYED")
  frame:SetScript("OnEvent", function(self)
    if self:IsShown() then RenderDetail() end
  end)

  return frame
end

function PJ.ToggleJournal()
  if not journal then
    journal = CreateJournal()
    SelectProfession(PJ.professions[1])
  end
  journal:SetShown(not journal:IsShown())
end
