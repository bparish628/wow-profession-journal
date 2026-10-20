# Profession Journal

A World of Warcraft: Forever addon that puts every profession and recipe in one in-game journal. It shows where each recipe comes from, pins drop locations on the world map, and searches the auction house for a recipe's reagents.

## Features

- Browse every profession from tabs on the journal's edge, styled like the spellbook.
- Search recipes by name. Recipes you haven't learned show a grey icon.
- Each recipe lists its sources (trainer, vendor, drop, quest). Click a drop source to open the world map with a waypoint pin on it.
- Each recipe lists its reagents with item tooltips. With the auction house open, click a reagent to search for it.

Open the journal with `/pj`, or from the addon compartment button on the minimap.

## Status

The UI, map pins, and auction house search are in place. The recipe database is a three-recipe seed that proves the data shape. A generated database covering every recipe is the next step. Nothing has been tested in the Forever client yet.

## Install

Copy this repository into `World of Warcraft/_classic_beta_/Interface/AddOns/ProfessionJournal`. The folder name must match `ProfessionJournal.toc`.

## Recipe data

`Data/Recipes.lua` registers one table per recipe:

```lua
{
  spell = 20034,          -- crafting spell ID; the name and icon come from the client
  profession = 333,       -- SkillLine ID from Data/Professions.lua
  skill = 300,            -- required skill rank
  creates = nil,          -- item ID the recipe makes, if any
  recipeItem = 16252,     -- the pattern/plans/formula item, if any
  reagents = { { item = 14344, count = 4 } },
  sources = {
    { kind = "drop", npc = "Scarlet Spellbinder", zone = "Western Plaguelands", x = 45.0, y = 18.0 },
  },
}
```

Sources name their zone instead of a `uiMapID`. The addon resolves zone names to map IDs at runtime, so the data survives Forever's map IDs differing from Classic Era or Mainline.

## Development

```sh
npm install
npm run check
```

`npm run check` parses every Lua file and verifies that the TOC lists exactly the Lua files in the repo.

## License

MIT
