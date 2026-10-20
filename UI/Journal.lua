local _, PJ = ...

-- Layout and art follow Forever's own profession window (Blizzard_Professions/Camelot).
local FRAME_WIDTH, FRAME_HEIGHT = 673, 594
local LIST_WIDTH = 304
local SLOT_WIDTH, SLOT_HEIGHT = 160, 50
local TAB_SCALE = 0.75
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
local SKILL_UP_ATLASES = {
  optimal = "Professions-Icon-Skill-High",
  medium = "Professions-Icon-Skill-Medium",
  easy = "Professions-Icon-Skill-Low",
}
local DEFAULT_FILTERS = { learned = true, unlearned = true, skillUps = false }
local SECTION_TITLES = { recipe = "Sources:", node = "Found in:", band = "Zones:" }
local GRID_TITLES = { recipe = "Reagents:", node = "Yields:", band = "Yields:" }

local journal, selectedProfession, selectedEntry
local collapsed = {}

local function ShowTextTooltip(owner, text)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(text, nil, nil, nil, nil, true)
  GameTooltip:Show()
end

local function ItemName(itemID)
  local name = C_Item.GetItemNameByID(itemID)
  if not name then
    C_Item.RequestLoadItemDataByID(itemID)
    return RETRIEVING_ITEM_INFO
  end
  return name
end

local function QualityColor(itemID)
  local quality = C_Item.GetItemQualityByID(itemID)
  return quality and ITEM_QUALITY_COLORS[quality] and ITEM_QUALITY_COLORS[quality].color or HIGHLIGHT_FONT_COLOR
end

local function HandleLinkClick(link)
  return IsModifiedClick() and link ~= nil and HandleModifiedItemClick(link)
end

-- The item an entry is best represented by: what a recipe makes, or the main
-- thing a gathering entry yields. Enchants make no item.
local function EntryItem(entry)
  return entry.creates or (entry.yields and entry.yields[1])
end

local function EntryLink(entry)
  local itemID = EntryItem(entry)
  if itemID then return select(2, C_Item.GetItemInfo(itemID)) end
  return C_Spell.GetSpellLink(entry.spell)
end

local function ShowEntryTooltip(owner, entry)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  local itemID = EntryItem(entry)
  if itemID then GameTooltip:SetItemByID(itemID) else GameTooltip:SetSpellByID(entry.spell) end
  GameTooltip:Show()
end

local function ZoneName(mapID)
  local info = C_Map.GetMapInfo(mapID)
  return info and info.name or ("Map " .. mapID)
end

local function CreateItemSlot(parent)
  local slot = CreateFrame("Button", nil, parent)
  slot:SetSize(SLOT_WIDTH, SLOT_HEIGHT)
  slot.Background = slot:CreateTexture(nil, "BACKGROUND")
  slot.Background:SetAtlas("Professions-Slot-bg")
  slot.Background:SetSize(39, 39)
  slot.Background:SetPoint("LEFT")
  slot.Icon = slot:CreateTexture(nil, "ARTWORK")
  slot.Icon:SetSize(33, 33)
  slot.Icon:SetPoint("CENTER", slot.Background)
  slot.Frame = slot:CreateTexture(nil, "OVERLAY")
  slot.Frame:SetAtlas("Professions-Slot-Frame", true)
  slot.Frame:SetPoint("CENTER", slot.Background)
  local highlight = slot:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
  highlight:SetBlendMode("ADD")
  highlight:SetAllPoints(slot.Icon)
  slot.Name = slot:CreateFontString(nil, "ARTWORK", "GameFontHighlight_NoShadow")
  slot.Name:SetPoint("LEFT", slot.Background, "RIGHT", 6, 0)
  slot.Name:SetWidth(SLOT_WIDTH - 48)
  slot.Name:SetJustifyH("LEFT")
  slot.Name:SetMaxLines(2)
  slot:SetScript("OnLeave", GameTooltip_Hide)
  return slot
end

local function SetItemSlot(slot, itemID, count)
  slot.Icon:SetTexture(C_Item.GetItemIconByID(itemID))
  if count then
    local have = C_Item.GetItemCount(itemID, true)
    local color = have >= count and HIGHLIGHT_FONT_COLOR or (DISABLED_REAGENT_COLOR or DISABLED_FONT_COLOR)
    slot.Name:SetText(color:WrapTextInColorCode(("%d/%d %s"):format(have, count, ItemName(itemID))))
    slot.Icon:SetDesaturated(have < count)
  else
    slot.Name:SetText(QualityColor(itemID):WrapTextInColorCode(ItemName(itemID)))
    slot.Icon:SetDesaturated(false)
  end
  slot:SetScript("OnClick", function()
    if not HandleLinkClick(select(2, C_Item.GetItemInfo(itemID))) then PJ.SearchAuctionHouse(itemID) end
  end)
  slot:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(itemID)
    GameTooltip:Show()
  end)
