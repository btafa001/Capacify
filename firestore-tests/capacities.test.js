// Emulator tests for the `capacities` rules — specifically the owner-UPDATE
// branch, which is where a post's public trust badges live.
//
// Background: the CREATE rule cross-checks a post's identity against the
// caller's own companies/{uid} doc, but the owner-UPDATE branch used to pin
// only contentFlagged/posterSuspended/dealNumber. That made every create-time
// check reachable one write later — publish a clean post, then update() it with
// posterVerified: true, an inflated rating, a different visibilityMode, or a
// competitor's name. These tests lock the fix (ownerPostSnapshotsHonest) down
// AND lock in the ordinary edit paths the app actually depends on, because the
// failure mode of over-pinning is just as bad: a rule that denies every profile
// save, silently, behind a `catch (_) {}`.
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
import { doc, setDoc, updateDoc, getDoc, deleteField } from 'firebase/firestore';

const here = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(here, '..', 'firestore.rules'), 'utf8');

const OWNER = 'owner-company';
const OTHER = 'other-company';
const POST = 'post-1';

let testEnv;

/** Signed-in context with a verified email — what every real account has. */
function owner() {
  return testEnv.authenticatedContext(OWNER, { email_verified: true }).firestore();
}
function other() {
  return testEnv.authenticatedContext(OTHER, { email_verified: true }).firestore();
}

/** Drops keys explicitly overridden to `undefined` — how a test says "this
 * field is ABSENT on the seeded doc" (Firestore rejects undefined values). */
function withoutUndefined(obj) {
  return Object.fromEntries(
    Object.entries(obj).filter(([, v]) => v !== undefined)
  );
}

/**
 * Seeds the world as the app really writes it: an owner company, its locked
 * identity sidecar, and one public post in `visible` mode carrying the banded
 * trust snapshot. Written with rules disabled so seeding never depends on the
 * rules under test.
 */
async function seed(companyOverrides = {}, postOverrides = {}) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'companies', OWNER), withoutUndefined({
      name: 'Bau Meier GmbH',
      logoUrl: 'https://example.test/meier.png',
      verificationStatus: 'none',
      ratingSum: 18,
      ratingCount: 4,
      responseCount: 0,
      responseSumMs: 0,
      contentFlagged: false,
      emailVerified: true,
      ...companyOverrides,
    }));
    await setDoc(doc(db, 'companies', OTHER), {
      name: 'Konkurrenz AG',
      logoUrl: 'https://example.test/konkurrenz.png',
      verificationStatus: 'verified',
      ratingSum: 500,
      ratingCount: 100,
      contentFlagged: false,
    });
    await setDoc(doc(db, 'capacityOwners', POST), {
      posterCompanyId: OWNER,
      companyName: 'Bau Meier GmbH',
      contactPhone: '+49 40 123',
      contactEmail: 'kontakt@meier.test',
    });
    await setDoc(doc(db, 'capacities', POST), withoutUndefined({
      type: 'offer',
      status: 'active',
      title: 'Zwei Maurer frei',
      description: 'Ab nächster Woche',
      trade: 'Rohbau',
      location: 'Altona',
      workerCount: 2,
      contentFlagged: false,
      viewCount: 0,
      favoriteCount: 0,
      interestCount: 0,
      posterSuspended: false,
      posterVerified: false,
      posterRatingSum: 18,
      posterRatingCount: 4,
      visibilityMode: 'visible',
      posterCompanyId: OWNER,
      posterCompanyName: 'Bau Meier GmbH',
      posterLogoUrl: 'https://example.test/meier.png',
      ...postOverrides,
    }));
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

describe('capacities: ordinary owner edits still work', () => {
  test('the owner can edit their own post text', async () => {
    await seed();
    await assertSucceeds(
      updateDoc(doc(owner(), 'capacities', POST), {
        title: 'Drei Maurer frei',
        description: 'Doch drei',
        contentFlagged: false,
      })
    );
  });

  test('the owner can change status (close a deal) without touching snapshots', async () => {
    await seed();
    await assertSucceeds(
      updateDoc(doc(owner(), 'capacities', POST), { status: 'closed' })
    );
  });

  test('anyone — even signed out — can bump viewCount', async () => {
    await seed();
    const anon = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(
      updateDoc(doc(anon, 'capacities', POST), { viewCount: 1 })
    );
  });

  test('a non-owner cannot edit the post', async () => {
    await seed();
    await assertFails(
      updateDoc(doc(other(), 'capacities', POST), { title: 'Gekapert' })
    );
  });
});

