local _, PJ = ...

local LIST_WIDTH = 260
local ROW_HEIGHT = 36
local SLOT_WIDTH = 160
local SLOT_HEIGHT = 44
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
local DIFFICULTY_COLORS = {
  impossible = RED_FONT_COLOR,
  optimal = CreateColor(1, 0.5, 0.25),
  medium = CreateColor(1, 1, 0),
  easy = CreateColor(0.25, 0.75, 0.25),
  trivial = CreateColor(0.5, 0.5, 0.5),
}

local journal, selectedProfession, selectedRecipe

local function ShowTextTooltip(owner, text)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(text, nil, nil, nil, nil, true)
  GameTooltip:Show()
end

local function ShowItemTooltip(owner, itemID)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetItemByID(itemID)
  GameTooltip:Show()
end

local function ItemName(itemID)
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

local function RecipeLink(recipe)
  if recipe.creates then return select(2, C_Item.GetItemInfo(recipe.creates)) end
  return C_Spell.GetSpellLink(recipe.spell)
end

local function SetQualityBorder(border, itemID)
  local quality = C_Item.GetItemQualityByID(itemID)
  local show = quality ~= nil and quality > Enum.ItemQuality.Common
  if show then border:SetVertexColor(ITEM_QUALITY_COLORS[quality].color:GetRGB()) end
  border:SetShown(show)
end

local function CreateSectionHeader(parent, text)
  local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalMed2")
  header:SetText(text)
  local divider = parent:CreateTexture(nil, "ARTWORK")
  divider:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
  divider:SetHeight(8)
  divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -1)
  divider:SetPoint("RIGHT", parent, "RIGHT")
  return header
end

-- A reagent slot in the style of the classic profession window: an item icon
-- with the have/need count on it, beside the quest reward name frame.
local function CreateItemSlot(parent)
  local slot = CreateFrame("Button", nil, parent)
  slot:SetSize(SLOT_WIDTH, SLOT_HEIGHT)
  slot.Icon = slot:CreateTexture(nil, "ARTWORK")
  slot.Icon:SetSize(37, 37)
  slot.Icon:SetPoint("LEFT")
  slot.Border = slot:CreateTexture(nil, "OVERLAY")
  slot.Border:SetTexture("Interface\\Common\\WhiteIconFrame")
  slot.Border:SetAllPoints(slot.Icon)
  slot.Count = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  slot.Count:SetPoint("BOTTOMRIGHT", slot.Icon, "BOTTOMRIGHT", -2, 2)
  local nameFrame = slot:CreateTexture(nil, "BACKGROUND")
  nameFrame:SetTexture("Interface\\QuestFrame\\UI-QuestItemNameFrame")
  nameFrame:SetSize(128, 64)
  nameFrame:SetPoint("LEFT", slot.Icon, "RIGHT", -10, 0)
  slot.Name = slot:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  slot.Name:SetPoint("LEFT", slot.Icon, "RIGHT", 6, 0)
  slot.Name:SetWidth(SLOT_WIDTH - 50)
  slot.Name:SetJustifyH("LEFT")
  slot.Name:SetMaxLines(2)
  local highlight = slot:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
  highlight:SetBlendMode("ADD")
  highlight:SetAllPoints(slot.Icon)
  slot:SetScript("OnLeave", GameTooltip_Hide)
  return slot
end

local function SetItemSlot(slot, itemID, count)
  slot.Icon:SetTexture(C_Item.GetItemIconByID(itemID))
  SetQualityBorder(slot.Border, itemID)
  slot.Name:SetText(ItemName(itemID))
  if count then
    local have = C_Item.GetItemCount(itemID, true)
    local color = have >= count and HIGHLIGHT_FONT_COLOR or RED_FONT_COLOR
    slot.Count:SetText(color:WrapTextInColorCode(("%d/%d"):format(have, count)))
    slot.Icon:SetDesaturated(have < count)
  else
    slot.Count:SetText("")
    slot.Icon:SetDesaturated(false)
  end
  slot:SetScript("OnClick", function()
    if not HandleLinkClick(select(2, C_Item.GetItemInfo(itemID))) then PJ.SearchAuctionHouse(itemID) end
  end)
  slot:SetScript("OnEnter", function(self) ShowItemTooltip(self, itemID) end)
end

local function CreateSourceRow(parent)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(24)
  row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  row.Icon = row:CreateTexture(nil, "ARTWORK")
  row.Icon:SetSize(20, 20)
  row.Icon:SetPoint("LEFT", 2, 0)
  row.Text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  row.Text:SetPoint("LEFT", row.Icon, "RIGHT", 6, 0)
  row.Text:SetPoint("RIGHT", -4, 0)
  row.Text:SetJustifyH("LEFT")
  row.Text:SetWordWrap(false)
  row:SetScript("OnLeave", GameTooltip_Hide)
  return row
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

