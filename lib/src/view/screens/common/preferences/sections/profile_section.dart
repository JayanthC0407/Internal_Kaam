import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/preferences/preferences_models.dart';
import 'package:ubci_bank/src/core/utils/common/statement_file_saver.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/view/providers/common/preferences_providers.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/widgets/preferences_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// Preferences → Profile (OBDX `base-components-profile`, retail): the
/// name with Download, "Personal Information" (Date of Birth and the
/// `profileConfig` personal fields) and "Contact Information". Fields the
/// bank marks `editable` get an Edit button that opens "Update Profile";
/// Save sends `PUT me/party {attr_name, attr_value}` and shows the green
/// confirmation bar.
class ProfileSection extends ConsumerStatefulWidget {
  const ProfileSection({super.key});

  @override
  ConsumerState<ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends ConsumerState<ProfileSection> {
  String? _confirmation;
  bool _downloading = false;

  Future<void> _download() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _downloading = true);
    final result = await ref.read(preferencesRepositoryProvider).downloadProfileCsv();
    if (!mounted) return;
    setState(() => _downloading = false);
    if (result is Success<List<int>> && result.data != null) {
      try {
        await StatementFileSaver.saveStatement(bytes: result.data!, fileName: 'profile.csv', mimeType: 'text/csv');
      } catch (_) {
        if (mounted) prefSnack(context, l10n.prefDownloadFailed);
      }
    } else {
      prefSnack(context, l10n.prefDownloadFailed);
    }
  }

  Future<void> _edit(PartyProfile profile, ProfileFieldConfig field) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _confirmation = null);
    final saved = await showPrefPanel<bool>(
      context,
      title: l10n.prefUpdateProfile,
      builder: (_) => _ProfileEditor(profile: profile, field: field),
    );
    if (saved != true || !mounted) return;
    ref.invalidate(partyProfileProvider);
    setState(() => _confirmation = field.fieldName == 'EMAIL' ? l10n.prefEmailUpdated : l10n.prefProfileUpdated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ref.watch(partyProfileProvider).when(
          loading: () => const PrefLoading(),
          error: (e, _) => PrefFailed(error: e, onRetry: () => ref.invalidate(partyProfileProvider)),
          data: (profile) {
            List<Widget> rows(List<ProfileFieldConfig> fields) => [
                  for (final (i, f) in fields.indexed)
                    PrefLabelValue(
                      label: f.label,
                      value: profile.valueOf(f.fieldName),
                      last: i == fields.length - 1,
                      editTooltip: l10n.prefEditField(f.label),
                      onEdit: f.editable ? () => _edit(profile, f) : null,
                    ),
                ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_confirmation != null) ...[
                  PrefSuccessBar(message: _confirmation!, onClose: () => setState(() => _confirmation = null)),
                  const SizedBox(height: 14),
                ],
                PayCard(
                  padding: 16,
                  child: Row(
                    children: [
                      PayAvatar(name: profile.displayName, size: 52),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          profile.displayName,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _downloading ? null : _download,
                        icon: _downloading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.download_rounded, size: 18),
                        label: Text(l10n.prefDownload),
                        style: TextButton.styleFrom(foregroundColor: HomeColors.brand(context)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PaySection(
                  title: l10n.prefPersonalInfo,
                  icon: Icons.badge_outlined,
                  child: Column(
                    children: [
                      PrefLabelValue(
                        label: l10n.prefDateOfBirth,
                        value: payDate(profile.birthDate),
                        last: profile.personalFields.isEmpty,
                      ),
                      ...rows(profile.personalFields),
                    ],
                  ),
                ),
                if (profile.contactFields.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  PaySection(
                    title: l10n.prefContactInfo,
                    icon: Icons.contact_mail_outlined,
                    child: Column(children: rows(profile.contactFields)),
                  ),
                ],
              ],
            );
          },
        );
  }
}

/// "Update Profile": the one field's form and Save. Pops `true` once saved.
class _ProfileEditor extends ConsumerStatefulWidget {
  const _ProfileEditor({required this.profile, required this.field});

