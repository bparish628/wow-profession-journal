// Regenerates Data/Professions.lua and Data/Recipes.lua.
// Recipes, reagents, and skill ranks come from the Forever client's DB2 tables (wago.tools).
// Where a recipe comes from (drops, vendors, quests) is not in client data, so it comes from Wowhead.
//
//   node scripts/build-data.mjs [--build=1.60.1.70245] [--wowhead=classic|forever|none]
//
// --wowhead=none builds from Blizzard data alone: no recipe drop sources,
// gathering nodes, zone levels, or fishing waters.

import { mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { createHash } from "node:crypto";

const root = new URL("..", import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1");
const args = Object.fromEntries(process.argv.slice(2).map((a) => a.replace(/^--/, "").split("=")));
const cacheDir = join(root, ".cache");
mkdirSync(cacheDir, { recursive: true });

const WOWHEAD = `https://www.wowhead.com/${args.wowhead ?? "classic"}`;
const USE_WOWHEAD = args.wowhead !== "none";
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
    const body = await res.text();
    if (res.status === 200 && body.length > 0) {
      writeFileSync(file, body);
      return body;
    }
    // Wowhead answers clients it treats as bots with an empty 202. Caching that
    // would record every page as having no data, so stop instead.
    if (res.status === 202) throw new Error(`${url} answered 202 with ${body.length} bytes: a bot check, not a page`);
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
const db2 = async (table, forBuild = build) => parseCsv(await cachedFetch(`https://wago.tools/db2/${table}/csv?build=${forBuild}`));
const latestBuild = async (product) => JSON.parse(await (await fetch("https://wago.tools/api/builds")).text())[product][0].version;
const num = (v) => Number(v) || 0;
console.log(`build ${build}, sources from ${WOWHEAD}`);

const [skillLines, abilities, spellReagents, spellEffects, itemEffects, itemXEffects, items, spellNames, areas, uiMaps,
  uiMapAssignments, tradeSkillCategories] = await Promise.all(["SkillLine", "SkillLineAbility", "SpellReagents",
  "SpellEffect", "ItemEffect", "ItemXItemEffect", "ItemSparse", "SpellName", "AreaTable", "UiMap", "UiMapAssignment",
  "TradeSkillCategory"].map((table) => db2(table)));

// Client data has no flag for gathering, so these are named here.
const GATHERING = new Set([182, 186, 393]);
const FISHING = 356;
const FISHING_POOL_TYPE = 25;
const MAX_CATCHES = 8;
const MIN_CATCH_SHARE = 0.02;
const NODE_LISTS = { 182: { list: "herbs", loot: "herbalism" }, 186: { list: "mineral-veins", loot: "mining" } };
const SECONDARY_CATEGORY = 9;
const MAX_YIELDS = 5;
const MIN_YIELD_CHANCE = 0.005;

// The client marks real professions by giving them child skill lines (one per expansion tier).
const parentIDs = new Set(skillLines.map((s) => num(s.ParentSkillLineID)).filter(Boolean));
const professions = skillLines
  .filter((s) => parentIDs.has(num(s.ID)) && !/DNT/.test(s.DisplayName_lang))
  .map((s) => ({
    id: num(s.ID), name: s.DisplayName_lang, icon: num(s.SpellIconFileID),
    group: GATHERING.has(num(s.ID)) ? "gathering" : num(s.CategoryID) === SECONDARY_CATEGORY ? "secondary" : "crafting",
    tiers: skillLines.filter((c) => num(c.ParentSkillLineID) === num(s.ID)).map((c) => num(c.ID)),
  }));
const professionIDs = new Set(professions.map((p) => p.id));

const spellName = new Map(spellNames.map((s) => [num(s.ID), s.Name_lang]));
const reagentsBySpell = new Map(spellReagents.map((r) => [num(r.SpellID),
  [0, 1, 2, 3, 4, 5, 6, 7].map((i) => ({ item: num(r[`Reagent_${i}`]), count: num(r[`ReagentCount_${i}`]) }))
    .filter((x) => x.item > 0 && x.count > 0)]));
const reagentItems = new Set([...reagentsBySpell.values()].flat().map((r) => r.item));
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

// The Forever client also ships Season of Discovery recipes, which Blizzard
// files under categories named "SEASON OF DISCOVERY". Recipes absent from the
// Classic Era client are new in Forever.
const seasonOfDiscovery = new Set(tradeSkillCategories
  .filter((c) => c.Name_lang === "SEASON OF DISCOVERY").map((c) => num(c.ID)));
const eraBuild = args.era ?? await latestBuild("wow_classic_era");
const eraSpells = new Set((await db2("SkillLineAbility", eraBuild)).map((a) => num(a.Spell)));
const uiMapIDs = new Set(uiMaps.map((m) => num(m.ID)));

const recipes = [];
const seen = new Set();
for (const a of abilities) {
  const spell = num(a.Spell);
  const profession = num(a.SkillLine);
  const name = spellName.get(spell) ?? "";
  if (!professionIDs.has(profession) || !reagentsBySpell.has(spell) || seen.has(spell)) continue;
  // Blizzard's profession window lists recipes by category, so one without a
  // category is a leftover (e.g. classic Basic Campfire beside Forever's).
  const category = num(a.TradeSkillCategoryID);
  if (/DNT|^zz|^Test /i.test(name) || !category || seasonOfDiscovery.has(category)) continue;
  seen.add(spell);
  const recipeItem = recipeItemBySpell.get(spell);
  recipes.push({
    spell, profession, name,
    category,
    forever: eraSpells.has(spell) ? undefined : true,
    skill: recipeItem ? num(itemByID.get(recipeItem).RequiredSkillRank) || undefined : undefined,
    yellow: num(a.TrivialSkillLineRankLow),
    grey: num(a.TrivialSkillLineRankHigh),
    creates: createdBy.get(spell),
    recipeItem,
    reagents: reagentsBySpell.get(spell),
  });
}
const shownProfessions = professions.filter((p) => GATHERING.has(p.id) || p.id === FISHING || recipes.some((r) => r.profession === p.id));
console.log(`${shownProfessions.length} professions, ${recipes.length} recipes, ${recipes.filter((r) => r.recipeItem).length} with recipe items`);

// Listview data is a JavaScript literal that sometimes has bare keys
// (`count:22`). Quote them outside strings so JSON.parse can read it, rather
// than evaluating page text as code.
function parseJsLiteral(text) {
  let out = "", inString = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (inString) {
      out += ch;
      if (ch === "\\") out += text[++i];
      else if (ch === '"') inString = false;
    } else if (ch === '"') {
      inString = true;
      out += ch;
    } else {
      const bare = /^[A-Za-z_]\w*(?=\s*:)/.exec(text.slice(i, i + 64));
      if (bare && /[{,]\s*$/.test(out)) {
        out += `"${bare[0]}"`;
        i += bare[0].length - 1;
      } else out += ch;
    }
  }
  return JSON.parse(out);
}

// Wowhead pages carry their tables either as JSON (list pages) or as
// `new Listview({ id: ..., data: [...] })` calls (detail pages).
function listview(html, id) {
  const json = html.match(/<script type="application\/json" id="data\.page\.listPage\.listviews">(.*?)<\/script>/s);
  const fromJson = json && JSON.parse(json[1]).find((view) => view.id === id);
  if (fromJson) return fromJson.data;
  const start = html.search(new RegExp(`id: ['"]${id}['"]`));
  if (start < 0) return [];
  const next = html.indexOf("new Listview", start);
  const dataMatch = /data:\s*\[/.exec(html.slice(start));
  const dataAt = dataMatch ? start + dataMatch.index : -1;
  if (dataAt < 0 || (next >= 0 && dataAt > next)) return [];
  const open = dataAt + dataMatch[0].length - 1;
  const total = Number(/_totalCount:\s*(\d+)/.exec(html.slice(start, dataAt))?.[1]) || undefined;
  let depth = 0, inString = false;
  for (let i = open; i < html.length; i++) {
    const ch = html[i];
    if (inString) {
      if (ch === "\\") i++;
      else if (ch === '"') inString = false;
    } else if (ch === '"') inString = true;
    else if (ch === "[" || ch === "{") depth++;
    else if ((ch === "]" || ch === "}") && --depth === 0) {
      return parseJsLiteral(html.slice(open, i + 1)).map((row) => ({ outof: total, ...row }));
    }
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
  if (!USE_WOWHEAD) {
    recipe.sources = recipe.recipeItem ? [] : [{ kind: "trainer" }];
    continue;
  }
  recipe.sources = await sourcesFor(recipe);
  recipe.skill ??= await learnedAt(recipe);
  if (++done % 100 === 0) console.log(`  sources ${done}/${recipes.length}`);
}

const uiMapByArea = new Map(uiMapAssignments
  .filter((a) => uiMapIDs.has(num(a.UiMapID)) && num(a.AreaID))
  .map((a) => [num(a.AreaID), num(a.UiMapID)]));

const zones = (USE_WOWHEAD ? listview(await cachedFetch(`${WOWHEAD}/zones`), "zones") : [])
  .filter((z) => !z.instance && z.minlevel > 0 && uiMapByArea.has(z.id))
  .map((z) => ({ area: z.id, map: uiMapByArea.get(z.id), minLevel: z.minlevel, maxLevel: z.maxlevel }))
  .sort((a, b) => a.minLevel - b.minLevel || a.map - b.map);

const round1 = (n) => Math.round(n * 10) / 10;

async function nodeDetails(objectID, lootID) {
  const html = await cachedFetch(`${WOWHEAD}/object=${objectID}`);
  const spawns = {};
  const mapper = html.match(/g_mapperData = (\{.*?\});/);
  for (const floor of mapper ? Object.values(JSON.parse(mapper[1])).flat() : []) {
    if (!uiMapIDs.has(floor.uiMapId)) continue;
    spawns[floor.uiMapId] = (spawns[floor.uiMapId] ?? []).concat(floor.coords.flatMap(([x, y]) => [round1(x), round1(y)]));
  }
  const yields = listview(html, lootID)
    .filter((i) => itemByID.has(i.id) && i.outof && i.count / i.outof >= MIN_YIELD_CHANCE)
    .sort((a, b) => b.count / b.outof - a.count / a.outof)
    .map((i) => i.id);
  return { spawns, yields };
}

// Wowhead lists several object IDs for one node name (variants and respawn
// copies), so nodes merge by name.
const nodes = [];
for (const [profession, { list, loot }] of USE_WOWHEAD ? Object.entries(NODE_LISTS) : []) {
  const byName = new Map();
  for (const object of listview(await cachedFetch(`${WOWHEAD}/objects/${list}`), "objects")) {
    const { spawns, yields } = await nodeDetails(object.id, loot);
    const node = byName.get(object.name) ?? { profession: Number(profession), name: object.name, skill: object.skill, yields: [], spawns: {} };
    for (const id of yields) if (!node.yields.includes(id)) node.yields.push(id);
    for (const [map, coords] of Object.entries(spawns)) node.spawns[map] = (node.spawns[map] ?? []).concat(coords);
    byName.set(object.name, node);
  }
  // Herb and mining lists also hold quest objects; a real node yields a crafting reagent.
  for (const node of byName.values()) {
    if (reagentItems.has(node.yields[0]) && Object.keys(node.spawns).length) {
      nodes.push({ ...node, yields: node.yields.slice(0, MAX_YIELDS) });
    }
  }
}
// Fishing pools have no list page of their own; they are type 25 in the full object list.
const pools = new Map();
for (const object of USE_WOWHEAD ? listview(await cachedFetch(`${WOWHEAD}/objects`), "objects") : []) {
  if (object.type !== FISHING_POOL_TYPE) continue;
  const { spawns, yields } = await nodeDetails(object.id, "fishing");
  const pool = pools.get(object.name) ?? { profession: FISHING, name: object.name, yields: [], spawns: {} };
  for (const id of yields) if (!pool.yields.includes(id)) pool.yields.push(id);
  for (const [map, coords] of Object.entries(spawns)) pool.spawns[map] = (pool.spawns[map] ?? []).concat(coords);
  pools.set(object.name, pool);
}
for (const pool of pools.values()) {
  if (pool.yields.length && Object.keys(pool.spawns).length) nodes.push({ ...pool, yields: pool.yields.slice(0, MAX_YIELDS) });
}

// What each zone's open water yields, skipping poor-quality junk. A zone's
// _totalCount counts every cast, most of them not itemized, so shares are
// taken against the catches Wowhead did list.
const waters = [];
for (const zone of zones) {
  const listed = listview(await cachedFetch(`${WOWHEAD}/zone=${zone.area}`), "fishing");
  const totalCaught = listed.reduce((sum, i) => sum + (i.count ?? 0), 0);
  const catches = listed
    .filter((i) => itemByID.has(i.id) && num(itemByID.get(i.id).OverallQualityID) > 0 && i.count / totalCaught >= MIN_CATCH_SHARE)
    .sort((a, b) => b.count - a.count)
    .slice(0, MAX_CATCHES)
    .map((i) => i.id);
  if (catches.length) waters.push({ profession: FISHING, map: zone.map, minLevel: zone.minLevel, maxLevel: zone.maxLevel, yields: catches });
}
console.log(`${zones.length} zones with levels, ${nodes.length} gathering nodes and pools, ${waters.length} fishing waters`);

const lua = (value) => {
  if (Array.isArray(value)) return `{ ${value.map(lua).join(", ")} }`;
  if (typeof value === "object") {
    return `{ ${Object.entries(value).filter(([, v]) => v !== undefined)
      .map(([k, v]) => `${/^\d+$/.test(k) ? `[${k}]` : k} = ${lua(v)}`).join(", ")} }`;
  }
  return typeof value === "string" ? JSON.stringify(value) : String(value);
};
const header = `local _, PJ = ...\n\n-- Generated by scripts/build-data.mjs from WoW Forever build ${build}. Do not edit by hand.\n`;

const writeData = (file, register, rows) => writeFileSync(join(root, "Data", file),
  `${header}for _, entry in ipairs({\n${rows.join("\n")}\n}) do\n  PJ.${register}(entry)\nend\n`);

shownProfessions.sort((a, b) => a.name.localeCompare(b.name));
writeData("Professions.lua", "RegisterProfession", shownProfessions.map((p) => `  ${lua(p)},`));
const usedCategories = new Set(recipes.map((r) => r.category));
const categories = tradeSkillCategories
  .filter((c) => usedCategories.has(num(c.ID)))
  .map((c) => ({ id: num(c.ID), name: c.Name_lang, order: num(c.OrderIndex) }))
  .sort((a, b) => a.id - b.id);
writeData("Categories.lua", "RegisterCategory", categories.map((c) => `  ${lua(c)},`));
writeData("Zones.lua", "RegisterZone", zones.map(({ area, ...z }) => `  ${lua(z)},`));
writeData("Waters.lua", "RegisterWater", waters.map((w) => `  ${lua(w)},`));
nodes.sort((a, b) => a.profession - b.profession || (a.skill ?? 0) - (b.skill ?? 0) || a.name.localeCompare(b.name));
writeData("Nodes.lua", "RegisterNode", nodes.map((n) => `  ${lua(n)},`));

recipes.sort((a, b) => a.profession - b.profession || (a.skill ?? a.yellow) - (b.skill ?? b.yellow) || a.spell - b.spell);
writeData("Recipes.lua", "RegisterRecipe", recipes.map(({ name, ...r }) => `  ${lua(r)}, -- ${name}`));

const withSources = recipes.filter((r) => r.sources.length).length;
const pinned = recipes.filter((r) => r.sources.some((s) => s.map)).length;
console.log(`wrote ${recipes.length} recipes: ${withSources} with a known source, ${pinned} with a map pin`);
