import 'package:ubci_bank/src/core/models/corp/trade_finance/bank_guarantee_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_bank_guarantee_providers.dart';

/// Route arguments for the Bank Guarantee screens (see `CorpRoutes`).

/// One guarantee's details. [seed] is the list row, shown while the
/// detail loads (and if it fails).
class BgDetailArgs {
  const BgDetailArgs({required this.seed});

  final CorpBankGuarantee seed;
}

/// One amendment awaiting acceptance, read-only.
class BgAmendmentArgs {
  const BgAmendmentArgs({required this.amendment});

  final CorpBgAmendment amendment;
}

/// Review and send an approve / reject decision.
class BgAcceptanceReviewArgs {
  const BgAcceptanceReviewArgs({required this.request});

  final BgAcceptanceRequest request;
}

/// Lodge a claim under [guarantee].
class BgClaimArgs {
  const BgClaimArgs({required this.guarantee});

  final CorpBankGuarantee guarantee;
}
