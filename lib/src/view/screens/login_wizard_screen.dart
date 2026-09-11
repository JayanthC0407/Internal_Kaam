import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/legal/legal_content.dart';
import 'package:ubci_bank/src/core/models/lfw_limits_options.dart';
import 'package:ubci_bank/src/core/models/lfw_party_profile.dart';
import 'package:ubci_bank/src/core/models/lfw_progress.dart';
import 'package:ubci_bank/src/core/models/security_question.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/infra/service/navigation_service.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/screens/auth/auth_colors.dart';
import 'package:ubci_bank/src/view/screens/home_dashboard_screen.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_form_shell.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_labeled_field.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_secondary_button.dart';
import 'package:ubci_bank/src/view/widgets/secure_screen.dart';
import 'package:ubci_bank/src/view/widgets/session_activity_scope.dart';

class LoginWizardArgs {
  const LoginWizardArgs({
    required this.homeArgs,
    this.initialProgress,
  });

  final HomeDashboardArgs homeArgs;
  final LfwProgress? initialProgress;
}

/// Post-auth first-time Login Flow Wizard — does not alter password/OTP login.
class LoginWizardScreen extends ConsumerStatefulWidget {
  const LoginWizardScreen({
    super.key,
    required this.args,
  });

  final LoginWizardArgs args;

  @override
  ConsumerState<LoginWizardScreen> createState() => _LoginWizardScreenState();
}

