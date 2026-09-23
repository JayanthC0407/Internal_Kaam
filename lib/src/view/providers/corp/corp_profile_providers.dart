import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/corp_bank_configuration.dart';
import 'package:ubci_bank/src/core/models/corp/corp_currency.dart';
import 'package:ubci_bank/src/core/models/corp/corp_party.dart';
import 'package:ubci_bank/src/core/models/corp/corp_user_profile.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_repository_providers.dart';

/// Corporate profile context for the dashboard chrome.
///
/// [profile] is seeded synchronously from the `me` response already captured
/// during login (no extra round trip), so the header renders the real user
/// name and initials on first frame. [party] and [bankConfiguration] are
/// then fetched to confirm the corporate entity name and the currency the
/// host reports its totals in.
class CorpProfileState {
  const CorpProfileState({
    this.profile,
    this.party,
    this.bankConfiguration = CorpBankConfiguration.empty,
    this.unreadMessageCount = 0,
    this.currencies = const <String, CorpCurrency>{},
    this.isLoading = false,
  });

  final CorpUserProfile? profile;
  final CorpParty? party;
  final CorpBankConfiguration bankConfiguration;
  final int unreadMessageCount;

  /// Currency master indexed by ISO code, for labelling amounts. Empty when
  /// the lookup failed — callers fall back to the raw code.
  final Map<String, CorpCurrency> currencies;

  final bool isLoading;

  /// Display name for [code], falling back to the code itself.
  String currencyLabel(String code) {
    final normalized = code.trim().toUpperCase();
    return currencies[normalized]?.label ?? normalized;
  }

  /// Corporate entity name — `me/party` wins over the `me` response, which
  /// can carry a stale entity label.
  String? get entityName {
    final fromParty = party?.fullName?.trim();
    if (fromParty != null && fromParty.isNotEmpty) return fromParty;
    final fromProfile = profile?.partyName?.trim();
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    return null;
  }

  /// Name shown in the dashboard header / on the account card.
  String displayName(String fallback) {
    final name = profile?.fullName.trim();
    if (name != null && name.isNotEmpty) return name;
    return fallback;
  }

  /// Currency the `summary.items[]` roll-ups are expressed in.
  String? get totalsCurrency => bankConfiguration.totalsCurrency;

  CorpProfileState copyWith({
    CorpUserProfile? profile,
    CorpParty? party,
    CorpBankConfiguration? bankConfiguration,
    int? unreadMessageCount,
    Map<String, CorpCurrency>? currencies,
    bool? isLoading,
  }) {
    return CorpProfileState(
      profile: profile ?? this.profile,
      party: party ?? this.party,
      bankConfiguration: bankConfiguration ?? this.bankConfiguration,
      unreadMessageCount: unreadMessageCount ?? this.unreadMessageCount,
      currencies: currencies ?? this.currencies,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class CorpProfileNotifier extends StateNotifier<CorpProfileState> {
  CorpProfileNotifier(this._ref) : super(const CorpProfileState());

  final Ref _ref;
  bool _loadedOnce = false;
  Future<void>? _pendingLoad;

  /// Seeds [CorpProfileState.profile] from the login trace's `me` response,
  /// so the header shows the real user without waiting on a network call.
  ///
  /// Never call this from a widget life-cycle method (`build`, `initState`,
  /// `dispose`, …) — Riverpod forbids mutating a provider while the tree is
  /// building. [ensureLoaded] takes the response and applies the seed from
  /// a post-frame callback instead, which is how the dashboard uses it.
  ///
  /// No-ops once a profile is present, so a rebuild cannot clobber a
  /// profile already confirmed by the network.
  void seedFromProfileResponse(dynamic profileResponse) {
    if (state.profile != null) return;
    final profile = CorpUserProfile.fromProfileResponse(profileResponse);
    if (profile == null) return;
    state = state.copyWith(profile: profile);
  }

  /// Seeds from [profileResponse] (when given) and then fetches the party /
  /// bank configuration / mailbox count, once per session.
  ///
  /// The seed is applied here rather than by a separate caller so it can
  /// never run inside a widget life-cycle: the dashboard invokes this from
  /// a post-frame callback.
  Future<void> ensureLoaded({dynamic profileResponse}) {
    if (profileResponse != null) seedFromProfileResponse(profileResponse);
    if (_loadedOnce) return Future.value();
    return _pendingLoad ??= refresh().whenComplete(() {
      _pendingLoad = null;
    });
  }

  /// Fetches party, bank configuration and the mailbox badge in parallel.
  ///
  /// None of these are required to render the dashboard, so a failure is
  /// swallowed rather than surfaced — the header simply keeps the values it
  /// already has from the login trace.
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    final repository = _ref.read(corpProfileRepositoryProvider);

    final results = await Future.wait([
      repository.fetchParty(),
      repository.fetchBankConfiguration(),
      repository.fetchUnreadMessageCount(),
      repository.fetchCurrencies(),
    ]);

    _loadedOnce = true;
    if (!mounted) return;

    final party = results[0];
    final bankConfig = results[1];
    final unread = results[2];
    final currencies = results[3];

    state = state.copyWith(
      isLoading: false,
      party: party is Success<CorpParty> ? party.data : null,
      bankConfiguration: bankConfig is Success<CorpBankConfiguration>
          ? bankConfig.data
          : null,
      unreadMessageCount: unread is Success<int> ? (unread.data ?? 0) : null,
      currencies: currencies is Success<List<CorpCurrency>>
          ? CorpCurrency.indexByCode(currencies.data ?? const [])
          : null,
    );
  }
}

final corpProfileProvider =
    StateNotifierProvider<CorpProfileNotifier, CorpProfileState>(
  (ref) => CorpProfileNotifier(ref),
);
