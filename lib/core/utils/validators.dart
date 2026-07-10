import '../localization/app_localizations.dart';

/// Shared field validators so the same rules apply consistently everywhere
/// a given field type is collected (registration, login, company profile,
/// personal profile, etc.) instead of each screen rolling its own.
class Validators {
  static final _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
  static final _phoneAllowedChars = RegExp(r'^[\d\s\-\+\/\(\)]+$');
  static final _postalCodeRegex = RegExp(r'^\d{5}$');

  static String? email(String? value, AppLocalizations l, {bool required = true}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? l.enterEmail : null;
    if (!_emailRegex.hasMatch(v)) return l.invalidEmailAddr;
    return null;
  }

  static String? phone(String? value, AppLocalizations l, {bool required = false}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? l.required : null;
    final digitsOnly = v.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length < 7 || digitsOnly.length > 15) return l.invalidPhoneNumber;
    if (!_phoneAllowedChars.hasMatch(v)) return l.invalidPhoneNumber;
    return null;
  }

  static String? postalCode(String? value, AppLocalizations l, {bool required = false}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? l.required : null;
    if (!_postalCodeRegex.hasMatch(v)) return l.invalidPostalCode;
    return null;
  }

  // German USt-IdNr format: "DE" + 9 digits (spaces tolerated). This is a
  // client-side FORMAT check only — it does not confirm the number is real or
  // active (that needs an EU VIES lookup, which browsers can't call directly
  // due to CORS and so requires a server proxy). Optional field: empty is fine.
  static final _deVatRegex = RegExp(r'^DE\d{9}$');
  static String? vatNumberDE(String? value, AppLocalizations l, {bool required = false}) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return required ? l.required : null;
    final normalized = raw.toUpperCase().replaceAll(RegExp(r'\s'), '');
    if (!_deVatRegex.hasMatch(normalized)) return l.vatError;
    return null;
  }
}
