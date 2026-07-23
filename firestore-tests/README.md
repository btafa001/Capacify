# firestore.rules tests

`firestore.rules` is ~900 lines of fail-closed logic whose own comments record
several production incidents ("keine Berechtigung" lockouts, the App Check
rollout, the dealNumber forge). Rules regressions are this project's most likely
outage class and they are invisible until a real user hits one — usually behind
a `catch (_) {}`. These tests run the real rules file against the Firestore
emulator so a regression fails a build instead of a customer.

## Run them

```bash
cd firestore-tests
npm ci
npm run test:emulator
```

That boots the emulator, loads `../firestore.rules` into it, runs every
`*.test.js`, and shuts it down. Nothing touches the real `capacify-mvp`
project — the emulator runs under the local-only project id `demo-capacify`.

**Requirements:** Node 20+, the Firebase CLI on `PATH` (`npm i -g firebase-tools`),
and a **JDK 17+** — the Firestore emulator is a Java process, and without one
`emulators:exec` fails with "java: command not found". Install e.g.
[Temurin 17](https://adoptium.net/). CI installs both for you.

## What's covered

`capacities.test.js` — the anonymized-post model:

- **Ordinary owner edits keep working.** Deliberately first: a rule tightened
  too far denies every profile save silently, which is as bad as a hole.
- **Identity can't be forged after creation** — `visibilityMode`,
  `posterCompanyId/Name/LogoUrl` are pinned on update, so a clean post can't be
  edited into carrying a competitor's name.
- **Trust badges can't be forged** — `posterVerified` only ever mirrors the
  caller's own (admin-pinned) `verificationStatus`; the rating pair can't exceed
  the company's real totals; `dealNumber` and `posterSuspended` stay
  server-only; `contentFlagged` is one-way.
- **Responsiveness can't be overstated** — a claimed "antwortet in ~Xh" must be
  at least the poster's real average, behind the same ≥3-sample floor the client
  applies.
- **The identity sidecar stays locked** — `capacityOwners` is readable by the
  owner, an admin, or a *granted* contact request, and nobody else.

## Adding tests

One `*.test.js` per collection area. Seed with
`testEnv.withSecurityRulesDisabled()` so setup never depends on the rules under
test, and always pair a negative (`assertFails`) with the positive
(`assertSucceeds`) it must not break — a rule that errors out denies everything,
which makes a suite of only-negative tests pass for the wrong reason.
