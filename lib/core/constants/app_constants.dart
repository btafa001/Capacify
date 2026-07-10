// Single source of truth for the Gewerke (trades) list — used everywhere
// a trade selector or filter appears. Do not duplicate this list elsewhere.
//
// Consolidated 2026-06-30: several trades that are routinely staffed by the
// same company were merged — SHK (was Sanitär & Heizung + HVAC),
// Fliesen & Boden (was Fliesenleger + Bodenleger), Beton & Stahl (was
// Beton + Stahl). 'Andere' stays LAST: edit_capacity_screen falls back to
// kTrades.last for any unrecognized stored value, and "Other" is the right
// home for those. Legacy values still translate (see tradeName) and existing
// data was migrated to these new values.
// Service region — single source of truth. Expanding beyond Hamburg or
// changing the radius is a one-line edit here (see topBarSubtitle / loginLiveBadge).
const String kServiceRegion = 'Hamburg';
const int kServiceRadiusKm = 50;

// Firebase App Check — reCAPTCHA v3 site key (public; safe in client). Attests
// that requests come from the real app before Firestore/Auth accept them.
// Registered in the Firebase Console → App Check. Enforcement is toggled there
// separately (only after tokens are confirmed flowing).
const String kAppCheckRecaptchaSiteKey = '6LfjN0QtAAAAALMSeyEhSflPiHFR3FPi0YWaupZr';

// Firebase Cloud Messaging — Web Push VAPID public key (public; safe in
// client). Generate in Firebase Console → Project Settings → Cloud Messaging
// → Web Push certificates. Until this is a real key, FcmService.registerForUser
// silently no-ops (getToken fails, caught, nothing sent).
const String kFcmVapidKey = 'TODO_SET_VAPID_KEY_FROM_FIREBASE_CONSOLE';

const List<String> kTrades = [
  'Rohbau',
  'Trockenbau',
  'Elektro',
  'SHK',
  'Maler',
  'Dach',
  'Fassade',
  'Gerüstbau',
  'Tiefbau',
  'Fliesen & Boden',
  'Beton & Stahl',
  'Andere',
];

/// Number of concrete trades a company can pick, excluding the 'Andere'
/// catch-all — used for the "N Gewerke" marketing stats so they stay in sync
/// with kTrades automatically (this number drifted to a stale 15 once already).
int get kSelectableTradeCount =>
    kTrades.where((t) => t != 'Andere').length;

const List<String> kHamburgDistricts = [
  'Hamburg Mitte',
  'Altona',
  'Eimsbüttel',
  'Wandsbek',
  'Bergedorf',
  'Harburg',
  'Hamburg Nord',
  'Billstedt',
  'Barmbek-Nord',
  'Uhlenhorst',
  'Rahlstedt',
  'Bramfeld',
  'Lurup',
  'Bahrenfeld',
  'Niendorf',
];

const List<String> kEmployeeCounts = [
  '1-5',
  '6-10',
  '11-25',
  '26-50',
  '51-100',
  '100+',
];

// ── Vermittlungen (credit-based intro) ──────────────────────────────────────
// A "Vermittlung" is one credit spent to unlock a poster's identity + contact +
// chat. During Early Access (first 6+ months) EVERY company gets the same
// generous flat quota, to train the spend-a-credit behaviour before pricing
// exists. Later the quota derives from the plan (Free/Pro/Premium). While
// kEarlyAccessMode is true the Firestore rules pin the wallet quota to
// kEarlyAccessQuota (keep the number in firestore.rules in sync with this).
const bool kEarlyAccessMode = true;
const int kEarlyAccessQuota = 20;
// Max capacity posts one company may publish per day (anti-spam). Enforced in
// firestore.rules via the postCounts counter — keep the literal 10 there in sync.
const int kMaxPostsPerDay = 10;
const int kFreeQuota = 2;
const int kProQuota = 20;
// Premium "unlimited" — a ceiling far above any real monthly usage.
const int kUnlimitedQuota = 100000;
// A post not updated within this many days can't be unlocked — protects the
// value of a credit (no burning one on a dead listing).
const int kVermittlungFreshnessDays = 30;

// A company may change its name at most once every this many days — prevents
// a verified/rated firm from repeatedly rebranding to shed history.
const int kNameChangeCooldownDays = 60;

/// The Vermittlung quota a company should have this month. Flat during Early
/// Access; plan-derived afterwards ('free'|'pro'|'premium').
int quotaForPlan(String? plan) {
  if (kEarlyAccessMode) return kEarlyAccessQuota;
  switch (plan) {
    case 'premium':
      return kUnlimitedQuota;
    case 'pro':
      return kProQuota;
    default:
      return kFreeQuota;
  }
}