  final PartyProfile profile;
  final ProfileFieldConfig field;

  @override
  ConsumerState<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends ConsumerState<_ProfileEditor> {
  final _value = TextEditingController();
  final _area = TextEditingController();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _line3 = TextEditingController();
  final _city = TextEditingController();
  final _zip = TextEditingController();
  String? _country;
  final _errors = <String, String?>{};
  bool _saving = false;

  String get _name => widget.field.fieldName;
  bool get _isAddress => _name == 'ADDRESS';
  bool get _isPhone => _name == 'PHONENO';
  bool get _isFax => _name == 'FAXNO';
  bool get _isd => (_isPhone && widget.profile.mobileIsd) || (_isFax && widget.profile.faxIsd);
  bool get _isId => widget.profile.isIdentification(_name);

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    if (_name == 'EMAIL') _value.text = p.email;
    if (_isAddress) {
      _line1.text = p.address.line1;
      _line2.text = p.address.line2;
      _line3.text = p.address.line3;
      _city.text = p.address.city;
      _zip.text = p.address.postalCode;
      _country = p.address.country.isEmpty ? null : p.address.country;
    }
  }

  @override
  void dispose() {
    for (final c in [_value, _area, _line1, _line2, _line3, _city, _zip]) {
      c.dispose();
    }
    super.dispose();
  }

  static final _digits = RegExp(r'^[0-9]*$');
  static final _email = RegExp(r'^(([^<>()[\]\\.,;:\s@"]+(\.[^<>()[\]\\.,;:\s@"]+)*)|(".+"))@(([^<>()[\]\.,;:\s@"]+\.)+[^<>()[\]\.,;:\s@"]{2,})$');
  static final _alnumSpecial = RegExp(r'''^[a-zA-Z0-9 .,\-/#'&()]*$''');
  static final _alnumSpace = RegExp(r'^[a-zA-Z0-9 ]*$');
  static final _alphaSpace = RegExp(r'^[a-zA-Z ]*$');

  /// OBDX's checks (profile panel validators and `save`); null when invalid.
  Object? _validate(AppLocalizations l10n) {
    _errors.clear();
    final value = _value.text.trim();
    if (_isAddress) {
      final l1 = _line1.text.trim(), l2 = _line2.text.trim(), l3 = _line3.text.trim();
      if (l1.isEmpty || l1.length > 30 || !_alnumSpecial.hasMatch(l1)) _errors['line1'] = l10n.prefInvalidAddress;
      if (l2.length > 30 || !_alnumSpace.hasMatch(l2)) _errors['line2'] = l10n.prefInvalidAddress;
      if (l3.length > 30 || !_alnumSpace.hasMatch(l3)) _errors['line3'] = l10n.prefInvalidAddress;
      if (!_alphaSpace.hasMatch(_city.text.trim())) _errors['city'] = l10n.prefInvalidCity;
      if (_zip.text.trim().length > 10 || !_digits.hasMatch(_zip.text.trim())) _errors['zip'] = l10n.prefInvalidZip;
      if (_errors.isNotEmpty) return null;
      return ProfileAddress(
        line1: l1,
        line2: l2,
        line3: l3,
        city: _city.text.trim(),
        country: _country ?? '',
        postalCode: _zip.text.trim(),
      );
    }
    if (_isPhone || _isFax) {
      final area = _area.text.trim();
      if (area.length > 6 || !_digits.hasMatch(area)) _errors['area'] = l10n.prefInvalidNumber;
      final validNumber = _digits.hasMatch(value) && (_isPhone ? value.length == 10 : value.isNotEmpty);
      if (!validNumber) _errors['value'] = _isPhone ? l10n.prefInvalidMobile : l10n.prefInvalidFax;
      if (_errors.isNotEmpty) return null;
      return _isd ? ProfilePhone(areaCode: area, number: value).toJson() : value;
    }
    if (_name == 'EMAIL') {
      if (!_email.hasMatch(value)) _errors['value'] = l10n.prefInvalidEmail;
      return _errors.isEmpty ? value : null;
    }
    if (_isId) {
      if (value.isEmpty) {
        _errors['value'] = l10n.prefInvalidId(widget.field.label);
      } else if (value.length > 20) {
        _errors['value'] = l10n.prefIdTooLong(widget.field.label);
      }
      return _errors.isEmpty ? value : null;
    }
    if (value.isEmpty) _errors['value'] = l10n.prefInvalidId(widget.field.label);
    return _errors.isEmpty ? value : null;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final value = _validate(l10n);
    setState(() {});
    if (value == null) return;
    // OBDX does not send an unchanged address.
    if (value is ProfileAddress && value.sameAs(widget.profile.address)) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(preferencesRepositoryProvider);
    final payload = value is ProfileAddress ? value.toJson() : value;
    final result = await runPrefWrite(context, (c, otp) => repo.updateProfileField(_name, payload, challenge: c, otp: otp));
    if (!mounted) return;
    setState(() => _saving = false);
    if (prefWriteDone(result)) {
      Navigator.of(context).pop(true);
    } else {
      final error = prefWriteError(context, result);
      if (error != null) prefSnack(context, error);
    }
  }

