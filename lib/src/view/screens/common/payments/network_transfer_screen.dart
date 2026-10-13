import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/own_account_transfer.dart';
import 'package:ubci_bank/src/core/models/common/payment/network_transfer.dart';
import 'package:ubci_bank/src/core/models/retail/casa_account.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/common/network_transfer_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// Which transfer the screen makes — five of the OBDX Transfers menu's
/// items share this one flow.
enum NetworkTransferMode {
  existingPayee,
  adhocPayee,
  repeatExistingPayee,
  repeatAdhocPayee,
  internationalLowValue;

  bool get isRepeat =>
      this == repeatExistingPayee || this == repeatAdhocPayee;

  /// Starts with a new (adhoc) payee.
  bool get startsAdhoc => this == adhocPayee || this == repeatAdhocPayee;
  bool get isLowValue => this == internationalLowValue;

  /// The flow's title — OBDX's menu name for the payment, following the
  /// Existing / Adhoc Payee switch at the top.
  String title({required bool adhoc}) => switch (this) {
        existingPayee || adhocPayee =>
          adhoc ? 'Transfers - Adhoc Payee' : 'Transfers - Existing Payee',
        repeatExistingPayee || repeatAdhocPayee =>
          adhoc ? 'Repeat Transfers - Adhoc Payee' : 'Repeat Transfers - Existing Payee',
        internationalLowValue => 'International Low Value Payment',
      };

  String intro({required bool adhoc}) => switch (this) {
        existingPayee || adhocPayee =>
          adhoc ? "To someone you haven't saved as a payee" : 'To one of your saved payees',
        repeatExistingPayee || repeatAdhocPayee =>
          adhoc ? 'Pay someone new on a schedule' : 'Pay a saved payee on a schedule',
        internationalLowValue => 'Fast international payment over SWIFT gpi',
      };

  IconData get icon => switch (this) {
        existingPayee => Icons.person_outline_rounded,
        adhocPayee => Icons.person_add_alt_1_outlined,
        repeatExistingPayee || repeatAdhocPayee => Icons.event_repeat_rounded,
        internationalLowValue => Icons.public_rounded,
      };
}

/// Route arguments: the mode, and a payee to start with (picked on the
/// Transfer hub).
class NetworkTransferArgs {
  const NetworkTransferArgs(this.mode, {this.payee});

  final NetworkTransferMode mode;
  final TransferPayee? payee;
}

/// One transfer to a payee — saved or new, now, later or on a schedule —
/// on the OBDX network payment APIs: details → the bank's validation and
/// charges for review → submit (with OTP when asked) → done.
class NetworkTransferScreen extends ConsumerStatefulWidget {
  const NetworkTransferScreen({
    super.key,
    required this.mode,
    this.initialPayee,
    this.embedded = false,
    this.onBack,
  });

  final NetworkTransferMode mode;

  /// A saved payee already chosen, e.g. from the hub's payee strip.
  final TransferPayee? initialPayee;

  /// Shown inside the dashboard shell (beside the side menu) rather than
  /// pushed; [onBack] then leaves it.
  final bool embedded;
  final VoidCallback? onBack;

  @override
  ConsumerState<NetworkTransferScreen> createState() =>
      _NetworkTransferScreenState();
}

class _NetworkTransferScreenState extends ConsumerState<NetworkTransferScreen> {
  NetworkTransferMode get mode => widget.mode;

  int _step = 0;

  // Payee
  late bool _adhoc = mode.startsAdhoc && widget.initialPayee == null;
  late TransferPayee? _payee = widget.initialPayee;
  late TransferKind _adhocKind =
      mode.isLowValue ? TransferKind.international : TransferKind.internal;
  final _account = TextEditingController();
  final _name = TextEditingController();
  final _bankCode = TextEditingController();
  final _bankName = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController();
  TransferBank? _bank;
  bool _lookingUp = false;

  // Payment
  TransferNetwork? _network;
  CasaAccount? _debit;
  String? _currency;
  final _amount = TextEditingController();
  TransferPurpose? _purpose;
  ChargeBearer _charges = ChargeBearer.me;
  bool _later = false;
  DateTime? _laterDate;
  final _remarks = TextEditingController();

  // Schedule
  TransferFrequency? _frequency;
  DateTime? _start;
  bool _endByCount = false;
  DateTime? _end;
  final _count = TextEditingController();

