/// Basic client-side profanity/slur blocklist. Checks whole words only
/// (splits on non-letters and compares exact tokens) so it doesn't trip
/// on innocent words that merely contain a blocked substring.
///
/// This is intentionally a coarse first line of defense, not a complete
/// moderation system — it won't catch spaced-out or l33tspeak evasions,
/// subtler harassment, or German compound words built around a blocked
/// term. Content it flags doesn't get rejected outright; it's held back
/// from public view until an admin reviews and approves it.
library;

final RegExp _wordSplitPattern = RegExp(r'[^a-zA-ZäöüÄÖÜß]+');

const Set<String> _blockedWords = {
  // English profanity / slurs
  'fuck', 'fucking', 'fucker', 'fucked', 'motherfucker', 'cocksucker',
  'shit', 'bullshit', 'bitch', 'asshole', 'bastard', 'cunt', 'twat',
  'dick', 'dickhead', 'pussy', 'whore', 'slut',
  'nigger', 'nigga', 'faggot', 'fag', 'retard',

  // German profanity / slurs
  'scheiße', 'scheiss', 'scheisse', 'arschloch', 'hure', 'hurensohn',
  'schlampe', 'fotze', 'wichser', 'missgeburt', 'mistgeburt', 'drecksau',
  'neger', 'kanake', 'schwuchtel',
};

/// True if [text] contains any blocked word as a standalone token.
bool containsBlockedContent(String text) {
  if (text.trim().isEmpty) return false;
  final words = text.toLowerCase().split(_wordSplitPattern);
  for (final word in words) {
    if (word.isNotEmpty && _blockedWords.contains(word)) return true;
  }
  return false;
}

// Anonymity guard: a poster must not leak their own contact via the free-text
// Beschreibung (which is public on the anonymized post). Detects emails and
// phone-number-like digit runs so such a description is flagged for review
// (routed through the existing contentFlagged path, not silently published).
final RegExp _emailPattern = RegExp(r'[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}');
// A phone-ish run: 7+ digits, allowing spaces / - / / / ( ) / leading +.
final RegExp _phonePattern =
    RegExp(r'(\+?\d[\d\s\-/().]{6,}\d)');

/// True if [text] appears to contain an email address or a phone number —
/// i.e. the poster is trying to route contact around the gated flow.
bool containsContactInfo(String text) {
  if (text.trim().isEmpty) return false;
  if (_emailPattern.hasMatch(text)) return true;
  // Count digits in the longest phone-ish match to avoid flagging short
  // numbers like "3 Mann" or "ab KW12".
  for (final m in _phonePattern.allMatches(text)) {
    final digits = m.group(0)!.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length >= 7) return true;
  }
  return false;
}

/// Combined check used when saving a post/profile description: blocked words
/// OR leaked contact info both route the content to admin review.
bool shouldFlagDescription(String text) =>
    containsBlockedContent(text) || containsContactInfo(text);