local function SetSourceRow(row, source)
  row.Text:SetText(SourceText(source))
  if source.map then
    row.Icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    row:SetScript("OnClick", function() PJ.ShowSourceOnMap(source) end)
    row:SetScript("OnEnter", function(self)
      ShowTextTooltip(self, ("Click to pin %.1f, %.1f on the world map"):format(source.x, source.y))
    end)
  else
    row.Icon:SetTexture(SOURCE_KINDS[source.kind].icon)
    row:SetScript("OnClick", nil)
    row:SetScript("OnEnter", nil)
  end
end

local function SkillText(recipe)
  return ("Requires %d  "):format(PJ.RequiredSkill(recipe))
    .. DIFFICULTY_COLORS.optimal:WrapTextInColorCode(PJ.RequiredSkill(recipe)) .. " "
    .. DIFFICULTY_COLORS.medium:WrapTextInColorCode(recipe.yellow) .. " "
    .. DIFFICULTY_COLORS.easy:WrapTextInColorCode(PJ.GreenSkill(recipe)) .. " "
    .. DIFFICULTY_COLORS.trivial:WrapTextInColorCode(recipe.grey)
end

local function RenderDetail()
  local detail = journal.Detail
  detail.sourceRows:ReleaseAll()
  detail.slots:ReleaseAll()
  local recipe = selectedRecipe
  detail:SetShown(recipe ~= nil)
  if not recipe then return end

  detail.Icon:SetTexture(PJ.RecipeIcon(recipe))
  if recipe.creates then SetQualityBorder(detail.IconBorder, recipe.creates) else detail.IconBorder:Hide() end
  detail.Name:SetText(recipe.creates and ItemName(recipe.creates) or PJ.RecipeName(recipe))
  local status = PJ.IsKnown(recipe) and GREEN_FONT_COLOR:WrapTextInColorCode("Known")
    or GRAY_FONT_COLOR:WrapTextInColorCode("Not learned")
  detail.Skill:SetText(SkillText(recipe) .. "   " .. status)

  local anchor, anchorGap = detail.SourcesHeader, 12
  local function Place(region, gap)
    region:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(gap or anchorGap))
    region:SetPoint("RIGHT", detail, "RIGHT", -4, 0)
    region:Show()
    anchor, anchorGap = region, 2
  end

  if recipe.recipeItem then
    local slot = detail.slots:Acquire()
    SetItemSlot(slot, recipe.recipeItem)
    slot:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -anchorGap)
    slot:Show()
    anchor, anchorGap = slot, 4
  end

  local blizzardText = PJ.BlizzardSourceText(recipe)
  local sources = recipe.sources
  if #sources == 0 and not blizzardText then sources = { UNKNOWN_SOURCE } end
  for _, source in ipairs(sources) do
    local row = detail.sourceRows:Acquire()
    SetSourceRow(row, source)
    Place(row)
  end

  detail.BlizzardSource:SetShown(blizzardText ~= nil)
  if blizzardText then
    detail.BlizzardSource:SetText(blizzardText)
    Place(detail.BlizzardSource, 6)
  end

  detail.ReagentsHeader:ClearAllPoints()
  detail.ReagentsHeader:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -18)
  for i, reagent in ipairs(recipe.reagents) do
    local slot = detail.slots:Acquire()
    SetItemSlot(slot, reagent.item, reagent.count)
    local column, line = (i - 1) % 2, math.floor((i - 1) / 2)
    slot:SetPoint("TOPLEFT", detail.ReagentsHeader, "BOTTOMLEFT", column * (SLOT_WIDTH + 12), -12 - line * SLOT_HEIGHT)
    slot:Show()
  end
  detail.AuctionHint:SetText(PJ.IsAuctionHouseOpen()
    and "Click an item to search the auction house. Shift-click to link it."
    or "Shift-click an item to link it. Open the auction house to search for it.")
end

local function RenderRank()
  local rank, maxRank = PJ.PlayerSkill(selectedProfession)
  local bar = journal.RankBar
  bar:SetMinMaxValues(0, maxRank or 1)
  bar:SetValue(rank or 0)
  bar.Text:SetText(rank and ("%s  %d/%d"):format(selectedProfession.name, rank, maxRank)
    or ("%s  (not learned)"):format(selectedProfession.name))
end

