local _, PJ = ...

-- Seed data until scripts/build-data.mjs generates the full database.
for _, recipe in ipairs({
  {
    spell = 2657, profession = 186, skill = 1, yellow = 25, grey = 70, creates = 2840,
    reagents = { { item = 2770, count = 1 } },
    sources = { { kind = "trainer" } },
  },
  {
    spell = 3275, profession = 129, skill = 1, yellow = 30, grey = 60, creates = 1251,
    reagents = { { item = 2589, count = 1 } },
    sources = { { kind = "trainer" } },
  },
  {
    spell = 20034, profession = 333, skill = 300, yellow = 320, grey = 360, recipeItem = 16252,
    reagents = { { item = 14344, count = 4 }, { item = 12811, count = 2 } },
    sources = {
      { kind = "drop", npc = "Scarlet Spellbinder", area = 28, map = 1422, x = 54.8, y = 23.6 },
    },
  },
}) do
  PJ.RegisterRecipe(recipe)
end
