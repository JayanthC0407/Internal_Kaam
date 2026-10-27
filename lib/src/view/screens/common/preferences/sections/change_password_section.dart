import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/account_settings/account_settings_models.dart';
import 'package:ubci_bank/src/view/providers/common/account_settings_providers.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/widgets/preferences_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// The text of one policy rule, OBDX's `showPasswordRule*` strings.
String passwordRuleLabel(AppLocalizations l10n, PasswordPolicy p, PasswordRule rule) {
  String withMin(String base, bool allowed, int min) {
    if (!allowed) return '$base ${l10n.cpNotAllowed}';
    return min > 0 ? '$base ${l10n.cpMinimumMandatory(min)}' : base;
  }

  return switch (rule) {
    PasswordRule.length => l10n.cpRuleLength(p.minLength, p.maxLength),
    PasswordRule.upper => withMin(l10n.cpRuleUpper, p.upperAllowed, p.minUpper),
    PasswordRule.lower => withMin(l10n.cpRuleLower, p.lowerAllowed, p.minLower),
    PasswordRule.number => withMin(l10n.cpRuleNumber, p.numberAllowed, p.minNumber),
    PasswordRule.special => p.specialAllowed && p.specialChars.isNotEmpty
        ? '${withMin(l10n.cpRuleSpecial, true, p.minSpecial)} ${l10n.cpAllowedChars(p.specialChars.join(' '))}'
        : withMin(l10n.cpRuleSpecial, p.specialAllowed, p.minSpecial),
    PasswordRule.successive => l10n.cpRuleSuccessive(p.maxSuccessive ?? 0),
    PasswordRule.repeated => l10n.cpRuleRepeated(p.maxRepeated ?? 0),
    PasswordRule.common => l10n.cpRuleCommon,
    PasswordRule.history => l10n.cpRuleHistory(p.historySize ?? 0),
  };
}

/// Preferences → Change Password (OBDX `change-password`): Current, New
/// and Confirm New Password; the bank's password policy as a live
/// checklist; Submit sends both passwords RSA-encrypted (`PUT
/// me/credentials`). Afterwards OBDX asks the user to sign in again, so
/// Login ends the session.
class ChangePasswordSection extends ConsumerStatefulWidget {
  const ChangePasswordSection({super.key, required this.userName, required this.onCancel, required this.onLogin});

  /// Whose password: needed for the salt the encryption uses.
  final String userName;
  final VoidCallback onCancel;

  /// "Login" on the success screen — logs out to the sign-in page.
  final VoidCallback onLogin;

  @override
  ConsumerState<ChangePasswordSection> createState() => _ChangePasswordSectionState();
}

class _ChangePasswordSectionState extends ConsumerState<ChangePasswordSection> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  String? _currentError;
  String? _newError;
  String? _confirmError;

  /// The requirements box turns red when Submit finds a rule broken.
  bool _rulesError = false;
  bool _saving = false;
  bool _done = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit(PasswordPolicy policy) async {
    final l10n = AppLocalizations.of(context);
    final current = _current.text, next = _new.text, confirm = _confirm.text;
    setState(() {
      _currentError = current.isEmpty ? l10n.cpEnterValue : null;
      _newError = next.isEmpty
          ? l10n.cpEnterValue
          : next == current
              ? l10n.cpDifferentPassword
              : null;
      _confirmError = confirm.isEmpty
          ? l10n.cpEnterValue
          : confirm != next
              ? l10n.cpPasswordsMatch
              : null;
      _rulesError = next.isNotEmpty && !policy.accepts(next);
    });
    if (_currentError != null || _newError != null || _confirmError != null || _rulesError) return;

    setState(() => _saving = true);
    final repo = ref.read(accountSettingsRepositoryProvider);
    final result = await runPrefWrite(
      context,
      (c, otp) => repo.changePassword(userName: widget.userName, current: current, next: next, challenge: c, otp: otp),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (prefWriteDone(result)) {
      _current.clear();
      _new.clear();
      _confirm.clear();
      setState(() => _done = true);
    } else {
      final error = prefWriteError(context, result);
      if (error != null) prefSnack(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_done) {
      return PayResultView(
        title: l10n.cpSuccessTitle,
        message: l10n.cpSuccessMessage,
        rows: const [],
        doneLabel: l10n.cpLogin,
        onDone: widget.onLogin,
      );
    }
    return ref.watch(passwordPolicyProvider).when(
          loading: () => const PrefLoading(),
          error: (e, _) => PrefFailed(error: e, onRetry: () => ref.invalidate(passwordPolicyProvider)),
          data: (policy) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              decoration: BoxDecoration(
                color: HomeColors.card(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: HomeColors.divider(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.cpIntro,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: HomeColors.textSecondary(context)),
                  ),
                  const SizedBox(height: 18),
                  _PasswordBox(
                    label: l10n.cpCurrent,
                    hint: l10n.cpCurrentHint,
                    controller: _current,
                    error: _currentError,
                    onChanged: () => setState(() => _currentError = null),
                  ),
                  const SizedBox(height: 10),
                  _PasswordBox(
                    label: l10n.cpNew,
                    hint: l10n.cpNewHint,
                    controller: _new,
                    error: _newError,
                    // OBDX clears Confirm whenever New changes.
                    onChanged: () => setState(() {
                      _newError = null;
                      _rulesError = false;
                      _confirm.clear();
                    }),
                  ),
                  const SizedBox(height: 10),
                  _PasswordBox(
                    label: l10n.cpConfirm,
                    hint: l10n.cpConfirmHint,
                    controller: _confirm,
                    error: _confirmError,
                    onChanged: () => setState(() => _confirmError = null),
                  ),
                  const SizedBox(height: 16),
                  _RequirementsNote(error: _rulesError),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 120,
                        child: PayPrimaryButton(label: l10n.prefSubmit, loading: _saving, onPressed: () => _submit(policy)),
                      ),
                      SizedBox(width: 120, child: PaySecondaryButton(label: l10n.prefCancel, onPressed: widget.onCancel)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _RulesCard(policy: policy, password: _new.text),
                ],
              ),
            ),
          ),
        );
  }
}

