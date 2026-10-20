local _, PJ = ...

local category

function PJ.RegisterSettings()
  category = Settings.RegisterVerticalLayoutCategory("Profession Journal")
  local showMinimap = Settings.RegisterAddOnSetting(category, "ProfessionJournal_ShowMinimapButton", "show",
    PJ.db.minimap, Settings.VarType.Boolean, "Show minimap button", true)
  showMinimap:SetValueChangedCallback(PJ.UpdateMinimapButton)
  Settings.CreateCheckbox(category, showMinimap, "Show the Profession Journal button around the minimap.")
  Settings.RegisterAddOnCategory(category)
end

function PJ.OpenSettings()
  Settings.OpenToCategory(category:GetID())
end
