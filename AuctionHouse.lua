local _, PJ = ...

function PJ.IsAuctionHouseOpen()
  return AuctionHouseFrame ~= nil and AuctionHouseFrame:IsShown()
end

function PJ.SearchAuctionHouse(itemID)
  local name = C_Item.GetItemNameByID(itemID)
  if not name then
    C_Item.RequestLoadItemDataByID(itemID)
    return
  end
  if not PJ.IsAuctionHouseOpen() then
    UIErrorsFrame:AddMessage("Open the auction house to search for reagents.", RED_FONT_COLOR:GetRGB())
    return
  end
  AuctionHouseFrame:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy)
  AuctionHouseFrame.SearchBar.SearchBox:SetText(name)
  AuctionHouseFrame.SearchBar:StartSearch()
end
