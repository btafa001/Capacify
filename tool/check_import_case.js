#!/usr/bin/env node
// Resolves every relative / package:capacify import in the Dart sources against
// (a) the filesystem with EXACT case and (b) what git actually tracks.
//
// Why this exists: Windows and macOS are case-insensitive, Linux is not. An
// import of '../../profile/...' pointing at a directory git tracks as
// 'Profile/' builds fine on a developer laptop and fails to compile the moment
// it hits CI, a Linux contributor, or a cloud build (this repo had exactly that
// break in dashboard_screen.dart). The same class of "works here, not there"
// bug is a source file that exists on disk but was never `git add`ed — the
// laptop builds, the fresh clone doesn't.
//
// Run: node tool/check_import_case.js   (exits non-zero on any finding)
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const PKG = 'capacify';
const root = process.cwd();

const tracked = new Set(
  execSync('git ls-files', { encoding: 'utf8' }).split('\n').filter(Boolean)
);

// Directory listings, cached — readdir returns the real on-disk casing even on
// a case-insensitive filesystem, which is the whole trick here.
const dirCache = new Map();
function entries(dir) {
  if (!dirCache.has(dir)) {
    try {
      dirCache.set(dir, fs.readdirSync(path.join(root, dir)));
    } catch {
      dirCache.set(dir, null);
    }
  }
  return dirCache.get(dir);
}

// Walks a repo-relative POSIX path segment by segment, returning the path as it
// is REALLY spelled on disk, or null if some segment doesn't exist at all.
function realCase(relPath) {
  let current = '.';
  for (const segment of relPath.split('/')) {
    const listing = entries(current);
    if (!listing) return null;
    const match = listing.find(
      (e) => e.toLowerCase() === segment.toLowerCase()
    );
    if (!match) return null;
    current = current === '.' ? match : `${current}/${match}`;
  }
  return current;
}

const dartFiles = [...tracked].filter((f) => f.endsWith('.dart'));
const problems = [];

for (const file of dartFiles) {
  const src = fs.readFileSync(path.join(root, file), 'utf8');
  const importRe = /^\s*(?:import|export|part)\s+'([^']+)'/gm;
  let m;
  while ((m = importRe.exec(src)) !== null) {
    const spec = m[1];
    if (spec.startsWith('dart:')) continue;
    let target;
    if (spec.startsWith(`package:${PKG}/`)) {
      target = 'lib/' + spec.slice(`package:${PKG}/`.length);
    } else if (spec.startsWith('package:')) {
      continue; // third-party, resolved by pub not by us
    } else {
      target = path.posix.normalize(
        path.posix.join(path.posix.dirname(file), spec)
      );
    }

    const onDisk = realCase(target);
    if (onDisk === null) {
      problems.push(`MISSING     ${file}\n  imports '${spec}' → ${target} (no such file)`);
    } else if (onDisk !== target) {
      problems.push(
        `CASE        ${file}\n  imports '${spec}' → ${target}\n  but the real path is ${onDisk} — this fails to compile on Linux`
      );
    } else if (!tracked.has(target)) {
      problems.push(
        `UNTRACKED   ${file}\n  imports '${spec}' → ${target}, which exists locally but is not in git (a fresh clone won't build)`
      );
    }
  }
}

if (problems.length > 0) {
  console.error(problems.join('\n\n'));
  console.error(`\n${problems.length} import problem(s).`);
  process.exit(1);
}
console.log(`OK — every import in ${dartFiles.length} Dart files resolves, with the right case, to a tracked file.`);
