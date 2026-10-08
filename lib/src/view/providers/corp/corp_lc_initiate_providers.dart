import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_trade_finance_repository.dart';
import 'package:ubci_bank/src/infra/session/session_generation.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';

/// "Application Sections" of the Initiate LC form, in order — the eight
/// sections of the OBDX web initiation (and of the design).
enum LcInitiateSection {
  lcDetails('LC Details'),
  goodsShipment('Goods & Shipment Details'),
  documents('Documents & Conditions'),
  linkages('Linkages'),
  instructions('Instructions'),
  insurance('Insurance'),
  charges('Charges'),
  attachments('Attachments');

  const LcInitiateSection(this.label);
  final String label;

  /// `01` … `08`.
  String get number => (index + 1).toString().padLeft(2, '0');

  bool get isLast => index == LcInitiateSection.values.length - 1;

  LcInitiateSection? get next =>
      isLast ? null : LcInitiateSection.values[index + 1];
}

/// The three bank fields that can be verified against `tradeBicCodes`.
enum LcBankRole { advising, adviseThrough, availableWith }

class CorpLcInitiateState {
  const CorpLcInitiateState({
    this.section = LcInitiateSection.lcDetails,
    this.completed = const {},
    this.draft = LcInitiateDraft.empty,
    this.productDocuments = const [],
    this.addedDocuments = const [],
    this.documentsLoading = false,
    this.draftId,
    this.isSaving = false,
    this.isUploading = false,
    this.isSubmitting = false,
    this.bankLookups = const {},
    this.bankMessages = const {},
    this.charges,
    this.chargesLoading = false,
    this.chargesMessage,
    this.errorMessage,
    this.infoMessage,
    this.challenge,
    this.otpError,
    this.outcome,
  });

  final LcInitiateSection section;

  /// Sections passed with "Next" — shown ticked in the section bar.
  final Set<LcInitiateSection> completed;
  final LcInitiateDraft draft;

  /// Documents offered by the selected product (H1 #159).
  final List<LcDocument> productDocuments;

  /// Documents added from the master with "+ Add Document" (H3 #58).
  final List<LcDocument> addedDocuments;
  final bool documentsLoading;

  /// Host id of the saved draft; null until first save.
  final String? draftId;

  final bool isSaving;

  /// Attachment upload running.
  final bool isUploading;
  final bool isSubmitting;

  /// Roles whose SWIFT lookup is running.
  final Set<LcBankRole> bankLookups;

  /// Lookup failures per role.
  final Map<LcBankRole, String> bankMessages;

  /// Charge preview for the Charges section; null = not requested yet.
  final List<LcCharge>? charges;
  final bool chargesLoading;
  final String? chargesMessage;

  final String? errorMessage;
  final String? infoMessage;

  /// Set while the host waits for an OTP.
  final ObdxChallenge? challenge;
  final String? otpError;

  /// Set once the LC has been submitted — the screen shows the result.
  final LcSubmitted? outcome;

  bool get isBusy => isSaving || isSubmitting || isUploading;

  /// Every document the 46A table lists: product documents first, then the
  /// ones added from the master.
  List<LcDocument> get availableDocuments => [
        ...productDocuments,
        for (final doc in addedDocuments)
          if (!productDocuments.any((p) => p.id == doc.id)) doc,
      ];

  /// A section can be opened once every section before it was completed.
  bool canOpen(LcInitiateSection target) {
    for (final s in LcInitiateSection.values) {
      if (s == target) return true;
      if (!completed.contains(s)) return false;
    }
    return true;
  }