class _LoginWizardScreenState extends ConsumerState<LoginWizardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final initial = widget.args.initialProgress;
    if (initial != null && initial.steps.isNotEmpty) {
      ref.read(loginWizardProgressProvider.notifier).state = initial;
      if (initial.pendingSteps.isEmpty) {
        _goHome();
      }
      return;
    }
    final l10n = AppLocalizations.of(context);
    final progress = await ref.read(loginWizardVmProvider).loadProgress(l10n: l10n);
    if (!mounted) return;
    if (progress != null && progress.pendingSteps.isEmpty) {
      _goHome();
    }
  }

  void _goHome() {
    NavigationService.openHomeAndClearStack(
      context,
      args: widget.args.homeArgs,
    );
  }

  Future<void> _onStepCompleted() async {
    final progress = ref.read(loginWizardProgressProvider);
    if (progress == null) return;
    if (progress.pendingSteps.isEmpty) {
      _goHome();
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loading = ref.watch(loginWizardIsLoadingProvider);
    final error = ref.watch(loginWizardErrorProvider);
    final progress = ref.watch(loginWizardProgressProvider);
    final current = progress?.currentStep;
    final totalEnabled = progress?.steps.where((s) => s.enabled).length ?? 0;
    final completedCount =
        progress?.steps.where((s) => s.enabled && s.completed).length ?? 0;
    final stepIndex = completedCount + 1;

    final body = Scaffold(
      backgroundColor: AuthColors.screenBackground(context),
      body: AuthFormShell(
        title: _shellTitle(l10n, current),
        subtitle: current == null
            ? l10n.lfwSubtitle
            : l10n.lfwStepOf(
                stepIndex.clamp(1, totalEnabled == 0 ? 1 : totalEnabled),
                totalEnabled == 0 ? 1 : totalEnabled,
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (progress != null && progress.enabledSteps.isNotEmpty) ...[
              _LfwStepStrip(
                steps: progress.enabledSteps,
                currentWizardStepId: current?.wizardStepId,
              ),
              const SizedBox(height: 16),
            ],
            if (error != null && error.isNotEmpty) ...[
              Text(
                error,
                style: TextStyle(
                  color: AuthColors.error(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (progress == null && loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (current == null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.lfwSubtitle),
                  const SizedBox(height: 16),
                  AuthFormPrimaryButton(
                    label: l10n.accountsRetry,
                    isLoading: loading,
                    onPressed: () async {
                      final p = await ref
                          .read(loginWizardVmProvider)
                          .loadProgress(l10n: l10n);
                      if (!mounted) return;
                      if (p != null && p.pendingSteps.isEmpty) {
                        _goHome();
                      }
                    },
                  ),
                ],
              )
            else
              _StepBody(
                step: current,
                onCompleted: _onStepCompleted,
              ),
          ],
        ),
      ),
    );

    final gated = AuthenticatedSessionGate(
      child: SecureScreen(child: body),
    );

    if (!kIsWeb) return gated;
    return PopScope(canPop: false, child: gated);
  }

  String _shellTitle(AppLocalizations l10n, LfwStepProgress? current) {
    if (current == null) return l10n.lfwTitle;
    switch (current.kind) {
      case LfwStepKind.termsAndConditions:
        return l10n.lfwTermsTitle;
      case LfwStepKind.securityQuestions:
        return l10n.lfwSecurityQuestionsTitle;
      case LfwStepKind.userProfile:
        return l10n.lfwProfileTitle;
      case LfwStepKind.transactionLimits:
        return l10n.lfwLimitsTitle;
      case LfwStepKind.unknown:
        return current.name?.trim().isNotEmpty == true
            ? current.name!.trim()
            : l10n.lfwTitle;
    }
  }
}

/// Compact strip of all enabled LFW steps (Terms → Security → Profile → Limits).
class _LfwStepStrip extends StatelessWidget {
  const _LfwStepStrip({
    required this.steps,
    this.currentWizardStepId,
  });

  final List<LfwStepProgress> steps;
  final String? currentWizardStepId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brand = AuthColors.brand(context);
    final muted = AuthColors.textSecondary(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.chevron_right, size: 16, color: muted),
              ),
            _chip(context, l10n, steps[i], brand, muted),
          ],
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    AppLocalizations l10n,
    LfwStepProgress step,
    Color brand,
    Color muted,
  ) {
    final isCurrent = step.wizardStepId == currentWizardStepId &&
        !step.completed &&
        step.enabled;
    final done = step.completed;
    final label = _label(l10n, step);
    final bg = done
        ? brand.withValues(alpha: 0.12)
        : isCurrent
            ? brand.withValues(alpha: 0.18)
            : AuthColors.inputBackground(context);
    final fg = done || isCurrent ? brand : muted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent ? brand : AuthColors.inputBorder(context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (done) ...[
            Icon(Icons.check_circle, size: 14, color: brand),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  String _label(AppLocalizations l10n, LfwStepProgress step) {
    switch (step.kind) {
      case LfwStepKind.termsAndConditions:
        return l10n.lfwTermsTitle;
      case LfwStepKind.securityQuestions:
        return l10n.lfwSecurityQuestionsTitle;
      case LfwStepKind.userProfile:
        return l10n.lfwProfileTitle;
      case LfwStepKind.transactionLimits:
        return l10n.lfwLimitsTitle;
      case LfwStepKind.unknown:
        final name = step.name?.trim();
        if (name != null && name.isNotEmpty) return name;
        return step.wizardStepId.isNotEmpty ? step.wizardStepId : l10n.lfwTitle;
    }
  }
}

class _StepBody extends ConsumerWidget {
  const _StepBody({
    required this.step,
    required this.onCompleted,
  });

  final LfwStepProgress step;
  final Future<void> Function() onCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (step.kind) {
      case LfwStepKind.termsAndConditions:
        return _TermsStep(step: step, onCompleted: onCompleted);
      case LfwStepKind.securityQuestions:
        return _SecurityQuestionsStep(step: step, onCompleted: onCompleted);
      case LfwStepKind.userProfile:
        return _ProfileStep(step: step, onCompleted: onCompleted);
      case LfwStepKind.transactionLimits:
        return _LimitsStep(step: step, onCompleted: onCompleted);
      case LfwStepKind.unknown:
        return _UnknownStep(step: step, onCompleted: onCompleted);
    }
  }
}

class _TermsStep extends ConsumerStatefulWidget {
  const _TermsStep({required this.step, required this.onCompleted});

  final LfwStepProgress step;
  final Future<void> Function() onCompleted;

  @override
  ConsumerState<_TermsStep> createState() => _TermsStepState();
}

class _TermsStepState extends ConsumerState<_TermsStep> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loading = ref.watch(loginWizardIsLoadingProvider);
    final brand = AuthColors.brand(context);
    final textPrimary = AuthColors.textPrimary(context);
    final textSecondary = AuthColors.textSecondary(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.lfwTermsSubtitle,
          style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),
        Container(
          height: 280,
          decoration: BoxDecoration(
            border: Border.all(color: AuthColors.inputBorder(context)),
            borderRadius: BorderRadius.circular(12),
            color: AuthColors.inputBackground(context),
          ),
          child: FutureBuilder<String>(
            future: LegalContent.loadTermsAndConditions(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Center(child: CircularProgressIndicator(color: brand));
              }
              final text = snapshot.data?.trim() ?? '';
              if (text.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.registrationTermsAndConditions,
                      style: TextStyle(color: textSecondary),
                    ),
                  ),
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: textPrimary,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          value: _accepted,
          onChanged: loading
              ? null
              : (v) => setState(() => _accepted = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(
            l10n.lfwAcceptTerms,
            style: TextStyle(fontSize: 14, color: textPrimary),
          ),
        ),
        const SizedBox(height: 8),
        AuthFormPrimaryButton(
          label: l10n.lfwAccept,
          isLoading: loading,
          enabled: _accepted,
          onPressed: () async {
            if (!_accepted) {
              ref.read(loginWizardErrorProvider.notifier).state =
                  l10n.lfwMustAcceptTerms;
              return;
            }
            final ok = await ref
                .read(loginWizardVmProvider)
                .acceptTerms(widget.step, l10n: l10n);
            if (ok) await widget.onCompleted();
          },
        ),
      ],
    );
  }
}

