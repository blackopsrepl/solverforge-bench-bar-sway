// Release configuration for commit-and-tag-version.
// SolverForgeBenchBar::VERSION is the tracked application version surface so a
// release no longer needs a hand-edited constant. Config schema 1 and snapshot
// schema 1 are separate compatibility contracts and are never bumped here.

const versionFile = {
  filename: 'lib/solverforge_bench_bar.rb',
  updater: {
    readVersion(contents) {
      const match = contents.match(/VERSION = "([^"]+)"/);
      return match ? match[1] : null;
    },
    writeVersion(contents, version) {
      return contents.replace(/(VERSION = ")[^"]+(")/, `$1${version}$2`);
    },
  },
};

module.exports = {
  packageFiles: [versionFile],
  bumpFiles: [versionFile],
  tagPrefix: 'v',
  releaseCommitMessageFormat: 'chore(release): {{currentTag}}',
  commitUrlFormat: 'https://github.com/blackopsrepl/solverforge-bench-bar-sway/commit/{{hash}}',
  compareUrlFormat: 'https://github.com/blackopsrepl/solverforge-bench-bar-sway/compare/{{previousTag}}...{{currentTag}}',
};
