import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/preferences/preferences_models.dart';
import 'package:ubci_bank/src/core/models/common/service_requests/service_request_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/providers/common/service_requests_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/widgets/preferences_widgets.dart';
import 'package:ubci_bank/src/view/screens/common/service_requests/track_requests_views.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

// ── Choosing a request (service-requests-base-main) ──────────────────────

/// "Service Request Form": search every request by name, OR pick a
/// Product, then a request under one of its categories.
class SrCatalogView extends ConsumerStatefulWidget {
  const SrCatalogView({super.key, required this.onPick});

  final ValueChanged<SrDefinition> onPick;

  @override
  ConsumerState<SrCatalogView> createState() => _SrCatalogViewState();
}

class _SrCatalogViewState extends ConsumerState<SrCatalogView> {
  String? _product;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ref.watch(srDefinitionsProvider).when(
          loading: () => const SrLoading(),
          error: (e, _) => SrFailed(error: e, onRetry: () => ref.invalidate(srDefinitionsProvider)),
          data: (definitions) {
            if (definitions.isEmpty) return PayCard(child: PayMuted(l10n.srNoDefinitions));
            final products = {for (final d in definitions) d.product}.where((p) => p.isNotEmpty).toList()..sort();
            final product = products.contains(_product) ? _product! : products.first;
            return LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 700;
                final productList = _ProductList(
                  products: products,
                  selected: product,
                  vertical: wide,
                  onSelect: (p) => setState(() => _product = p),
                );
                final categories = _Categories(
                  product: product,
                  definitions: [
                    for (final d in definitions)
                      if (d.product == product) d
                  ],
                  onPick: widget.onPick,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PaySection(
                      title: l10n.srServiceRequestForm,
                      icon: Icons.search_rounded,
                      child: _Search(definitions: definitions, onPick: widget.onPick),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: HomeColors.divider(context))),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: HomeColors.card(context),
                              border: Border.all(color: HomeColors.divider(context)),
                            ),
                            child: Text(
                              l10n.srOr,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: HomeColors.textSecondary(context)),
                            ),
                          ),
                          Expanded(child: Divider(color: HomeColors.divider(context))),
                        ],
                      ),
                    ),
                    PaySection(
                      title: l10n.srOrganizedByProduct,
                      icon: Icons.category_outlined,
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 220, child: productList),
                                const SizedBox(width: 20),
                                Expanded(child: categories),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [productList, const SizedBox(height: 12), categories],
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
  }
}

class _Search extends StatelessWidget {
  const _Search({required this.definitions, required this.onPick});

  final List<SrDefinition> definitions;
  final ValueChanged<SrDefinition> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Autocomplete<SrDefinition>(
      displayStringForOption: (d) => d.name,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<SrDefinition>.empty();
        return definitions.where((d) => d.name.toLowerCase().contains(q));
      },
      onSelected: onPick,
      fieldViewBuilder: (context, controller, focus, submit) => TextField(
        controller: controller,
        focusNode: focus,
        onSubmitted: (_) => submit(),
        decoration: payInputDecoration(
          context,
          hint: l10n.srSearchHint,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Icon(Icons.search_rounded, color: HomeColors.textSecondary(context)),
          ),
        ),
      ),
      optionsViewBuilder: (context, select, options) => Align(
        alignment: AlignmentDirectional.topStart,
        child: Material(
          color: HomeColors.card(context),
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280, maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              shrinkWrap: true,
              children: [
                for (final d in options)
                  ListTile(
                    dense: true,
                    title: Text(d.name, style: TextStyle(color: HomeColors.textPrimary(context))),
                    subtitle: Text(d.product, style: TextStyle(color: HomeColors.textSecondary(context))),
                    onTap: () => select(d),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// OBDX's "Products" nav-bar: vertical beside the categories on wide
/// layouts, a row of chips on a phone.
class _ProductList extends StatelessWidget {
  const _ProductList({required this.products, required this.selected, required this.vertical, required this.onSelect});

  final List<String> products;
  final String selected;
  final bool vertical;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final l10n = AppLocalizations.of(context);
    if (!vertical) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (i, p) in products.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              ChoiceChip(
                label: Text(p),
                selected: p == selected,
                showCheckmark: false,
                selectedColor: brand.withValues(alpha: 0.14),
                side: BorderSide(color: p == selected ? brand : HomeColors.divider(context)),
                labelStyle: TextStyle(
                  fontWeight: p == selected ? FontWeight.w700 : FontWeight.w500,
                  color: p == selected ? brand : HomeColors.textPrimary(context),
                ),
                onSelected: (_) => onSelect(p),
              ),
            ],
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PayFieldLabel(l10n.srProducts),
        for (final p in products)
          Material(
            color: p == selected ? brand.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: ListTile(
              dense: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              title: Text(
                p,
                style: TextStyle(
                  fontWeight: p == selected ? FontWeight.w700 : FontWeight.w500,
                  color: p == selected ? brand : HomeColors.textPrimary(context),
                ),
              ),
              onTap: () => onSelect(p),
            ),
          ),
      ],
    );
  }
}