class _SecurityQuestionsStep extends ConsumerStatefulWidget {
  const _SecurityQuestionsStep({
    required this.step,
    required this.onCompleted,
  });

  final LfwStepProgress step;
  final Future<void> Function() onCompleted;

  @override
  ConsumerState<_SecurityQuestionsStep> createState() =>
      _SecurityQuestionsStepState();
}

class _SecurityQuestionsStepState
    extends ConsumerState<_SecurityQuestionsStep> {
  bool _loadingOptions = true;
  bool _editing = false;
  bool _showValidation = false;
  int _requiredCount = 5;
  List<SecurityQuestionOption> _options = const [];
  late List<String?> _selectedIds;
  late List<TextEditingController> _answerControllers;

  @override
  void initState() {
    super.initState();
    _selectedIds = List<String?>.filled(5, null);
    _answerControllers = List.generate(5, (_) => TextEditingController());
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in _answerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final l10n = AppLocalizations.of(context);
    final vm = ref.read(loginWizardVmProvider);
    final count = await vm.loadQuestionCount(l10n: l10n) ?? 5;
    final catalog = await vm.loadMasterQuestions(l10n: l10n);
    if (!mounted) return;
    final seen = <String>{};
    final unique = <SecurityQuestionOption>[];
    for (final q in catalog.options) {
      if (q.id.isEmpty || !seen.add(q.id)) continue;
      unique.add(q);
    }

    setState(() {
      _requiredCount = count.clamp(1, 10);
      _options = unique;
      _selectedIds = List<String?>.filled(_requiredCount, null);
      for (final c in _answerControllers) {
        c.dispose();
      }
      _answerControllers =
          List.generate(_requiredCount, (_) => TextEditingController());
      _loadingOptions = false;
    });
  }

  List<SecurityQuestionOption> _optionsFor(int index) {
    final taken = <String>{};
    for (var i = 0; i < _selectedIds.length; i++) {
      if (i == index) continue;
      final id = _selectedIds[i];
      if (id != null && id.isNotEmpty) taken.add(id);
    }
    return _options.where((q) => !taken.contains(q.id)).toList();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _showValidation = true);

    final ids = _selectedIds;
    if (ids.any((id) => id == null || id.isEmpty)) {
      ref.read(loginWizardErrorProvider.notifier).state =
          l10n.lfwFieldRequired;
      return;
    }
    if (ids.toSet().length != ids.length) {
      ref.read(loginWizardErrorProvider.notifier).state =
          l10n.lfwDuplicateQuestion;
      return;
    }
    final answers = <UserSecurityQuestionAnswer>[];
    for (var i = 0; i < _requiredCount; i++) {
      final answer = _answerControllers[i].text.trim();
      if (answer.isEmpty) {
        ref.read(loginWizardErrorProvider.notifier).state =
            l10n.lfwFieldRequired;
        return;
      }
      answers.add(
        UserSecurityQuestionAnswer(
          questionId: ids[i]!,
          answer: answer,
        ),
      );
    }

    ref.read(loginWizardErrorProvider.notifier).state = null;
    final ok = await ref.read(loginWizardVmProvider).submitSecurityQuestions(
          step: widget.step,
          answers: answers,
          l10n: l10n,
        );
    if (ok) await widget.onCompleted();
  }

  Widget _noteCard(AppLocalizations l10n, Color textPrimary, Color textSecondary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthColors.inputBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, color: textSecondary, size: 22),
              const SizedBox(width: 8),
              Text(
                l10n.lfwSecurityNoteTitle,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.lfwSecurityNoteBody,
            style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.lfwSecurityNoteMust,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '• ${l10n.lfwSecurityNoteBullet1}',
            style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
          ),
          const SizedBox(height: 4),
          Text(
            '• ${l10n.lfwSecurityNoteBullet2}',
            style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loading = ref.watch(loginWizardIsLoadingProvider);
    final colors = AppColors.of(context);
    final textPrimary = AuthColors.textPrimary(context);
    final textSecondary = AuthColors.textSecondary(context);

    if (_loadingOptions) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // digx-ui: landing state before the question form.
    if (!_editing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.lfwSecurityQuestionsNotSetup,
            style: TextStyle(fontSize: 14, color: textPrimary, height: 1.4),
          ),
          const SizedBox(height: 16),
          _noteCard(l10n, textPrimary, textSecondary),
          const SizedBox(height: 20),
          AuthFormPrimaryButton(
            label: l10n.lfwSecurityQuestionsSetupNow,
            onPressed: () => setState(() => _editing = true),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.lfwSecurityQuestionsSection,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.lfwSecurityQuestionsSubtitle,
          style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
        ),
        const SizedBox(height: 12),
        _noteCard(l10n, textPrimary, textSecondary),
        if (_options.isEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.errorGeneric,
            style: TextStyle(fontSize: 13, color: colors.error, height: 1.4),
          ),
          const SizedBox(height: 12),
          AuthFormPrimaryButton(
            label: l10n.accountsRetry,
            isLoading: loading,
            onPressed: () {
              setState(() => _loadingOptions = true);
              _load();
            },
          ),
        ],
        const SizedBox(height: 16),
        for (var i = 0; i < _requiredCount; i++) ...[
          AuthLabeledDropdown<String>(
            // Note: your AuthLabeledDropdown doesn't have vendor's `fieldId`
            // disambiguation param (used there to keep focus stable when
            // several dropdowns share a label, e.g. this loop). Not needed
            // to compile; see MERGE_REPORT.md.
            label: l10n.lfwSecurityQuestionLabel,
            hint: l10n.lfwSelectQuestion,
            required: true,
            value: _selectedIds[i],
            enabled: !loading && _options.isNotEmpty,
            validator: (_) {
              if (!_showValidation) return null;
              final id = _selectedIds[i];
              if (id == null || id.isEmpty) return l10n.lfwFieldRequired;
              return null;
            },
            items: [
              for (final q in _optionsFor(i))
                DropdownMenuItem(
                  value: q.id,
                  child: Text(
                    q.text.isEmpty ? q.id : q.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _selectedIds[i] = v),
          ),
          const SizedBox(height: 8),
          AuthLabeledField(
            label: l10n.lfwAnswerLabel,
            hint: l10n.lfwEnterAnswer,
            required: true,
            controller: _answerControllers[i],
            enabled: !loading,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (!_showValidation) return null;
              if (value == null || value.trim().isEmpty) {
                return l10n.lfwFieldRequired;
              }
              return null;
            },
            autovalidateMode: _showValidation
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
          ),
          const SizedBox(height: 16),
        ],
        AuthFormPrimaryButton(
          label: l10n.lfwSaveAndContinue,
          isLoading: loading,
          enabled: _options.isNotEmpty,
          onPressed: _submit,
        ),
        const SizedBox(height: 12),
        AuthSecondaryButton(
          label: l10n.cancel,
          onPressed: loading
              ? null
              : () => setState(() {
                    _editing = false;
                    _showValidation = false;
                    ref.read(loginWizardErrorProvider.notifier).state = null;
                  }),
        ),
      ],
    );
  }
}

