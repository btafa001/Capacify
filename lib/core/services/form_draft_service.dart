import 'dart:convert';
import 'package:web/web.dart' as web;

/// Persists an in-progress form's field values to localStorage — closes the
/// gap a pre-launch audit persona test flagged directly: form state lived
/// only in widget controllers, so backgrounding the tab or the OS reclaiming
/// memory (common on low-RAM Android under multitasking, or just someone
/// getting a phone call mid-registration) silently lost everything typed.
/// Same JS-interop localStorage pattern already used for theme/consent
/// (package:web, synchronous, no backend).
///
/// Deliberately NOT wired to every keystroke — callers save periodically
/// (e.g. every few seconds while the screen is open) and once more on
/// dispose, which covers the actual failure modes (backgrounding, a crash,
/// navigating away) without a debounce timer per field.
class FormDraftService {
  static void save(String key, Map<String, dynamic> data) {
    try {
      web.window.localStorage.setItem(key, jsonEncode(data));
    } catch (_) {}
  }

  static Map<String, dynamic>? load(String key) {
    try {
      final raw = web.window.localStorage.getItem(key);
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static void clear(String key) {
    try {
      web.window.localStorage.removeItem(key);
    } catch (_) {}
  }
}