  // Review
  final _errors = <String, String>{};
  bool _preparing = false;
  NetworkTransferRequest? _request;
  TransferValidationResult? _validation;
  PaymentChargesSummary? _chargesQuote;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    for (final c in [
      _account, _name, _bankCode, _bankName, _address, _city, _country,
      _amount, _remarks, _count,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  TransferKind? get _kind => _adhoc ? _adhocKind : _payee?.kind;

  /// Networks for the current payee: GPI for low-value payments, else the
  /// kind's own (repeat transfers: those that run standing instructions,
  /// when the bank says which).
  List<TransferNetwork> _networksFor(List<TransferNetwork> all) {
    final kind = _kind;
    if (mode.isLowValue) {
      final gpi = all.where((n) => n.code.toUpperCase() == kGpiNetworkCode);
      return gpi.isEmpty ? const [TransferNetwork(code: kGpiNetworkCode)] : gpi.toList();
    }
    if (kind == null) return const [];
    var list = all
        .where((n) =>
            n.paymentType?.toUpperCase() == kind.paymentType &&
            n.code.toUpperCase() != kGpiNetworkCode)
        .toList();
    if (mode.isRepeat && list.any((n) => n.hasStandingInstruction)) {
      list = list.where((n) => n.hasStandingInstruction).toList();
    }
    if (list.isEmpty && kind == TransferKind.internal) {
      return const [TransferNetwork(code: 'INTERNAL', paymentType: 'INTERNAL')];
    }
    return list;
  }

  String? get _taskCode => _network == null
      ? null
      : (_adhoc ? (_network!.taskCodeAdhoc ?? _network!.taskCode) : _network!.taskCode);

  String get _currencyCode => _currency ?? _debit?.currencyCode ?? '';

  void _resetNetwork() {
    _network = null;
    _purpose = null;
    _debit = null;
  }

  // ── Bank lookup ─────────────────────────────────────────────────────────

  Future<void> _lookupBank() async {
    final code = _bankCode.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _lookingUp = true;
      _bank = null;
    });
    final result = await ref.read(networkTransferRepositoryProvider).lookupBank(
          kind: _adhocKind,
          code: code,
          network: _network?.code ?? '',
        );
    if (!mounted) return;
    setState(() {
      _lookingUp = false;
      if (result is Success<TransferBank?> && result.data != null) {
        _bank = result.data;
        _bankName.text = result.data!.name;
        _errors.remove('bankCode');
      } else {
        _errors['bankCode'] = "We couldn't find a bank for this code.";
      }
    });
  }

  // ── Continue ────────────────────────────────────────────────────────────

  bool _validateForm(List<GpiCurrency> gpi) {
    final e = <String, String>{};
    if (_adhoc) {
      if (_account.text.trim().length < 4) e['account'] = 'Enter the account number.';
      if (_name.text.trim().isEmpty) e['name'] = "Enter the payee's name.";
      if (_adhocKind == TransferKind.domestic && _bankCode.text.trim().isEmpty) {
        e['bankCode'] = 'Enter the bank code.';
      }
      if (_adhocKind == TransferKind.international &&
          _bankCode.text.trim().isEmpty &&
          _bankName.text.trim().isEmpty) {
        e['bankCode'] = 'Enter the SWIFT code, or the bank name.';
      }
      if (_adhocKind == TransferKind.international &&
          _country.text.trim().length != 2) {
        e['country'] = 'Enter the two-letter country code, e.g. GB.';
      }
    } else if (_payee == null) {
      e['payee'] = 'Choose a payee.';
    }
    if (_network == null) e['network'] = 'Choose how to send the money.';
    if (_debit == null) e['debit'] = 'Choose the account to pay from.';
    if (mode.isLowValue && _currency == null) e['currency'] = 'Choose a currency.';

    final amount = payParseAmount(_amount.text);
    if (amount == null || amount <= 0) {
      e['amount'] = 'Enter an amount.';
    } else {
      double? min;
      double? max;
      if (mode.isLowValue) {
        final c = gpi.where((c) => c.code == _currency).firstOrNull;
        min = c?.min;
        max = c?.max;
      } else {
        final l = _network?.limitFor(_currencyCode);
        min = l?.min;
        max = l?.max;
      }
      if (min != null && amount < min) {
        e['amount'] = 'The minimum is ${payAmount(min, _currencyCode)}.';
      } else if (max != null && amount > max) {
        e['amount'] = 'The maximum is ${payAmount(max, _currencyCode)}.';
      }
    }

    final purposes = _network == null
        ? const <TransferPurpose>[]
        : ref.read(transferPurposesProvider(_network!.code)).valueOrNull ?? const [];
    if (purposes.isNotEmpty && _purpose == null && _kind != TransferKind.internal) {
      e['purpose'] = 'Choose the purpose of the transfer.';
    }

    if (mode.isRepeat) {
      if (_frequency == null) e['frequency'] = 'Choose how often.';
      if (_start == null) e['start'] = 'Choose the first transfer date.';
      if (_endByCount) {
        final n = int.tryParse(_count.text.trim());
        if (n == null || n < 2) e['end'] = 'Enter at least 2 transfers.';
      } else if (_end == null) {
        e['end'] = 'Choose the last transfer date.';
      } else if (_start != null && !_end!.isAfter(_start!)) {
        e['end'] = 'The last date must be after the first.';
      }
    } else if (_later && _laterDate == null) {
      e['later'] = 'Choose the transfer date.';
    }

    setState(() {
      _errors
        ..clear()
        ..addAll(e);
    });
    return e.isEmpty;
  }