class _ProfileStep extends ConsumerStatefulWidget {
  const _ProfileStep({required this.step, required this.onCompleted});

  final LfwStepProgress step;
  final Future<void> Function() onCompleted;

  @override
  ConsumerState<_ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends ConsumerState<_ProfileStep> {
  bool _loadingData = true;
  LfwPartyProfile? _party;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final l10n = AppLocalizations.of(context);
    final party =
        await ref.read(loginWizardVmProvider).loadPartyProfile(l10n: l10n);
    if (!mounted) return;
    setState(() {
      _party = party;
      _loadingData = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loading = ref.watch(loginWizardIsLoadingProvider);
    final textPrimary = AuthColors.textPrimary(context);
    final textSecondary = AuthColors.textSecondary(context);

    if (_loadingData) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final party = _party ?? const LfwPartyProfile();
    final displayName = party.fullName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (displayName.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.person_outline, color: textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        Text(
          l10n.lfwProfilePersonalInfo,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.lfwProfileSubtitle,
          style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (party.dateOfBirth.isEmpty)
          Text(l10n.lfwNoProfileData, style: TextStyle(color: textSecondary))
        else ...[
          Text(
            l10n.lfwProfileDateOfBirth,
            style: TextStyle(
              fontSize: 12,
              color: textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            party.dateOfBirth,
            style: TextStyle(fontSize: 14, color: textPrimary),
          ),
        ],
        const SizedBox(height: 16),
        AuthFormPrimaryButton(
          label: l10n.next,
          isLoading: loading,
          onPressed: () async {
            final ok = await ref
                .read(loginWizardVmProvider)
                .completeCurrentStep(widget.step, l10n: l10n);
            if (ok) await widget.onCompleted();
          },
        ),
      ],
    );
  }

}

class _LimitsStep extends ConsumerStatefulWidget {
  const _LimitsStep({required this.step, required this.onCompleted});

  final LfwStepProgress step;
  final Future<void> Function() onCompleted;

  @override
  ConsumerState<_LimitsStep> createState() => _LimitsStepState();
}

class _LimitsStepState extends ConsumerState<_LimitsStep> {
  bool _loadingData = true;
  Map<String, dynamic>? _snapshot;
  String? _channelId;
  String? _transactionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final l10n = AppLocalizations.of(context);
    final data =
        await ref.read(loginWizardVmProvider).loadLimitsSnapshot(l10n: l10n);
    if (!mounted) return;
    final options = LfwLimitsOptions.fromSnapshot(data ?? const {});
    setState(() {
      _snapshot = data;
      _channelId = options.channels.isEmpty ? null : options.channels.first.id;
      _transactionId =
          options.transactions.isEmpty ? null : options.transactions.first.id;
      _loadingData = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loading = ref.watch(loginWizardIsLoadingProvider);
    final colors = AppColors.of(context);
    final textSecondary = AuthColors.textSecondary(context);
    final options = LfwLimitsOptions.fromSnapshot(_snapshot ?? const {});

    if (_loadingData) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.lfwLimitsSubtitle,
          style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (options.channels.isNotEmpty) ...[
          AuthLabeledDropdown<String>(
            label: l10n.lfwLimitsChannel,
            hint: l10n.lfwSelectChannel,
            value: _channelId,
            enabled: !loading,
            items: [
              for (final c in options.channels)
                DropdownMenuItem(
                  value: c.id,
                  child: Text(
                    c.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _channelId = v),
          ),
          const SizedBox(height: 12),
        ],
        if (options.transactions.isNotEmpty) ...[
          AuthLabeledDropdown<String>(
            label: l10n.lfwLimitsTransactions,
            hint: l10n.lfwSelectTransaction,
            value: _transactionId,
            enabled: !loading,
            items: [
              for (final t in options.transactions)
                DropdownMenuItem(
                  value: t.id,
                  child: Text(
                    t.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _transactionId = v),
          ),
          const SizedBox(height: 16),
        ],
        Icon(Icons.description_outlined, size: 56, color: textSecondary),
        const SizedBox(height: 12),
        Text(
          l10n.lfwLimitsEmptyAssigned,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        AuthFormPrimaryButton(
          label: l10n.next,
          isLoading: loading,
          onPressed: () async {
            final ok = await ref
                .read(loginWizardVmProvider)
                .completeCurrentStep(widget.step, l10n: l10n);
            if (ok) await widget.onCompleted();
          },
        ),
      ],
    );
  }
}

class _UnknownStep extends ConsumerWidget {
  const _UnknownStep({required this.step, required this.onCompleted});

  final LfwStepProgress step;
  final Future<void> Function() onCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final loading = ref.watch(loginWizardIsLoadingProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(step.name ?? l10n.lfwUnknownStep),
        const SizedBox(height: 16),
        AuthFormPrimaryButton(
          label: l10n.next,
          isLoading: loading,
          onPressed: () async {
            final ok = await ref
                .read(loginWizardVmProvider)
                .completeCurrentStep(step, l10n: l10n);
            if (ok) await onCompleted();
          },
        ),
      ],
    );
  }
}