  CorpLcInitiateState copyWith({
    LcInitiateSection? section,
    Set<LcInitiateSection>? completed,
    LcInitiateDraft? draft,
    List<LcDocument>? productDocuments,
    List<LcDocument>? addedDocuments,
    bool? documentsLoading,
    String? draftId,
    bool? isSaving,
    bool? isUploading,
    bool? isSubmitting,
    Set<LcBankRole>? bankLookups,
    Map<LcBankRole, String>? bankMessages,
    List<LcCharge>? charges,
    bool clearCharges = false,
    bool? chargesLoading,
    String? chargesMessage,
    String? errorMessage,
    String? infoMessage,
    bool clearMessages = false,
    ObdxChallenge? challenge,
    bool clearChallenge = false,
    String? otpError,
    bool clearOtpError = false,
    LcSubmitted? outcome,
  }) {
    return CorpLcInitiateState(
      section: section ?? this.section,
      completed: completed ?? this.completed,
      draft: draft ?? this.draft,
      productDocuments: productDocuments ?? this.productDocuments,
      addedDocuments: addedDocuments ?? this.addedDocuments,
      documentsLoading: documentsLoading ?? this.documentsLoading,
      draftId: draftId ?? this.draftId,
      isSaving: isSaving ?? this.isSaving,
      isUploading: isUploading ?? this.isUploading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      bankLookups: bankLookups ?? this.bankLookups,
      bankMessages: bankMessages ?? this.bankMessages,
      charges: clearCharges ? null : (charges ?? this.charges),
      chargesLoading: chargesLoading ?? this.chargesLoading,
      chargesMessage:
          clearCharges ? null : (chargesMessage ?? this.chargesMessage),
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearMessages ? null : (infoMessage ?? this.infoMessage),
      challenge: clearChallenge ? null : (challenge ?? this.challenge),
      otpError: (clearChallenge || clearOtpError)
          ? null
          : (otpError ?? this.otpError),
      outcome: outcome ?? this.outcome,
    );
  }
}

// ── Per-section reference data ──────────────────────────────────────────
//
// One provider per section, loaded the first time the section opens —
// the calls each section's capture shows (H5). The screen keeps the
// providers of visited sections alive until it closes, so moving back
// and forth does not refetch. Goods (`tradeGoods`), conditions
// (`additionalConditions`) and incoterms (`tradeIncoterms`) come with
// `corpLcLookupsProvider`, which the form loads when it opens.

/// 01 LC Details — `beneficiaries`, `me/party/relations`,
/// `branchdate/{TRADE_BRANCH_CODE}`.
final corpLcDetailsSectionProvider =
    FutureProvider.autoDispose<LcDetailsSectionData>((ref) {
  final branch =
      ref.read(corpLcLookupsProvider).lookups.configuration.branchCode;
  return ref
      .read(corpTradeFinanceRepositoryProvider)
      .fetchLcDetailsSection(branchCode: branch);
});

/// 03 Documents & Conditions — `tradeDocument`,
/// `additionalConditionMaintenance?partyId=`.
final corpLcDocumentsSectionProvider =
    FutureProvider.autoDispose<LcDocumentsSectionData>((ref) {
  return ref
      .read(corpTradeFinanceRepositoryProvider)
      .fetchDocumentsSection(partyId: currentLcParty(ref).value);
});

/// 04 Linkages — `corporateDeposit`, `currencies`, `demandDeposit`.
final corpLcLinkagesSectionProvider =
    FutureProvider.autoDispose<LcLinkagesSectionData>((ref) {
  return ref.read(corpTradeFinanceRepositoryProvider).fetchLinkagesSection();
});

/// 05 Instructions, per product — `confirmationInstruction`,
/// `confirmationParty`, `customerInstructions` (productCode).
final corpLcInstructionsSectionProvider = FutureProvider.autoDispose
    .family<LcInstructionsSectionData, String?>((ref, productCode) {
  return ref
      .read(corpTradeFinanceRepositoryProvider)
      .fetchInstructionsSection(productCode: productCode);
});

Future<T> _orThrow<T>(
  Future<ResponseHandler<T>> call,
  String fallback,
  T empty,
) async {
  final result = await call;
  if (result is Success<T>) return result.data ?? empty;
  throw Exception(await lcFailureMessage(result, fallback: fallback) ?? fallback);
}

/// 06 Insurance — `me/party`, then `insurancePolicies?partyId=`.
final corpLcInsuranceSectionProvider =
    FutureProvider.autoDispose<List<LcInsurancePolicy>>((ref) {
  return _orThrow(
    ref.read(corpTradeFinanceRepositoryProvider).fetchInsuranceSection(
          fallbackPartyId: currentLcParty(ref).value,
        ),
    'Insurance policies could not be loaded.',
    const <LcInsurancePolicy>[],
  );
});

