import '../localization/app_localizations.dart';

/// Shared field validators so the same rules apply consistently everywhere
/// a given field type is collected (registration, login, company profile,
/// personal profile, etc.) instead of each screen rolling its own.
class Validators {
  static final _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
  static final _phoneAllowedChars = RegExp(r'^[\d\s\-\+\/\(\)]+$');
  static final _postalCodeRegex = RegExp(r'^\d{5}$');

  // Common disposable/temp-mail providers — raises the cost of the
  // "fifty free throwaway accounts" flood (each still needs a real, checkable
  // inbox for sendEmailVerification to land in). Not exhaustive — new
  // disposable services appear constantly — so this is one layer among
  // several (email verification, per-account post throttle), not a complete
  // defense on its own.
  static const _disposableEmailDomains = {
    'mailinator.com', 'guerrillamail.com', 'guerrillamail.info', '10minutemail.com',
    'tempmail.com', 'temp-mail.org', 'yopmail.com', 'throwawaymail.com',
    'trashmail.com', 'getnada.com', 'sharklasers.com', 'dispostable.com',
    'maildrop.cc', 'fakeinbox.com', 'mintemail.com', 'mailnesia.com',
    'discard.email', 'moakt.com', 'tempinbox.com', 'emailondeck.com',
  };

  static String? email(String? value, AppLocalizations l, {bool required = true}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? l.enterEmail : null;
    if (!_emailRegex.hasMatch(v)) return l.invalidEmailAddr;
    final domain = v.split('@').last.toLowerCase();
    if (_disposableEmailDomains.contains(domain)) return l.disposableEmailError;
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

  // EU VAT number formats (per-country digit/letter layout after the 2-letter
  // country prefix, per the VIES member-state format table). This is a
  // client-side FORMAT check only — it does not confirm the number is real or
  // active (that needs an EU VIES lookup, which browsers can't call directly
  // due to CORS and so requires a server proxy — see verifyMyCompany in
  // functions/index.js, which already accepts any of these country codes).
  // Previously DE-only, which rejected every valid non-German subcontractor's
  // VAT number before it ever reached that server check. XI (Northern
  // Ireland) is included since VIES still validates it post-Brexit.
  static final Map<String, RegExp> _euVatFormats = {
    'AT': RegExp(r'^U\d{8}$'),
    'BE': RegExp(r'^[01]\d{9}$'),
    'BG': RegExp(r'^\d{9,10}$'),
    'CY': RegExp(r'^\d{8}[A-Z]$'),
    'CZ': RegExp(r'^\d{8,10}$'),
    'DE': RegExp(r'^\d{9}$'),
    'DK': RegExp(r'^\d{8}$'),
    'EE': RegExp(r'^\d{9}$'),
    'EL': RegExp(r'^\d{9}$'),
    'ES': RegExp(r'^[A-Z0-9]\d{7}[A-Z0-9]$'),
    'FI': RegExp(r'^\d{8}$'),
    'FR': RegExp(r'^[A-Z0-9]{2}\d{9}$'),
    'HR': RegExp(r'^\d{11}$'),
    'HU': RegExp(r'^\d{8}$'),
    'IE': RegExp(r'^(\d{7}[A-Z]{1,2}|\d[A-Z+*]\d{5}[A-Z])$'),
    'IT': RegExp(r'^\d{11}$'),
    'LT': RegExp(r'^(\d{9}|\d{12})$'),
    'LU': RegExp(r'^\d{8}$'),
    'LV': RegExp(r'^\d{11}$'),
    'MT': RegExp(r'^\d{8}$'),
    'NL': RegExp(r'^\d{9}B\d{2}$'),
    'PL': RegExp(r'^\d{10}$'),
    'PT': RegExp(r'^\d{9}$'),
    'RO': RegExp(r'^\d{2,10}$'),
    'SE': RegExp(r'^\d{12}$'),
    'SI': RegExp(r'^\d{8}$'),
    'SK': RegExp(r'^\d{10}$'),
    'XI': RegExp(r'^(\d{9}|\d{12}|(GD|HA)\d{3})$'),
  };
  static String? vatNumberEU(String? value, AppLocalizations l, {bool required = false}) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return required ? l.required : null;
    final normalized = raw.toUpperCase().replaceAll(RegExp(r'\s'), '');
    if (normalized.length < 3) return l.vatError;
    final country = normalized.substring(0, 2);
    final rest = normalized.substring(2);
    final pattern = _euVatFormats[country];
    if (pattern == null || !pattern.hasMatch(rest)) return l.vatError;
    return null;
  }
}
