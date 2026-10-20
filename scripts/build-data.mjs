// Regenerates Data/Professions.lua and Data/Recipes.lua.
// Recipes, reagents, and skill ranks come from the Forever client's DB2 tables (wago.tools).
// Where a recipe comes from (drops, vendors, quests) is not in client data, so it comes from Wowhead.
//
//   node scripts/build-data.mjs [--build=1.60.1.70245] [--wowhead=classic]

import { mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { createHash } from "node:crypto";

const root = new URL("..", import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1");
const args = Object.fromEntries(process.argv.slice(2).map((a) => a.replace(/^--/, "").split("=")));
const cacheDir = join(root, ".cache");
mkdirSync(cacheDir, { recursive: true });

const WOWHEAD = `https://www.wowhead.com/${args.wowhead ?? "classic"}`;
const MAX_DROPPERS = 6;
const MAX_VENDORS = 4;
const MAX_QUESTS = 3;
const EFFECT_CREATE_ITEM = 24;
const ITEM_EFFECT_LEARN = 6;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Wowhead blocks an IP for a while after a few hundred quick requests, so its
// pages are fetched one at a time with a gap, and a block means waiting it out.
const WOWHEAD_GAP_MS = 2500;
const BLOCKED_WAIT_MS = 15 * 60 * 1000;
let lastWowheadFetch = 0;

async function cachedFetch(url) {
  const file = join(cacheDir, createHash("sha1").update(url).digest("hex"));
  if (existsSync(file)) return readFileSync(file, "utf8");
  const throttled = url.startsWith(WOWHEAD);
  for (let attempt = 0; attempt < 8; attempt++) {
    if (throttled) {
      await sleep(Math.max(0, lastWowheadFetch + WOWHEAD_GAP_MS - Date.now()));
      lastWowheadFetch = Date.now();
    }
    const res = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0 wow-profession-journal data build" } });
    if (res.status === 404) {
      writeFileSync(file, "");
      return "";
    }
    if (res.ok) {
      const body = await res.text();
      writeFileSync(file, body);
      return body;
    }
    const wait = throttled ? BLOCKED_WAIT_MS : 5000;
    console.warn(`${res.status} ${url}, retrying in ${wait / 1000}s`);
    await sleep(wait);
  }
  throw new Error(`giving up on ${url}`);
}

function parseCsv(text) {
  const rows = [];
  let row = [], field = "", quoted = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (ch === '"') quoted = false;
      else field += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ",") { row.push(field); field = ""; }
    else if (ch === "\n" || ch === "\r") {
      if (ch === "\r" && text[i + 1] === "\n") i++;
      row.push(field); rows.push(row); row = []; field = "";
    } else field += ch;
  }
  if (field || row.length) { row.push(field); rows.push(row); }
  const [header, ...body] = rows;
  return body.filter((r) => r.length === header.length)
    .map((r) => Object.fromEntries(header.map((h, i) => [h, r[i]])));
}

async function latestForeverBuild() {
  const builds = JSON.parse(await (await fetch("https://wago.tools/api/builds")).text());
  return builds.wowf[0].version;
}

const build = args.build ?? await latestForeverBuild();
const db2 = async (table) => parseCsv(await cachedFetch(`https://wago.tools/db2/${table}/csv?build=${build}`));
const num = (v) => Number(v) || 0;
console.log(`build ${build}, sources from ${WOWHEAD}`);

const [skillLines, abilities, spellReagents, spellEffects, itemEffects, itemXEffects, items, spellNames, areas, uiMaps] =
  await Promise.all(["SkillLine", "SkillLineAbility", "SpellReagents", "SpellEffect", "ItemEffect",
    "ItemXItemEffect", "ItemSparse", "SpellName", "AreaTable", "UiMap"].map(db2));

// The client marks real professions by giving them child skill lines (one per expansion tier).
const parentIDs = new Set(skillLines.map((s) => num(s.ParentSkillLineID)).filter(Boolean));
const professions = skillLines
  .filter((s) => parentIDs.has(num(s.ID)) && !/DNT/.test(s.DisplayName_lang))
  .map((s) => ({ id: num(s.ID), name: s.DisplayName_lang, icon: num(s.SpellIconFileID) }));
const professionIDs = new Set(professions.map((p) => p.id));