/// 07 Charges — `demandDeposit?taskCode=TF_AF_CLC` (the preview itself is
/// [CorpLcInitiateNotifier.loadCharges]).
final corpLcChargeAccountsProvider =
    FutureProvider.autoDispose<List<LcAccount>>((ref) {
  return _orThrow(
    ref.read(corpTradeFinanceRepositoryProvider).fetchChargeAccounts(),
    'Charge accounts could not be loaded.',
    const <LcAccount>[],
  );
});

/// 08 Attachments — `documentcontent/documentcategories`.
final corpLcAttachmentCategoriesProvider =
    FutureProvider.autoDispose<List<LcDocumentCategory>>((ref) {
  return _orThrow(
    ref.read(corpTradeFinanceRepositoryProvider).fetchDocumentCategories(),
    'Document categories could not be loaded.',
    const <LcDocumentCategory>[],
  );
});

class CorpLcInitiateNotifier extends StateNotifier<CorpLcInitiateState> {
  CorpLcInitiateNotifier(this._ref) : super(const CorpLcInitiateState());

  final Ref _ref;

  CorpTradeFinanceRepository get _repo =>
      _ref.read(corpTradeFinanceRepositoryProvider);

  // ── Prefill sources (Initiate LC tabs) ───────────────────────────────

  /// Seeds from an existing LC ("Copy & initiate") or a saved draft.
  /// [draftId] is passed for a draft so later saves update it in place.
  void seed(CorpLetterOfCredit lc, {String? draftId}) {
    final products = _ref.read(corpLcLookupsProvider).lookups.products;
    LcProduct? product;
    for (final p in products) {
      if (p.id == lc.productId) product = p;
    }
    state = CorpLcInitiateState(
      draft: LcInitiateDraft.fromLetterOfCredit(lc, product: product),
      draftId: draftId,
    );
    final id = lc.productId;
    if (id != null) _loadProductDocuments(id);
  }

  /// By Drafts — the drafts list may carry summaries only, so the full draft
  /// is read (OBDX spec `readDraft`); the list row is the fallback.
  Future<void> seedFromDraft(String draftId, CorpLetterOfCredit row) async {
    final generation = SessionGeneration.current;
    final result = await _repo.fetchDraft(draftId);
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    final lc = _dataOr(result, row);
    seed(lc, draftId: draftId);
    // A Back to Back draft keeps its backing Export LC.
    final parents = lc.raw['parentReferenceLCs'];
    if (parents is List && parents.isNotEmpty) {
      final parent = TfJson.str(parents.first);
      if (parent != null) {
        state = state.copyWith(draft: state.draft.copyWith(parentLcId: parent));
      }
    }
  }

  /// By Template — prefills a *new* LC; the template itself is untouched,
  /// so no draft id and no draft name are carried over.
  Future<void> seedFromTemplate(String templateId, CorpLetterOfCredit row) async {
    final generation = SessionGeneration.current;
    final result = await _repo.fetchTemplate(templateId);
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    seed(_dataOr(result, row));
    state = state.copyWith(draft: state.draft.copyWith(clearDraftName: true));
  }

  /// Copy & Initiate — the full LC is read (H1 #48) and duplicated.
  Future<void> seedFromLc(String lcId, CorpLetterOfCredit row) async {
    final generation = SessionGeneration.current;
    final result = await _repo.fetchLetterOfCredit(lcId);
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    seed(_dataOr(result, row));
    state = state.copyWith(draft: state.draft.copyWith(clearDraftName: true));
  }

  /// Back to Back LC — a new Import LC backed by [exportLc]. Currency,
  /// goods, shipment and incoterm follow the export LC; beneficiary and
  /// amount are left for the user.
  Future<void> seedBackToBack(CorpLetterOfCredit exportLc) async {
    final generation = SessionGeneration.current;
    final result = await _repo.fetchLetterOfCredit(exportLc.id);
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    final source = _dataOr(result, exportLc);
    state = CorpLcInitiateState(
      draft: LcInitiateDraft(
        newBeneficiary: true,
        currency: source.amount?.currency,
        expiryDate: source.expiryDate,
        shipment: source.shipment,
        incoterm:
            (source.incoterm?.code.isEmpty ?? true) ? null : source.incoterm,
        goods: source.goods,
        parentLcId: source.id,
      ),
    );
  }