describe('capacities: an owner cannot forge identity (H1)', () => {
  test('visibilityMode is fixed at creation', async () => {
    await seed();
    await assertFails(
      updateDoc(doc(owner(), 'capacities', POST), { visibilityMode: 'anonymous' })
    );
  });

  test('posterCompanyName cannot be repointed at another company', async () => {
    await seed();
    await assertFails(
      updateDoc(doc(owner(), 'capacities', POST), {
        posterCompanyName: 'Konkurrenz AG',
      })
    );
  });

  test('posterLogoUrl cannot be swapped for another company logo', async () => {
    await seed();
    await assertFails(
      updateDoc(doc(owner(), 'capacities', POST), {
        posterLogoUrl: 'https://example.test/konkurrenz.png',
      })
    );
  });

  test('posterCompanyId cannot be reassigned', async () => {
    await seed();
    await assertFails(
      updateDoc(doc(owner(), 'capacities', POST), { posterCompanyId: OTHER })
    );
  });

  test('an anonymous post cannot grow identity fields after the fact', async () => {
    await seed({}, {
      visibilityMode: 'anonymous',
      posterCompanyId: undefined,
      posterCompanyName: undefined,
      posterLogoUrl: undefined,
    });
    await assertFails(
      updateDoc(doc(owner(), 'capacities', POST), {
        posterCompanyName: 'Bau Meier GmbH',
      })
    );
  });
});

describe('capacities: an owner cannot forge trust badges (H1)', () => {
  test('posterVerified cannot be set true by an unverified company', async () => {
    await seed({ verificationStatus: 'none' });
    await assertFails(
      updateDoc(doc(owner(), 'capacities', POST), { posterVerified: true })
    );
  });

  test('posterVerified cannot be set true while verification is merely pending', async () => {
    await seed({ verificationStatus: 'pending' });
    await assertFails(
      updateDoc(doc(owner(), 'capacities', POST), { posterVerified: true })
    );
  });

  test('posterVerified CAN be synced true once the company really is verified', async () => {
    await seed({ verificationStatus: 'verified' });
    await assertSucceeds(
      updateDoc(doc(owner(), 'capacities', POST), { posterVerified: true })
    );
  });

  test('the rating pair cannot be inflated past the company totals', async () => {
    await seed();
    await assertFails(
      updateDoc(doc(owner(), 'capacities', POST), {
        posterRatingSum: 500,
        posterRatingCount: 100,
      })
    );
  });

  test('posterRatingCount alone cannot be inflated', async () => {
    await seed();
    await assertFails(
      updateDoc(doc(owner(), 'capacities', POST), { posterRatingCount: 100 })
    );
  });

  test('a legitimate banded rating re-sync is allowed (bands round DOWN)', async () => {
    // Company really holds 22 stars over 5 reviews; bandRatingCount(5) => 5 and
    // bandRatingSum floors the average to 4.0 => 20. Both under the raw totals.
    await seed({ ratingSum: 22, ratingCount: 5 });
    await assertSucceeds(
      updateDoc(doc(owner(), 'capacities', POST), {
        posterRatingSum: 20,
        posterRatingCount: 5,
      })
    );
  });

  test('dealNumber cannot be self-assigned', async () => {
    await seed();
    await assertFails(
      updateDoc(doc(owner(), 'capacities', POST), { dealNumber: 7 })
    );
  });

  test('a suspended poster cannot un-hide their own post', async () => {
    await seed({}, { posterSuspended: true });
    await assertFails(
      updateDoc(doc(owner(), 'capacities', POST), { posterSuspended: false })
    );
  });

  test('contentFlagged can only move false→true from the client', async () => {
    await seed({}, { contentFlagged: true });
    await assertFails(
      updateDoc(doc(owner(), 'capacities', POST), { contentFlagged: false })
    );
  });
});