const spellName = new Map(spellNames.map((s) => [num(s.ID), s.Name_lang]));
const reagentsBySpell = new Map(spellReagents.map((r) => [num(r.SpellID),
  [0, 1, 2, 3, 4, 5, 6, 7].map((i) => ({ item: num(r[`Reagent_${i}`]), count: num(r[`ReagentCount_${i}`]) }))
    .filter((x) => x.item > 0 && x.count > 0)]));
const createdBy = new Map(spellEffects
  .filter((e) => num(e.Effect) === EFFECT_CREATE_ITEM && num(e.EffectItemType) > 0)
  .map((e) => [num(e.SpellID), num(e.EffectItemType)]));
const itemByID = new Map(items.map((i) => [num(i.ID), i]));
const itemsByEffect = new Map();
for (const x of itemXEffects) {
  const list = itemsByEffect.get(num(x.ItemEffectID)) ?? [];
  list.push(num(x.ItemID));
  itemsByEffect.set(num(x.ItemEffectID), list);
}
const recipeItemBySpell = new Map();
for (const e of itemEffects) {
  if (num(e.TriggerType) !== ITEM_EFFECT_LEARN) continue;
  const candidates = (itemsByEffect.get(num(e.ID)) ?? []).filter((id) => itemByID.has(id)).sort((a, b) => a - b);
  if (candidates.length && !recipeItemBySpell.has(num(e.SpellID))) recipeItemBySpell.set(num(e.SpellID), candidates[0]);
}
const areaIDs = new Set(areas.map((a) => num(a.ID)));
const uiMapIDs = new Set(uiMaps.map((m) => num(m.ID)));

const recipes = [];
const seen = new Set();
for (const a of abilities) {
  const spell = num(a.Spell);
  const profession = num(a.SkillLine);
  const name = spellName.get(spell) ?? "";
  if (!professionIDs.has(profession) || !reagentsBySpell.has(spell) || seen.has(spell)) continue;
  if (/DNT|^zz|^Test /i.test(name)) continue;
  seen.add(spell);
  const recipeItem = recipeItemBySpell.get(spell);
  recipes.push({
    spell, profession, name,
    skill: recipeItem ? num(itemByID.get(recipeItem).RequiredSkillRank) || undefined : undefined,
    yellow: num(a.TrivialSkillLineRankLow),
    grey: num(a.TrivialSkillLineRankHigh),
    creates: createdBy.get(spell),
    recipeItem,
    reagents: reagentsBySpell.get(spell),
  });
}
const craftingProfessions = professions.filter((p) => recipes.some((r) => r.profession === p.id));
console.log(`${craftingProfessions.length} professions, ${recipes.length} recipes, ${recipes.filter((r) => r.recipeItem).length} with recipe items`);

function listview(html, id) {
  const start = html.search(new RegExp(`id: ['"]${id}['"]`));
  if (start < 0) return [];
  const next = html.indexOf("new Listview", start);
  const dataAt = html.indexOf("data: [", start);
  if (dataAt < 0 || (next >= 0 && dataAt > next)) return [];
  const open = dataAt + "data: ".length;
  let depth = 0, inString = false;
  for (let i = open; i < html.length; i++) {
    const ch = html[i];
    if (inString) {
      if (ch === "\\") i++;
      else if (ch === '"') inString = false;
    } else if (ch === '"') inString = true;
    else if (ch === "[" || ch === "{") depth++;
    else if ((ch === "]" || ch === "}") && --depth === 0) return JSON.parse(html.slice(open, i + 1));
  }
  throw new Error(`unterminated ${id} listview`);
}

const npcCache = new Map();
async function npcSpawn(npcID) {
  if (npcCache.has(npcID)) return npcCache.get(npcID);
  const html = await cachedFetch(`${WOWHEAD}/npc=${npcID}`);
  const mapper = html.match(/g_mapperData = (\{.*?\});/);
  let spawn;
  if (mapper) {
    const floors = Object.values(JSON.parse(mapper[1])).flat()
      .filter((f) => uiMapIDs.has(f.uiMapId) && f.coords?.length)
      .sort((a, b) => b.coords.length - a.coords.length);
    if (floors.length) {
      const { coords, uiMapId } = floors[0];
      const cx = coords.reduce((s, c) => s + c[0], 0) / coords.length;
      const cy = coords.reduce((s, c) => s + c[1], 0) / coords.length;
      const [x, y] = coords.reduce((best, c) =>
        Math.hypot(c[0] - cx, c[1] - cy) < Math.hypot(best[0] - cx, best[1] - cy) ? c : best);
      spawn = { map: uiMapId, x, y };
    }
  }
  npcCache.set(npcID, spawn);
  return spawn;
}