  static CorpLetterOfCredit _dataOr(
    ResponseHandler<CorpLetterOfCredit> result,
    CorpLetterOfCredit fallback,
  ) =>
      (result is Success<CorpLetterOfCredit> ? result.data : null) ?? fallback;

  // ── Form editing ─────────────────────────────────────────────────────

  void update(LcInitiateDraft Function(LcInitiateDraft draft) change) {
    state = state.copyWith(
      draft: change(state.draft),
      clearMessages: true,
      clearCharges: true,
    );
  }

  /// Selecting a product applies its tolerance defaults, drops revolving
  /// when the product does not allow it, and loads its documents.
  void selectProduct(LcProduct product) {
    update((d) => d.copyWith(
          product: product,
          toleranceAbove: product.positiveTolerance,
          toleranceUnder: product.negativeTolerance,
          revolving: product.revolving ? d.revolving : false,
          documents: const [],
        ));
    _loadProductDocuments(product.id);
  }

  Future<void> _loadProductDocuments(String productId) async {
    final generation = SessionGeneration.current;
    state = state.copyWith(documentsLoading: true, productDocuments: const []);
    final result = await _repo.fetchProductDocuments(productId);
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    state = state.copyWith(
      documentsLoading: false,
      productDocuments: result is Success<List<LcDocument>>
          ? (result.data ?? const [])
          : const [],
    );
  }

  /// 59 — picks a maintained beneficiary (H3 #49).
  void selectBeneficiary(LcBeneficiary beneficiary) {
    update((d) => d.copyWith(
          newBeneficiary: false,
          beneficiaryId: beneficiary.id,
          beneficiaryName: beneficiary.name,
          beneficiaryAddress: beneficiary.address,
        ));
  }

  /// 59 — Existing / New. Switching clears what the other mode filled in.
  void setNewBeneficiary(bool isNew) {
    if (state.draft.newBeneficiary == isNew) return;
    update((d) => d.copyWith(
          newBeneficiary: isNew,
          clearBeneficiaryId: true,
          beneficiaryName: '',
          beneficiaryAddress: LcAddress.empty,
        ));
  }

  void toggleDocument(LcDocument document, bool selected) {
    final current = [...state.draft.documents]
      ..removeWhere((d) => d.id == document.id);
    if (selected) current.add(document);
    update((d) => d.copyWith(documents: current));
  }

  void updateDocument(LcDocument document) {
    update((d) => d.copyWith(documents: [
          for (final doc in d.documents) doc.id == document.id ? document : doc,
        ]));
  }

  /// 46A "+ Add Document" — adds a master document (H3 #58) and selects it.
  void addMasterDocument(LcDocument document) {
    if (!state.availableDocuments.any((d) => d.id == document.id)) {
      state = state.copyWith(
        addedDocuments: [...state.addedDocuments, document],
      );
    }
    toggleDocument(document, true);
  }

  void toggleCondition(TradeCode condition, bool selected) {
    final current = [...state.draft.additionalConditions]
      ..removeWhere((c) => c.code == condition.code);
    if (selected) current.add(condition);
    update((d) => d.copyWith(additionalConditions: current));
  }

  void addGoods(LcGoods goods) =>
      update((d) => d.copyWith(goods: [...d.goods, goods]));

  void removeGoodsAt(int index) {
    final list = [...state.draft.goods]..removeAt(index);
    update((d) => d.copyWith(goods: list));
  }

  void addBillingDraft(LcBillingDraft draft) =>
      update((d) => d.copyWith(billingDrafts: [...d.billingDrafts, draft]));

  void removeBillingDraftAt(int index) {
    final list = [...state.draft.billingDrafts]..removeAt(index);
    update((d) => d.copyWith(billingDrafts: list));
  }

  /// 04 — links [account] with [amount]; a null amount unlinks it.
  void setLinkage(LcAccount account, double? amount) {
    final list = [
      for (final l in state.draft.depositLinkages)
        if (l.account != account) l,
      if (amount != null) LcDepositLinkage(account: account, amount: amount),
    ];
    update((d) => d.copyWith(depositLinkages: list));
  }

  // ── Banks ────────────────────────────────────────────────────────────

