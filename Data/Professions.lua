local _, PJ = ...

-- Seed data until scripts/build-data.mjs generates the full database.
-- tiers are the client's per-expansion child skill lines, which GetProfessionInfo reports.
for _, profession in ipairs({
  { id = 171, name = "Alchemy", icon = 136240, tiers = { 2937 } },
  { id = 164, name = "Blacksmithing", icon = 136241, tiers = { 2938 } },
  { id = 185, name = "Cooking", icon = 133971, tiers = { 2939 } },
  { id = 333, name = "Enchanting", icon = 136244, tiers = { 2940 } },
  { id = 202, name = "Engineering", icon = 136243, tiers = { 2941 } },
  { id = 129, name = "First Aid", icon = 135966, tiers = { 2942 } },
  { id = 165, name = "Leatherworking", icon = 136247, tiers = { 2945 } },
  { id = 186, name = "Mining", icon = 136248, tiers = { 2946 } },
  { id = 197, name = "Tailoring", icon = 136249, tiers = { 2948 } },
}) do
  PJ.RegisterProfession(profession)
end
