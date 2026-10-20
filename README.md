# Profession Journal

A World of Warcraft: Forever addon that puts every profession and recipe in one in-game journal. It shows where each recipe comes from, pins drop locations on the world map, and searches the auction house for a recipe's reagents.

## Features

- Browse every profession from tabs on the journal's edge, styled like the spellbook.
- Search recipes by name. Recipes you haven't learned show a grey icon.
- Each recipe lists its sources (trainer, vendor, drop, quest). Click a drop source to open the world map with a waypoint pin on it.
- Each recipe shows its skill-up colors (orange, yellow, green, grey) and the formula, pattern, or plans item that teaches it.
- Each recipe lists its reagents in their quality colors, with how many you have across bags and bank.
- With the auction house open, click a reagent or recipe item to search for it. Shift-click any item or recipe to link it in chat.
- Opening a profession window caches Blizzard's own source text for its unlearned recipes, which fills in recipes the generated data has no source for.

Open the journal with `/pj`, the minimap button, or the addon compartment. Right-click the minimap button or type `/pj options` to open the settings, where the minimap button can be turned off.

## Status

The UI, map pins, and auction house search are in place, and the recipe database is generated from the Forever client's own data. The journal loads and renders in the Forever beta (build 1.60.1.70450).

## Install

Copy this repository into `World of Warcraft/_classic_beta_/Interface/AddOns/ProfessionJournal`. The folder name must match `ProfessionJournal.toc`.

## Recipe data

`Data/Professions.lua` and `Data/Recipes.lua` are generated. Don't edit them by hand. Regenerate them with:

```sh
npm install
npm run data                           # latest Forever build
npm run data -- --build=1.60.1.70245   # a specific build
```

The generator reads two sources:

- **Blizzard client data.** The Forever client's DB2 tables, exported by [wago.tools](https://wago.tools) for the `wowf` product, provide the professions, recipes, reagents, created items, recipe items, required skill, and skill-up colors. Rerunning against a new build picks up new recipes automatically.
- **Wowhead.** Where a recipe item comes from (drops with drop chance, vendors, quests, containers) isn't in client data, so it comes from Wowhead's item and NPC pages. Map pins use Wowhead's spawn coordinates, kept only when the map exists in Forever's own `UiMap` table. Wowhead's Forever database isn't public yet, so this reads the Classic database by default. Pass `--wowhead=forever` once it is. Recipes new to Forever show "Source unknown" until then.

Downloads are cached in `.cache/`. Delete it to refetch.

Each recipe looks like this:

```lua
{
  spell = 20034,          -- crafting spell; the client supplies its name and icon
  profession = 333,       -- SkillLine ID from Data/Professions.lua
  skill = 300,            -- required rank (orange)
  yellow = 320, grey = 360,
  recipeItem = 16252,     -- the formula, pattern, or plans item, if any
  reagents = { { item = 14344, count = 4 }, { item = 12811, count = 2 } },
  sources = {
    { kind = "drop", npc = "Scarlet Spellbinder", chance = 0.4, area = 28, map = 1422, x = 54.8, y = 23.6 },
  },
}
```

`kind` is one of `trainer`, `drop`, `worlddrop`, `vendor`, `quest`, or `object`. `area` is an AreaTable ID the client turns into a localized zone name. `map`, `x`, and `y` appear only when the source can be pinned.

## Development

```sh
npm install
npm run check
```

`npm run check` parses every Lua file and verifies that the TOC lists exactly the Lua files in the repo.

## License

MIT