  LcBankSelection bankOf(LcBankRole role) => switch (role) {
        LcBankRole.advising => state.draft.advisingBank,
        LcBankRole.adviseThrough => state.draft.adviseThroughBank,
        LcBankRole.availableWith => state.draft.availableWith,
      };

  void setBank(LcBankRole role, LcBankSelection bank) {
    final messages = {...state.bankMessages}..remove(role);
    update((d) => switch (role) {
          LcBankRole.advising => d.copyWith(advisingBank: bank),
          LcBankRole.adviseThrough => d.copyWith(adviseThroughBank: bank),
          LcBankRole.availableWith => d.copyWith(availableWith: bank),
        });
    state = state.copyWith(bankMessages: messages);
  }

  /// Resolves a SWIFT code via `tradeBicCodes` (H1 #143).
  Future<void> lookupBank(LcBankRole role, String code) async {
    final swift = code.trim().toUpperCase();
    final current = bankOf(role).copyWith(
      byName: false,
      swiftCode: swift,
      clearResolved: true,
    );
    if (swift.length != 8 && swift.length != 11) {
      setBank(role, current);
      state = state.copyWith(bankMessages: {
        ...state.bankMessages,
        role: 'Enter an 8 or 11 character SWIFT code.',
      });
      return;
    }
    final generation = SessionGeneration.current;
    setBank(role, current);
    state = state.copyWith(bankLookups: {...state.bankLookups, role});
    final result = await _repo.lookupBic(swift);
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;

    final lookups = {...state.bankLookups}..remove(role);
    if (result is Success<TradeBank?> && result.data != null) {
      state = state.copyWith(bankLookups: lookups);
      setBank(role, current.copyWith(resolved: result.data));
      return;
    }
    final message = result is Success
        ? 'No bank found for $swift.'
        : (await lcFailureMessage(result, fallback: 'Bank lookup failed.'));
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    state = state.copyWith(
      bankLookups: lookups,
      bankMessages: {
        ...state.bankMessages,
        if (message != null) role: message,
      },
    );
  }

  // ── Navigation & validation ──────────────────────────────────────────

  /// Client-side checks for [section]. The host re-validates everything on
  /// submit (limits, product rules, dates), so this only catches what the
  /// user can fix without a round trip.
  List<String> validate(LcInitiateSection section) {
    final d = state.draft;
    final errors = <String>[];
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    switch (section) {
      case LcInitiateSection.lcDetails:
        if (d.product == null) errors.add('Select an LC product.');
        if (d.revolving && (d.revolvingDetails.frequency ?? 0) <= 0) {
          errors.add('Enter the repeat frequency for the revolving LC.');
        }
        if (d.expiryDate == null) {
          errors.add('Select the date of expiry.');
        } else if (!d.expiryDate!.isAfter(todayDate)) {
          errors.add('Date of expiry must be in the future.');
        }
        if ((d.expiryPlace ?? '').trim().isEmpty) {
          errors.add('Enter the place of expiry.');
        }
        if (d.newBeneficiary) {
          if ((d.beneficiaryName ?? '').trim().isEmpty) {
            errors.add('Enter the beneficiary name.');
          }
          if ((d.beneficiaryAddress.line1 ?? '').trim().isEmpty) {
            errors.add('Enter the beneficiary address.');
          }
          if (d.beneficiaryAddress.country == null) {
            errors.add('Select the beneficiary country.');
          }
        } else if (d.beneficiaryId == null) {
          errors.add('Select a beneficiary.');
        }
        if ((d.currency ?? '').length != 3) errors.add('Select the LC currency.');
        if (d.amount == null || d.amount! <= 0) {
          errors.add('Enter an LC amount greater than zero.');
        }
        if (d.toleranceAbove < 0 ||
            d.toleranceAbove > 100 ||
            d.toleranceUnder < 0 ||
            d.toleranceUnder > 100) {
          errors.add('Tolerances must be between 0 and 100%.');
        }
      case LcInitiateSection.goodsShipment:
        final s = d.shipment;
        if ((s.loadingPort ?? '').trim().isEmpty) {
          errors.add('Enter the port of loading.');
        }
        if ((s.dischargePort ?? '').trim().isEmpty) {
          errors.add('Enter the port of discharge.');
        }
        if (d.shipmentByPeriod) {
          if ((s.period ?? '').trim().isEmpty) {
            errors.add('Enter the shipment period.');
          }
        } else if (s.latestShipmentDate != null &&
            d.expiryDate != null &&
            s.latestShipmentDate!.isAfter(d.expiryDate!)) {
          errors.add('Shipment date cannot be after the date of expiry.');
        }
      case LcInitiateSection.documents:
        if (d.documentPresentationDays <= 0) {
          errors.add('Enter the days within which documents are presented.');
        }
      case LcInitiateSection.linkages:
        if (d.depositLinkages.any((l) => (l.amount ?? 0) <= 0)) {
          errors.add('Enter a linkage amount for every linked account.');
        }
      case LcInitiateSection.instructions:
        final bank = d.advisingBank;
        if (bank.byName) {
          if ((bank.name ?? '').trim().isEmpty) {
            errors.add('Enter the advising bank name.');
          }
        } else {
          final code = bank.code ?? '';
          if (code.length != 8 && code.length != 11) {
            errors.add('Enter the advising bank SWIFT code (8 or 11 characters).');
          }
        }
        if (!d.standardInstructionsAccepted) {
          errors.add('Confirm that you have read the standard instructions.');
        }
      case LcInitiateSection.insurance:
      case LcInitiateSection.charges:
        break;
      case LcInitiateSection.attachments:
        if (!d.termsAccepted) {
          errors.add('Accept the Terms & Conditions to submit.');
        }
    }
    return errors;
  }