  NetworkTransferRequest _buildRequest() {
    final kind = _kind!;
    return NetworkTransferRequest(
      kind: kind,
      network: _network!.code,
      debitAccount: _debit!,
      amount: payParseAmount(_amount.text)!,
      currency: _currencyCode,
      paymentDate: _later ? _laterDate! : _today,
      payee: _adhoc ? null : _payee,
      adhoc: !_adhoc
          ? null
          : AdhocBeneficiary(
              kind: kind,
              accountNumber: _account.text.trim(),
              name: _name.text.trim(),
              bankCode: _bankCode.text.trim().isEmpty
                  ? null
                  : _bankCode.text.trim().toUpperCase(),
              bankName: _bankName.text.trim().isEmpty ? null : _bankName.text.trim(),
              addressLine1: _address.text.trim().isEmpty ? null : _address.text.trim(),
              city: _city.text.trim().isEmpty ? null : _city.text.trim(),
              country: _country.text.trim().isEmpty
                  ? null
                  : _country.text.trim().toUpperCase(),
            ),
      remarks: _remarks.text,
      purpose: _purpose,
      charges: kind == TransferKind.international ? _charges : ChargeBearer.me,
      schedule: !mode.isRepeat
          ? null
          : RepeatSchedule(
              frequency: _frequency!,
              startDate: _start!,
              endDate: _endByCount ? null : _end,
              instances: _endByCount ? int.parse(_count.text.trim()) : null,
            ),
    );
  }

