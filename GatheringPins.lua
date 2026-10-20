local _, PJ = ...

local TEMPLATE = "ProfessionJournalNodePinTemplate"

ProfessionJournalNodePinMixin = CreateFromMixins(MapCanvasPinMixin)

function ProfessionJournalNodePinMixin:OnLoad()
  self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
end

function ProfessionJournalNodePinMixin:OnAcquired(x, y, node)
  self.node = node
  self:SetPosition(x, y)
  self.Icon:SetTexture(PJ.EntryIcon(node))
end

function ProfessionJournalNodePinMixin:OnMouseEnter()
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(self.node.name)
  GameTooltip:AddLine(("Requires %d"):format(self.node.skill), 1, 1, 1)
  GameTooltip:AddLine("Right-click to clear these pins.", 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

function ProfessionJournalNodePinMixin:OnMouseLeave()
  GameTooltip:Hide()
end

function ProfessionJournalNodePinMixin:OnMouseUp(button)
  if button == "RightButton" then PJ.ShowNodeOnMap(nil) end
end

local provider = CreateFromMixins(MapCanvasDataProviderMixin)

function provider:RemoveAllData()
  self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
end

function provider:RefreshAllData()
  self:RemoveAllData()
  local node = PJ.mapNode
  local coords = node and node.spawns[self:GetMap():GetMapID()]
  if not coords then return end
  for i = 1, #coords, 2 do
    self:GetMap():AcquirePin(TEMPLATE, coords[i] / 100, coords[i + 1] / 100, node)
  end
end

WorldMapFrame:AddDataProvider(provider)

-- Pins every spawn of the node on the world map until another node is shown
-- or a pin is right-clicked.
function PJ.ShowNodeOnMap(node, mapID)
  PJ.mapNode = node
  if mapID then OpenWorldMap(mapID) end
  provider:RefreshAllData()
end
