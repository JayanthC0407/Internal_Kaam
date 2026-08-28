import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/payee/payee_models.dart';
import 'package:ubci_bank/src/core/theme/app_radius.dart';
import 'package:ubci_bank/src/core/theme/app_spacing.dart';
import 'package:ubci_bank/src/core/utils/email_validator.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/providers/payee_providers.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

class AddBankAccountPayeeScreen extends ConsumerStatefulWidget {
  const AddBankAccountPayeeScreen({
    super.key,
    this.embedded = false,
    this.onBack,
    this.onCompleted,
  });

  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onCompleted;

  @override
  ConsumerState<AddBankAccountPayeeScreen> createState() =>
      _AddBankAccountPayeeScreenState();
}

class _AddBankAccountPayeeScreenState
    extends ConsumerState<AddBankAccountPayeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountNumber = TextEditingController();
  final _confirmAccountNumber = TextEditingController();
  final _accountName = TextEditingController();
  final _payeeEmail = TextEditingController();
  final _ifscCode = TextEditingController();
  final _nickname = TextEditingController();

  int _selectedType = 0; // 0 Internal, 1 Domestic, 2 International.
  String? _selectedNetwork;
  String? _selectedAccountType;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(payeesProvider.notifier).ensureLoaded();
    });
  }

  @override
  void dispose() {
    _accountNumber.dispose();
    _confirmAccountNumber.dispose();
    _accountName.dispose();
    _payeeEmail.dispose();
    _ifscCode.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedType != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The supplied API capture does not include the final Domestic/International submit endpoint yet.',
          ),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(payeesProvider.notifier).createInternalPayee(
          nickname: _nickname.text.trim(),
          accountNumber: _accountNumber.text.trim(),
          accountName: _accountName.text.trim(),
          payeeEmail: _payeeEmail.text.trim(),
        );

    if (!mounted) return;
    final state = ref.read(payeesProvider);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payee validated successfully.')),
      );
      if (widget.embedded) {
        widget.onCompleted?.call();
      } else {
        Navigator.of(context).pop(true);
      }
      return;
    }

    if (state.submitError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.submitError!)),
      );
    }
  }

  Future<void> _uploadPhoto() async {
    // The captured API exposes upload constraints through payeecontent, but
    // the supplied source does not contain the actual multipart upload API.
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
                            const Expanded(flex: 4, child: _InfoPanel()),
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
            // Back navigation for embedded mode
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

            // Existing screen content
            Expanded(
              child: body,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      appBar: AppBar(
        title: const Text('Add Bank Account Payee'),
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
      _buildPhotoSection(context),
      const SizedBox(height: AppSpacing.lg),
      _buildPayeeTypeTabs(context),
      const SizedBox(height: AppSpacing.xl),
      if (_selectedType == 0) ..._buildInternalFields(context),
      if (_selectedType == 1) ..._buildDomesticFields(context, state),
      if (_selectedType == 2) const _InternationalPlaceholder(),
      const SizedBox(height: AppSpacing.xxxl),
      _buildActions(context, state),
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

  Widget _buildPayeeTypeTabs(BuildContext context) {
    final brand = HomeColors.brand(context);
    final divider = HomeColors.divider(context);
    final labels = const ['Internal', 'Domestic', 'International'];
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
                onTap: () => setState(() => _selectedType = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedType == i
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
                        color: _selectedType == i
                            ? brand
                            : HomeColors.textSecondary(context),
                        fontWeight: _selectedType == i
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

  List<Widget> _buildInternalFields(BuildContext context) {
    return [
      _field(
        controller: _accountNumber,
        label: 'Account Number',
        keyboardType: TextInputType.number,
        validator: _required,
      ),
      const SizedBox(height: AppSpacing.lg),
      _field(
        controller: _confirmAccountNumber,
        label: 'Confirm Account Number',
        keyboardType: TextInputType.number,
        validator: (value) {
          final required = _required(value);
          if (required != null) return required;
          if (value != _accountNumber.text) return 'Account numbers do not match';
          return null;
        },
      ),
      const SizedBox(height: AppSpacing.lg),
      _field(
        controller: _accountName,
        label: 'Account Name',
        validator: _required,
      ),
      const SizedBox(height: AppSpacing.lg),
      _field(
        controller: _payeeEmail,
        label: 'Payee Email ID',
        keyboardType: TextInputType.emailAddress,
        validator: (value) {
          final required = _required(value);
          if (required != null) return required;
          if (!EmailValidator.isValid(value!.trim())) return 'Enter a valid email';
          return null;
        },
      ),
      const SizedBox(height: AppSpacing.lg),
      _field(
        controller: _nickname,
        label: 'Nickname',
        validator: _required,
      ),
    ];
  }

  List<Widget> _buildDomesticFields(
    BuildContext context,
    PayeesState state,
  ) {
    final networks = state.domesticNetworks;
    final accountTypes = state.accountTypes;
    return [
      _dropdown<DomesticNetworkOption>(
        label: 'Network Type',
        value: networks.any((e) => e.code == _selectedNetwork)
            ? networks.firstWhere((e) => e.code == _selectedNetwork)
            : null,
        items: networks,
        itemLabel: (e) => e.code,
        onChanged: (value) => setState(() => _selectedNetwork = value?.code),
      ),
      const SizedBox(height: AppSpacing.lg),
      _dropdown<PayeeAccountTypeOption>(
        label: 'Account Type',
        value: accountTypes.any((e) => e.code == _selectedAccountType)
            ? accountTypes.firstWhere((e) => e.code == _selectedAccountType)
            : null,
        items: accountTypes,
        itemLabel: (e) => e.description,
        onChanged: (value) =>
            setState(() => _selectedAccountType = value?.code),
      ),
      const SizedBox(height: AppSpacing.lg),
      _field(
        controller: _accountNumber,
        label: 'Account Number',
        keyboardType: TextInputType.number,
        validator: _required,
      ),
      const SizedBox(height: AppSpacing.lg),
      _field(
        controller: _confirmAccountNumber,
        label: 'Confirm Account Number',
        keyboardType: TextInputType.number,
        validator: (value) {
          final required = _required(value);
          if (required != null) return required;
          if (value != _accountNumber.text) return 'Account numbers do not match';
          return null;
        },
      ),
      const SizedBox(height: AppSpacing.lg),
      _field(
        controller: _accountName,
        label: 'Account Name',
        validator: _required,
      ),
      const SizedBox(height: AppSpacing.lg),
      _field(
        controller: _payeeEmail,
        label: 'Payee Email ID',
        keyboardType: TextInputType.emailAddress,
        validator: (value) {
          final required = _required(value);
          if (required != null) return required;
          if (!EmailValidator.isValid(value!.trim())) return 'Enter a valid email';
          return null;
        },
      ),
      const SizedBox(height: AppSpacing.lg),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _field(
              controller: _ifscCode,
              label: 'IFSC Code',
              textCapitalization: TextCapitalization.characters,
              validator: _required,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('IFSC verification endpoint was not included in the supplied capture.'),
                ),
              ),
              child: const Text('Verify'),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      TextButton(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('IFSC lookup endpoint was not included in the supplied capture.'),
          ),
        ),
        style: TextButton.styleFrom(alignment: Alignment.centerLeft),
        child: const Text('Lookup IFSC Code'),
      ),
      _field(
        controller: _nickname,
        label: 'Nickname',
        validator: _required,
      ),
    ];
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
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(itemLabel(item)),
            ),
          )
          .toList(),
      onChanged: items.isEmpty ? null : onChanged,
    );
  }

  Widget _buildActions(BuildContext context, PayeesState state) {
    return Row(
      children: [
        FilledButton(
          onPressed: state.isSubmitting ? null : _submit,
          child: state.isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
        const SizedBox(width: AppSpacing.md),
        OutlinedButton(
          onPressed: state.isSubmitting
              ? null
              : _handleBack,
          child: const Text('Cancel'),
        ),
        const SizedBox(width: AppSpacing.md),
        TextButton(
          onPressed: state.isSubmitting
              ? null
              : _handleBack,
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

class _InfoPanel extends StatelessWidget {
  const _InfoPanel();

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
            child: Icon(Icons.account_balance_rounded, color: brand, size: 34),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Transfer money faster than ever!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Set up a payee to make transferring money easy and quick.',
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
            'You can also edit the payee at any time by selecting the edit option provided on the payee details screen.',
            textAlign: TextAlign.left,
            style: TextStyle(color: textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _InternationalPlaceholder extends StatelessWidget {
  const _InternationalPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: HomeColors.surfaceSecondary(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Text(
        'International Payee UI/API fields were not part of the supplied capture. This tab is intentionally left unimplemented rather than inventing an API contract.',
      ),
    );
  }
}