/// One collapsible per category that has requests, each listing them.
class _Categories extends ConsumerWidget {
  const _Categories({required this.product, required this.definitions, required this.onPick});

  final String product;
  final List<SrDefinition> definitions;
  final ValueChanged<SrDefinition> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(srCategoriesProvider(product)).valueOrNull ?? const <SrCategory>[];
    String nameOf(String type) => names.where((c) => c.id == type || c.name == type).firstOrNull?.name ?? type;
    final byCategory = <String, List<SrDefinition>>{};
    for (final d in definitions) {
      byCategory.putIfAbsent(d.categoryType, () => []).add(d);
    }
    final keys = byCategory.keys.toList()..sort((a, b) => nameOf(a).compareTo(nameOf(b)));
    // Its own Material: the tiles' ink would hide under the card otherwise.
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, key) in keys.indexed)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: PageStorageKey('$product/$key'),
                initiallyExpanded: i == 0,
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                iconColor: HomeColors.brand(context),
                collapsedIconColor: HomeColors.textSecondary(context),
                title: Text(
                  nameOf(key).isEmpty ? '—' : nameOf(key),
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
                ),
                children: [
                  for (final d in byCategory[key]!)
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.description_outlined, color: HomeColors.brand(context), size: 20),
                      title: Text(d.name, style: TextStyle(fontSize: 14, color: HomeColors.textPrimary(context))),
                      trailing: Icon(Icons.chevron_right_rounded, color: HomeColors.navInactive(context)),
                      onTap: () => onPick(d),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── The request's form (service-requests-base-form) ──────────────────────

/// The bank-built form of one request. Submit checks it and goes to Review
/// with the answers.
class SrFormView extends ConsumerStatefulWidget {
  const SrFormView({
    super.key,
    required this.definitionId,
    required this.answers,
    required this.wide,
    required this.onCancel,
    required this.onReview,
  });

  final String definitionId;

  /// Answers from an earlier visit (Review → Back).
  final Map<String, SrAnswer> answers;
  final bool wide;
  final VoidCallback onCancel;
  final void Function(SrDefinition definition, Map<String, SrAnswer> answers) onReview;

  @override
  ConsumerState<SrFormView> createState() => _SrFormViewState();
}

class _SrFormViewState extends ConsumerState<SrFormView> {
  late final Map<String, SrAnswer> _answers = Map.of(widget.answers);
  final _text = <String, TextEditingController>{};
  final _errors = <String, String?>{};
  final _uploading = <String>{};

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(SrField f) => _text.putIfAbsent(
        f.name,
        () => TextEditingController(text: _answers[f.name]?.values.firstOrNull ?? ''),
      );

  void _set(SrField f, SrAnswer answer) => setState(() {
        _answers[f.name] = answer;
        _errors[f.name] = null;
      });

  static final _patterns = <String, RegExp>{
    'ALPHABETS': RegExp(r'^[a-zA-Z]*$'),
    'NUMBERS': RegExp(r'^[0-9]*$'),
    'ALPHANUMERIC': RegExp(r'^[a-zA-Z0-9]*$'),
    'ALPHANUMERIC_WITH_SPACE': RegExp(r'^[a-zA-Z0-9 ]*$'),
    'ALPHANUMERIC_WITH_SOME_SPECIAL': RegExp(r'''^[a-zA-Z0-9 .,\-/'&()#@:]*$'''),
  };

