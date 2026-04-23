import { bundle } from "luabundle";
import { existsSync, readFileSync, statSync, writeFileSync } from "fs";
import { join, resolve } from "path";

const root = resolve(import.meta.dirname, "..");
const entryPoint = join(root, "yaxi/init.lua");

const paths = [
  "?.lua",
  "?/init.lua",
  "yaxi/?.lua",
  "yaxi/?/init.lua",
  "yaxi/routex-client-lua/?.lua",
  "yaxi/routex-client-lua/?/init.lua",
  "yaxi/routex-client-lua/routex-client/vendor/?.lua",
  "yaxi/routex-client-lua/routex-client/vendor/?/init.lua",
].map((p) => join(root, p));

function resolveModule(name, packagePaths) {
  const platformName = name.replace(/\./g, "/");
  for (const pattern of packagePaths) {
    const path = pattern.replace(/\?/g, platformName);
    if (existsSync(path) && statSync(path).isFile()) {
      return path;
    }
  }
  return null;
}

const outPath = join(import.meta.dirname, "YAXI.lua");

const result = bundle(entryPoint, {
  luaVersion: "5.3",
  paths,
  resolveModule,
  ignoredModuleNames: [
    "io",
    "os",
    "string",
    "table",
    "math",
    "debug",
    "coroutine",
    "package",
    "utf8",
  ],
});

// Extract the logo/header comment block from the entry point source and
// prepend it to the bundle output (the bundle itself starts with luabundle boilerplate).
const entrySource = readFileSync(entryPoint, "utf-8");
const headerLines = [];
let headerLineCount = 0;
let pastPreamble = false;
for (const line of entrySource.split("\n")) {
  if (!pastPreamble && (line.startsWith("-- SPDX") || line.startsWith("-- Author"))) {
    // Skip license/author lines — the bundle is a build artifact, not a source file.
    headerLineCount++;
    continue;
  }
  if (!pastPreamble && headerLines.length === 0 && (line.trim() === "" || line.trim() === "--")) {
    // Skip blank/empty-comment lines between preamble and logo.
    headerLineCount++;
    continue;
  }
  pastPreamble = true;
  if (line.startsWith("--") && !line.startsWith("---")) {
    headerLines.push(line);
    headerLineCount++;
  } else if (line.trim() === "") {
    headerLines.push(line);
    headerLineCount++;
  } else {
    break;
  }
}

// Remove the header lines from inside the __root closure so they aren't duplicated.
// The __root body starts after: __bundle_register("__root", function(...)\n
const rootMarker = '__bundle_register("__root", function(require, _LOADED, __bundle_register, __bundle_modules)\n';
const rootStart = result.indexOf(rootMarker);
let output = result;
if (rootStart !== -1) {
  const bodyStart = rootStart + rootMarker.length;
  const bodyLines = result.slice(bodyStart).split("\n");
  // Skip the same number of lines we extracted as header
  const remaining = bodyLines.slice(headerLineCount).join("\n");
  output = result.slice(0, bodyStart) + remaining;
}

headerLines.unshift("--");
const header = headerLines.join("\n").trimEnd();
writeFileSync(outPath, header + "\n\n" + output);
console.log(`Bundled successfully -> ${outPath}`);
