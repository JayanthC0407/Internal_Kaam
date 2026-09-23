import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_accounts_api.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_profile_api.dart';
import 'package:ubci_bank/src/view/providers/common/network_providers.dart';

/// Corporate API providers. They share the single app-wide Dio client
/// (`obdxDioClientProvider`) with the Retail APIs, so auth, cookies, SSL
/// pinning and session-expiry handling stay in one place.
final obdxCorpAccountsApiProvider = Provider(
  (ref) => ObdxCorpAccountsApi(ref.watch(obdxDioClientProvider)),
);

final obdxCorpProfileApiProvider = Provider(
  (ref) => ObdxCorpProfileApi(ref.watch(obdxDioClientProvider)),
);
