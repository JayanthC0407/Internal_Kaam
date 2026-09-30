import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';

/// Route arguments for the Letter of Credit screens (see `CorpRoutes`).

class LcDetailArgs {
  const LcDetailArgs({required this.lcId, this.lcType = LcType.importLc});

  final String lcId;
  final LcType lcType;
}

class LcInitiateArgs {
  const LcInitiateArgs({this.seed, this.draftId});

  /// Existing LC to copy, or a saved draft to continue.
  final CorpLetterOfCredit? seed;

  /// Set when [seed] is a draft, so saves update it instead of creating one.
  final String? draftId;
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