  Future<void> _continue(List<GpiCurrency> gpi) async {
    if (!_validateForm(gpi)) {
      HapticFeedback.mediumImpact();
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() => _preparing = true);
    final repository = ref.read(networkTransferRepositoryProvider);
    final request = _buildRequest();
    final results = await Future.wait([
      repository.validate(request),
      repository.fetchCharges(request),
    ]);
    if (!mounted) return;
    setState(() => _preparing = false);
    final validated = results[0];
    if (validated is! Success<TransferValidationResult> || validated.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(validated.resolveUserMessage(
          l10n: l10n,
          fallback: "The bank couldn't accept this transfer.",
        )),
      ));
      return;
    }
    final charges = results[1];
    setState(() {
      _validation = validated.data;
      _chargesQuote =
          charges is Success<PaymentChargesSummary> ? charges.data : null;
      _request = request.withReference(validated.data!.systemReferenceId);
      _step = 1;
    });
  }

  void _confirm() {
    final request = _request;
    if (request == null) return;
    final repository = ref.read(networkTransferRepositoryProvider);
    ref.read(transferSubmissionProvider.notifier).submit(
          (otp, challenge) =>
              repository.submit(request, challenge: challenge, otp: otp),
        );
  }

  void _startAgain() {
    ref.read(transferSubmissionProvider.notifier).reset();
    setState(() {
      _step = 0;
      _request = null;
      _validation = null;
      _chargesQuote = null;
      _amount.clear();
      _remarks.clear();
    });
  }

  void _exit() {
    if (widget.embedded && widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).maybePop(true);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  void _switchPayeeMode(bool adhoc) => setState(() {
        _adhoc = adhoc;
        _payee = null;
        _errors.clear();
        _resetNetwork();
      });

  String? get _toName {
    if (!_adhoc) return _payee?.title;
    final name = _name.text.trim();
    return name.isEmpty ? null : name;
  }

  static String _payeeDetail(TransferPayee p) => [
        p.kind?.label,
        if ((p.accountNumber ?? '').isNotEmpty) payMask(p.accountNumber!),
        p.bankName,
      ].whereType<String>().join(' · ');

  String _accountLine(CasaAccount a) => '${payAccountName(a)} ${payMask(a.displayNumber)}';

  /// The amount's hints: the balance to pay from and the network's limits.
  String? _amountHelper(List<GpiCurrency> gpi) {
    final parts = <String>[];
    final balance = _debit?.availableBalance;
    if (balance != null) {
      parts.add('Available ${payAmount(balance.amount, _debit!.currencyCode)}');
    }
    double? min;
    double? max;
    if (mode.isLowValue) {
      final c = gpi.where((c) => c.code == _currency).firstOrNull;
      min = c?.min;
      max = c?.max;
    } else {
      final l = _network?.limitFor(_currencyCode);
      min = l?.min;
      max = l?.max;
    }
    if (max != null) {
      parts.add('Up to ${payAmount(max, _currencyCode)}'
          '${min != null && min > 0 ? ' (min ${payAmount(min, _currencyCode)})' : ''}');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String _chargesText(NetworkTransferRequest r) {
    final c = _chargesQuote;
    return c?.totalAmount == null
        ? 'As per bank tariff'
        : payAmount(c!.totalAmount, c.currency ?? r.currency);
  }

  /// Amount plus charges — when both are in the transfer's currency.
  String _totalText(NetworkTransferRequest r) {
    final c = _chargesQuote;
    if (c?.totalAmount == null) return payAmount(r.amount, r.currency);
    if ((c!.currency ?? r.currency) != r.currency) return 'Amount + charges';
    return payAmount(r.amount + c.totalAmount!, r.currency);
  }

  @override
  Widget build(BuildContext context) {
    final submission = ref.watch(transferSubmissionProvider);
    payListenToSubmission(ref, context, onDone: () => setState(() => _step = 2));
    final networks = ref.watch(transferNetworksProvider);
    final gpi = mode.isLowValue
        ? ref.watch(gpiCurrenciesProvider).valueOrNull ?? const <GpiCurrency>[]
        : const <GpiCurrency>[];

    // Pick the network on its own when there is just one.
    final options = _networksFor(networks.valueOrNull ?? const []);
    if (_network == null && options.length == 1 && _kind != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _network == null) setState(() => _network = options.first);
      });
    }

    final amount = payParseAmount(_amount.text);
    final request = _request;
    final Widget child = switch (_step) {
      0 => _form(context, networks, options, gpi),
      1 => _review(),
      _ => _result(submission),
    };
    final Widget? action = switch (_step) {
      0 => PayPrimaryButton(
          label: 'Continue',
          loading: _preparing,
          onPressed: _kind == null ? null : () => _continue(gpi),
        ),
      1 => PayPrimaryButton(
          label: request!.isRepeat ? 'Confirm repeat transfer' : 'Confirm transfer',
          icon: Icons.lock_outline_rounded,
          loading: submission.isSubmitting,
          onPressed: _confirm,
        ),
      _ => null,
    };
    final String? caption = switch (_step) {
      0 when amount != null => [
          'Sending ${payAmount(amount, _currencyCode)}',
          if (_toName != null) 'to $_toName',
        ].join(' '),
      1 => 'Total debit ${_totalText(request!)}',
      _ => null,
    };

    return PayFlowScaffold(
      title: mode.title(adhoc: _adhoc),
      subtitle: switch (_step) {
        0 => mode.intro(adhoc: _adhoc),
        1 => 'Review and confirm',
        _ => null,
      },
      step: _step,
      onBackStep: () => setState(() => _step = 0),
      onExit: widget.embedded ? widget.onBack : null,
      summary: _summary(amount),
      action: action,
      actionCaption: caption,
      child: child,
    );
  }

  /// The live summary beside the form on wide layouts.
  Widget _summary(double? amount) {
    final r = _request;
    final reviewing = _step >= 1 && r != null;
    return PaySummaryCard(
      icon: mode.icon,
      title: 'Summary',
      subtitle: mode.intro(adhoc: _adhoc),
      rows: [
        if (_toName != null) ('To', _toName!),
        if (_debit != null) ('From', _accountLine(_debit!)),
        if (_network != null && _kind != TransferKind.internal) ('Send by', _network!.label),
        if (mode.isRepeat) ...[
          if (_frequency != null) ('Repeats', _frequency!.label),
          if (_start != null) ('Starts', payDate(_start)),
        ] else if (_kind != null)
          ('When', _later ? payDate(_laterDate) : 'Now'),
        if (reviewing) ...[
          ('Amount', payAmount(r.amount, r.currency)),
          ('Charges', _chargesText(r)),
        ],
      ],
      total: reviewing
          ? ('Total debit', _totalText(r))
          : amount == null
              ? null
              : ('Amount', payAmount(amount, _currencyCode)),
    );
  }

  Widget _form(
    BuildContext context,
    AsyncValue<List<TransferNetwork>> networks,
    List<TransferNetwork> options,
    List<GpiCurrency> gpi,
  ) {
    final kind = _kind;
    final purposes = _network == null
        ? const AsyncValue<List<TransferPurpose>>.data([])
        : ref.watch(transferPurposesProvider(_network!.code));
    final sections = <Widget>[
      PaySection(
        title: 'To',
        icon: Icons.person_outline_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PaySegmented<bool>(
              options: const [(false, 'Existing Payee'), (true, 'Adhoc Payee')],
              selected: _adhoc,
              onChanged: _switchPayeeMode,
            ),
            const SizedBox(height: 14),
            if (_adhoc) _adhocFields(context) else _payeePicker(context),
            if (kind != null) ...[
              if (!mode.isLowValue && options.length > 1) ...[
                const SizedBox(height: 14),
                const PayFieldLabel('Send by'),
                PayPickerField(
                  placeholder: 'Choose how to send it',
                  title: _network?.label,
                  icon: Icons.hub_outlined,
                  error: _errors['network'],
                  onTap: () async {
                    final picked = await showPayPicker<TransferNetwork>(
                      context,
                      title: 'Send by',
                      selected: _network,
                      options: [
                        for (final n in options)
                          PayOption(value: n, title: n.label, subtitle: n.code, icon: Icons.hub_outlined),
                      ],
                    );
                    if (picked != null) {
                      setState(() {
                        _network = picked;
                        _purpose = null;
                        _debit = null;
                        _errors.remove('network');
                      });
                    }
                  },
                ),
              ] else if (networks.hasError) ...[
                const SizedBox(height: 14),
                PayErrorRetry(
                  message: "We couldn't load the ways to send money.",
                  onRetry: () => ref.invalidate(transferNetworksProvider),
                ),
              ] else if (options.isEmpty && !networks.isLoading) ...[
                const SizedBox(height: 14),
                PayNote('This bank has no network for ${kind.label.toLowerCase()} transfers.'),
              ],
            ],
          ],
        ),
      ),
      if (kind != null) ...[
        PaySection(
          title: 'From',
          icon: Icons.account_balance_wallet_outlined,
          child: _debitField(context),
        ),
        PaySection(
          title: 'Amount',
          icon: Icons.payments_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mode.isLowValue) ...[
                const PayFieldLabel('Currency'),
                PayPickerField(
                  placeholder: 'Choose a currency',
                  title: _currency,
                  icon: Icons.currency_exchange_rounded,
                  error: _errors['currency'],
                  loading: ref.watch(gpiCurrenciesProvider).isLoading,
                  onTap: () async {
                    final picked = await showPayPicker<String>(
                      context,
                      title: 'Currency',
                      selected: _currency,
                      options: [
                        for (final c in gpi)
                          PayOption(
                            value: c.code,
                            title: c.code,
                            icon: Icons.currency_exchange_rounded,
                            subtitle: [
                              if (c.description != null) c.description!,
                              if (c.min != null || c.max != null)
                                '${payAmount(c.min, c.code)} – ${payAmount(c.max, c.code)}',
                            ].join(' · '),
                          ),
                      ],
                    );
                    if (picked != null) {
                      setState(() {
                        _currency = picked;
                        _errors.remove('currency');
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),
              ],
              PayAmountField(
                controller: _amount,
                currency: _currencyCode,
                error: _errors['amount'],
                helper: _amountHelper(gpi),
                onChanged: (_) => setState(() => _errors.remove('amount')),
              ),
              ...purposes.maybeWhen(
                data: (list) => list.isEmpty
                    ? const <Widget>[]
                    : [
                        const SizedBox(height: 14),
                        const PayFieldLabel('Purpose'),
                        PayPickerField(
                          placeholder: 'Choose the purpose',
                          title: _purpose?.description,
                          icon: Icons.label_outline_rounded,
                          error: _errors['purpose'],
                          onTap: () async {
                            final picked = await showPayPicker<TransferPurpose>(
                              context,
                              title: 'Purpose',
                              selected: _purpose,
                              options: [
                                for (final p in list)
                                  PayOption(value: p, title: p.description, subtitle: p.code),
                              ],
                            );
                            if (picked != null) {
                              setState(() {
                                _purpose = picked;
                                _errors.remove('purpose');
                              });
                            }
                          },
                        ),
                      ],
                orElse: () => const <Widget>[],
              ),
              if (kind == TransferKind.international) ...[
                const SizedBox(height: 14),
                const PayFieldLabel('Charges'),
                PaySegmented<ChargeBearer>(
                  options: [for (final c in ChargeBearer.values) (c, c.label)],
                  selected: _charges,
                  onChanged: (c) => setState(() => _charges = c),
                ),
              ],
            ],
          ),
        ),
        PaySection(
          title: mode.isRepeat ? 'Schedule' : 'When',
          icon: mode.isRepeat ? Icons.event_repeat_rounded : Icons.event_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mode.isRepeat) _scheduleFields(context) else _whenFields(context),
              const SizedBox(height: 14),
              PayTextField(
                label: 'Note (optional)',
                controller: _remarks,
                hint: 'A note for this transfer',
              ),
            ],
          ),
        ),
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, section) in sections.indexed) ...[
          if (i > 0) const SizedBox(height: 16),
          section,
        ],
      ],
    );
  }

  Widget _payeePicker(BuildContext context) {
    final payees = ref.watch(transferPayeesProvider);
    final allowed = mode.isLowValue
        ? [TransferKind.international]
        : TransferKind.values;
    final list = (payees.valueOrNull ?? const <TransferPayee>[])
        .where((p) => p.kind != null && allowed.contains(p.kind))
        .toList();
    if (payees.hasError) {
      return PayErrorRetry(
        message: "We couldn't load your payees.",
        onRetry: () => ref.invalidate(transferPayeesProvider),
      );
    }
    return PayPickerField(
      placeholder: 'Choose a payee',
      title: _payee?.title,
      subtitle: _payee == null ? null : _payeeDetail(_payee!),
      icon: Icons.person_search_outlined,
      leading: _payee == null ? null : PayAvatar(name: _payee!.title, size: 38),
      loading: payees.isLoading,
      error: _errors['payee'],
      onTap: payees.valueOrNull == null
          ? null
          : () async {
              final picked = await showPayPicker<TransferPayee>(
                context,
                title: 'Choose a payee',
                selected: _payee,
                empty: mode.isLowValue
                    ? 'No international payees yet. Add one under Payees.'
                    : 'No payees yet. Add one under Payees.',
                options: [
                  for (final p in list)
                    PayOption(
                      value: p,
                      title: p.title,
                      subtitle: _payeeDetail(p),
                      avatar: p.title,
                    ),
                ],
              );
              if (picked != null) {
                setState(() {
                  _payee = picked;
                  _errors.remove('payee');
                  _resetNetwork();
                });
              }
            },
    );
  }

  Widget _adhocFields(BuildContext context) {
    final kinds = mode.isLowValue ? [TransferKind.international] : TransferKind.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kinds.length > 1) ...[
          const PayFieldLabel('Their bank is'),
          PaySegmented<TransferKind>(
            options: [for (final k in kinds) (k, k.label)],
            selected: _adhocKind,
            onChanged: (k) => setState(() {
              _adhocKind = k;
              _bank = null;
              _errors.clear();
              _resetNetwork();
            }),
          ),
          const SizedBox(height: 14),
        ],
        PayTextField(
          label: 'Account number',
          controller: _account,
          hint: _adhocKind == TransferKind.international ? 'Account number or IBAN' : 'Account number',
          error: _errors['account'],
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 14),
        PayTextField(
          label: "Payee's name",
          controller: _name,
          hint: 'As on their account',
          error: _errors['name'],
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
        if (_adhocKind != TransferKind.internal) ...[
          const SizedBox(height: 14),
          PayTextField(
            label: _adhocKind == TransferKind.international ? 'SWIFT / BIC code' : 'Bank code',
            controller: _bankCode,
            hint: _adhocKind == TransferKind.international ? 'e.g. CITIGB2L' : 'Clearing code of the bank',
            error: _errors['bankCode'],
            textCapitalization: TextCapitalization.characters,
            suffix: _lookingUp
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    tooltip: 'Find the bank',
                    icon: const Icon(Icons.search_rounded),
                    onPressed: _lookupBank,
                  ),
          ),
          if (_bank != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.verified_rounded, size: 16, color: HomeColors.success(context)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [_bank!.name, _bank!.branchName, _bank!.address].whereType<String>().join(' · '),
                      style: TextStyle(fontSize: 12.5, color: HomeColors.success(context)),
                    ),
                  ),
                ],
              ),
            ),
          if (_adhocKind == TransferKind.international) ...[
            const SizedBox(height: 14),
            PayTextField(label: 'Bank name', controller: _bankName, hint: 'If there is no SWIFT code'),
            const SizedBox(height: 14),
            PayTextField(label: "Payee's address", controller: _address),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: PayTextField(label: 'City', controller: _city)),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: PayTextField(
                    label: 'Country',
                    controller: _country,
                    hint: 'e.g. GB',
                    error: _errors['country'],
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [LengthLimitingTextInputFormatter(2)],
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _debitField(BuildContext context) {
    final accounts = ref.watch(transferDebitAccountsProvider(_taskCode));
    if (accounts.hasError) {
      return PayErrorRetry(
        message: "We couldn't load your accounts.",
        onRetry: () => ref.invalidate(transferDebitAccountsProvider(_taskCode)),
      );
    }
    final balance = _debit?.availableBalance;
    return PayPickerField(
      placeholder: 'Choose an account',
      title: _debit == null ? null : payAccountName(_debit!),
      subtitle: _debit == null ? null : '${payMask(_debit!.displayNumber)} · ${_debit!.currencyCode}',
      trailingText: balance == null ? null : payAmount(balance.amount, _debit!.currencyCode),
      loading: accounts.isLoading,
      error: _errors['debit'],
      onTap: accounts.valueOrNull == null
          ? null
          : () async {
              final picked = await showPayPicker<CasaAccount>(
                context,
                title: 'Pay from',
                selected: _debit,
                options: [
                  for (final a in accounts.value!)
                    PayOption(
                      value: a,
                      title: payAccountName(a),
                      subtitle: '${payMask(a.displayNumber)} · ${a.currencyCode}',
                      trailing: a.availableBalance == null
                          ? null
                          : payAmount(a.availableBalance!.amount, a.currencyCode),
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                ],
              );
              if (picked != null) {
                setState(() {
                  _debit = picked;
                  _errors.remove('debit');
                });
              }
            },
    );
  }

  Widget _whenFields(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaySegmented<bool>(
            options: const [(false, 'Now'), (true, 'Later')],
            selected: _later,
            onChanged: (v) => setState(() => _later = v),
          ),
          if (_later) ...[
            const SizedBox(height: 10),
            PayDateField(
              value: _laterDate,
              first: _today.add(const Duration(days: 1)),
              placeholder: 'Choose the transfer date',
              error: _errors['later'],
              onChanged: (d) => setState(() {
                _laterDate = d;
                _errors.remove('later');
              }),
            ),
          ],
        ],
      );

  Widget _scheduleFields(BuildContext context) {
    final frequencies = ref.watch(transferFrequenciesProvider).valueOrNull ??
        TransferFrequency.all;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PayFieldLabel('How often'),
        PayPickerField(
          placeholder: 'Choose a frequency',
          title: _frequency?.label,
          icon: Icons.event_repeat_rounded,
          error: _errors['frequency'],
          onTap: () async {
            final picked = await showPayPicker<TransferFrequency>(
              context,
              title: 'How often',
              selected: _frequency,
              options: [
                for (final f in frequencies)
                  PayOption(value: f, title: f.label, icon: Icons.event_repeat_rounded),
              ],
            );
            if (picked != null) {
              setState(() {
                _frequency = picked;
                _errors.remove('frequency');
              });
            }
          },
        ),
        const SizedBox(height: 14),
        const PayFieldLabel('First transfer'),
        PayDateField(
          value: _start,
          first: _today,
          error: _errors['start'],
          onChanged: (d) => setState(() {
            _start = d;
            _errors.remove('start');
          }),
        ),
        const SizedBox(height: 14),
        const PayFieldLabel('Ends'),
        PaySegmented<bool>(
          options: const [(false, 'On a date'), (true, 'After a number of transfers')],
          selected: _endByCount,
          onChanged: (v) => setState(() {
            _endByCount = v;
            _errors.remove('end');
          }),
        ),
        const SizedBox(height: 10),
        if (_endByCount)
          PayTextField(
            label: 'Number of transfers',
            controller: _count,
            hint: 'e.g. 12',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
            error: _errors['end'],
            onChanged: (_) => setState(() => _errors.remove('end')),
          )
        else
          PayDateField(
            value: _end,
            first: (_start ?? _today).add(const Duration(days: 1)),
            placeholder: 'Choose the last transfer date',
            error: _errors['end'],
            onChanged: (d) => setState(() {
              _end = d;
              _errors.remove('end');
            }),
          ),
        if (_frequency != null && _start != null && _endByCount &&
            (int.tryParse(_count.text) ?? 0) > 1) ...[
          const SizedBox(height: 8),
          PayMuted('Last transfer on ${payDate(_frequency!.nth(_start!, int.parse(_count.text)))}'),
        ],
      ],
    );
  }

  /// Everything about the transfer but the money — for review and done.
  List<(String, String)> _detailRows(NetworkTransferRequest r) => [
        ('From', _accountLine(r.debitAccount)),
        if (r.kind == TransferKind.internal)
          ('Type', r.kind.label)
        else
          ('Send by', _network?.label ?? r.network),
        if (r.purpose != null) ('Purpose', r.purpose!.description),
        if (r.kind == TransferKind.international) ('Charges paid by', r.charges.label),
        if (r.schedule != null) ...[
          ('Frequency', r.schedule!.frequency.label),
          ('First transfer', payDate(r.schedule!.startDate)),
          ('Last transfer', payDate(r.schedule!.lastDate)),
        ] else
          ('When', _later ? payDate(r.paymentDate) : 'Now'),
        if (r.remarks?.trim().isNotEmpty ?? false) ('Note', r.remarks!.trim()),
      ];

  String _toDetail(NetworkTransferRequest r) => r.payee != null
      ? _payeeDetail(r.payee!)
      : [r.kind.label, if (r.adhoc != null) payMask(r.adhoc!.accountNumber)].join(' · ');

  Widget _review() {
    final r = _request!;
    final v = _validation;
    final details = [
      ..._detailRows(r),
      if (v?.valueDate != null) ('Value date', payDate(v!.valueDate)),
      if (v?.exchangeRate != null) ('Exchange rate', v!.exchangeRate!.toString()),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaySection(
          child: PayReceiptHero(
            amount: payAmount(r.amount, r.currency),
            toName: r.payeeLabel,
            toDetail: _toDetail(r),
            caption: r.isRepeat ? "You're scheduling" : "You're sending",
          ),
        ),
        const SizedBox(height: 16),
        PaySection(
          title: 'Details',
          child: Column(
            children: [
              for (final (i, (label, value)) in details.indexed)
                PayReviewRow(label: label, value: value, last: i == details.length - 1),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PaySection(
          title: 'Cost',
          child: Column(
            children: [
              PayReviewRow(label: 'Amount', value: payAmount(r.amount, r.currency)),
              PayReviewRow(label: 'Charges', value: _chargesText(r)),
              PayReviewRow(
                label: r.isRepeat ? 'Each transfer debits' : 'Total debit',
                value: _totalText(r),
                emphasize: true,
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _result(TransferSubmissionState submission) {
    final r = _request!;
    return PayResultView(
      title: r.isRepeat ? 'Repeat Transfer set up' : 'Transfer submitted',
      message: r.isRepeat
          ? '${r.schedule!.frequency.label} transfers to ${r.payeeLabel} start on '
              '${payDate(r.schedule!.startDate)}.'
          : 'Your money is on its way to ${r.payeeLabel}.',
      amount: payAmount(r.amount, r.currency),
      reference: submission.result?.referenceNumber,
      rows: [('To', '${r.payeeLabel} · ${_toDetail(r)}'), ..._detailRows(r)],
      onDone: _exit,
      onAnother: _startAgain,
    );
  }
}
