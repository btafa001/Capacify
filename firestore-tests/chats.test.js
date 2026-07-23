// Emulator tests for the `chats` create rule — specifically that a thread's
// membership is pinned to exactly the two real parties (M2).
//
// The create rule confirms the requester AND the poster are both `in
// participants`, but `in` says nothing about SIZE: before the fix a requester
// could create the thread as [requester, poster, thirdAccount], and that third
// uid then passed every read/write rule in the collection — all of which key
// off `uid in participants`. participants.size() == 2 closes that, and the
// update rule already freezes the set, so pinning it at creation is enough.
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
import { doc, setDoc } from 'firebase/firestore';

const here = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(here, '..', 'firestore.rules'), 'utf8');

const REQUESTER = 'req-co';
const POSTER = 'post-co';
const THIRD = 'third-co';
const POST = 'post-1';
// chatId == the contact_request id == {requesterCompanyId}_{postId}.
const CHAT = `${REQUESTER}_${POST}`;

let testEnv;

/** Signed-in, email-verified context — what every real account carries. */
function ctx(uid) {
  return testEnv.authenticatedContext(uid, { email_verified: true }).firestore();
}

/**
 * Seeds a GRANTED contact request plus the locked owner sidecar the create rule
 * resolves the poster identity from. Written with rules disabled so seeding
 * never depends on the rules under test.
 */
async function seed({ status = 'granted' } = {}) {
  await testEnv.withSecurityRulesDisabled(async (c) => {
    const db = c.firestore();
    await setDoc(doc(db, 'contact_requests', CHAT), {
      requesterCompanyId: REQUESTER,
      postId: POST,
      status,
    });
    await setDoc(doc(db, 'capacityOwners', POST), {
      posterCompanyId: POSTER,
      companyName: 'Bau Meier GmbH',
    });
  });
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

describe('chats: a thread is exactly its two parties (M2)', () => {
  test('the requester can open the thread with {requester, poster}', async () => {
    await seed();
    await assertSucceeds(
      setDoc(doc(ctx(REQUESTER), 'chats', CHAT), {
        participants: [REQUESTER, POSTER],
        lastMessage: 'Hallo',
      })
    );
  });

  test('the poster can open the same thread (participants in either order)', async () => {
    await seed();
    await assertSucceeds(
      setDoc(doc(ctx(POSTER), 'chats', CHAT), {
        participants: [POSTER, REQUESTER],
        lastMessage: 'Hallo',
      })
    );
  });

  test('a third account cannot be smuggled into participants', async () => {
    await seed();
    await assertFails(
      setDoc(doc(ctx(REQUESTER), 'chats', CHAT), {
        participants: [REQUESTER, POSTER, THIRD],
        lastMessage: 'Hallo',
      })
    );
  });

  test('the poster cannot be dropped for a stranger, even at size 2', async () => {
    await seed();
    await assertFails(
      setDoc(doc(ctx(REQUESTER), 'chats', CHAT), {
        participants: [REQUESTER, THIRD],
        lastMessage: 'Hallo',
      })
    );
  });

  test('a stranger cannot create the thread at all', async () => {
    await seed();
    await assertFails(
      setDoc(doc(ctx(THIRD), 'chats', CHAT), {
        participants: [REQUESTER, POSTER],
        lastMessage: 'Hallo',
      })
    );
  });

  test('no thread without a granted request', async () => {
    await seed({ status: 'pending' });
    await assertFails(
      setDoc(doc(ctx(REQUESTER), 'chats', CHAT), {
        participants: [REQUESTER, POSTER],
        lastMessage: 'Hallo',
      })
    );
  });
});

// Sanity: prove the size check these tests rely on is actually in the rules.
test('the rules file under test pins chat membership to two', () => {
  assert.match(rules, /participants\.size\(\) == 2/);
  assert.match(rules, /match \/chats\/\{chatId\}/);
});
