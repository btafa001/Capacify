import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/company_model.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/company_provider.dart';
import '../../../core/services/company_service.dart' show InvalidLogoFileException;
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/star_rating.dart';
import '../../../shared/widgets/milestone.dart';
import '../../../shared/widgets/company_logo_avatar.dart';
import '../../../core/services/capacity_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/content_moderation.dart';
import '../../../core/utils/validators.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/constants/app_constants.dart';

class CompanyProfileScreen extends ConsumerStatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  ConsumerState<CompanyProfileScreen> createState() =>
      _CompanyProfileScreenState();
}

class _CompanyProfileScreenState
    extends ConsumerState<CompanyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _certificationsController = TextEditingController();
  final _websiteController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController(text: 'Hamburg');
  final _postalCodeController = TextEditingController();
  final _vatNumberController = TextEditingController();

  // Used to scroll a field into view when its validation fails — checked in
  // this same top-to-bottom order so the first one found is the topmost.
  final _nameFieldKey = GlobalKey<FormFieldState>();
  final _tradesFieldKey = GlobalKey();
  final _descriptionFieldKey = GlobalKey<FormFieldState>();
  final _emailFieldKey = GlobalKey<FormFieldState>();
  final _phoneFieldKey = GlobalKey<FormFieldState>();
  final _cityFieldKey = GlobalKey<FormFieldState>();
  final _postalCodeFieldKey = GlobalKey<FormFieldState>();
  final _vatNumberFieldKey = GlobalKey<FormFieldState>();

  List<String> _selectedTrades = [];
  String _selectedEmployees = kEmployeeCounts[0];
  List<String> _selectedServices = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _verifyingVat = false;
  bool _uploadingLogo = false;
  String? _errorMessage;
  String? _successMessage;
  CompanyModel? _existingCompany;

  // Instant verification via the server-side EU VIES check (verifyMyCompany
  // Cloud Function). A valid VAT flips verificationStatus to 'verified' at
  // once; invalid/unavailable leaves it for the founder's manual review.
  Future<void> _runVatVerification() async {
    final l = AppLocalizations.of(context);
    if (_vatNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.verifyNeedVatFirst), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _verifyingVat = true);
    try {
      final res = await FirebaseFunctions.instanceFor(region: 'europe-west3')
          .httpsCallable('verifyMyCompany')
          .call();
      final valid = (res.data?['valid'] as bool?) ?? false;
      if (!mounted) return;
      if (valid) {
        await _loadExistingCompany();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l.verifySuccessVies), backgroundColor: AppColors.live));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.verifyInvalidVies), backgroundColor: AppColors.error));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.errorWithMessage(e)), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _verifyingVat = false);
    }
  }

  String _guessMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'application/octet-stream';
  }

  /// Uploads straight to Storage + Firestore as soon as a file is picked —
  /// kept out of the main _save() flow (same reasoning as setEmailOptIn) so
  /// it works even mid-edit and doesn't wait on the rest of the form's
  /// validation. Only ever callable once the company already exists (see the
  /// section's own build()-time gating) — Storage's write rule keys off the
  /// company already existing being irrelevant to it, but a logo for a
  /// not-yet-created company doesn't make sense product-wise either.
  Future<void> _pickAndUploadLogo() async {
    final l = AppLocalizations.of(context);
    final company = _existingCompany;
    if (company == null) return;
    try {
      // Downscaled to a logo-appropriate size before it ever reaches the size
      // check below — without maxWidth/maxHeight, a straight-from-camera photo
      // (often 3-8 MB at full resolution) kept its original pixel dimensions
      // regardless of imageQuality (which only compresses JPEG/WEBP, not PNG),
      // so real photos were routinely rejected by the size cap. 512px is well
      // above anything the avatar is ever displayed at (44px radius, even at
      // 2x/3x DPI), so this never visibly softens the logo.
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 90,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final contentType = picked.mimeType ?? _guessMimeType(picked.name);
      setState(() => _uploadingLogo = true);
      final service = ref.read(companyServiceProvider);
      final url = await service.uploadLogo(
          companyId: company.id, bytes: bytes, contentType: contentType);
      await service.updateLogoUrl(company.id, url);
      if (mounted) {
        setState(() => _existingCompany = company.copyWith(logoUrl: url));
      }
    } on InvalidLogoFileException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.errorWithMessage(e)), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('CompanyProfile');
    _loadExistingCompany();
    // Rebuild on any field change so the completeness meter AND the Save button's
    // enabled/disabled state (dirty tracking, see _snapshot) stay current.
    for (final controller in [
      _nameController,
      _descriptionController,
      _certificationsController,
      _websiteController,
      _emailController,
      _phoneController,
      _addressController,
      _cityController,
      _postalCodeController,
      _vatNumberController,
    ]) {
      controller.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  // Snapshot of every editable field — the Save button is disabled while the
  // current form equals the last-saved snapshot (#2: disable after save until
  // something changes).
  String _savedSnapshot = '';
  String _snapshot() => [
        _nameController.text,
        _descriptionController.text,
        _certificationsController.text,
        _websiteController.text,
        _emailController.text,
        _phoneController.text,
        _addressController.text,
        _cityController.text,
        _postalCodeController.text,
        _vatNumberController.text,
        _selectedTrades.join(','),
        _selectedEmployees,
        _selectedServices.join(','),
      ].join('|');

  double get _completeness => CompanyModel.calculateCompleteness(
        description: _descriptionController.text,
        website: _websiteController.text,
        phone: _phoneController.text,
        address: _addressController.text,
        trades: _selectedTrades,
      );

  Future<void> _loadExistingCompany() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      final service = ref.read(companyServiceProvider);
      final company = await service.getCompanyByOwner(user.uid);

      if (company != null) {
        _existingCompany = company;
        _nameController.text = company.name;
        _descriptionController.text = company.description;
        _certificationsController.text = company.certifications;
        _websiteController.text = company.website;
        _emailController.text = company.email;
        _phoneController.text = company.phone;
        _addressController.text = company.address;
        if (company.city.isNotEmpty) _cityController.text = company.city;
        _postalCodeController.text = company.postalCode;
        _vatNumberController.text = company.vatNumber;
        _selectedTrades = company.trades.where(kTrades.contains).take(2).toList();
        _selectedEmployees = kEmployeeCounts.contains(company.employees)
            ? company.employees
            : kEmployeeCounts[0];
        _selectedServices = List.from(company.services);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _savedSnapshot = _snapshot(); // baseline: nothing changed yet
        });
      }
    }
  }

  void _scrollToField(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  /// Finds the first field (in on-screen order) whose validation failed and
  /// scrolls it to the center of the screen — the orange border alone isn't
  /// enough to notice if the field is off-screen when Save is pressed.
  bool _scrollToFirstInvalidField() {
    for (final key in [
      _nameFieldKey,
      _descriptionFieldKey,
      _emailFieldKey,
      _phoneFieldKey,
      _cityFieldKey,
      _postalCodeFieldKey,
      _vatNumberFieldKey,
    ]) {
      if (key.currentState?.hasError ?? false) {
        _scrollToField(key);
        return true;
      }
    }
    return false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      _scrollToFirstInvalidField();
      return;
    }
    if (_selectedTrades.isEmpty) {
      setState(() => _errorMessage = AppLocalizations.of(context).selectAtLeastOneTrade);
      _scrollToField(_tradesFieldKey);
      return;
    }

    // Rename cooldown (#policy): a company can change its name only every
    // kNameChangeCooldownDays. Stamp lastNameChangeAt only when it actually
    // changes; otherwise preserve the existing stamp.
    final trimmedName = _nameController.text.trim();
    DateTime? nameStamp = _existingCompany?.lastNameChangeAt;
    if (_existingCompany != null && trimmedName != _existingCompany!.name) {
      final last = _existingCompany!.lastNameChangeAt;
      if (last != null &&
          DateTime.now().difference(last).inDays < kNameChangeCooldownDays) {
        setState(() => _errorMessage =
            AppLocalizations.of(context).nameChangeCooldownError(kNameChangeCooldownDays));
        _scrollToField(_tradesFieldKey);
        return;
      }
      nameStamp = DateTime.now();
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      final service = ref.read(companyServiceProvider);
      final companyId = _existingCompany?.id ?? user.uid;

      final vatNumber = _vatNumberController.text.trim();
      // Captured before _existingCompany is overwritten below — used after
      // the save succeeds to decide whether a fresh VIES check is warranted.
      final previousVatNumber = _existingCompany?.vatNumber ?? '';
      // verificationStatus is no longer derived client-side from "is the VAT
      // field non-empty" — that let anyone show a real "Verifizierung
      // ausstehend" trust badge just by typing any string into the field,
      // with the actual VIES check never having run. 'pending' is now
      // reachable ONLY via the verifyMyCompany Cloud Function after a real
      // check (see firestore.rules + _maybeVerifyVat below); a profile save
      // simply preserves whatever verificationStatus the company already had
      // ('none' for a brand-new one).
      final verificationStatus = _existingCompany?.verificationStatus ?? 'none';

      final company = CompanyModel(
        id: companyId,
        ownerId: user.uid,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        certifications: _certificationsController.text.trim(),
        website: _websiteController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        country: 'Deutschland',
        employees: _selectedEmployees,
        trades: _selectedTrades,
        services: _selectedServices,
        logoUrl: _existingCompany?.logoUrl ?? '',
        vatNumber: vatNumber,
        verificationStatus: verificationStatus,
        // Once flagged, stays flagged through owner edits until an admin
        // clears it — matches the Firestore rule, which only allows
        // contentFlagged to move false→true (never true→false) on a
        // non-admin write, so a self-edit can never silently unflag.
        contentFlagged: (_existingCompany?.contentFlagged ?? false) ||
            containsBlockedContent(_nameController.text) ||
            containsBlockedContent(_descriptionController.text),
        lastNameChangeAt: nameStamp,
      );

      if (_existingCompany == null) {
        await service.createCompany(company);
      } else {
        await service.updateCompany(company);
      }

        // Sync updated company info to all capacity posts — the contact
        // snapshot (on the locked owner sidecars) and the non-identifying
        // trust signals (on the public posts) both refresh best-effort here.
        await ref
            .read(capacityServiceProvider)
            .updateCompanyNameOnAllPosts(
              companyId: companyId,
              newName: company.name,
              newCity: company.city,
              newPhone: company.phone,
              newEmail: company.email,
              verified: company.isVerified,
              ratingSum: company.ratingSum,
              ratingCount: company.ratingCount,
            );

        AnalyticsService.logEvent('company_profile_completed');

        setState(() {
          _successMessage = company.contentFlagged
              ? AppLocalizations.of(context).postingUnderReviewNotice
              : AppLocalizations.of(context).profileSavedSuccess;
          _existingCompany = company;
          _savedSnapshot = _snapshot(); // now clean → disable Save until a change
        });

        // A VAT number is on file and either just changed or was never
        // actually checked (verificationStatus stayed 'none') — kick off the
        // real VIES check right away rather than leaving it sitting at
        // 'none' until the company happens to separately press "Automatisch
        // prüfen". Runs AFTER the setState above so its own refresh (via
        // _loadExistingCompany) isn't immediately clobbered by it. Best-effort:
        // VIES downtime shouldn't block a profile save that already
        // succeeded; the manual button and founder review queue remain the
        // fallback either way.
        final vatNeedsCheck = vatNumber.isNotEmpty &&
            verificationStatus != 'verified' &&
            (vatNumber != previousVatNumber || verificationStatus == 'none');
        if (vatNeedsCheck) {
          try {
            await FirebaseFunctions.instanceFor(region: 'europe-west3')
                .httpsCallable('verifyMyCompany')
                .call();
            await _loadExistingCompany(); // pick up the real post-check status
          } catch (_) {
            // Non-fatal — same fallback as the manual verify button.
          }
        }

        // Wow moment: profile complete (once) — the activation milestone that
        // unlocks visibility + posting.
        if (mounted && company.isProfileComplete && !company.contentFlagged) {
          final l = AppLocalizations.of(context);
          Milestone.celebrateOnce(context,
              uid: companyId,
              key: 'first_profile',
              icon: Icons.verified_user_outlined,
              title: l.msProfileTitle,
              subtitle: l.msProfileBody);
        }
      } catch (e) {
        setState(() {
          _errorMessage =
              AppLocalizations.of(context).saveErrorRetry;
        });
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _certificationsController.dispose();
    _websiteController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _vatNumberController.dispose();
    super.dispose();
  }

  Future<void> _emailVerificationDoc() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'info@capacify.de',
      queryParameters: {'subject': 'Capacify Verifizierung'},
    );
    try {
      await launchUrl(uri);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: c.surface,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: c.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l.companyProfileTitle,
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: _completeness,
            minHeight: 3,
            backgroundColor: c.border,
            color: _completeness >= 1.0 ? AppColors.live : AppColors.primary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.all(isMobile ? 20 : 32),
        child: Center(
          child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  l.companyProfileSubtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.profileCompletePercent((_completeness * 100).round()),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _completeness >= 1.0 ? AppColors.live : c.textTertiary,
                  ),
                ),

                SizedBox(height: isMobile ? 14 : 24),

                // Logo — only offered once the company actually exists (a
                // logo for a not-yet-created profile doesn't make sense, and
                // Storage's path convention keys off the owner's own uid
                // regardless, so there's nothing to upload TO yet). Uploads
                // straight away rather than waiting on the Save button, same
                // reasoning as the emailOptIn toggle elsewhere.
                if (_existingCompany != null) ...[
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _uploadingLogo ? null : _pickAndUploadLogo,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CompanyLogoAvatar(
                                logoUrl: _existingCompany!.logoUrl,
                                companyName: _existingCompany!.name,
                                radius: 44,
                              ),
                              if (_uploadingLogo)
                                const Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black38),
                                    child: Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: c.background, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt_outlined, size: 14, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(l.logoUploadHint, style: TextStyle(fontSize: 12, color: c.textTertiary)),
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 14 : 20),
                ],

                if (_existingCompany != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        Text(l.yourRatingSectionTitle, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textSecondary)),
                        const SizedBox(width: 12),
                        if (_existingCompany!.ratingCount > 0) ...[
                          StarRatingDisplay(rating: _existingCompany!.avgRating, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${_existingCompany!.avgRating.toStringAsFixed(1)} (${_existingCompany!.ratingCount})',
                            style: TextStyle(fontSize: 13, color: c.textTertiary),
                          ),
                        ] else
                          Expanded(
                            child: Text(
                              l.noRatingYetOwnText,
                              style: TextStyle(fontSize: 13, color: c.textTertiary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 8 : 12),

                  if (_existingCompany!.contentFlagged)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.visibility_off_outlined, color: AppColors.accent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l.profileUnderReviewHidden,
                              style: const TextStyle(color: AppColors.accent, fontSize: 12, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: isMobile ? 8 : 12),
                ],

                // Section: Basic Info
                _SectionHeader(title: l.basicInfoSection),
                SizedBox(height: isMobile ? 10 : 16),

                CustomTextField(
                  fieldKey: _nameFieldKey,
                  label: l.companyNameLabel,
                  hint: l.companyNameHint,
                  controller: _nameController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l.required;
                    }
                    return null;
                  },
                ),

                SizedBox(height: isMobile ? 12 : 20),

                // Trade selection (up to 2)
                Column(
                  key: _tradesFieldKey,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.tradeBranchLabel,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.maxTwoTradesNotice,
                      style: TextStyle(
                        color: c.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kTrades.map((trade) {
                        final isSelected = _selectedTrades.contains(trade);
                        final atLimit = _selectedTrades.length >= 2 && !isSelected;
                        return FilterChip(
                          label: Text(l.tradeName(trade)),
                          selected: isSelected,
                          onSelected: atLimit
                              ? null
                              : (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedTrades.add(trade);
                                    } else {
                                      _selectedTrades.remove(trade);
                                    }
                                  });
                                },
                          backgroundColor: c.surfaceVariant,
                          selectedColor: AppColors.primary.withOpacity(0.2),
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : (atLimit ? c.textTertiary : c.textSecondary),
                            fontSize: 13,
                          ),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : c.border,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                SizedBox(height: isMobile ? 12 : 20),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.descriptionRequiredLabel,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: _descriptionFieldKey,
                      controller: _descriptionController,
                      maxLines: 4,
                      style: TextStyle(
                        color: c.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: l.describeCompanyHint,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l.required;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l.certificationsLabel,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _certificationsController,
                      maxLines: 2,
                      style: TextStyle(color: c.textPrimary),
                      decoration: InputDecoration(hintText: l.certificationsHint),
                    ),
                  ],
                ),

                SizedBox(height: isMobile ? 18 : 32),

                // Section: Contact
                _SectionHeader(title: l.contactInfoSection),
                SizedBox(height: isMobile ? 10 : 16),

                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        fieldKey: _emailFieldKey,
                        label: l.emailLabel,
                        hint: l.companyEmailHint,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => Validators.email(v, l, required: false),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        fieldKey: _phoneFieldKey,
                        label: l.companyPhoneRequiredLabel,
                        hint: l.phoneHint,
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        validator: (v) => Validators.phone(v, l, required: true),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: isMobile ? 12 : 20),

                CustomTextField(
                  label: l.websiteOptionalLabel,
                  hint: l.websiteHint,
                  controller: _websiteController,
                  keyboardType: TextInputType.url,
                ),

                SizedBox(height: isMobile ? 18 : 32),

                // Section: Location
                _SectionHeader(title: l.locationSection),
                SizedBox(height: isMobile ? 10 : 16),

                CustomTextField(
                  label: l.companyAddressRequiredLabel,
                  hint: l.addressHint,
                  controller: _addressController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? l.required : null,
                ),

                SizedBox(height: isMobile ? 12 : 20),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: CustomTextField(
                        fieldKey: _cityFieldKey,
                        label: l.cityLabel,
                        hint: l.cityHint,
                        controller: _cityController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l.required;
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        fieldKey: _postalCodeFieldKey,
                        label: l.postalCodeLabel,
                        hint: '10115',
                        controller: _postalCodeController,
                        keyboardType: TextInputType.number,
                        validator: (v) => Validators.postalCode(v, l),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: isMobile ? 18 : 32),

                // Section: Company Details
                _SectionHeader(title: l.companyDetailsSection),
                SizedBox(height: isMobile ? 10 : 16),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.employeeCountLabel,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedEmployees,
                      dropdownColor: c.surface,
                      style: TextStyle(
                        color: c.textPrimary,
                      ),
                      decoration: const InputDecoration(),
                      items: kEmployeeCounts
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(l.employeesSuffix(e)),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedEmployees = value!;
                        });
                      },
                    ),
                  ],
                ),

                SizedBox(height: isMobile ? 18 : 32),

                // Verification
                _SectionHeader(title: l.sectionVerify),
                SizedBox(height: isMobile ? 10 : 16),

                CustomTextField(
                  fieldKey: _vatNumberFieldKey,
                  label: l.vatLabel, hint: l.vatHint,
                  controller: _vatNumberController,
                  validator: (v) => Validators.vatNumberDE(v, l),
                ),
                SizedBox(height: isMobile ? 8 : 12),

                if (_existingCompany?.verificationStatus == 'verified')
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.live.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.live.withOpacity(0.25)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.verified, size: 15, color: AppColors.live),
                      const SizedBox(width: 8),
                      Text(l.verifiedBadgeLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.live)),
                    ]),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.live.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.live.withOpacity(0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.verified_outlined, size: 15, color: AppColors.live),
                          const SizedBox(width: 8),
                          Text(l.verifyHowTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.live)),
                        ]),
                        const SizedBox(height: 10),
                        Text(l.verifySteps, style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.6)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _emailVerificationDoc,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mail_outline, size: 13, color: AppColors.live),
                              SizedBox(width: 5),
                              Text(
                                'info@capacify.de',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.live,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.live,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Instant automatic verification via the EU VIES check
                        // (server-side function). A valid VAT verifies at once —
                        // no waiting for the founder. Save your VAT number first.
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _verifyingVat ? null : _runVatVerification,
                            icon: _verifyingVat
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.live))
                                : const Icon(Icons.verified_user_outlined, size: 16),
                            label: Text(l.verifyNowVies),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.live,
                              side: const BorderSide(color: AppColors.live),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: isMobile ? 20 : 40),

                // Success message — shown right above the button the user
                // just pressed, instead of making them scroll up to find it.
                if (_successMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.success.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: AppColors.success,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _successMessage!,
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 14 : 20),
                ],

                // Error message — same placement; field-level problems are
                // also scrolled into view via _scrollToFirstInvalidField().
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.error.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 14 : 20),
                ],

                // Save button — disabled while saving, and disabled again once
                // saved until the form actually changes (dirty tracking, #2).
                ElevatedButton(
                  onPressed: (_isSaving || _snapshot() == _savedSnapshot) ? null : _save,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 50),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l.saveProfileButton),
                ),

                SizedBox(height: isMobile ? 16 : 32),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Divider(color: c.border),
      ],
    );
  }
}