const area = (npc) => (npc.location ?? []).find((id) => areaIDs.has(id));

async function sourcesFor(recipe) {
  if (!recipe.recipeItem) return [{ kind: "trainer" }];
  const html = await cachedFetch(`${WOWHEAD}/item=${recipe.recipeItem}`);
  const sources = [];

  const droppers = listview(html, "dropped-by");
  if (droppers.length > MAX_DROPPERS * 2) {
    sources.push({ kind: "worlddrop" });
  } else {
    const ranked = droppers
      .map((n) => ({ ...n, chance: n.outof ? (100 * n.count) / n.outof : 0 }))
      .sort((a, b) => b.chance - a.chance)
      .slice(0, MAX_DROPPERS);
    for (const n of ranked) {
      sources.push({ kind: "drop", npc: n.name, chance: Math.round(n.chance * 10) / 10 || undefined, area: area(n), ...await npcSpawn(n.id) });
    }
  }
  for (const n of listview(html, "sold-by").slice(0, MAX_VENDORS)) {
    sources.push({ kind: "vendor", npc: n.name, area: area(n), ...await npcSpawn(n.id) });
  }
  for (const q of listview(html, "reward-from").slice(0, MAX_QUESTS)) {
    sources.push({ kind: "quest", quest: q.name });
  }
  for (const o of listview(html, "contained-in-object").slice(0, MAX_DROPPERS)) {
    sources.push({ kind: "object", object: o.name, area: area(o) });
  }
  return sources;
}

const skillPages = new Map();
async function learnedAt(recipe) {
  if (!skillPages.has(recipe.profession)) {
    const html = await cachedFetch(`${WOWHEAD}/skill=${recipe.profession}`);
    skillPages.set(recipe.profession, new Map(listview(html, "recipes").map((s) => [s.id, s.learnedat])));
  }
  return skillPages.get(recipe.profession).get(recipe.spell);
}

let done = 0;
for (const recipe of recipes) {
  recipe.sources = await sourcesFor(recipe);
  recipe.skill ??= await learnedAt(recipe);
  if (++done % 100 === 0) console.log(`  sources ${done}/${recipes.length}`);
}

const lua = (value) => {
  if (Array.isArray(value)) return `{ ${value.map(lua).join(", ")} }`;
  if (typeof value === "object") {
    return `{ ${Object.entries(value).filter(([, v]) => v !== undefined).map(([k, v]) => `${k} = ${lua(v)}`).join(", ")} }`;
  }
  return typeof value === "string" ? JSON.stringify(value) : String(value);
};
const header = `local _, PJ = ...\n\n-- Generated by scripts/build-data.mjs from WoW Forever build ${build}. Do not edit by hand.\n`;

craftingProfessions.sort((a, b) => a.name.localeCompare(b.name));
writeFileSync(join(root, "Data", "Professions.lua"),
  `${header}for _, profession in ipairs({\n${craftingProfessions.map((p) => `  ${lua(p)},`).join("\n")}\n}) do\n  PJ.RegisterProfession(profession)\nend\n`);

recipes.sort((a, b) => a.profession - b.profession || (a.skill ?? a.yellow) - (b.skill ?? b.yellow) || a.spell - b.spell);
writeFileSync(join(root, "Data", "Recipes.lua"),
  `${header}for _, recipe in ipairs({\n${recipes.map(({ name, ...r }) => `  ${lua(r)}, -- ${name}`).join("\n")}\n}) do\n  PJ.RegisterRecipe(recipe)\nend\n`);

const withSources = recipes.filter((r) => r.sources.length).length;
const pinned = recipes.filter((r) => r.sources.some((s) => s.map)).length;
console.log(`wrote ${recipes.length} recipes: ${withSources} with a known source, ${pinned} with a map pin`);
