local _, PJ = ...

-- Seed data until scripts/build-data.mjs generates the full database.
for _, category in ipairs({
  { id = 2502, name = "Weapon Enchants", order = 130 },
  { id = 2530, name = "Bandages", order = 10 },
  { id = 2575, name = "Smelted Bars", order = 100 },
}) do
  PJ.RegisterCategory(category)
end
