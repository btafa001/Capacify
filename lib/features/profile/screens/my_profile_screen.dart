import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_provider.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../settings/screens/settings_screen.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/utils/validators.dart';

class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() =>
      _MyProfileScreenState();
}

class _MyProfileScreenState
    extends ConsumerState<MyProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  int? _joinYear;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('MyProfile');
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      final data = await ref.read(authServiceProvider).getUserProfile(user.uid);
      if (data != null) {
        _firstNameController.text = data['firstName'] as String? ?? '';
        _lastNameController.text = data['lastName'] as String? ?? '';
        _jobTitleController.text = data['jobTitle'] as String? ?? '';
        _phoneController.text = data['phone'] as String? ?? '';
        final createdAt = data['createdAt'];
        if (createdAt is Timestamp) {
          _joinYear = createdAt.toDate().year;
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final l = AppLocalizations.of(context);
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final phoneError = Validators.phone(_phoneController.text, l);
    if (phoneError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(phoneError), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(authServiceProvider).updateUserProfile(
            uid: user.uid,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            phone: _phoneController.text.trim(),
            jobTitle: _jobTitleController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.profileSavedSuccess),
            backgroundColor: const Color(0xFF2ECC71),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.saveErrorRetry),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showChangePasswordDialog() async {
    final success = await showDialog<bool>(
      context: context,
      builder: (_) => ChangePasswordDialog(
        authService: ref.read(authServiceProvider),
      ),
    );
    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).passwordChangedSuccess),
          backgroundColor: const Color(0xFF2ECC71),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final user = ref.watch(authStateProvider).value;
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.surface,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: c.textPrimary),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            l.menuProfile,
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: c.textPrimary),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l.menuProfile,
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 20 : 32),
        child: Center(
          child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar section
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor:
                          AppColors.primary.withOpacity(0.2),
                      child: Text(
                        user?.email?.isNotEmpty == true
                            ? user!.email![0].toUpperCase()
                            : 'P',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    SizedBox(height: isMobile ? 10 : 16),
                    Text(
                      user?.email ?? l.profileFallback,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                    SizedBox(height: isMobile ? 2 : 4),
                    Text(
                      l.memberSince(_joinYear ?? DateTime.now().year),
                      style: TextStyle(
                        fontSize: 13,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: isMobile ? 16 : 40),

              // Personal Info Section
              Text(
                l.personalInfoSection,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),

              const SizedBox(height: 4),
              Divider(color: c.border),

              SizedBox(height: isMobile ? 12 : 20),

              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: l.firstNameLabelPlain,
                      hint: l.firstNameHint,
                      controller: _firstNameController,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      label: l.lastNameLabelPlain,
                      hint: l.lastNameHint,
                      controller: _lastNameController,
                    ),
                  ),
                ],
              ),

              SizedBox(height: isMobile ? 14 : 20),

              CustomTextField(
                label: l.jobTitleLabel,
                hint: l.jobTitleHint,
                controller: _jobTitleController,
              ),

              SizedBox(height: isMobile ? 14 : 20),

              CustomTextField(
                label: l.phoneLabel,
                hint: l.phoneHint,
                controller: _phoneController,
                keyboardType: TextInputType.phone,
              ),

              SizedBox(height: isMobile ? 18 : 32),

              ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(160, 48),
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
                    : Text(l.saveButtonGeneric),
              ),

              SizedBox(height: isMobile ? 16 : 40),

              // Account section
              Text(
                l.accountSection,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),

              const SizedBox(height: 4),
              Divider(color: c.border),

              SizedBox(height: isMobile ? 10 : 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.emailAddressLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '-',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: isMobile ? 8 : 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.passwordLabel,
                          style: TextStyle(
                            fontSize: 13,
                            color: c.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '••••••••',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: _showChangePasswordDialog,
                      child: Text(l.changeButton),
                    ),
                  ],
                ),
              ),

              SizedBox(height: isMobile ? 16 : 32),
            ],
          ),
        ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _jobTitleController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}