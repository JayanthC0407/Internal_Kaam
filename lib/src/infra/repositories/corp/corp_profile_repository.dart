import 'package:ubci_bank/src/core/models/corp/corp_bank_configuration.dart';
import 'package:ubci_bank/src/core/models/corp/corp_currency.dart';
import 'package:ubci_bank/src/core/models/corp/corp_party.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_profile_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_repository_base.dart';

/// Corporate profile context: the party behind the logged-in user, the bank
/// configuration, and the header's unread-message count.
class CorpProfileRepository extends CorpRepositoryBase {
  CorpProfileRepository({required ObdxCorpProfileApi profileApi})
      : _profileApi = profileApi;

  final ObdxCorpProfileApi _profileApi;

  Future<ResponseHandler<CorpParty>> fetchParty() async {
    try {
      final result = await _profileApi.fetchParty();
      return parseBody(result, (body) {
        final party = CorpParty.fromPayload(body);
        if (party == null) throw StateError('Empty party payload');
        return party;
      });
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  /// Currency master for labelling exposure rows. Never fatal — the
  /// Currency Exposure widget falls back to raw ISO codes.
  Future<ResponseHandler<List<CorpCurrency>>> fetchCurrencies() async {
    try {
      final result = await _profileApi.fetchCurrencies();
      return parseBody(result, CorpCurrency.listFromPayload);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<CorpBankConfiguration>>
      fetchBankConfiguration() async {
    try {
      final result = await _profileApi.fetchBankConfiguration();
      return parseBody(result, CorpBankConfiguration.fromPayload);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  /// Unread-message count for the header bell. `mailbox/count` returns the
  /// figure under one of a few keys depending on host version, so this
  /// reads the first numeric one it finds rather than assuming a shape.
  Future<ResponseHandler<int>> fetchUnreadMessageCount() async {
    try {
      final result = await _profileApi.fetchMailboxCount();
      return parseBody(result, (body) {
        for (final key in const [
          'count',
          'unreadCount',
          'totalCount',
          'mailBoxCount',
        ]) {
          final value = body[key];
          if (value is num) return value.toInt();
          final parsed = int.tryParse(value?.toString() ?? '');
          if (parsed != null) return parsed;
        }
        return 0;
      });
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }
}
