import { readFileSync, readdirSync } from "node:fs";
import { join, relative } from "node:path";
import luaparse from "luaparse";

const root = new URL("..", import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1");
const tocFiles = readFileSync(join(root, "ProfessionJournal.toc"), "utf8")
  .split(/\r?\n/)
  .filter((line) => line.trim() && !line.startsWith("#"))
  .map((line) => line.trim().replaceAll("\\", "/"));

const walk = (dir) => readdirSync(dir, { withFileTypes: true }).flatMap((entry) =>
  entry.isDirectory() ? (entry.name === "node_modules" || entry.name.startsWith(".") ? [] : walk(join(dir, entry.name)))
    : /.(lua|xml)$/.test(entry.name) ? [relative(root, join(dir, entry.name)).replaceAll("\\", "/")] : []);
const luaFiles = walk(root);

let failed = false;
for (const file of luaFiles.filter((f) => !tocFiles.includes(f))) {
  console.error(`not listed in TOC: ${file}`);
  failed = true;
}
for (const file of tocFiles.filter((f) => !luaFiles.includes(f))) {
  console.error(`TOC lists missing file: ${file}`);
  failed = true;
}
for (const file of luaFiles.filter((f) => f.endsWith(".lua"))) {
  try {
    luaparse.parse(readFileSync(join(root, file), "utf8"), { luaVersion: "5.1" });
  } catch (error) {
    console.error(`${file}: ${error.message}`);
    failed = true;
  }
}
console.log(failed ? "check failed" : `ok: ${luaFiles.length} files match the TOC and the Lua parses`);
process.exit(failed ? 1 : 0);
