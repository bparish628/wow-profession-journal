local _, PJ = ...

-- Seed data until scripts/build-data.mjs generates the full database.
-- tiers are the client's per-expansion child skill lines, which GetProfessionInfo reports.
for _, profession in ipairs({
  { id = 171, name = "Alchemy", icon = 136240, group = "crafting", tiers = { 2937 } },
  { id = 164, name = "Blacksmithing", icon = 136241, group = "crafting", tiers = { 2938 } },
  { id = 333, name = "Enchanting", icon = 136244, group = "crafting", tiers = { 2940 } },
  { id = 202, name = "Engineering", icon = 136243, group = "crafting", tiers = { 2941 } },
  { id = 165, name = "Leatherworking", icon = 136247, group = "crafting", tiers = { 2945 } },
  { id = 197, name = "Tailoring", icon = 136249, group = "crafting", tiers = { 2948 } },
  { id = 182, name = "Herbalism", icon = 136246, group = "gathering", tiers = { 2944 } },
  { id = 186, name = "Mining", icon = 136248, group = "gathering", tiers = { 2946 } },
  { id = 393, name = "Skinning", icon = 134366, group = "gathering", tiers = { 2947 } },
  { id = 185, name = "Cooking", icon = 133971, group = "secondary", tiers = { 2939 } },
  { id = 129, name = "First Aid", icon = 135966, group = "secondary", tiers = { 2942 } },
}) do
  PJ.RegisterProfession(profession)
end
