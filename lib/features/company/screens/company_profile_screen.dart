import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/company_model.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/company_provider.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/star_rating.dart';
import 'company_analytics_screen.dart';
import '../../../core/services/capacity_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/content_moderation.dart';

const List<String> kTrades = [
  'Generalunternehmer',
  'Rohbau',
  'Trockenbau',
  'Elektro',
  'Sanitär & Heizung',
  'Dach',
  'Fassade',
  'Tiefbau',
  'Architektur',
  'Statik',
  'Stahl',
  'Beton',
  'HVAC',
  'Lieferant',
];

const List<String> kEmployees = [
  '1-5',
  '6-10',
  '11-25',
  '26-50',
  '51-100',
  '100+',
];

class CompanyProfileScreen extends ConsumerStatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  ConsumerState<CompanyProfileScreen> createState() =>
      _CompanyProfileScreenState();
}

class _CompanyProfileScreenState
    extends ConsumerState<CompanyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _websiteController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();

  String _selectedTrade = kTrades[0];
  String _selectedEmployees = kEmployees[0];
  List<String> _selectedServices = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;
  CompanyModel? _existingCompany;

  @override
  void initState() {
    super.initState();
    _loadExistingCompany();
  }

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
        _websiteController.text = company.website;
        _emailController.text = company.email;
        _phoneController.text = company.phone;
        _addressController.text = company.address;
        _cityController.text = company.city;
        _postalCodeController.text = company.postalCode;
        _selectedTrade = company.trade.isNotEmpty
            ? company.trade
            : kTrades[0];
        _selectedEmployees = company.employees.isNotEmpty
            ? company.employees
            : kEmployees[0];
        _selectedServices = List.from(company.services);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

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

      final company = CompanyModel(
        id: companyId,
        ownerId: user.uid,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        website: _websiteController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        country: 'Deutschland',
        employees: _selectedEmployees,
        trade: _selectedTrade,
        services: _selectedServices,
        logoUrl: _existingCompany?.logoUrl ?? '',
        contentFlagged: containsBlockedContent(_nameController.text) ||
            containsBlockedContent(_descriptionController.text),
      );

      if (_existingCompany == null) {
        await service.createCompany(company);
      } else {
        await service.updateCompany(company);
      }

        // Sync updated company info to all capacity posts
        await ref
            .read(capacityServiceProvider)
            .updateCompanyNameOnAllPosts(
              companyId: companyId,
              newName: company.name,
              newCity: company.city,
              newPhone: company.phone,
              newEmail: company.email,
            );

        setState(() {
          _successMessage = company.contentFlagged
              ? AppLocalizations.of(context).postingUnderReviewNotice
              : AppLocalizations.of(context).profileSavedSuccess;
          _existingCompany = company;
        });
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
    _nameController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
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
                  l.companyProfileTitle,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.companyProfileSubtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textSecondary,
                  ),
                ),

                const SizedBox(height: 24),

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
                  const SizedBox(height: 12),

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

                  const SizedBox(height: 12),
                ],

                // Success message
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
                  const SizedBox(height: 24),
                ],

                // Error message
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
                  const SizedBox(height: 24),
                ],

                // Section: Basic Info
                _SectionHeader(title: l.basicInfoSection),
                const SizedBox(height: 16),

                CustomTextField(
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

                const SizedBox(height: 20),

                // Trade dropdown
                Column(
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
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedTrade,
                      dropdownColor: c.surface,
                      style: TextStyle(
                        color: c.textPrimary,
                      ),
                      decoration: const InputDecoration(),
                      items: kTrades
                          .map((trade) => DropdownMenuItem(
                                value: trade,
                                child: Text(l.tradeName(trade)),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedTrade = value!;
                        });
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),

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
                  ],
                ),

                const SizedBox(height: 32),

                // Section: Contact
                _SectionHeader(title: l.contactInfoSection),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: l.emailLabel,
                        hint: l.companyEmailHint,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        label: l.phoneLabel,
                        hint: l.phoneHint,
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                CustomTextField(
                  label: l.websiteLabel,
                  hint: l.websiteHint,
                  controller: _websiteController,
                  keyboardType: TextInputType.url,
                ),

                const SizedBox(height: 32),

                // Section: Location
                _SectionHeader(title: l.locationSection),
                const SizedBox(height: 16),

                CustomTextField(
                  label: l.addressLabel,
                  hint: l.addressHint,
                  controller: _addressController,
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: CustomTextField(
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
                        label: l.postalCodeLabel,
                        hint: '10115',
                        controller: _postalCodeController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Section: Company Details
                _SectionHeader(title: l.companyDetailsSection),
                const SizedBox(height: 16),

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
                      items: kEmployees
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

                const SizedBox(height: 20),

                // Services multi-select
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.servicesLabel,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kTrades.map((trade) {
                        final isSelected =
                            _selectedServices.contains(trade);
                        return FilterChip(
                          label: Text(l.tradeName(trade)),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedServices.add(trade);
                              } else {
                                _selectedServices.remove(trade);
                              }
                            });
                          },
                          backgroundColor: c.surfaceVariant,
                          selectedColor:
                              AppColors.primary.withOpacity(0.2),
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : c.textSecondary,
                            fontSize: 13,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : c.border,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Save button
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
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

                const SizedBox(height: 32),
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