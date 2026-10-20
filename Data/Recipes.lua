local _, PJ = ...

-- Seed data proving the shape end to end. A generated database replaces it.
-- Source coordinates are approximate and unverified on Forever.
for _, recipe in ipairs({
  {
    spell = 2657, profession = 186, skill = 1, creates = 2840,
    reagents = { { item = 2770, count = 1 } },
    sources = { { kind = "trainer" } },
  },
  {
    spell = 3275, profession = 129, skill = 1, creates = 1251,
    reagents = { { item = 2589, count = 1 } },
    sources = { { kind = "trainer" } },
  },
  {
    spell = 20034, profession = 333, skill = 300, recipeItem = 16252,
    reagents = { { item = 14344, count = 4 }, { item = 12811, count = 2 } },
    sources = {
      { kind = "drop", npc = "Scarlet Spellbinder", zone = "Western Plaguelands", x = 45.0, y = 18.0 },
    },
  },
}) do
  PJ.RegisterRecipe(recipe)
end
