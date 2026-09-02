import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/payment/payment_models.dart';
import 'package:ubci_bank/src/core/theme/app_radius.dart';
import 'package:ubci_bank/src/core/theme/app_spacing.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/providers/payee_providers.dart';
import 'package:ubci_bank/src/view/providers/payment_providers.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// Add Demand Draft Payee — Domestic / International draft type, matching
/// the captured "Add Demand Draft Payee" screens.
///
/// The supplied API capture does not contain a Demand Draft payee submit
/// endpoint (or a branch/city enumeration endpoint for "Draft Payable At"),
/// so this screen builds the full captured UI/UX and validation, and — like
/// the Domestic/International tabs on Add Bank Account Payee — surfaces a
/// clear message instead of inventing an unverified API contract on submit.
class AddDemandDraftPayeeScreen extends ConsumerStatefulWidget {
  const AddDemandDraftPayeeScreen({
    super.key,
    this.embedded = false,
    this.onBack,
    this.onCompleted,
  });

  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onCompleted;

  @override
  ConsumerState<AddDemandDraftPayeeScreen> createState() =>
      _AddDemandDraftPayeeScreenState();
}

/// Draft Payable At, for the Domestic tab, is not backed by a captured
/// branch/city enumeration endpoint. These placeholder options mirror the
/// values visible in the captured demo-bank screens.
const List<String> _kDomesticDraftPayableAtOptions = ['TZ', 'California', 'test'];
const List<String> _kDomesticBranchOptions = ['NMB BANK PLC'];
const List<String> _kMyAddressTypeOptions = ['Postal', 'Residence', 'Work'];