  /// Validates the current section and moves to the next. Returns the
  /// errors (an empty list means the section changed).
  List<String> next() {
    final errors = validate(state.section);
    if (errors.isNotEmpty) return errors;
    final next = state.section.next;
    final completed = {...state.completed, state.section};
    if (next == null) {
      state = state.copyWith(completed: completed);
      return const [];
    }
    state = state.copyWith(
      section: next,
      completed: completed,
      clearMessages: true,
    );
    if (next == LcInitiateSection.charges && state.charges == null) {
      loadCharges();
    }
    return const [];
  }

  /// Opens [section] from the section bar — any section up to the first
  /// one not yet completed.
  void goTo(LcInitiateSection section) {
    if (!state.canOpen(section) || section == state.section) return;
    state = state.copyWith(section: section, clearMessages: true);
    if (section == LcInitiateSection.charges && state.charges == null) {
      loadCharges();
    }
  }

  // ── Host calls ───────────────────────────────────────────────────────

  Map<String, dynamic> _body({
    required String lcState,
    String? id,
    bool autoSaved = false,
  }) {
    final lookups = _ref.read(corpLcLookupsProvider).lookups;
    return state.draft.toRequestJson(
      partyId: currentLcParty(_ref),
      partyName: currentLcPartyName(_ref),
      branchId: lookups.configuration.branchCode,
      state: lcState,
      id: id,
      autoSaved: autoSaved,
    );
  }

  /// Charge preview (H1 #121, H3 #74). Failure is informational only — the
  /// bank still computes charges on submit.
  Future<void> loadCharges() async {
    final generation = SessionGeneration.current;
    state = state.copyWith(chargesLoading: true, clearCharges: true);
    final result = await _repo.previewCharges(_body(lcState: 'INITIATED'));
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    if (result is Success<List<LcCharge>>) {
      state = state.copyWith(chargesLoading: false, charges: result.data ?? []);
      return;
    }
    state = state.copyWith(
      chargesLoading: false,
      charges: const [],
      chargesMessage:
          'Charges could not be previewed. The bank will apply the applicable charges on processing.',
    );
  }

  /// "Save Template" on the Attachments section — `template save api.har`:
  /// the full body with `state: TEMPLATE`, the template `name` and
  /// `visibility`, posted as a new LC (`id` null). Returns true on success.
  Future<bool> saveTemplate() async {
    final name = state.draft.templateName?.trim() ?? '';
    if (name.isEmpty) {
      state = state.copyWith(errorMessage: 'Enter a name for the template.');
      return false;
    }
    final generation = SessionGeneration.current;
    state = state.copyWith(isSaving: true, clearMessages: true);
    final body = _body(lcState: 'TEMPLATE')
      ..['name'] = name
      ..['visibility'] = state.draft.templateVisibility;
    final result = await _repo.saveTemplate(body);
    if (!SessionGeneration.isCurrent(generation) || !mounted) return false;
    if (result is Success<String>) {
      state = state.copyWith(
        isSaving: false,
        infoMessage: 'Template "$name" saved.',
      );
      refreshLcListIfOpen(_ref, LcListKind.templates);
      return true;
    }
    state = state.copyWith(
      isSaving: false,
      errorMessage: await lcFailureMessage(
        result,
        fallback: 'Could not save the template.',
      ),
    );
    return false;
  }

