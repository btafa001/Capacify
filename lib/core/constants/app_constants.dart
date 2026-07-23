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
//
// Rotated 2026-07-11: the previous key (6LfjN0QtAAAAALMSeyEhSflPiHFR3FPi0YWaupZr)
// caused a total login lockout once enforcement was turned on — the client was
// still presenting that old key to reCAPTCHA while Firebase's App Check
// registration expected this new one, so every token Firestore/Auth received
// was rejected (surfaced as a generic permission-denied, even on `allow read:
// if true` collections, since App Check rejects before rules ever evaluate).
//
// Rotated again 2026-07-16: the 2026-07-11 key (6Ldgvk0tAAAAAIvbk0uuaxsb1oox2YUNxylCV0g_)
// ended up split across several disconnected reCAPTCHA admin-console entries
// with inconsistent domain allowlists (some had capacify.de, some didn't),
// so reCAPTCHA itself rejected it in production ("Invalid site key or not
// loaded in api.js") regardless of what Firebase's App Check registration
// expected — same failure mode as the first rotation, just from the domain
// list instead of the key value. This key is a single fresh reCAPTCHA v3
// entry with capacify.de, capacify-mvp.web.app, capacify-mvp.firebaseapp.com,
// and localhost all on it, replacing every prior entry.
const String kAppCheckRecaptchaSiteKey = '6Lem2FUtAAAAAAKuVNafvIZWj7fQsdJdxxJe0Zt9';

// Firebase Cloud Messaging — Web Push VAPID public key (public; safe in
// client). Generated in Firebase Console → Project Settings → Cloud Messaging
// → Web Push certificates (2026-07-10).
const String kFcmVapidKey = 'BOeNM4nx46oJBq5fouSIjdYgb7r1b6Hev4zqY1gPIrhq8qUyHRsGP4BvUFfA55xxbHItphwmvVpFw8C9dyIISl8';

// ── Sign in with Apple ──────────────────────────────────────────────────────
// Hides the "Weiter mit Apple" button on both auth screens. The Dart side is
// COMPLETE and deliberately left in place (AuthService.signInWithApple, both
// screens' handlers, the localized label) — only the button is hidden.
//
// Off because the Apple provider is not enabled in Firebase Auth, so every tap
// returned 'operation-not-allowed' ("Diese Anmeldeart ist nicht aktiviert") —
// a visible dead end for exactly the iPhone users most likely to try it.
// Enabling it in the console requires a Services ID and a private key that
// only exist inside a PAID Apple Developer Program membership (99 €/yr), which
// we don't have yet (2026-07-20). Note this is optional for us: Apple's rule
// forcing Sign in with Apple alongside other social logins applies to App
// Store apps, and Capacify ships as Flutter web on Firebase Hosting (see
// firebase.json — a web app is the only platform registered).
//
// To re-enable after enrolling: turn on Authentication → Sign-in method →
// Apple in the Firebase Console, then flip this to true. No other code change.
const bool kAppleSignInEnabled = false;

// Revision of the AGB + Datenschutzerklärung the signup consent checkbox
// refers to. Stored alongside the acceptance timestamp on the user doc
// (AuthService.recordLegalConsent) so an acceptance always records WHAT was
// accepted — a bare boolean is worth little if the terms have since changed.
// Bump this (YYYY-MM) whenever either document changes materially.
const String kLegalTermsVersion = '2026-07';

// App version stamped onto client crash reports (see ErrorService / the
// clientErrors collection) so a report can be tied to a release. Keep in sync
// with `version:` in pubspec.yaml — there's no build-time injection wired up.
const String kAppVersion = '1.0.0+1';

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

// Approximate centroid coordinates for each kHamburgDistricts entry — not
// precise addresses, but real enough for "within N km" radius math and
// map-style display, which is the actual CapacityOS gap this closes: the
// "50km radius" language used in marketing copy had no lat/lng anywhere in
// the data model to back it up. Deliberately a plain (lat, lng) record here
// rather than a Firestore GeoPoint, so this file stays framework-light —
// CapacityModel converts to GeoPoint at the point of use. Keyed by the exact
// district string; a post whose location doesn't match one of these (e.g.
// free-text edited away from the original dropdown value) simply gets no
// coordinates rather than a wrong guess.
const Map<String, (double lat, double lng)> kHamburgDistrictCoordinates = {
  'Hamburg Mitte': (53.5511, 9.9937),
  'Altona': (53.5503, 9.9352),
  'Eimsbüttel': (53.5786, 9.9598),
  'Wandsbek': (53.5722, 10.0797),
  'Bergedorf': (53.4880, 10.2160),
  'Harburg': (53.4610, 9.9850),
  'Hamburg Nord': (53.6021, 10.0126),
  'Billstedt': (53.5389, 10.1069),
  'Barmbek-Nord': (53.5928, 10.0392),
  'Uhlenhorst': (53.5714, 10.0161),
  'Rahlstedt': (53.6041, 10.1531),
  'Bramfeld': (53.6193, 10.0682),
  'Lurup': (53.5814, 9.8944),
  'Bahrenfeld': (53.5646, 9.9095),
  'Niendorf': (53.6280, 9.9491),
};

// Self-reported day-rate band on a capacity post — CapacityOS readiness gap:
// no price signal existed anywhere, making any future rate-benchmarking
// feature impossible. Optional and left unset by default ('') rather than
// required — day rates are commercially sensitive and disclosing one
// publicly (even on an anonymized post) is a business decision each company
// should opt into, not something the form should force.
const List<String> kDayRateBands = [
  'unter_300',
  '300_500',
  '500_800',
  'ueber_800',
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
// Same pattern (see firestore.rules' MESSAGE/RATING/REPORT THROTTLE blocks) —
// only posts had a daily cap before; messages/ratings/reports were uncapped.
const int kMaxMessagesPerDay = 200;
const int kMaxRatingsPerDay = 20;
const int kMaxReportsPerDay = 10;
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