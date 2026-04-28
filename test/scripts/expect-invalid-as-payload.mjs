import {spawnSync} from "node:child_process";
import {dirname, join} from "node:path";
import {fileURLToPath} from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const testRoot = dirname(scriptDir);
const fixtureDir = join(testRoot, "fixtures", "invalid-as-payload");
const binName = process.platform === "win32" ? "rescript.cmd" : "rescript";
const rescriptBin = join(testRoot, "node_modules", ".bin", binName);
const expected =
  "@spice.as is only supported on constructors without payload";

const result = spawnSync(rescriptBin, [], {
  cwd: fixtureDir,
  encoding: "utf8",
});

const output = `${result.stdout ?? ""}${result.stderr ?? ""}`;

if (result.status === 0) {
  console.error("Expected invalid @spice.as payload fixture to fail.");
  process.exit(1);
}

if (!output.includes(expected)) {
  console.error("Invalid @spice.as payload fixture failed with unexpected output.");
  console.error(output);
  process.exit(1);
}

console.log("compile-fail: invalid @spice.as payload rejected");