  /// Every field's check (OBDX validators plus `mandatory`); true when the
  /// form can go to Review.
  bool _validate(SrForm form) {
    final l10n = AppLocalizations.of(context);
    var ok = true;
    for (final f in form.fields) {
      final type = f.type;
      if (type == null || type.isHeader) continue;
      if (type == SrFieldType.textBox) {
        final text = _controller(f).text.trim();
        _answers[f.name] = SrAnswer(values: [text], displayValues: [text]);
      }
      final answer = _answers[f.name] ?? SrAnswer.empty;
      String? error;
      final required = f.errorMessage ?? l10n.srRequired;
      if (f.mandatory && answer.isEmpty) {
        error = required;
      } else if (f.mandatory && type == SrFieldType.accountDebitCard && answer.values.length < 2) {
        error = required;
      } else if (type == SrFieldType.textBox && !answer.isEmpty) {
        final text = answer.values.first;
        final pattern = _patterns[f.validationType];
        if ((f.minLength != null && text.length < f.minLength!) ||
            (f.maxLength != null && f.maxLength! > 0 && text.length > f.maxLength!) ||
            (pattern != null && !pattern.hasMatch(text))) {
          error = f.errorMessage ?? l10n.srInvalidValue;
        }
      }
      _errors[f.name] = error;
      if (error != null) ok = false;
    }
    setState(() {});
    return ok;
  }

  Future<void> _pick(SrField f, String title, List<SrOption> options, {List<String>? indirection}) async {
    final picked = await showPayPicker<String>(
      context,
      title: title,
      selected: _answers[f.name]?.values.firstOrNull,
      options: [for (final o in options) PayOption(value: o.code, title: o.description)],
    );
    if (picked == null || !mounted) return;
    final o = options.firstWhere((o) => o.code == picked);
    _set(f, SrAnswer(values: [o.code], displayValues: [o.description], indirectionTypes: indirection));
  }

