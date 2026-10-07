import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';

/// Route arguments for the Letter of Credit screens (see `CorpRoutes`).

class LcDetailArgs {
  const LcDetailArgs({required this.lcId, this.lcType = LcType.importLc});

  final String lcId;
  final LcType lcType;
}

/// How the Initiate LC wizard is prefilled — one per Initiate LC tab.
enum LcInitiateSource {
  /// "Create LC" — empty form.
  blank,

  /// By Template — [LcInitiateArgs.seed] is the template row.
  template,

  /// Copy & Initiate — [LcInitiateArgs.seed] is the LC to duplicate.
  copy,

  /// By Drafts — [LcInitiateArgs.seed] is the draft; saves update it.
  draft,

  /// Back to Back LC — [LcInitiateArgs.seed] is the backing Export LC.
  backToBack,
}

class LcInitiateArgs {
  const LcInitiateArgs({
    this.seed,
    this.draftId,
    this.source = LcInitiateSource.blank,
  });

  const LcInitiateArgs.fromTemplate(CorpLetterOfCredit template)
      : seed = template,
        draftId = null,
        source = LcInitiateSource.template;

  const LcInitiateArgs.copyOf(CorpLetterOfCredit lc)
      : seed = lc,
        draftId = null,
        source = LcInitiateSource.copy;

  LcInitiateArgs.fromDraft(CorpLetterOfCredit draft)
      : seed = draft,
        draftId = draft.id,
        source = LcInitiateSource.draft;

  const LcInitiateArgs.backToBack(CorpLetterOfCredit exportLc)
      : seed = exportLc,
        draftId = null,
        source = LcInitiateSource.backToBack;

  /// The row the wizard is prefilled from (see [source]).
  final CorpLetterOfCredit? seed;

  /// Set when [seed] is a draft, so saves update it instead of creating one.
  final String? draftId;

  final LcInitiateSource source;
}

class LcAmendArgs {
  const LcAmendArgs({required this.lcId});

  final String lcId;
}

class LcAcceptanceArgs {
  const LcAcceptanceArgs({required this.amendment});

  final CorpLcAmendment amendment;
}

class LcTransferArgs {
  const LcTransferArgs({required this.lcId});

  final String lcId;
}

/// One export bill — View Export Bill.
class ExportBillArgs {
  const ExportBillArgs({required this.billId});

  final String billId;
}
