import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/corp_bank_configuration.dart';
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
    this.isLoading = false,
  });

  final CorpUserProfile? profile;
  final CorpParty? party;
  final CorpBankConfiguration bankConfiguration;
  final int unreadMessageCount;
  final bool isLoading;

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
    bool? isLoading,
  }) {
    return CorpProfileState(
      profile: profile ?? this.profile,
      party: party ?? this.party,
      bankConfiguration: bankConfiguration ?? this.bankConfiguration,
      unreadMessageCount: unreadMessageCount ?? this.unreadMessageCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class CorpProfileNotifier extends StateNotifier<CorpProfileState> {
  CorpProfileNotifier(this._ref) : super(const CorpProfileState());

  final Ref _ref;
  bool _loadedOnce = false;
  Future<void>? _pendingLoad;

  /// Seeds [CorpProfileState.profile] from the login trace's `me` response.
  /// Safe to call on every build — it no-ops once a profile is present.
  void seedFromProfileResponse(dynamic profileResponse) {
    if (state.profile != null) return;
    final profile = CorpUserProfile.fromProfileResponse(profileResponse);
    if (profile == null) return;
    state = state.copyWith(profile: profile);
  }

  Future<void> ensureLoaded() {
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
    ]);

    _loadedOnce = true;
    if (!mounted) return;

    final party = results[0];
    final bankConfig = results[1];
    final unread = results[2];

    state = state.copyWith(
      isLoading: false,
      party: party is Success<CorpParty> ? party.data : null,
      bankConfiguration: bankConfig is Success<CorpBankConfiguration>
          ? bankConfig.data
          : null,
      unreadMessageCount: unread is Success<int> ? (unread.data ?? 0) : null,
    );
  }
}

final corpProfileProvider =
    StateNotifierProvider<CorpProfileNotifier, CorpProfileState>(
  (ref) => CorpProfileNotifier(ref),
);
