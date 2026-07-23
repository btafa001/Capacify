// Emulator tests for the write-only `clientErrors` crash sink (M6).
//
// The collection is append-only: create is open (even signed-out — errors
// happen on public pages, and App Check is the real gate), but the shape is
// pinned so it can't become an arbitrary write dump, and nobody can read,
// update or delete through the client.
import { test, describe, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc } from 'firebase/firestore';

const here = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(here, '..', 'firestore.rules'), 'utf8');

let testEnv;

/** The reporter runs for signed-out visitors too, so that's the default. */
function anon() {
  return testEnv.unauthenticatedContext().firestore();
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-capacify',
    firestore: { rules, host: '127.0.0.1', port: 8080 },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe('clientErrors: append-only crash sink (M6)', () => {
  test('a well-formed report can be written by a signed-out caller', async () => {
    await assertSucceeds(
      setDoc(doc(anon(), 'clientErrors', 'e1'), {
        message: 'RangeError: index out of range',
        stack: '#0 ...',
        context: 'FlutterError',
        uid: '',
        url: 'https://capacify.de/app',
        userAgent: 'Mozilla/5.0',
        appVersion: '1.0.0+1',
      })
    );
  });

  test('a report carrying an unexpected key is rejected', async () => {
    await assertFails(
      setDoc(doc(anon(), 'clientErrors', 'e2'), {
        message: 'boom',
        evilPayload: 'x'.repeat(100),
      })
    );
  });

  test('an over-long message is rejected', async () => {
    await assertFails(
      setDoc(doc(anon(), 'clientErrors', 'e3'), {
        message: 'x'.repeat(2001),
      })
    );
  });

  test('a non-string message is rejected', async () => {
    await assertFails(
      setDoc(doc(anon(), 'clientErrors', 'e4'), { message: 42 })
    );
  });

  test('nobody can read the sink through the client', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'clientErrors', 'seed'), {
        message: 'seeded',
      });
    });
    const signedIn = testEnv
      .authenticatedContext('some-user', { email_verified: true })
      .firestore();
    await assertFails(getDoc(doc(signedIn, 'clientErrors', 'seed')));
  });
});

// Sanity: prove the sink the tests target is actually declared.
test('the rules file under test declares the clientErrors sink', () => {
  assert.match(rules, /match \/clientErrors\/\{errorId\}/);
});
