import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const auth = require("firebase-tools/lib/auth.js");
const rules = require("firebase-tools/lib/gcp/rules.js");
const projectId = "uri-sai-a8c73";
const releaseName = `projects/${projectId}/releases/cloud.firestore`;

async function main() {
  const projectConfig = JSON.parse(await readFile(".firebaserc", "utf8"));
  assert.equal(projectConfig.projects.default, projectId, "Unexpected Firebase project");

  const account = auth.getProjectDefaultAccount(process.cwd());
  assert.ok(account, "Firebase CLI login required: npm run login:firebase");
  auth.setActiveAccount({}, account);

  const releases = await rules.listAllReleases(projectId);
  const release = releases.find((entry) => entry.name === releaseName);
  assert.ok(release?.rulesetName, "No published rules for the default Firestore database");

  const files = await rules.getRulesetContent(release.rulesetName);
  assert.equal(files.length, 1, "Expected exactly one published rules file");
  const localContent = await readFile("firestore.rules", "utf8");
  assert.equal(files[0].content, localContent, "Published rules differ from firestore.rules");
  process.stdout.write(`Published Firestore rules match firestore.rules (${projectId}).\n`);
}

main().catch((error) => {
  process.stderr.write(`${error.message}\n`);
  process.exitCode = 1;
});
