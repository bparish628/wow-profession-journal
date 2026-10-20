local _, PJ = ...

local LIST_WIDTH = 260
local ROW_HEIGHT = 36
local SOURCE_LABELS = {
  trainer = "Trainer",
  vendor = "Vendor",
  drop = "Drop",
  quest = "Quest",
}

local journal, selectedProfession, selectedRecipe

local function CreateRow(parent, height)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(height)
  row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  row.Icon = row:CreateTexture(nil, "ARTWORK")
  row.Icon:SetSize(height - 6, height - 6)
  row.Icon:SetPoint("LEFT", 4, 0)
  row.Text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  row.Text:SetPoint("LEFT", row.Icon, "RIGHT", 8, 0)
  row.Text:SetPoint("RIGHT", -8, 0)
  row.Text:SetJustifyH("LEFT")
  return row
end

local function ShowItemTooltip(owner, itemID)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetItemByID(itemID)
  GameTooltip:Show()
end

local function ShowTextTooltip(owner, text)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(text)
  GameTooltip:Show()
end

local function ItemLabel(itemID)
  local name = C_Item.GetItemNameByID(itemID)
  if not name then
    C_Item.RequestLoadItemDataByID(itemID)
    return RETRIEVING_ITEM_INFO
  end
  return name
end

local function RenderDetail()
  local detail = journal.Detail
  detail.rows:ReleaseAll()
  local recipe = selectedRecipe
  detail:SetShown(recipe ~= nil)
  if not recipe then return end

  detail.Icon:SetTexture(PJ.RecipeIcon(recipe))
  detail.Name:SetText(PJ.RecipeName(recipe))
  local status = PJ.IsKnown(recipe) and GREEN_FONT_COLOR:WrapTextInColorCode("Known")
    or GRAY_FONT_COLOR:WrapTextInColorCode("Not learned")
  detail.Skill:SetText(("Requires skill %d  |  %s"):format(recipe.skill, status))

  local anchor = detail.SourcesHeader
  local function Place(row)
    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    row:SetPoint("RIGHT", detail, "RIGHT", -8, 0)
    row:Show()
    anchor = row
  end

  for _, source in ipairs(recipe.sources) do
    local row = detail.rows:Acquire()
    local label = SOURCE_LABELS[source.kind] .. (source.npc and (": " .. source.npc) or "")
    if source.zone then
      row.Icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
      row.Text:SetText(("%s |cffffffff%s (%.1f, %.1f)|r"):format(label, source.zone, source.x, source.y))
      row:SetScript("OnClick", function() PJ.ShowSourceOnMap(source) end)
      row:SetScript("OnEnter", function(self) ShowTextTooltip(self, "Click to pin on the world map") end)
    else
      row.Icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
      row.Text:SetText(label)
      row:SetScript("OnClick", nil)
      row:SetScript("OnEnter", nil)
    end
    row:SetScript("OnLeave", GameTooltip_Hide)
    Place(row)
  end

  detail.ReagentsHeader:ClearAllPoints()
  detail.ReagentsHeader:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
  anchor = detail.ReagentsHeader
  for _, reagent in ipairs(recipe.reagents) do
    local row = detail.rows:Acquire()
    row.Icon:SetTexture(C_Item.GetItemIconByID(reagent.item))
    row.Text:SetText(("%d x %s"):format(reagent.count, ItemLabel(reagent.item)))
    row:SetScript("OnClick", function() PJ.SearchAuctionHouse(reagent.item) end)
    row:SetScript("OnEnter", function(self) ShowItemTooltip(self, reagent.item) end)
    row:SetScript("OnLeave", GameTooltip_Hide)
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
    row.Sub = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Sub:SetPoint("BOTTOMLEFT", row.Icon, "BOTTOMRIGHT", 8, 2)
    row:SetScript("OnClick", function(self) SelectRecipe(self:GetElementData()) end)
  end
  row.Icon:SetTexture(PJ.RecipeIcon(recipe))
  row.Icon:SetDesaturated(not PJ.IsKnown(recipe))
  row.Name:SetText(PJ.RecipeName(recipe))
  row.Sub:SetText(("Skill %d"):format(recipe.skill))
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
  detail.Icon = detail:CreateTexture(nil, "ARTWORK")
  detail.Icon:SetSize(40, 40)
  detail.Icon:SetPoint("TOPLEFT")
  detail.Name = detail:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  detail.Name:SetPoint("TOPLEFT", detail.Icon, "TOPRIGHT", 10, -2)
  detail.Name:SetPoint("RIGHT")
  detail.Name:SetJustifyH("LEFT")
  detail.Skill = detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  detail.Skill:SetPoint("BOTTOMLEFT", detail.Icon, "BOTTOMRIGHT", 10, 2)
  detail.SourcesHeader = detail:CreateFontString(nil, "ARTWORK", "GameFontNormalMed2")
  detail.SourcesHeader:SetPoint("TOPLEFT", detail.Icon, "BOTTOMLEFT", 0, -18)
  detail.SourcesHeader:SetText("Sources")
  detail.ReagentsHeader = detail:CreateFontString(nil, "ARTWORK", "GameFontNormalMed2")
  detail.ReagentsHeader:SetText("Reagents")
  detail.AuctionHint = detail:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  detail.AuctionHint:SetPoint("BOTTOMLEFT")
  detail.AuctionHint:SetText("Click a reagent to search the auction house.")
  detail.rows = CreateObjectPool(function() return CreateRow(detail, 28) end,
    function(_, row) row:Hide(); row:ClearAllPoints() end)
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
