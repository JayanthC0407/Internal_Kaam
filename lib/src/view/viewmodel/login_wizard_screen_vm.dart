import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/lfw_party_profile.dart';
import 'package:ubci_bank/src/core/models/lfw_progress.dart';
import 'package:ubci_bank/src/core/models/security_question.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/repository_providers.dart';

final loginWizardIsLoadingProvider = StateProvider.autoDispose<bool>(
  (_) => false,
);

final loginWizardErrorProvider = StateProvider.autoDispose<String?>(
  (_) => null,
);

final loginWizardProgressProvider =
    StateProvider.autoDispose<LfwProgress?>((_) => null);

final loginWizardVmProvider = Provider.autoDispose(
  (ref) => LoginWizardScreenVm(ref),
);

class LoginWizardScreenVm {
  LoginWizardScreenVm(this._ref);

  final Ref _ref;

  Future<LfwProgress?> loadProgress({AppLocalizations? l10n}) async {
    _setLoading(true);
    _setError(null);
    try {
      return await _refreshProgress(l10n: l10n);
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> completeCurrentStep(
    LfwStepProgress step, {
    AppLocalizations? l10n,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final result =
          await _ref.read(loginWizardRepositoryProvider).completeStep(step);
      if (result is! Success) {
        _setError(result.resolveUserMessage(l10n: l10n));
        return false;
      }
      final refreshed = await _refreshProgress(l10n: l10n);
      return refreshed != null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> acceptTerms(
    LfwStepProgress step, {
    AppLocalizations? l10n,
  }) {
    return completeCurrentStep(step, l10n: l10n);
  }

  Future<int?> loadQuestionCount({AppLocalizations? l10n}) async {
    final result = await _ref
        .read(loginWizardRepositoryProvider)
        .fetchRequiredQuestionCount();
    if (result is Success<int> && result.data != null) return result.data;
    _setError(result.resolveUserMessage(l10n: l10n));
    return null;
  }

  Future<SecurityQuestionCatalog> loadMasterQuestions({
    AppLocalizations? l10n,
  }) async {
    final result = await _ref
        .read(loginWizardRepositoryProvider)
        .fetchMasterSecurityQuestions();
    if (result is Success<SecurityQuestionCatalog> && result.data != null) {
      return result.data!;
    }
    _setError(result.resolveUserMessage(l10n: l10n));
    return const SecurityQuestionCatalog(options: []);
  }

  Future<bool> submitSecurityQuestions({
    required LfwStepProgress step,
    required List<UserSecurityQuestionAnswer> answers,
    AppLocalizations? l10n,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final submit = await _ref
          .read(loginWizardRepositoryProvider)
          .submitSecurityQuestions(answers);
      if (submit is! Success) {
        _setError(submit.resolveUserMessage(l10n: l10n));
        return false;
      }
      final complete =
          await _ref.read(loginWizardRepositoryProvider).completeStep(step);
      if (complete is! Success) {
        _setError(complete.resolveUserMessage(l10n: l10n));
        return false;
      }
      final refreshed = await _refreshProgress(l10n: l10n);
      return refreshed != null;
    } finally {
      _setLoading(false);
    }
  }

  Future<LfwPartyProfile?> loadPartyProfile({
    AppLocalizations? l10n,
  }) async {
    final result =
        await _ref.read(loginWizardRepositoryProvider).fetchPartyProfile();
    if (result is Success<LfwPartyProfile> && result.data != null) {
      return result.data;
    }
    _setError(result.resolveUserMessage(l10n: l10n));
    return null;
  }

  Future<Map<String, dynamic>?> loadLimitsSnapshot({
    AppLocalizations? l10n,
  }) async {
    final result =
        await _ref.read(loginWizardRepositoryProvider).fetchLimitsSnapshot();
    if (result is Success<Map<String, dynamic>> && result.data != null) {
      return result.data;
    }
    _setError(result.resolveUserMessage(l10n: l10n));
    return null;
  }

  Future<LfwProgress?> _refreshProgress({AppLocalizations? l10n}) async {
    final result =
        await _ref.read(loginWizardRepositoryProvider).fetchProgress();
    if (result is Success<LfwProgress> && result.data != null) {
      _ref.read(loginWizardProgressProvider.notifier).state = result.data;
      return result.data;
    }
    _setError(result.resolveUserMessage(l10n: l10n));
    return null;
  }

  void _setLoading(bool value) {
    _ref.read(loginWizardIsLoadingProvider.notifier).state = value;
  }

  void _setError(String? value) {
    _ref.read(loginWizardErrorProvider.notifier).state = value;
  }
}
