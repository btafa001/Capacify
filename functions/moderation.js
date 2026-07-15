// Server-side port of lib/core/utils/content_moderation.dart's blocklist/
// contact-info checks, plus a name-similarity helper for impersonation
// detection. This is the AUTHORITATIVE copy — the Dart version only gives
// instant client-side feedback before a save; a direct API write skips it
// entirely, which is exactly the gap these Cloud Function triggers (see
// index.js: enforceCapacityModeration, enforceCompanyIntegrity) close.
'use strict';

const WORD_SPLIT = /[^a-zA-Zäöüß]+/;

const BLOCKED_WORDS = new Set([
  // English profanity / slurs
  'fuck', 'fucking', 'fucker', 'fucked', 'motherfucker', 'cocksucker',
  'shit', 'bullshit', 'bitch', 'asshole', 'bastard', 'cunt', 'twat',
  'dick', 'dickhead', 'pussy', 'whore', 'slut',
  'nigger', 'nigga', 'faggot', 'fag', 'retard',
  // German profanity / slurs
  'scheiße', 'scheiss', 'scheisse', 'arschloch', 'hure', 'hurensohn',
  'schlampe', 'fotze', 'wichser', 'missgeburt', 'mistgeburt', 'drecksau',
  'neger', 'kanake', 'schwuchtel',
]);

function containsBlockedContent(text) {
  const t = String(text || '').trim();
  if (!t) return false;
  const words = t.toLowerCase().split(WORD_SPLIT);
  return words.some((w) => w && BLOCKED_WORDS.has(w));
}

const EMAIL_PATTERN = /[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}/;
const PHONE_PATTERN = /(\+?\d[\d\s\-/().]{6,}\d)/g;

function containsContactInfo(text) {
  const t = String(text || '').trim();
  if (!t) return false;
  if (EMAIL_PATTERN.test(t)) return true;
  for (const m of t.matchAll(PHONE_PATTERN)) {
    const digits = m[0].replace(/[^\d]/g, '');
    if (digits.length >= 7) return true;
  }
  return false;
}

/// Combined check — mirrors shouldFlagDescription() in the Dart client.
function shouldFlagText(text) {
  return containsBlockedContent(text) || containsContactInfo(text);
}

// ─── Impersonation: normalized name similarity ───

const LEGAL_FORM_PATTERN =
  /\b(gmbh ?& ?co ?kg|gmbh|ug|kg|ohg|gbr|e ?k|ag|co|inh)\b/g;

function normalizeCompanyName(name) {
  return String(name || '')
    .toLowerCase()
    .replace(/[^a-z0-9äöüß\s]+/g, ' ')
    .replace(LEGAL_FORM_PATTERN, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

// Classic O(n*m) edit distance, two-row rolling buffer.
function levenshtein(a, b) {
  const m = a.length;
  const n = b.length;
  if (m === 0) return n;
  if (n === 0) return m;
  let prev = new Array(n + 1);
  let curr = new Array(n + 1);
  for (let j = 0; j <= n; j++) prev[j] = j;
  for (let i = 1; i <= m; i++) {
    curr[0] = i;
    for (let j = 1; j <= n; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      curr[j] = Math.min(curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost);
    }
    [prev, curr] = [curr, prev];
  }
  return prev[n];
}

function sortedWords(name) {
  return normalizeCompanyName(name).split(' ').filter(Boolean).sort().join(' ');
}

function ratio(a, b) {
  if (!a || !b) return 0;
  if (a === b) return 1;
  return 1 - levenshtein(a, b) / Math.max(a.length, b.length);
}

/// 1.0 == identical (after stripping legal-form suffixes/punctuation), 0.0 ==
/// completely different. Used to flag a new/renamed company whose name is
/// suspiciously close to an already VIES-verified company's registered name.
/// Takes the max of the direct comparison and a word-sorted comparison, so
/// "Schmidt Elektro" vs "Elektro Schmidt" (a plausible impersonation move —
/// reordering a competitor's name) scores as near-identical instead of
/// completely different, which plain edit distance would miss entirely.
function nameSimilarity(a, b) {
  const direct = ratio(normalizeCompanyName(a), normalizeCompanyName(b));
  const reordered = ratio(sortedWords(a), sortedWords(b));
  return Math.max(direct, reordered);
}

module.exports = {
  containsBlockedContent,
  containsContactInfo,
  shouldFlagText,
  normalizeCompanyName,
  levenshtein,
  nameSimilarity,
};