  Future<void> _upload(SrField f) async {
    final l10n = AppLocalizations.of(context);
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf', 'zip'],
        withData: true,
      );
    } on PlatformException {
      result = await FilePicker.pickFiles(withData: true);
    } catch (_) {
      result = null;
    }
    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null || !mounted) return;
    final ext = file.name.split('.').last.toLowerCase();
    if (!const ['jpg', 'jpeg', 'png', 'pdf', 'zip'].contains(ext)) {
      setState(() => _errors[f.name] = l10n.srFileType);
      return;
    }
    final mime = switch (ext) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'zip' => 'application/zip',
      _ => 'image/jpeg',
    };
    setState(() => _uploading.add(f.name));
    final r = await ref.read(serviceRequestsRepositoryProvider).uploadAttachment(bytes: file.bytes!, fileName: file.name, mimeType: mime);
    if (!mounted) return;
    setState(() => _uploading.remove(f.name));
    if (r is Success<String> && r.data != null) {
      _set(f, SrAnswer(values: [r.data!], displayValues: [file.name], indirectionTypes: const ['File']));
    } else {
      setState(() => _errors[f.name] = (r is Error<String> ? r.error : null) ?? l10n.srUploadFailed);
    }
  }

  void _removeFile(SrField f) {
    final id = _answers[f.name]?.values.firstOrNull;
    if (id != null) ref.read(serviceRequestsRepositoryProvider).removeAttachment(id);
    _set(f, SrAnswer.empty);
  }

  Widget _field(SrField f) {
    final l10n = AppLocalizations.of(context);
    final type = f.type;
    final answer = _answers[f.name] ?? SrAnswer.empty;
    final error = _errors[f.name];
    final first = answer.displayValues.firstOrNull;

    Widget labelled(Widget child, {String? label}) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PayFieldLabel(label ?? f.label, required: f.mandatory),
            child,
            if (f.hint != null && type != SrFieldType.textBox)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(f.hint!, style: TextStyle(fontSize: 12, color: HomeColors.textSecondary(context))),
              ),
            PayFieldError(error),
          ],
        );

    Widget picker(String placeholder, AsyncValue<List<SrOption>> options, {List<String>? indirection}) => PayPickerField(
          placeholder: placeholder,
          title: first,
          dense: true,
          loading: options.isLoading,
          onTap: options.valueOrNull == null ? null : () => _pick(f, f.label, options.value!, indirection: indirection),
        );

    switch (type) {
      case null:
        return PayMuted('${f.label} (${f.typeCode})');
      case SrFieldType.sectionHeader:
      case SrFieldType.subHeader:
        return Padding(
          padding: EdgeInsets.only(top: type == SrFieldType.sectionHeader ? 8 : 0),
          child: Text(
            f.headerText,
            style: TextStyle(
              fontSize: type == SrFieldType.sectionHeader ? 16 : 14.5,
              fontWeight: FontWeight.w700,
              color: type == SrFieldType.sectionHeader ? HomeColors.brand(context) : HomeColors.textPrimary(context),
            ),
          ),
        );
      case SrFieldType.textBox:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PayTextField(
              label: f.label,
              controller: _controller(f),
              hint: f.hint,
              required: f.mandatory,
              error: error,
              keyboardType: f.validationType == 'NUMBERS' ? TextInputType.number : null,
              inputFormatters: [if (f.maxLength != null && f.maxLength! > 0) LengthLimitingTextInputFormatter(f.maxLength)],
              onChanged: (_) {
                if (_errors[f.name] != null) setState(() => _errors[f.name] = null);
              },
            ),
          ],
        );
      case SrFieldType.radio:
        return labelled(Column(
          children: [
            for (final o in f.options)
              PrefRadio<String>(
                value: o.code,
                group: answer.values.firstOrNull,
                label: o.description,
                onChanged: (_) => _set(f, SrAnswer(values: [o.code], displayValues: [o.description])),
              ),
          ],
        ));
      case SrFieldType.checkBoxes:
      case SrFieldType.multiSelect:
        return labelled(Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final o in f.options)
              FilterChip(
                label: Text(o.description),
                selected: answer.values.contains(o.code),
                selectedColor: HomeColors.brand(context).withValues(alpha: 0.14),
                checkmarkColor: HomeColors.brand(context),
                onSelected: (on) {
                  final picked = [
                    for (final x in f.options)
                      if (x.code == o.code ? on : answer.values.contains(x.code)) x
                  ];
                  _set(f, SrAnswer(values: [for (final x in picked) x.code], displayValues: [for (final x in picked) x.description]));
                },
              ),
          ],
        ));
      case SrFieldType.dropList:
        return labelled(picker(l10n.srSelectValue, AsyncValue.data(f.options)));
      case SrFieldType.toggle:
        final a = f.firstOption ?? '', b = f.secondOption ?? '';
        return labelled(PayChoiceChips<String>(
          options: [(a, a), (b, b)],
          selected: answer.values.firstOrNull ?? '',
          onChanged: (v) => _set(f, SrAnswer(values: [v], displayValues: [v])),
        ));
      case SrFieldType.fileUpload:
        return labelled(
          answer.isEmpty
              ? Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    onPressed: _uploading.contains(f.name) ? null : () => _upload(f),
                    icon: _uploading.contains(f.name)
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload_file_rounded, size: 18),
                    label: Text(l10n.srChooseFile),
                    style: OutlinedButton.styleFrom(foregroundColor: HomeColors.brand(context)),
                  ),
                )
              : Row(
                  children: [
                    Icon(Icons.attach_file_rounded, color: HomeColors.brand(context), size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text(first ?? '', style: TextStyle(color: HomeColors.textPrimary(context)))),
                    IconButton(
                      tooltip: l10n.srRemoveFile,
                      icon: Icon(Icons.delete_outline_rounded, color: HomeColors.error(context)),
                      onPressed: () => _removeFile(f),
                    ),
                  ],
                ),
          label: '${f.label} (${l10n.srFileTypes})',
        );
      case SrFieldType.account:
        final accounts = ref.watch(srAccountsProvider);
        return labelled(picker(
          l10n.srSelectAccount,
          accounts.whenData((list) => [for (final a in list) SrOption(code: a.value, description: a.displayValue)]),
          indirection: const ['Account'],
        ));
      case SrFieldType.accountDebitCard:
        final accounts = ref.watch(srAccountsProvider);
        final account = answer.values.firstOrNull;
        final cards = account == null ? null : ref.watch(srDebitCardsProvider(account));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PayFieldLabel(l10n.srAccountNumber, required: f.mandatory),
            PayPickerField(
              placeholder: l10n.srSelectAccount,
              title: first,
              dense: true,
              loading: accounts.isLoading,
              onTap: accounts.valueOrNull == null
                  ? null
                  : () async {
                      final list = accounts.value!;
                      final picked = await showPayPicker<String>(
                        context,
                        title: l10n.srAccountNumber,
                        selected: account,
                        options: [for (final a in list) PayOption(value: a.value, title: a.displayValue)],
                      );
                      if (picked == null || !mounted) return;
                      final a = list.firstWhere((x) => x.value == picked);
                      _set(f, SrAnswer(values: [a.value], displayValues: [a.displayValue], indirectionTypes: const ['Account', 'Debit']));
                    },
            ),
            const SizedBox(height: 12),
            PayFieldLabel(l10n.srDebitCard, required: f.mandatory),
            PayPickerField(
              placeholder: l10n.srSelectValue,
              title: answer.displayValues.length > 1 ? answer.displayValues[1] : null,
              dense: true,
              loading: cards?.isLoading ?? false,
              onTap: cards?.valueOrNull == null
                  ? null
                  : () async {
                      final list = cards!.value!;
                      final picked = await showPayPicker<String>(
                        context,
                        title: l10n.srDebitCard,
                        options: [for (final c in list) PayOption(value: c.code, title: c.description)],
                      );
                      if (picked == null || !mounted) return;
                      final c = list.firstWhere((x) => x.code == picked);
                      _set(
                        f,
                        SrAnswer(
                          values: [answer.values.first, c.code],
                          displayValues: [answer.displayValues.first, c.description],
                          indirectionTypes: const ['Account', 'Debit'],
                        ),
                      );
                    },
            ),
            PayFieldError(error),
          ],
        );
      case SrFieldType.gender:
        return labelled(picker(l10n.srSelectGender, ref.watch(srEnumerationProvider('gender'))));
      case SrFieldType.salutation:
        return labelled(picker(l10n.srSelectSalutation, ref.watch(srEnumerationProvider('salutation'))));
      case SrFieldType.countryState:
        final countries = ref.watch(srEnumerationProvider('country'));
        final country = answer.values.firstOrNull;
        final states = country == null ? null : ref.watch(srEnumerationProvider('country/${Uri.encodeComponent(country)}/state'));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PayFieldLabel(l10n.srCountry, required: f.mandatory),
            PayPickerField(
              placeholder: l10n.srSelectValue,
              title: first,
              dense: true,
              loading: countries.isLoading,
              onTap: countries.valueOrNull == null
                  ? null
                  : () async {
                      final list = countries.value!;
                      final picked = await showPayPicker<String>(
                        context,
                        title: l10n.srCountry,
                        selected: country,
                        options: [for (final c in list) PayOption(value: c.code, title: c.description)],
                      );
                      if (picked == null || !mounted) return;
                      final c = list.firstWhere((x) => x.code == picked);
                      _set(f, SrAnswer(values: [c.code], displayValues: [c.description]));
                    },
            ),
            const SizedBox(height: 12),
            PayFieldLabel(l10n.srState),
            PayPickerField(
              placeholder: l10n.srSelectValue,
              title: answer.displayValues.length > 1 ? answer.displayValues[1] : null,
              dense: true,
              loading: states?.isLoading ?? false,
              onTap: states?.valueOrNull == null || states!.value!.isEmpty
                  ? null
                  : () async {
                      final list = states.value!;
                      final picked = await showPayPicker<String>(
                        context,
                        title: l10n.srState,
                        options: [for (final s in list) PayOption(value: s.code, title: s.description)],
                      );
                      if (picked == null || !mounted) return;
                      final s = list.firstWhere((x) => x.code == picked);
                      _set(f, SrAnswer(values: [answer.values.first, s.code], displayValues: [answer.displayValues.first, s.description]));
                    },
            ),
            PayFieldError(error),
          ],
        );
      case SrFieldType.date:
        final value = DateTime.tryParse(answer.values.firstOrNull ?? '');
        return labelled(PayDateField(
          value: value,
          placeholder: l10n.srPleaseSelect,
          first: DateTime(1900),
          last: DateTime(DateTime.now().year + 20),
          onChanged: (d) => _set(
            f,
            SrAnswer(
              values: ['${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'],
              displayValues: [payDate(d)],
            ),
          ),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ref.watch(srDefinitionProvider(widget.definitionId)).when(
          loading: () => const SrLoading(),
          error: (e, _) => SrFailed(error: e, onRetry: () => ref.invalidate(srDefinitionProvider(widget.definitionId))),
          data: (definition) {
            final form = definition.form;
            if (form == null || form.fields.isEmpty) return PayCard(child: PayMuted(l10n.srNoDefinitions));
            final fields = PaySection(
              title: form.header ?? definition.name,
              icon: Icons.edit_note_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, f) in form.fields.indexed) ...[if (i > 0) const SizedBox(height: 16), _field(f)],
                ],
              ),
            );
            final note = (form.infoHeader ?? form.infoDescription) == null
                ? null
                : PaySection(
                    title: form.infoHeader ?? l10n.srInformation,
                    icon: Icons.info_outline_rounded,
                    child: Text(
                      form.infoDescription ?? '',
                      style: TextStyle(fontSize: 13, color: HomeColors.textSecondary(context)),
                    ),
                  );
            final actions = PrefActions(children: [
              PayPrimaryButton(
                label: l10n.prefSubmit,
                onPressed: _uploading.isNotEmpty
                    ? null
                    : () {
                        if (_validate(form)) widget.onReview(definition, Map.of(_answers));
                      },
              ),
              PaySecondaryButton(label: l10n.prefCancel, onPressed: widget.onCancel),
            ]);
            if (widget.wide && note != null) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [fields, const SizedBox(height: 16), actions],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(child: note),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (note != null) ...[note, const SizedBox(height: 14)],
                fields,
                const SizedBox(height: 16),
                actions,
              ],
            );
          },
        );
  }
}