class _AddDemandDraftPayeeScreenState
    extends ConsumerState<AddDemandDraftPayeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _payeeName = TextEditingController();
  final _draftFavouring = TextEditingController();

  // Other Address fields.
  final _otherAddressLine1 = TextEditingController();
  final _otherAddressLine2 = TextEditingController();
  final _otherCity = TextEditingController();
  final _otherState = TextEditingController();
  final _otherZipCode = TextEditingController();

  int _draftType = 0; // 0 Domestic, 1 International.
  String? _draftPayableAtDomestic;
  String? _draftPayableAtCountry; // International.
  String? _otherAddressCountry; // International "Other Address" only.

  int _addressMode = 0; // 0 Branch Near Me, 1 My Address, 2 Other Address.
  String? _branchCity;
  String? _branchNearMe;
  String? _myAddressType;

  bool _uploadingPhoto = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(payeesProvider.notifier).ensureLoaded();
    });
  }

  @override
  void dispose() {
    _payeeName.dispose();
    _draftFavouring.dispose();
    _otherAddressLine1.dispose();
    _otherAddressLine2.dispose();
    _otherCity.dispose();
    _otherState.dispose();
    _otherZipCode.dispose();
    super.dispose();
  }

  Future<void> _uploadPhoto() async {
    setState(() => _uploadingPhoto = true);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() => _uploadingPhoto = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Photo upload UI is ready; the captured source does not contain the multipart upload endpoint.',
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_draftPayableAtSelected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft Payable At is required.')),
      );
      return;
    }

    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() => _submitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'The supplied API capture does not include a Demand Draft payee submit endpoint yet.',
        ),
      ),
    );
  }

  String? get _draftPayableAtSelected =>
      _draftType == 0 ? _draftPayableAtDomestic : _draftPayableAtCountry;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(payeesProvider);
    final responsive = Responsive.of(context);

    final form = Form(
      key: _formKey,
      child: _buildForm(context, state, responsive),
    );

    final body = SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              responsive.isPhone ? AppSpacing.lg : AppSpacing.xxxl,
              AppSpacing.lg,
              responsive.isPhone ? AppSpacing.lg : AppSpacing.xxxl,
              AppSpacing.xxxl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: form),
                          const SizedBox(width: AppSpacing.xxxl),
                          const Expanded(flex: 4, child: _DraftInfoPanel()),
                        ],
                      )
                    : form,
              ),
            ),
          );
        },
      ),
    );

    if (widget.embedded) {
      return Scaffold(
        backgroundColor: HomeColors.bg(context),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.sm,
                top: AppSpacing.xs,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: _handleBack,
                  tooltip: 'Back',
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: HomeColors.textPrimary(context),
                  ),
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      appBar: AppBar(
        title: const Text('Add Demand Draft Payee'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _handleBack,
        ),
      ),
      body: body,
    );
  }

  void _handleBack() {
    if (widget.embedded) {
      widget.onBack?.call();
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget _buildForm(
    BuildContext context,
    PayeesState state,
    Responsive responsive,
  ) {
    final content = [
      _field(controller: _payeeName, label: 'Payee Name', validator: _required),
      const SizedBox(height: AppSpacing.lg),
      _buildPhotoSection(context),
      const SizedBox(height: AppSpacing.lg),
      Text('Draft Type', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: AppSpacing.xs),
      _buildDraftTypeTabs(context),
      const SizedBox(height: AppSpacing.lg),
      _field(
        controller: _draftFavouring,
        label: 'Draft Favouring',
        validator: _required,
      ),
      const SizedBox(height: AppSpacing.lg),
      _buildDraftPayableAt(context, state),
      const SizedBox(height: AppSpacing.lg),
      _buildAddressModeRadios(context),
      const SizedBox(height: AppSpacing.lg),
      ..._buildAddressModeFields(context, state),
      const SizedBox(height: AppSpacing.xxxl),
      _buildActions(context),
    ];

    return Container(
      padding: EdgeInsets.all(responsive.isPhone ? AppSpacing.lg : AppSpacing.xxl),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: content,
      ),
    );
  }

  Widget _buildPhotoSection(BuildContext context) {
    final textSecondary = HomeColors.textSecondary(context);
    final brand = HomeColors.brand(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: brand.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Icon(Icons.person_add_alt_1_rounded, color: brand, size: 32),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payee Photo', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              TextButton.icon(
                onPressed: _uploadingPhoto ? null : _uploadPhoto,
                icon: _uploadingPhoto
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_rounded, size: 18),
                label: const Text('Upload Photo'),
              ),
              Text(
                'Max image size – 1000 KB.\nFile format – .JPG and .PNG',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDraftTypeTabs(BuildContext context) {
    final brand = HomeColors.brand(context);
    final divider = HomeColors.divider(context);
    final labels = const ['Domestic', 'International'];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: divider),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => setState(() {
                  _draftType = i;
                  // Reset the selections that differ between the two flows.
                  _addressMode = 0;
                  _otherAddressCountry = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: _draftType == i
                        ? brand.withValues(alpha: 0.1)
                        : Colors.transparent,
                    border: i == 0
                        ? null
                        : Border(left: BorderSide(color: divider)),
                  ),
                  child: Center(
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        color: _draftType == i
                            ? brand
                            : HomeColors.textSecondary(context),
                        fontWeight: _draftType == i
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDraftPayableAt(BuildContext context, PayeesState state) {
    if (_draftType == 0) {
      return _dropdown<String>(
        label: 'Draft Payable At',
        value: _kDomesticDraftPayableAtOptions.contains(_draftPayableAtDomestic)
            ? _draftPayableAtDomestic
            : null,
        items: _kDomesticDraftPayableAtOptions,
        itemLabel: (e) => e,
        onChanged: (value) => setState(() {
          _draftPayableAtDomestic = value;
          _addressMode = 0;
        }),
      );
    }

    final countries = ref.watch(paymentCountriesProvider).valueOrNull ??
        const <PaymentCountry>[];
    return _dropdown<PaymentCountry>(
      label: 'Draft Payable At',
      searchable: true,
      value: countries.any((e) => e.code == _draftPayableAtCountry)
          ? countries.firstWhere((e) => e.code == _draftPayableAtCountry)
          : null,
      items: countries,
      itemLabel: (e) => e.name,
      onChanged: (value) => setState(() {
        _draftPayableAtCountry = value?.code;
        _addressMode = 0;
      }),
    );
  }

  Widget _buildAddressModeRadios(BuildContext context) {
    final enabled = _draftPayableAtSelected != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.xs,
          children: [
            _radioOption(
              label: 'Branch Near Me',
              value: 0,
              groupValue: _addressMode,
              onChanged: (value) => setState(() => _addressMode = value!),
            ),
            _radioOption(
              label: 'My Address',
              value: 1,
              groupValue: _addressMode,
              onChanged: (value) => setState(() => _addressMode = value!),
            ),
            _radioOption(
              label: 'Other Address',
              value: 2,
              groupValue: _addressMode,
              onChanged: (value) => setState(() => _addressMode = value!),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAddressModeFields(BuildContext context, PayeesState state) {
    if (_draftPayableAtSelected == null) return const [];

    switch (_addressMode) {
      case 1:
        return _buildMyAddressFields(context);
      case 2:
        return _buildOtherAddressFields(context, state);
      case 0:
      default:
        return _buildBranchNearMeFields(context);
    }
  }

  List<Widget> _buildBranchNearMeFields(BuildContext context) {
    final resolved = _branchCity != null && _branchNearMe != null;
    return [
      _dropdown<String>(
        label: 'City',
        value: _kDomesticDraftPayableAtOptions.contains(_branchCity)
            ? _branchCity
            : null,
        items: _kDomesticDraftPayableAtOptions,
        itemLabel: (e) => e,
        onChanged: (value) => setState(() {
          _branchCity = value;
          _branchNearMe = null;
        }),
      ),
      const SizedBox(height: AppSpacing.lg),
      _dropdown<String>(
        label: 'Branch Near Me',
        value: _kDomesticBranchOptions.contains(_branchNearMe)
            ? _branchNearMe
            : null,
        items: _kDomesticBranchOptions,
        itemLabel: (e) => e,
        onChanged: (value) => setState(() => _branchNearMe = value),
      ),
      if (resolved) ...[
        const SizedBox(height: AppSpacing.lg),
        _AddressPreview(
          lines: const [
            'OHIO STREET, ALI HASSAN MWINYI RD',
            'TANZANIA',
            'TZ',
            'GREAT BRITAIN',
          ],
        ),
      ],
    ];
  }

  List<Widget> _buildMyAddressFields(BuildContext context) {
    return [
      _dropdown<String>(
        label: 'Address Type',
        hint: 'Postal',
        value: _kMyAddressTypeOptions.contains(_myAddressType)
            ? _myAddressType
            : null,
        items: _kMyAddressTypeOptions,
        itemLabel: (e) => e,
        onChanged: (value) => setState(() => _myAddressType = value),
      ),
      if (_myAddressType != null) ...[
        const SizedBox(height: AppSpacing.lg),
        const _AddressPreview(
          lines: ['ADDRESS1', 'ADDRESS2', 'ADDRESS3', 'IN'],
        ),
      ],
    ];
  }

  List<Widget> _buildOtherAddressFields(
    BuildContext context,
    PayeesState state,
  ) {
    final fields = <Widget>[];

    if (_draftType == 1) {
      final countries = ref.watch(paymentCountriesProvider).valueOrNull ??
          const <PaymentCountry>[];
      fields.addAll([
        _dropdown<PaymentCountry>(
          label: 'Country',
          hint: 'Please Select',
          value: countries.any((e) => e.code == _otherAddressCountry)
              ? countries.firstWhere((e) => e.code == _otherAddressCountry)
              : null,
          items: countries,
          itemLabel: (e) => e.name,
          onChanged: (value) =>
              setState(() => _otherAddressCountry = value?.code),
        ),
        const SizedBox(height: AppSpacing.lg),
      ]);
    }

    fields.addAll([
      _field(
        controller: _otherAddressLine1,
        label: 'Address Line 1',
        validator: _required,
      ),
      const SizedBox(height: AppSpacing.lg),
      _field(
        controller: _otherAddressLine2,
        label: 'Address Line 2',
        validator: _required,
      ),
      const SizedBox(height: AppSpacing.lg),
      _field(
        controller: _otherCity,
        label: 'City',
        validator: _required,
      ),
      const SizedBox(height: AppSpacing.lg),
      _field(
        controller: _otherState,
        label: 'State',
        validator: _required,
      ),
      const SizedBox(height: AppSpacing.lg),
      _field(
        controller: _otherZipCode,
        label: 'Zip Code',
        validator: _required,
      ),
    ]);

    return fields;
  }

  Widget _radioOption<T>({
    required String label,
    required T value,
    required T groupValue,
    required ValueChanged<T?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<T>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
    String? hint,
    bool searchable = false,
  }) {
    if (!searchable) {
      return DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, hintText: hint),
        items: items
            .map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: items.isEmpty ? null : onChanged,
      );
    }

    // Searchable variant, used for the International "Draft Payable At"
    // country list — matches the captured search-in-dropdown behaviour.
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: items.isEmpty
          ? null
          : () async {
              final selected = await _showSearchablePicker<T>(
                context: context,
                title: label,
                items: items,
                itemLabel: itemLabel,
              );
              if (selected != null) onChanged(selected);
            },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, hintText: hint ?? 'Select'),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value != null ? itemLabel(value) : (hint ?? 'Select'),
                overflow: TextOverflow.ellipsis,
                style: value == null
                    ? TextStyle(color: HomeColors.textSecondary(context))
                    : null,
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }

  Future<T?> _showSearchablePicker<T>({
    required BuildContext context,
    required String title,
    required List<T> items,
    required String Function(T) itemLabel,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        var query = '';
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final filtered = query.isEmpty
                ? items
                : items
                    .where((e) =>
                        itemLabel(e).toLowerCase().contains(query.toLowerCase()))
                    .toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.of(sheetContext).size.height * 0.7,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: TextField(
                          autofocus: true,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search_rounded),
                            hintText: 'Search',
                          ),
                          onChanged: (value) =>
                              setSheetState(() => query = value),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return ListTile(
                              title: Text(itemLabel(item)),
                              onTap: () =>
                                  Navigator.of(sheetContext).pop(item),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
        const SizedBox(width: AppSpacing.md),
        OutlinedButton(
          onPressed: _submitting ? null : _handleBack,
          child: const Text('Cancel'),
        ),
        const SizedBox(width: AppSpacing.md),
        TextButton(
          onPressed: _submitting ? null : _handleBack,
          child: const Text('Back'),
        ),
      ],
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }
}

class _AddressPreview extends StatelessWidget {
  const _AddressPreview({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final textPrimary = HomeColors.textPrimary(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: HomeColors.surfaceSecondary(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Text(
              line,
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
            ),
        ],
      ),
    );
  }
}

class _DraftInfoPanel extends StatelessWidget {
  const _DraftInfoPanel();

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final textSecondary = HomeColors.textSecondary(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: brand.withValues(alpha: 0.1),
            child: Icon(Icons.receipt_long_rounded, color: brand, size: 34),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Transfer money faster than ever!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Transferring money towards payees is easy and quick.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, height: 1.45),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Perform a one-time Payee addition maintenance and simply select the payee while transferring funds.',
            textAlign: TextAlign.left,
            style: TextStyle(color: textSecondary, height: 1.45),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'The payee details will be listed on the screen for verification and all you have to do is enter the amount and date of transfer to initiate the transfer.',
            textAlign: TextAlign.left,
            style: TextStyle(color: textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }
}
