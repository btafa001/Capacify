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