// ── Review and Confirm (service-requests-verify) ─────────────────────────

class SrReviewView extends ConsumerStatefulWidget {
  const SrReviewView({
    super.key,
    required this.submission,
    required this.onBack,
    required this.onCancel,
    required this.onSubmitted,
  });

  final SrSubmission submission;
  final VoidCallback onBack;
  final VoidCallback onCancel;

  /// The reference, and whether it went for approval.
  final void Function(String? reference, bool pendingApproval) onSubmitted;

  @override
  ConsumerState<SrReviewView> createState() => _SrReviewViewState();
}

class _SrReviewViewState extends ConsumerState<SrReviewView> {
  bool _saving = false;

  Future<void> _confirm() async {
    setState(() => _saving = true);
    final repo = ref.read(serviceRequestsRepositoryProvider);
    final result = await runPrefWrite(context, (c, otp) => repo.submit(widget.submission, challenge: c, otp: otp));
    if (!mounted) return;
    setState(() => _saving = false);
    if (prefWriteDone(result)) {
      final outcome = (result as Success<PrefWriteOutcome>).data!;
      // The new request shows up in Track Requests.
      ref.invalidate(srRequestsProvider);
      widget.onSubmitted(outcome.reference, outcome.pendingApproval);
    } else {
      final error = prefWriteError(context, result);
      if (error != null) prefSnack(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sub = widget.submission;
    final fields = sub.definition.form?.fields ?? const <SrField>[];
    final rows = <Widget>[];
    for (final f in fields) {
      final type = f.type;
      if (type?.isHeader ?? false) {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(f.headerText, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context))),
        ));
        continue;
      }
      final a = sub.answers[f.name] ?? SrAnswer.empty;
      String at(int i) => i < a.displayValues.length && a.displayValues[i].isNotEmpty ? a.displayValues[i] : '-';
      switch (type) {
        case SrFieldType.accountDebitCard:
          rows
            ..add(PayReviewRow(label: l10n.srAccountNumber, value: at(0)))
            ..add(PayReviewRow(label: l10n.srDebitCard, value: at(1)));
        case SrFieldType.countryState:
          rows
            ..add(PayReviewRow(label: l10n.srCountry, value: at(0)))
            ..add(PayReviewRow(label: l10n.srState, value: at(1)));
        case SrFieldType.fileUpload:
          rows.add(PayReviewRow(label: f.label, value: a.isEmpty ? '-' : '${l10n.srAttachment}: ${at(0)}'));
        default:
          final shown = a.displayValues.where((v) => v.isNotEmpty).join(', ');
          rows.add(PayReviewRow(label: f.label, value: shown.isEmpty ? '-' : shown));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrefReviewBanner(message: l10n.srReviewMessage),
        const SizedBox(height: 14),
        PaySection(
          title: sub.definition.form?.header ?? sub.definition.name,
          icon: Icons.fact_check_outlined,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
        ),
        const SizedBox(height: 16),
        PrefActions(children: [
          PayPrimaryButton(label: l10n.prefConfirm, loading: _saving, onPressed: _confirm),
          PaySecondaryButton(label: l10n.prefBack, onPressed: _saving ? null : widget.onBack),
          PaySecondaryButton(label: l10n.prefCancel, onPressed: _saving ? null : widget.onCancel),
        ]),
      ],
    );
  }
}