  /// Saves (POST, then PUT) the current form as a draft — H1 #71 / #74.
  Future<bool> saveDraft() async {
    final generation = SessionGeneration.current;
    state = state.copyWith(isSaving: true, clearMessages: true);
    final name = state.draft.draftName ?? _generatedDraftName();
    if (state.draft.draftName == null) {
      state = state.copyWith(draft: state.draft.copyWith(draftName: name));
    }
    final result = await _repo.saveDraft(
      _body(lcState: 'DRAFT', id: state.draftId),
      draftId: state.draftId,
    );
    if (!SessionGeneration.isCurrent(generation) || !mounted) return false;

    if (result is Success<String> && result.data != null) {
      state = state.copyWith(
        isSaving: false,
        draftId: result.data,
        infoMessage: 'Draft "$name" saved.',
      );
      refreshLcListIfOpen(_ref, LcListKind.drafts);
      return true;
    }
    state = state.copyWith(
      isSaving: false,
      errorMessage:
          await lcFailureMessage(result, fallback: 'Could not save the draft.'),
    );
    return false;
  }

  /// Discards the saved draft (H1 #80), if there is one.
  Future<void> discardDraft() async {
    final id = state.draftId;
    if (id == null) return;
    await _repo.deleteDraft(id);
    refreshLcListIfOpen(_ref, LcListKind.drafts);
  }

  /// User-initiated delete of the draft being edited. Returns true on success.
  Future<bool> deleteCurrentDraft() async {
    final id = state.draftId;
    if (id == null) return false;
    final generation = SessionGeneration.current;
    state = state.copyWith(isSaving: true, clearMessages: true);
    final result = await _repo.deleteDraft(id);
    if (!SessionGeneration.isCurrent(generation) || !mounted) return false;

    if (result is Success<bool>) {
      state = state.copyWith(isSaving: false);
      refreshLcListIfOpen(_ref, LcListKind.drafts);
      return true;
    }
    state = state.copyWith(
      isSaving: false,
      errorMessage: await lcFailureMessage(
        result,
        fallback: 'Could not delete the draft.',
      ),
    );
    return false;
  }

  // ── 08 Attachments ────────────────────────────────────────────────────

  int _attachmentSeq = 0;

  /// Adds picked files to the list under [category] / [documentType]. They
  /// are uploaded only when the user taps Upload ([uploadAttachments]), as
  /// on the web. Returns the files rejected by the upload rules (type,
  /// 5 MB, file name), one message each.
  List<String> addAttachments(
    List<(String name, List<int> bytes)> files, {
    String? category,
    String? documentType,
  }) {
    final rejected = <String>[];
    final added = <LcAttachment>[];
    for (final (name, bytes) in files) {
      final problem = LcAttachment.ruleViolation(name, bytes.length);
      if (problem != null) {
        rejected.add(problem);
        continue;
      }
      added.add(LcAttachment(
        key: '${DateTime.now().microsecondsSinceEpoch}-${_attachmentSeq++}',
        fileName: name,
        bytes: bytes,
        mimeType: LcAttachment.mimeFor(name),
        category: category,
        documentType: documentType,
      ));
    }
    if (added.isNotEmpty) {
      update((d) => d.copyWith(attachments: [...d.attachments, ...added]));
    }
    return rejected;
  }