end

local function CreateSourceRow(parent)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(22)
  row:SetHighlightAtlas("Professions_Recipe_Hover")
  row.Icon = row:CreateTexture(nil, "ARTWORK")
  row.Icon:SetSize(18, 18)
  row.Icon:SetPoint("LEFT", 2, 0)
  row.Text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall2")
  row.Text:SetPoint("LEFT", row.Icon, "RIGHT", 6, 0)
  row.Text:SetPoint("RIGHT", -4, 0)
  row.Text:SetJustifyH("LEFT")
  row.Text:SetWordWrap(false)
  row:SetScript("OnLeave", GameTooltip_Hide)
  return row
end

local function SourceText(source)
  local text = NORMAL_FONT_COLOR:WrapTextInColorCode(SOURCE_KINDS[source.kind].label)
  local who = source.npc or source.quest or source.object
  if who then text = text .. ": " .. who end
  if source.chance then text = text .. (" (%s%%)"):format(source.chance) end
  local area = source.area and C_Map.GetAreaInfo(source.area)
  if area then text = text .. GRAY_FONT_COLOR:WrapTextInColorCode(" - " .. area) end
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

local function SetZoneRow(row, text, onClick, tooltip)
  row.Icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
  row.Text:SetText(text)
  row:SetScript("OnClick", onClick)
  row:SetScript("OnEnter", function(self) ShowTextTooltip(self, tooltip) end)
end

local function SkillText(entry)
  return NORMAL_FONT_COLOR:WrapTextInColorCode("Requires: ") .. PJ.RequiredSkill(entry) .. "   "
    .. DIFFICULTY_COLORS.optimal:WrapTextInColorCode(PJ.RequiredSkill(entry)) .. " "
    .. DIFFICULTY_COLORS.medium:WrapTextInColorCode(entry.yellow) .. " "
    .. DIFFICULTY_COLORS.easy:WrapTextInColorCode(PJ.GreenSkill(entry)) .. " "
    .. DIFFICULTY_COLORS.trivial:WrapTextInColorCode(entry.grey)
end

-- Lays out the detail pane top to bottom: a labelled section of rows, then a
-- labelled two-column grid of item slots.
local function CreateLayout(detail)
  local anchor, gap = detail.SectionLabel, 6
  local layout = {}

  local function Place(region, nextGap)
    region:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
    region:Show()
    anchor, gap = region, nextGap
  end

  function layout.Row()
    local row = detail.sourceRows:Acquire()
    row:SetPoint("RIGHT", detail, "RIGHT", -20, 0)
    Place(row, 1)
    return row
  end

  function layout.Text(text)
    detail.Note:SetText(text)
    detail.Note:SetPoint("RIGHT", detail, "RIGHT", -20, 0)
    Place(detail.Note, 4)
  end

  function layout.Slot(itemID)
    local slot = detail.slots:Acquire()
    SetItemSlot(slot, itemID)
    Place(slot, 2)
  end

  function layout.Grid(title, items)
    detail.GridLabel:SetText(title)
    Place(detail.GridLabel, 6)
    for i, item in ipairs(items) do
      local slot = detail.slots:Acquire()
      SetItemSlot(slot, item.item, item.count)
      local column, line = (i - 1) % 2, math.floor((i - 1) / 2)
      slot:SetPoint("TOPLEFT", detail.GridLabel, "BOTTOMLEFT", column * (SLOT_WIDTH + 6), -6 - line * SLOT_HEIGHT)
      slot:Show()
    end
  end

  return layout
end

local function Yields(entry)
  local items = {}
  for i, itemID in ipairs(entry.yields) do items[i] = { item = itemID } end
  return items
end

