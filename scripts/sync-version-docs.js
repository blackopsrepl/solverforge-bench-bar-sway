// Sync tracked application-version statements with the bumped VERSION.
// Runs as the commit-and-tag-version precommit hook: VERSION is already
// bumped in lib/solverforge_bench_bar.rb, and this rewrites the old version
// to the new one in every doc surface that names it. Config schema 1 and
// snapshot schema 1 are separate contracts and are never touched.
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const versionFile = path.join(root, 'lib', 'solverforge_bench_bar.rb');
const docs = [
  'README.md',
  'AGENTS.md',
  'WIREFRAME.md',
  'docs/configuration.md',
  'docs/runtime-contracts.md',
];

const newVersion = (fs.readFileSync(versionFile, 'utf8').match(/VERSION = "([^"]+)"/) || [])[1];
if (!newVersion) {
  throw new Error('sync-version-docs: could not read VERSION from lib/solverforge_bench_bar.rb');
}

let previous = null;
try {
  previous = require('child_process')
    .execSync('git describe --tags --abbrev=0', { cwd: root, encoding: 'utf8' })
    .trim()
    .replace(/^v/, '');
} catch {
  previous = null;
}

if (!previous || previous === newVersion) {
  // Fall back to the version currently named in the docs.
  const probe = fs.readFileSync(path.join(root, docs[0]), 'utf8');
  const found = probe.match(/(\d+\.\d+\.\d+)/);
  previous = found ? found[1] : null;
}

if (!previous || previous === newVersion) {
  console.log(`sync-version-docs: docs already at ${newVersion}`);
  process.exit(0);
}

const pattern = new RegExp(previous.replace(/\./g, '\\.'), 'g');
for (const file of docs) {
  const target = path.join(root, file);
  const before = fs.readFileSync(target, 'utf8');
  const after = before.replace(pattern, newVersion);
  if (after !== before) {
    fs.writeFileSync(target, after);
    console.log(`sync-version-docs: ${file} ${previous} -> ${newVersion}`);
  }
}
