local _, PJ = ...

-- id is the SkillLine ID, the key recipes reference.
for _, profession in ipairs({
  { id = 171, name = "Alchemy",        icon = "Interface\Icons\Trade_Alchemy" },
  { id = 164, name = "Blacksmithing",  icon = "Interface\Icons\Trade_BlackSmithing" },
  { id = 333, name = "Enchanting",     icon = "Interface\Icons\Trade_Engraving" },
  { id = 202, name = "Engineering",    icon = "Interface\Icons\Trade_Engineering" },
  { id = 165, name = "Leatherworking", icon = "Interface\Icons\INV_Misc_ArmorKit_17" },
  { id = 197, name = "Tailoring",      icon = "Interface\Icons\Trade_Tailoring" },
  { id = 186, name = "Mining",         icon = "Interface\Icons\Trade_Mining" },
  { id = 185, name = "Cooking",        icon = "Interface\Icons\INV_Misc_Food_15" },
  { id = 129, name = "First Aid",      icon = "Interface\Icons\Spell_Holy_SealOfSacrifice" },
}) do
  PJ.RegisterProfession(profession)
end
