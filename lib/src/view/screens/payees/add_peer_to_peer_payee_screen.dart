import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/theme/app_radius.dart';
import 'package:ubci_bank/src/core/theme/app_spacing.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/providers/payee_providers.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// Add Peer To Peer Payee, matching the captured "Peer To Peer Payee" screen.
///
/// The supplied API capture does not contain a Peer To Peer payee submit
/// endpoint, so — as with the Domestic/International tabs on Add Bank
/// Account Payee — this screen builds the full captured UI/validation and
/// surfaces a clear message on submit rather than inventing an API contract.
class AddPeerToPeerPayeeScreen extends ConsumerStatefulWidget {
  const AddPeerToPeerPayeeScreen({
    super.key,
    this.embedded = false,
    this.onBack,
    this.onCompleted,
  });

  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onCompleted;

  @override
  ConsumerState<AddPeerToPeerPayeeScreen> createState() =>
      _AddPeerToPeerPayeeScreenState();
}

class _AddPeerToPeerPayeeScreenState
    extends ConsumerState<AddPeerToPeerPayeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _payeeName = TextEditingController();
  final _emailOrMobile = TextEditingController();
  final _nickname = TextEditingController();

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
    _emailOrMobile.dispose();
    _nickname.dispose();
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

  Future<void> _add() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() => _submitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'The supplied API capture does not include a Peer To Peer payee submit endpoint yet.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);

    final form = Form(
      key: _formKey,
      child: _buildForm(context, responsive),
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
                          const Expanded(flex: 4, child: _P2PInfoPanel()),
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
        title: const Text('Peer To Peer Payee'),
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

  Widget _buildForm(BuildContext context, Responsive responsive) {
    final content = [
      _field(controller: _payeeName, label: 'Payee Name'),
      const SizedBox(height: AppSpacing.lg),
      _buildPhotoSection(context),
      const SizedBox(height: AppSpacing.lg),
      _field(
        controller: _emailOrMobile,
        label: 'Email / Mobile',
        keyboardType: TextInputType.text,
        validator: _required,
      ),
      const SizedBox(height: AppSpacing.lg),
      _field(
        controller: _nickname,
        label: 'Nickname',
        validator: _required,
      ),
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        FilledButton.icon(
          onPressed: _submitting ? null : _add,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_circle_outline_rounded),
          label: const Text('Add'),
        ),
        const SizedBox(width: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: _submitting ? null : _handleBack,
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Cancel'),
        ),
      ],
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }
}

class _P2PInfoPanel extends StatelessWidget {
  const _P2PInfoPanel();

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
            child: Icon(Icons.people_alt_rounded, color: brand, size: 34),
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
