import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_accounts_repository.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_profile_repository.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_network_providers.dart';

final corpAccountsRepositoryProvider = Provider(
  (ref) => CorpAccountsRepository(
    accountsApi: ref.watch(obdxCorpAccountsApiProvider),
  ),
);

final corpProfileRepositoryProvider = Provider(
  (ref) => CorpProfileRepository(
    profileApi: ref.watch(obdxCorpProfileApiProvider),
  ),
);
