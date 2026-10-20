local _, PJ = ...

function PJ.ShowSourceOnMap(source)
  if C_Map.CanSetUserWaypointOnMap(source.map) then
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(source.map, source.x / 100, source.y / 100))
  end
  OpenWorldMap(source.map)
end