/// The design's field: label inside a rounded box over the input, the box
/// and label red with the message under them while in error.
class _PasswordBox extends StatefulWidget {
  const _PasswordBox({required this.label, required this.hint, required this.controller, required this.onChanged, this.error});

  final String label;
  final String hint;
  final TextEditingController controller;
  final String? error;
  final VoidCallback onChanged;

  @override
  State<_PasswordBox> createState() => _PasswordBoxState();
}

class _PasswordBoxState extends State<_PasswordBox> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.error;
    final red = HomeColors.error(context);
    final border = error != null
        ? red
        : _focus.hasFocus
            ? HomeColors.brand(context)
            : HomeColors.divider(context);
    return GestureDetector(
      onTap: _focus.requestFocus,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: HomeColors.card(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: error != null || _focus.hasFocus ? 1.4 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: error != null ? red : HomeColors.textPrimary(context),
              ),
            ),
            TextField(
              controller: widget.controller,
              focusNode: _focus,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              onChanged: (_) => widget.onChanged(),
              style: TextStyle(fontSize: 14.5, color: HomeColors.textPrimary(context)),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.only(top: 6, bottom: 4),
                hintText: widget.hint,
                hintStyle: TextStyle(fontSize: 14.5, color: HomeColors.textSecondary(context).withValues(alpha: 0.75)),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 6),
              Text(error, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: red)),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Password requirements — All requirements must be satisfied before
/// Submit." in the brand tint (error red after a failed Submit).
class _RequirementsNote extends StatelessWidget {
  const _RequirementsNote({required this.error});

  final bool error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tone = error ? HomeColors.error(context) : HomeColors.brand(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.cpRequirements, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: tone)),
          const SizedBox(height: 2),
          Text(l10n.cpRequirementsNote, style: TextStyle(fontSize: 12, color: tone)),
        ],
      ),
    );
  }
}

/// The policy as bullets; once something is typed each becomes a tick or
/// a cross. History can only be checked by the bank, so it stays a bullet.
class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.policy, required this.password});

  final PasswordPolicy policy;
  final String password;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brand = HomeColors.brand(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.cpRulesIntro, style: TextStyle(fontSize: 13, color: HomeColors.textSecondary(context))),
          const SizedBox(height: 8),
          for (final rule in policy.rules)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  _RuleMark(ok: password.isEmpty ? null : policy.satisfies(rule, password), brand: brand),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      passwordRuleLabel(l10n, policy, rule),
                      style: TextStyle(fontSize: 13, color: HomeColors.textPrimary(context)),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            constraints: const BoxConstraints(maxWidth: 520),
            decoration: BoxDecoration(
              color: HomeColors.bg(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: HomeColors.divider(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.cpSecurityTip,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
                ),
                const SizedBox(height: 2),
                Text(l10n.cpSecurityTipText, style: TextStyle(fontSize: 12, color: HomeColors.textSecondary(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A brand dot until checked, then a green tick or a red cross.
class _RuleMark extends StatelessWidget {
  const _RuleMark({required this.ok, required this.brand});

  final bool? ok;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    if (ok == null) {
      return Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(color: brand, shape: BoxShape.circle),
      );
    }
    return Icon(
      ok! ? Icons.check_circle_rounded : Icons.cancel_rounded,
      size: 14,
      color: ok! ? HomeColors.success(context) : HomeColors.error(context),
    );
  }
}