describe('capacities: responsiveness cannot be overstated (H1)', () => {
  // 4 responses totalling 40h — the honest average is 10h, which the client
  // bands UP to 24h. Claiming anything below 10h is a lie the rule must reject.
  const realistic = { responseCount: 4, responseSumMs: 40 * 3600000 };

  test('a faster-than-real response time is rejected', async () => {
    await seed(realistic);
    await assertFails(
      updateDoc(doc(owner(), 'capacities', POST), { posterAvgResponseHours: 2 })
    );
  });

  test('the honest banded value is accepted', async () => {
    await seed(realistic);
    await assertSucceeds(
      updateDoc(doc(owner(), 'capacities', POST), { posterAvgResponseHours: 24 })
    );
  });

  test('a company with too few samples cannot claim any response time', async () => {
    await seed({ responseCount: 1, responseSumMs: 3600000 });
    await assertFails(
      updateDoc(doc(owner(), 'capacities', POST), { posterAvgResponseHours: 2 })
    );
  });

  test('dropping the signal entirely is always allowed (self-downgrade)', async () => {
    await seed(realistic, { posterAvgResponseHours: 24 });
    await assertSucceeds(
      updateDoc(doc(owner(), 'capacities', POST), {
        posterAvgResponseHours: deleteField(),
      })
    );
  });

  test('an unrelated edit does not have to re-justify a stale stored value', async () => {
    // The stored 24h was honest when it was written; the company has since got
    // slower (real average now 30h). Editing the title must still work — the
    // "unchanged" branch is what keeps a tightened rule from bricking edits.
    await seed(
      { responseCount: 4, responseSumMs: 120 * 3600000 },
      { posterAvgResponseHours: 24 }
    );
    await assertSucceeds(
      updateDoc(doc(owner(), 'capacities', POST), { title: 'Neuer Titel' })
    );
  });
});

describe('companies: the trust inputs the post rule leans on are pinned', () => {
  test('a company cannot self-verify', async () => {
    await seed();
    await assertFails(
      updateDoc(doc(owner(), 'companies', OWNER), { verificationStatus: 'verified' })
    );
  });

  test('a company cannot inflate its own rating', async () => {
    await seed();
    await assertFails(
      updateDoc(doc(owner(), 'companies', OWNER), { ratingSum: 500, ratingCount: 100 })
    );
  });
});

describe('capacityOwners: the identity sidecar stays locked', () => {
  test('a stranger cannot read a poster identity', async () => {
    await seed();
    await assertFails(getDoc(doc(other(), 'capacityOwners', POST)));
  });

  test('the owner can read their own sidecar', async () => {
    await seed();
    await assertSucceeds(getDoc(doc(owner(), 'capacityOwners', POST)));
  });

  test('a requester with a GRANTED contact request can read it', async () => {
    await seed();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'contact_requests', `${OTHER}_${POST}`), {
        requesterCompanyId: OTHER,
        postId: POST,
        status: 'granted',
      });
    });
    await assertSucceeds(getDoc(doc(other(), 'capacityOwners', POST)));
  });

  test('a merely PENDING contact request does not release identity', async () => {
    await seed();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'contact_requests', `${OTHER}_${POST}`), {
        requesterCompanyId: OTHER,
        postId: POST,
        status: 'pending',
      });
    });
    await assertFails(getDoc(doc(other(), 'capacityOwners', POST)));
  });
});

describe('capacities: engagement counters can only step by their honest delta (M1)', () => {
  // The +1 view bump succeeding is already covered by "anyone can bump
  // viewCount" above; these lock the forge the delta-pin closes.
  test('viewCount cannot be pinned to an arbitrary value', async () => {
    await seed();
    const anon = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      updateDoc(doc(anon, 'capacities', POST), { viewCount: 9999 })
    );
  });

  test('viewCount cannot jump by more than one', async () => {
    await seed();
    const anon = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      updateDoc(doc(anon, 'capacities', POST), { viewCount: 2 })
    );
  });

  test('favoriteCount may step +1 (favourite)', async () => {
    await seed({}, { favoriteCount: 3 });
    await assertSucceeds(
      updateDoc(doc(other(), 'capacities', POST), { favoriteCount: 4 })
    );
  });

  test('favoriteCount may step -1 (un-favourite)', async () => {
    await seed({}, { favoriteCount: 3 });
    await assertSucceeds(
      updateDoc(doc(other(), 'capacities', POST), { favoriteCount: 2 })
    );
  });

  test('favoriteCount cannot be inflated as social proof', async () => {
    await seed();
    await assertFails(
      updateDoc(doc(other(), 'capacities', POST), { favoriteCount: 500 })
    );
  });

  test('a signed-out caller cannot touch favoriteCount at all', async () => {
    await seed();
    const anon = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      updateDoc(doc(anon, 'capacities', POST), { favoriteCount: 1 })
    );
  });

  test('interestCount may step +1 for a signed-in user', async () => {
    await seed();
    await assertSucceeds(
      updateDoc(doc(other(), 'capacities', POST), { interestCount: 1 })
    );
  });

  test('interestCount cannot be forged to a large value', async () => {
    await seed();
    await assertFails(
      updateDoc(doc(other(), 'capacities', POST), { interestCount: 250 })
    );
  });
});

// Sanity: the suite is worthless if it silently runs against no rules at all.
test('the rules file under test is the real one', () => {
  assert.match(rules, /function ownerPostSnapshotsHonest\(\)/);
  assert.match(rules, /match \/capacities\/\{capacityId\}/);
});
