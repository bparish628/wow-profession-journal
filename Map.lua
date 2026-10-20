local _, PJ = ...

local zoneMapIDs

-- Data names zones instead of hardcoding uiMapIDs, because Forever's map IDs
-- may differ from both Classic Era and Mainline.
local function ResolveZone(zoneName)
  if not zoneMapIDs then
    zoneMapIDs = {}
    for mapID = 1, 3000 do
      local info = C_Map.GetMapInfo(mapID)
      if info and info.mapType == Enum.UIMapType.Zone and not zoneMapIDs[info.name] then
        zoneMapIDs[info.name] = mapID
      end
    end
  end
  return zoneMapIDs[zoneName]
end

function PJ.ShowSourceOnMap(source)
  local mapID = ResolveZone(source.zone)
  if not mapID then
    UIErrorsFrame:AddMessage(("Profession Journal: unknown zone %s"):format(source.zone), RED_FONT_COLOR:GetRGB())
    return
  end
  if not C_Map.CanSetUserWaypointOnMap(mapID) then
    OpenWorldMap(mapID)
    return
  end
  C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, source.x / 100, source.y / 100))
  OpenWorldMap(mapID)
end