local function RenderList()
  local recipes = PJ.RecipesFor(selectedProfession.id, journal.SearchBox:GetText())
  journal.ScrollBox:SetDataProvider(CreateDataProvider(recipes), ScrollBoxConstants.RetainScrollPosition)
  journal:SetTitle(("Profession Journal - %s"):format(selectedProfession.name))
  journal:SetPortraitToAsset(selectedProfession.icon)
  for _, tab in ipairs(journal.Tabs) do
    tab:SetChecked(tab.profession == selectedProfession)
  end
  RenderRank()
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
    row.Selected:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    row.Selected:SetVertexColor(1, 0.82, 0, 0.35)
    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(ROW_HEIGHT - 8, ROW_HEIGHT - 8)
    row.Icon:SetPoint("LEFT", 6, 0)
    row.Name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.Name:SetPoint("TOPLEFT", row.Icon, "TOPRIGHT", 8, -1)
    row.Name:SetPoint("RIGHT", -6, 0)
    row.Name:SetJustifyH("LEFT")
    row.Name:SetWordWrap(false)
    row.Sub = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.Sub:SetPoint("BOTTOMLEFT", row.Icon, "BOTTOMRIGHT", 8, 1)
    row:SetScript("OnClick", function(self)
      local data = self:GetElementData()
      if not HandleLinkClick(RecipeLink(data)) then SelectRecipe(data) end
    end)
  end
  local rank = PJ.PlayerSkill(selectedProfession)
  local color = rank and DIFFICULTY_COLORS[PJ.Difficulty(recipe, rank)] or NORMAL_FONT_COLOR
  row.Icon:SetTexture(PJ.RecipeIcon(recipe))
  row.Icon:SetDesaturated(not PJ.IsKnown(recipe))
  row.Name:SetText(PJ.RecipeName(recipe))
  row.Name:SetTextColor(color:GetRGB())
  row.Sub:SetText(PJ.IsKnown(recipe) and ("Skill %d"):format(PJ.RequiredSkill(recipe))
    or ("Skill %d  -  not learned"):format(PJ.RequiredSkill(recipe)))
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

local function CreateRankBar(frame)
  local bar = CreateFrame("StatusBar", nil, frame)
  bar:SetSize(220, 14)
  bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 74, -36)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetStatusBarColor(0.25, 0.25, 0.75)
  local background = bar:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints()
  background:SetColorTexture(0, 0, 0, 0.5)
  local border = bar:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder")
  border:SetPoint("TOPLEFT", -5, 9)
  border:SetPoint("BOTTOMRIGHT", 5, -9)
  bar.Text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bar.Text:SetPoint("CENTER", 0, 1)
  return bar
end

local function CreateDetail(frame)
  local detail = CreateFrame("Frame", nil, frame.Inset)
  detail:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", LIST_WIDTH + 34, -12)
  detail:SetPoint("BOTTOMRIGHT", frame.Inset, "BOTTOMRIGHT", -12, 10)

  local iconButton = CreateFrame("Button", nil, detail)
  iconButton:SetSize(44, 44)
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
  detail.IconBorder = iconButton:CreateTexture(nil, "OVERLAY")
  detail.IconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
  detail.IconBorder:SetAllPoints()

  detail.Name = detail:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  detail.Name:SetPoint("TOPLEFT", iconButton, "TOPRIGHT", 10, -3)
  detail.Name:SetPoint("RIGHT")
  detail.Name:SetJustifyH("LEFT")
  detail.Skill = detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  detail.Skill:SetPoint("BOTTOMLEFT", iconButton, "BOTTOMRIGHT", 10, 3)
  detail.SourcesHeader = CreateSectionHeader(detail, "Sources")
  detail.SourcesHeader:SetPoint("TOPLEFT", iconButton, "BOTTOMLEFT", 0, -16)
  detail.BlizzardSource = detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  detail.BlizzardSource:SetJustifyH("LEFT")
  detail.BlizzardSource:SetSpacing(2)
  detail.ReagentsHeader = CreateSectionHeader(detail, "Reagents")
  detail.AuctionHint = detail:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  detail.AuctionHint:SetPoint("BOTTOMLEFT")
  local function Reset(_, region) region:Hide(); region:ClearAllPoints() end
  detail.sourceRows = CreateObjectPool(function() return CreateSourceRow(detail) end, Reset)
  detail.slots = CreateObjectPool(function() return CreateItemSlot(detail) end, Reset)
  return detail
end

local function CreateJournal()
  local frame = CreateFrame("Frame", "ProfessionJournalFrame", UIParent, "ButtonFrameTemplate")
  frame:SetSize(740, 540)
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

  frame.RankBar = CreateRankBar(frame)

  local search = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
  search:SetSize(200, 20)
  search:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -33)
  search:HookScript("OnTextChanged", RenderList)
  frame.SearchBox = search

  local scrollBox = CreateFrame("Frame", nil, frame, "WowScrollBoxList")
  scrollBox:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", 4, -4)
  scrollBox:SetPoint("BOTTOMLEFT", frame.Inset, "BOTTOMLEFT", 4, 4)
  scrollBox:SetWidth(LIST_WIDTH)
  local scrollBar = CreateFrame("EventFrame", nil, frame, "MinimalScrollBar")
  scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, -2)
  scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 2)
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
  frame:RegisterEvent("SKILL_LINES_CHANGED")
  frame:SetScript("OnEvent", function(self, event)
    if not self:IsShown() then return end
    if event == "SKILL_LINES_CHANGED" then RenderList() end
    RenderDetail()
  end)
  frame:SetScript("OnShow", function() RenderList(); RenderDetail() end)

  return frame
end

function PJ.ToggleJournal()
  if not journal then
    journal = CreateJournal()
    for _, profession in ipairs(PJ.professions) do
      if PJ.PlayerSkill(profession) then
        selectedProfession = profession
        break
      end
    end
    selectedProfession = selectedProfession or PJ.professions[1]
  end
  journal:SetShown(not journal:IsShown())
end