  Future<void> _pickCountry(List<ProfileCountry> countries) async {
    final picked = await showPayPicker<String>(
      context,
      title: AppLocalizations.of(context).prefCountry,
      selected: _country,
      options: [for (final c in countries) PayOption(value: c.code, title: c.name)],
    );
    if (picked != null && mounted) setState(() => _country = picked);
  }

  Widget _field(String label, TextEditingController c, String key,
          {TextInputType? keyboard, int? maxLength, bool digitsOnly = false, bool required = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: PayTextField(
          label: label,
          controller: c,
          required: required,
          error: _errors[key],
          keyboardType: keyboard,
          inputFormatters: [
            if (digitsOnly) FilteringTextInputFormatter.digitsOnly,
            if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final children = <Widget>[];
    if (_isAddress) {
      final countries = ref.watch(profileCountriesProvider);
      final list = countries.valueOrNull ?? const <ProfileCountry>[];
      final countryName = list.where((c) => c.code.toUpperCase() == (_country ?? '').toUpperCase()).firstOrNull?.name ?? _country;
      children.addAll([
        _field(l10n.prefLine1, _line1, 'line1', maxLength: 30, required: true),
        _field(l10n.prefLine2, _line2, 'line2', maxLength: 30),
        _field(l10n.prefLine3, _line3, 'line3', maxLength: 30),
        _field(l10n.prefCity, _city, 'city'),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PayFieldLabel(l10n.prefCountry),
              PayPickerField(
                placeholder: l10n.prefSelectCountry,
                title: countryName,
                loading: countries.isLoading,
                icon: Icons.public_rounded,
                onTap: list.isEmpty ? null : () => _pickCountry(list),
              ),
            ],
          ),
        ),
        _field(l10n.prefZipCode, _zip, 'zip', keyboard: TextInputType.number, maxLength: 10, digitsOnly: true),
      ]);
    } else if (_isPhone || _isFax) {
      if (_isd) {
        children.add(_field(l10n.prefAreaCode, _area, 'area', keyboard: TextInputType.phone, maxLength: 6, digitsOnly: true));
      }
      children.add(_field(_isd ? l10n.prefNumber : widget.field.label, _value, 'value',
          keyboard: TextInputType.phone, maxLength: _isPhone ? 10 : null, digitsOnly: true, required: true));
    } else {
      children.add(_field(
        _isId ? l10n.prefContactAttribute : widget.field.label,
        _value,
        'value',
        keyboard: _name == 'EMAIL' ? TextInputType.emailAddress : null,
        required: true,
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            widget.field.label,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
          ),
        ),
        ...children,
        const SizedBox(height: 6),
        PayPrimaryButton(label: l10n.prefSave, loading: _saving, onPressed: _save),
      ],
    );
  }
}
