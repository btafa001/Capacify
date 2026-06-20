import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/capacity_model.dart';
import '../../../core/services/capacity_provider.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/content_moderation.dart';

const List<String> kTradesList = [
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

class EditCapacityScreen extends ConsumerStatefulWidget {
  final CapacityModel capacity;

  const EditCapacityScreen({
    super.key,
    required this.capacity,
  });

  @override
  ConsumerState<EditCapacityScreen> createState() =>
      _EditCapacityScreenState();
}

class _EditCapacityScreenState
    extends ConsumerState<EditCapacityScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _workerCountController;

  late CapacityType _type;
  late String _selectedTrade;
  late DateTime _availableFrom;
  late DateTime _availableTo;
  late CapacityStatus _status;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.capacity.title);
    _descriptionController =
        TextEditingController(text: widget.capacity.description);
    _locationController =
        TextEditingController(text: widget.capacity.location);
    _workerCountController = TextEditingController(
      text: widget.capacity.workerCount.toString(),
    );
    _type = widget.capacity.type;
    _selectedTrade = widget.capacity.trade;
    _availableFrom = widget.capacity.availableFrom;
    _availableTo = widget.capacity.availableTo;
    _status = widget.capacity.status;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _workerCountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final c = AppColors.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _availableFrom : _availableTo,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              surface: c.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _availableFrom = picked;
        } else {
          _availableTo = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final service = ref.read(capacityServiceProvider);

      final updatedCapacity = CapacityModel(
        id: widget.capacity.id,
        companyId: widget.capacity.companyId,
        companyName: widget.capacity.companyName,
        companyCity: widget.capacity.companyCity,
        companyPhone: widget.capacity.companyPhone,
        companyEmail: widget.capacity.companyEmail,
        type: _type,
        status: _status,
        availabilityType: widget.capacity.availabilityType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        trade: _selectedTrade,
        location: _locationController.text.trim(),
        workerCount:
            int.tryParse(_workerCountController.text) ?? 1,
        availableFrom: _availableFrom,
        availableTo: _availableTo,
        contentFlagged: containsBlockedContent(_descriptionController.text),
      );

      await service.updateCapacity(updatedCapacity);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).capacityUpdatedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).saveErrorGeneric),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l.editCapacityTitle,
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type and Status info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: (_type == CapacityType.offer
                                ? AppColors.success
                                : AppColors.accent)
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (_type == CapacityType.offer
                                  ? AppColors.success
                                  : AppColors.accent)
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _type == CapacityType.offer
                            ? l.offerLabel
                            : l.needLabel,
                        style: TextStyle(
                          color: _type == CapacityType.offer
                              ? AppColors.success
                              : AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: (_status == CapacityStatus.active
                                ? AppColors.success
                                : c.textHint)
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (_status == CapacityStatus.active
                                  ? AppColors.success
                                  : c.textHint)
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _status == CapacityStatus.active
                            ? l.statusActiveBadge
                            : l.endedBadge,
                        style: TextStyle(
                          color: _status == CapacityStatus.active
                              ? AppColors.success
                              : c.textHint,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                CustomTextField(
                  label: l.titleRequiredLabel,
                  controller: _titleController,
                  validator: (v) =>
                      v == null || v.isEmpty ? l.required : null,
                ),

                const SizedBox(height: 20),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.tradeLabel,
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
                          color: c.textPrimary),
                      decoration: const InputDecoration(),
                      items: kTradesList
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(l.tradeName(t)),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedTrade = v!),
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
                          color: c.textPrimary),
                      decoration:
                          const InputDecoration(),
                      validator: (v) => v == null || v.isEmpty
                          ? l.required
                          : null,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: l.locationRequiredLabel,
                        controller: _locationController,
                        validator: (v) => v == null || v.isEmpty
                            ? l.required
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        label: l.countRequiredLabel,
                        controller: _workerCountController,
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.isEmpty
                            ? l.required
                            : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: _DatePickerField(
                        label: l.fromDateLabel,
                        date: _availableFrom,
                        onTap: () => _pickDate(isFrom: true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _DatePickerField(
                        label: l.toDateLabel,
                        date: _availableTo,
                        onTap: () => _pickDate(isFrom: false),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Status toggle
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.statusFieldLabel,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _StatusButton(
                            label: l.activeStatusButton,
                            isSelected:
                                _status == CapacityStatus.active,
                            color: AppColors.success,
                            onTap: () => setState(() =>
                                _status =
                                    CapacityStatus.active),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatusButton(
                            label: l.endedStatusButton,
                            isSelected:
                                _status == CapacityStatus.closed,
                            color: c.textHint,
                            onTap: () => setState(() =>
                                _status =
                                    CapacityStatus.closed),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 40),

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
                      : Text(l.saveButtonGeneric),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: c.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : c.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : c.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? color : c.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}