local BODIES = {
  recipe = function(layout, recipe)
    if recipe.recipeItem then layout.Slot(recipe.recipeItem) end
    local blizzardText = PJ.BlizzardSourceText(recipe)
    local sources = recipe.sources
    if #sources == 0 and not blizzardText then sources = { UNKNOWN_SOURCE } end
    for _, source in ipairs(sources) do SetSourceRow(layout.Row(), source) end
    if blizzardText then layout.Text(blizzardText) end
    layout.Grid(GRID_TITLES.recipe, recipe.reagents)
  end,

  node = function(layout, node)
    local maps = {}
    for mapID, coords in pairs(node.spawns) do maps[#maps + 1] = { id = mapID, count = #coords / 2 } end
    table.sort(maps, function(a, b) return a.count > b.count end)
    if #maps == 0 then layout.Text("No known spawn locations.") end
    for _, map in ipairs(maps) do
      SetZoneRow(layout.Row(), ("%s %s"):format(ZoneName(map.id), GRAY_FONT_COLOR:WrapTextInColorCode(("(%d)"):format(map.count))),
        function() PJ.ShowNodeOnMap(node, map.id) end,
        ("Click to pin all %d spawns on the world map"):format(map.count))
    end
    layout.Grid(GRID_TITLES.node, Yields(node))
  end,

  band = function(layout, band)
    layout.Text(("Skinning a level %d beast needs %d skill. Up to level 20 that is (level - 10) x 10, above it level x 5.")
      :format(band.maxLevel, band.skill))
    for _, zone in ipairs(PJ.ZonesForLevels(band.minLevel, band.maxLevel)) do
      SetZoneRow(layout.Row(), ("%s %s"):format(ZoneName(zone.map),
        GRAY_FONT_COLOR:WrapTextInColorCode(("(%d-%d)"):format(zone.minLevel, zone.maxLevel))),
        function() OpenWorldMap(zone.map) end, "Click to open the world map")
    end
    layout.Grid(GRID_TITLES.band, Yields(band))
  end,
}

local function ProfessionBackgroundAtlas(profession)
  local atlas = "Profession-background-card-" .. profession.name:gsub(" ", "")
  return C_Texture.GetAtlasInfo(atlas) and atlas or "Professions-Recipe-Background"
end

local function RenderDetail()
  local detail = journal.Detail
  detail.sourceRows:ReleaseAll()
  detail.slots:ReleaseAll()
  detail.Note:Hide()
  detail.Note:ClearAllPoints()
  detail.GridLabel:Hide()
  detail.GridLabel:ClearAllPoints()
  detail.Background:SetAtlas(ProfessionBackgroundAtlas(selectedProfession))

  local entry = selectedEntry
  detail.Content:SetShown(entry ~= nil)
  if not entry then return end

  local itemID = EntryItem(entry)
  detail.Icon:SetTexture(PJ.EntryIcon(entry))
  detail.IconRing:SetVertexColor((itemID and QualityColor(itemID) or HIGHLIGHT_FONT_COLOR):GetRGB())
  detail.Name:SetText(entry.creates and ItemName(entry.creates) or PJ.EntryName(entry))
  local status = ""
  if entry.kind == "recipe" then
    status = "   " .. (PJ.IsKnown(entry) and GREEN_FONT_COLOR:WrapTextInColorCode("Known")
      or GRAY_FONT_COLOR:WrapTextInColorCode("Not learned"))
  end
  detail.Skill:SetText(SkillText(entry) .. status)
  detail.Favorite:SetNormalAtlas(PJ.IsFavorite(entry) and "auctionhouse-icon-favorite" or "auctionhouse-icon-favorite-off")
  detail.SectionLabel:SetText(SECTION_TITLES[entry.kind])

  BODIES[entry.kind](CreateLayout(detail), entry)
  detail.AuctionHint:SetText(PJ.IsAuctionHouseOpen()
    and "Click an item to search the auction house. Shift-click to link it."
    or "Shift-click an item to link it. Open the auction house to search for it.")
end

-- Laid out like ProfessionsRankBarTemplate. Blizzard animates the fill from a
-- flipbook sheet (2 columns, 34px rows) and reveals it with a mask; this shows
-- the sheet's final frame, where Blizzard's animation comes to rest, cropped
-- to the player's progress.
local RANK_BAR_WIDTH, RANK_FILL_WIDTH, RANK_FILL_HEIGHT = 453, 441, 18
local FLIPBOOK_COLUMNS, FLIPBOOK_FRAME_HEIGHT = 2, 34

local function CreateRankBar(frame)
  local bar = CreateFrame("Frame", nil, frame)
  bar:SetSize(RANK_BAR_WIDTH, RANK_FILL_HEIGHT)
  bar:SetPoint("TOPLEFT", 110, -40)
  local background = bar:CreateTexture(nil, "ARTWORK", nil, 1)
  background:SetAtlas("Professions-skillbar-bg", true)
  background:SetPoint("TOPLEFT")
  bar.Fill = bar:CreateTexture(nil, "ARTWORK", nil, 2)
  bar.Fill:SetHeight(RANK_FILL_HEIGHT)
  bar.Fill:SetPoint("TOPLEFT", 5, -3)
  local border = bar:CreateTexture(nil, "ARTWORK", nil, 3)
  border:SetAtlas("Professions-skillbar-frame")
  border:SetSize(451, 29)
  border:SetPoint("TOPLEFT")
  local rankText = CreateFrame("Frame", nil, bar)
  rankText:SetFrameLevel(bar:GetFrameLevel() + 5)
  rankText:SetPoint("LEFT", 0, -3)
  rankText:SetPoint("RIGHT", 0, -3)
  rankText:SetHeight(RANK_FILL_HEIGHT)
  bar.Text = rankText:CreateFontString(nil, "ARTWORK", "Number12FontOutline")
  bar.Text:SetPoint("CENTER")
  return bar
end

local function SetRankBarFill(bar, profession, progress)
  local atlas = "Skillbar_Fill_Flipbook_" .. profession.name:gsub(" ", "")
  local info = C_Texture.GetAtlasInfo(atlas)
  if not info then
    atlas = "Skillbar_Fill_Flipbook_DefaultBlue"
    info = C_Texture.GetAtlasInfo(atlas)
  end
  bar.Fill:SetShown(progress > 0)
  if progress <= 0 then return end
  local rows = info.height / FLIPBOOK_FRAME_HEIGHT
  local cellWidth = (info.rightTexCoord - info.leftTexCoord) / FLIPBOOK_COLUMNS
  local cellHeight = (info.bottomTexCoord - info.topTexCoord) / rows
  local left = info.leftTexCoord + cellWidth * (FLIPBOOK_COLUMNS - 1)
  local top = info.topTexCoord + cellHeight * (rows - 1)
  bar.Fill:SetTexture(info.file)
  bar.Fill:SetTexCoord(left, left + cellWidth * progress, top, top + cellHeight)
  bar.Fill:SetWidth(RANK_FILL_WIDTH * progress)
end

local function RenderRank()
  local rank, maxRank = PJ.PlayerSkill(selectedProfession)
  local bar = journal.RankBar
  SetRankBarFill(bar, selectedProfession, rank and maxRank > 0 and rank / maxRank or 0)
  bar.Text:SetText(rank and ("%s %d/%d"):format(selectedProfession.name, rank, maxRank)
    or ("%s (not learned)"):format(selectedProfession.name))
end

local function RenderList()
  local list = PJ.ListFor(selectedProfession, journal.SearchBox:GetText(), PJ.db.filters, collapsed)
  journal.ScrollBox:SetDataProvider(CreateDataProvider(list), ScrollBoxConstants.RetainScrollPosition)
  journal:SetTitle(selectedProfession.name)
  journal:SetPortraitToAsset(selectedProfession.icon)
  for _, tab in ipairs(journal.Tabs) do
    tab:SetChecked(tab.profession == selectedProfession)
  end
  RenderRank()
end

local function SelectProfession(profession)
  selectedProfession = profession
  selectedEntry = nil
  RenderList()
  RenderDetail()
end

local function SelectEntry(entry)
  selectedEntry = entry
  journal.ScrollBox:ForEachFrame(function(row)
    if row.Selected then row.Selected:SetShown(row:GetElementData() == entry) end
  end)
  RenderDetail()
end

local function ToggleCollapsed(key)
  collapsed[key] = not collapsed[key] or nil
  RenderList()
end

local function InitHeader(button, data)
  if not button.initialized then
    button:SetTitleColor(false, NORMAL_FONT_COLOR)
    button:SetTitleColor(true, HIGHLIGHT_FONT_COLOR)
    button:SetScript("OnEnter", function(self) self:CheckHighlightTitle(true) end)
    button:SetScript("OnLeave", function(self) self:CheckHighlightTitle(false) end)
    button:SetScript("OnClick", function(self) ToggleCollapsed(self:GetElementData().header.key) end)
    button.CollapseButton:SetScript("OnClick", function() ToggleCollapsed(button:GetElementData().header.key) end)
    button.initialized = true
  end
  button:SetHeaderText(data.header.name)
  button.CollapseButton:UpdateCollapsedState(data.collapsed)
end

local function InitEntry(row, entry)
  if not row.initialized then
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
      local data = self:GetElementData()
      if button == "RightButton" then
        PJ.ToggleFavorite(data)
        RenderList()
        if data == selectedEntry then RenderDetail() end
      elseif not HandleLinkClick(EntryLink(data)) then
        SelectEntry(data)
      end
    end)
    row:SetScript("OnEnter", function(self) ShowEntryTooltip(self, self:GetElementData()) end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row.initialized = true
  end
  local known = PJ.IsKnown(entry)
  local rank = PJ.PlayerSkill(selectedProfession)
  local difficulty = rank and known and PJ.Difficulty(entry, rank)
  local atlas = difficulty and SKILL_UP_ATLASES[difficulty]
  row.SkillUp:SetShown(atlas ~= nil)
  if atlas then row.SkillUp:SetAtlas(atlas) end
  row.Label:SetText(PJ.EntryName(entry))
  local color = not known and DISABLED_FONT_COLOR
    or difficulty == "impossible" and RED_FONT_COLOR
    or PROFESSION_RECIPE_COLOR or HIGHLIGHT_FONT_COLOR
  row.Label:SetTextColor(color:GetRGB())
  row.Selected:SetShown(entry == selectedEntry)
end

local function CreateProfessionTabs(frame)
  local tabs, previous = {}, nil
  for _, group in ipairs(PJ.GROUPS) do
    local first = true
    for _, profession in ipairs(PJ.professions) do
      if profession.group == group then
        local tab = CreateFrame("Frame", nil, frame, "LargeSideTabButtonTemplate")
        tab:SetScale(TAB_SCALE)
        if previous then
          tab:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, first and -16 or -2)
        else
          tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -60 / TAB_SCALE)
        end
        tab.Icon:SetTexture(profession.icon)
        tab:SetFillToInterior(true, 44)
        tab.tooltipText = profession.name
        tab.profession = profession
        tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
          if button == "LeftButton" and upInside then SelectProfession(profession) end
        end)
        tabs[#tabs + 1] = tab
        previous, first = tab, false
      end
    end
  end
  return tabs
end

local function CreateFilterDropdown(parent)
  local filter = CreateFrame("DropdownButton", nil, parent, "WowStyle1FilterDropdownTemplate")
  local function Option(root, text, key)
    root:CreateCheckbox(text, function() return PJ.db.filters[key] end, function()
      PJ.db.filters[key] = not PJ.db.filters[key]
      RenderList()
    end)
  end
  filter:SetupMenu(function(_, root)
    Option(root, "Learned", "learned")
    Option(root, "Not learned", "unlearned")
    Option(root, "Only skill-ups", "skillUps")
  end)
  filter:SetDefaultCallback(function()
    PJ.db.filters = CopyTable(DEFAULT_FILTERS)
    RenderList()
  end)
  filter:SetIsDefaultCallback(function() return tCompare(PJ.db.filters, DEFAULT_FILTERS) end)
  return filter
end

local function CreateRecipeList(frame)
  local list = CreateFrame("Frame", nil, frame)
  list:SetPoint("TOPLEFT", 5, -72)
  list:SetPoint("BOTTOMLEFT", 5, 5)
  list:SetWidth(LIST_WIDTH)

  local filter = CreateFilterDropdown(list)
  filter:SetPoint("TOPRIGHT", -10, -8)
  local search = CreateFrame("EditBox", nil, list, "SearchBoxTemplate")
  search:SetHeight(20)
  search:SetPoint("TOPLEFT", 14, -7)
  search:SetPoint("RIGHT", filter, "LEFT", -10, 0)
  search:HookScript("OnTextChanged", RenderList)
  frame.SearchBox = search

  local scrollBox = CreateFrame("Frame", nil, list, "WowScrollBoxList")
  scrollBox:SetPoint("TOPLEFT", 6, -34)
  scrollBox:SetPoint("BOTTOMRIGHT", -20, 6)
  local scrollBar = CreateFrame("EventFrame", nil, list, "MinimalScrollBar")
  scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, 0)
  scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 0)
  local view = CreateScrollBoxListLinearView(2, 2, 0, 0, 2)
  view:SetElementFactory(function(factory, data)
    if data.header then
      factory("ProfessionJournalHeaderTemplate", InitHeader)
    else
      factory("ProfessionJournalEntryTemplate", InitEntry)
    end
  end)
  view:SetElementExtentCalculator(function(_, data) return data.header and 25 or 20 end)
  ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
  frame.ScrollBox = scrollBox
  return list