  /// "Upload" — posts every file not uploaded yet, one at a time
  /// (`upload api.har`).
  Future<void> uploadAttachments() async {
    if (state.isUploading) return;
    final pending = [
      for (final a in state.draft.attachments)
        if (!a.isUploaded) a,
    ];
    if (pending.isEmpty) return;
    final generation = SessionGeneration.current;
    state = state.copyWith(isUploading: true, clearMessages: true);
    for (var i = 0; i < pending.length; i++) {
      final file = pending[i];
      _replaceAttachment(file.copyWith(uploading: true, clearError: true));
      final result = await _repo.uploadAttachment(
        file,
        index: i,
        fileCount: pending.length,
      );
      if (!SessionGeneration.isCurrent(generation) || !mounted) return;
      if (result is Success<String>) {
        _replaceAttachment(
          file.copyWith(uploading: false, contentId: result.data ?? ''),
        );
      } else {
        final message =
            await lcFailureMessage(result, fallback: 'Upload failed.');
        if (!mounted) return;
        _replaceAttachment(
          file.copyWith(uploading: false, error: message ?? 'Upload failed.'),
        );
      }
    }
    state = state.copyWith(isUploading: false);
  }

  /// Writes [attachment] without clearing messages or the charge preview.
  void _replaceAttachment(LcAttachment attachment) {
    state = state.copyWith(
      draft: state.draft.copyWith(attachments: [
        for (final a in state.draft.attachments)
          a.key == attachment.key ? attachment : a,
      ]),
    );
  }

  void updateAttachment(LcAttachment attachment) {
    update((d) => d.copyWith(attachments: [
          for (final a in d.attachments)
            a.key == attachment.key ? attachment : a,
        ]));
  }

  void removeAttachment(String key) {
    update((d) => d.copyWith(attachments: [
          for (final a in d.attachments)
            if (a.key != key) a,
        ]));
  }

  /// Submits the LC; call again with [otp] after an [LcAwaitingOtp].
  ///
  /// SUBMIT API NOT CAPTURED: `LC_inititation complete flow.har` stops
  /// before Submit. This posts the same body with `state: INITIATED` to
  /// `POST …/letterofcredits` (the OBDX spec `create` operation) — see
  /// `CorpTradeFinanceRepository.submitInitiation`. Re-check against a
  /// capture of the web Submit before release.
  Future<void> submit({String? otp}) async {
    for (final section in LcInitiateSection.values) {
      final errors = validate(section);
      if (errors.isNotEmpty) {
        state = state.copyWith(section: section, errorMessage: errors.first);
        return;
      }
    }
    final generation = SessionGeneration.current;
    state = state.copyWith(isSubmitting: true, clearMessages: true);
    final result = await _repo.submitInitiation(
      _body(lcState: 'INITIATED'),
      challenge: otp == null ? null : state.challenge,
      otp: otp,
    );
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;

    if (result is Success<LcSubmitOutcome>) {
      switch (result.data) {
        case LcAwaitingOtp(:final challenge):
          state = state.copyWith(
            isSubmitting: false,
            challenge: challenge,
            otpError: otp == null ? null : 'Incorrect code. Please try again.',
            clearOtpError: otp == null,
          );
          return;
        case final LcSubmitted submitted:
          // The draft (if any) has served its purpose.
          await discardDraft();
          if (!mounted) return;
          state = state.copyWith(
            isSubmitting: false,
            clearChallenge: true,
            outcome: submitted,
          );
          refreshLcListIfOpen(_ref, LcListKind.importLc);
          return;
        case null:
          break;
      }
    }
    final message =
        await lcFailureMessage(result, fallback: 'Could not submit the LC.');
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    state = otp != null && state.challenge != null
        ? state.copyWith(isSubmitting: false, otpError: message)
        : state.copyWith(
            isSubmitting: false,
            clearChallenge: true,
            errorMessage: message,
          );
  }

  void cancelOtp() => state = state.copyWith(clearChallenge: true);

  /// `LC_CREATE_<party 4>_<4 digits>` — the pattern the web uses
  /// (`LC_CREATE_18BA_2189`, H1 #71).
  String _generatedDraftName() {
    final party = currentLcParty(_ref).value ?? '';
    final tag = party.length >= 6 ? party.substring(2, 6) : 'CORP';
    final stamp = DateTime.now().millisecondsSinceEpoch % 10000;
    return 'LC_CREATE_${tag}_${stamp.toString().padLeft(4, '0')}';
  }
}

final corpLcInitiateProvider = StateNotifierProvider.autoDispose<
    CorpLcInitiateNotifier, CorpLcInitiateState>(
  (ref) => CorpLcInitiateNotifier(ref),
);
