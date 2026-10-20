local _, PJ = ...

local ICON = "Interface\\Icons\\INV_Misc_Book_11"

local button

local function Place()
  local angle = math.rad(PJ.db.minimap.angle)
  local radius = Minimap:GetWidth() / 2 + 10
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function FollowCursor()
  local centerX, centerY = Minimap:GetCenter()
  local scale = Minimap:GetEffectiveScale()
  local cursorX, cursorY = GetCursorPosition()
  PJ.db.minimap.angle = math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX))
  Place()
end

function PJ.CreateMinimapButton()
  button = CreateFrame("Button", "ProfessionJournalMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  background:SetSize(24, 24)
  background:SetPoint("CENTER")
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(ICON)
  icon:SetSize(18, 18)
  icon:SetPoint("CENTER")
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(50, 50)
  border:SetPoint("TOPLEFT")

  button:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then PJ.OpenSettings() else PJ.ToggleJournal() end
  end)
  button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", FollowCursor) end)
  button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Profession Journal")
    GameTooltip:AddLine("Click to open. Right-click for options.", 1, 1, 1)
    GameTooltip:AddLine("Drag to move.", 1, 1, 1)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", GameTooltip_Hide)

  Place()
  PJ.UpdateMinimapButton()
end

function PJ.UpdateMinimapButton()
  button:SetShown(PJ.db.minimap.show)
end