end

local function CreateDetail(frame, list)
  local detail = CreateFrame("Frame", nil, frame)
  detail:SetPoint("TOPLEFT", list, "TOPRIGHT", 2, 0)
  detail:SetPoint("BOTTOMRIGHT", -5, 5)
  detail.Background = detail:CreateTexture(nil, "BACKGROUND")
  detail.Background:SetPoint("TOPLEFT", 3, -3)
  detail.Background:SetPoint("BOTTOMRIGHT", -3, 3)
  local border = detail:CreateTexture(nil, "BORDER")
  border:SetAtlas("common-insideframe")
  border:SetAllPoints()

  local content = CreateFrame("Frame", nil, detail)
  content:SetAllPoints()
  detail.Content = content

  local iconButton = CreateFrame("Button", nil, content)
  iconButton:SetSize(53, 53)
  iconButton:SetPoint("TOPLEFT", 24, -24)
  iconButton:SetScript("OnEnter", function(self) ShowEntryTooltip(self, selectedEntry) end)
  iconButton:SetScript("OnLeave", GameTooltip_Hide)
  iconButton:SetScript("OnClick", function() HandleLinkClick(EntryLink(selectedEntry)) end)
  detail.Icon = iconButton:CreateTexture(nil, "ARTWORK")
  detail.Icon:SetAllPoints()
  local mask = iconButton:CreateMaskTexture()
  mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(detail.Icon)
  detail.Icon:AddMaskTexture(mask)
  detail.IconRing = iconButton:CreateTexture(nil, "OVERLAY")
  detail.IconRing:SetAtlas("auctionhouse-itemicon-border-white")
  detail.IconRing:SetSize(68, 68)
  detail.IconRing:SetPoint("CENTER")

  local favorite = CreateFrame("Button", nil, content)
  favorite:SetSize(20, 18)
  favorite:SetPoint("TOPRIGHT", -18, -22)
  favorite:SetScript("OnClick", function()
    PJ.ToggleFavorite(selectedEntry)
    RenderList()
    RenderDetail()
  end)
  favorite:SetScript("OnEnter", function(self) ShowTextTooltip(self, "Favorite. You can also right-click a recipe in the list.") end)
  favorite:SetScript("OnLeave", GameTooltip_Hide)
  detail.Favorite = favorite

  detail.Name = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightMed2")
  detail.Name:SetPoint("TOPLEFT", iconButton, "TOPRIGHT", 14, -8)
  detail.Name:SetWidth(225)
  detail.Name:SetJustifyH("LEFT")
  detail.Skill = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall2")
  detail.Skill:SetPoint("TOPLEFT", detail.Name, "BOTTOMLEFT", 0, -4)

  detail.SectionLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  detail.SectionLabel:SetPoint("TOPLEFT", iconButton, "BOTTOMLEFT", -4, -20)
  detail.GridLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  detail.Note = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall2")
  detail.Note:SetJustifyH("LEFT")
  detail.Note:SetSpacing(2)
  detail.AuctionHint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  detail.AuctionHint:SetPoint("BOTTOMLEFT", 18, 14)
  detail.AuctionHint:SetPoint("RIGHT", -18, 0)
  detail.AuctionHint:SetJustifyH("LEFT")

  local function Reset(_, region) region:Hide(); region:ClearAllPoints() end
  detail.sourceRows = CreateObjectPool(function() return CreateSourceRow(content) end, Reset)
  detail.slots = CreateObjectPool(function() return CreateItemSlot(content) end, Reset)
  return detail
end

local function CreateJournal()
  local frame = CreateFrame("Frame", "ProfessionJournalFrame", UIParent, "PortraitFrameTemplate")
  frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:Hide()
  tinsert(UISpecialFrames, frame:GetName())

  if frame.Bg then frame.Bg:SetAtlas("Profession-Background-Overview") end
  if frame.TopTileStreaks then frame.TopTileStreaks:Hide() end
  local page = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
  page:SetAtlas("Profession-Background-Template2", true)
  page:SetPoint("TOPLEFT", 3, -21)

  frame.Tabs = CreateProfessionTabs(frame)
  frame.RankBar = CreateRankBar(frame)
  local list = CreateRecipeList(frame)
  frame.Detail = CreateDetail(frame, list)

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
    for _, profession in ipairs(PJ.professions) do
      if PJ.PlayerSkill(profession) then
        selectedProfession = profession
        break
      end
    end
    selectedProfession = selectedProfession or PJ.professions[1]
    journal = CreateJournal()
  end
  journal:SetShown(not journal:IsShown())
end
