import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/retail/certificate_models.dart';
import 'package:ubci_bank/src/infra/network/apis/retail/obdx_certificates_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/retail/certificates_repository.dart';
import 'package:ubci_bank/src/view/providers/common/network_providers.dart';

/// Certificates (docs/obdx/features/certificates.md). autoDispose: loaded
/// while a certificate screen is open.

final obdxCertificatesApiProvider = Provider((ref) => ObdxCertificatesApi(ref.watch(obdxDioClientProvider)));

final certificatesRepositoryProvider =
    Provider((ref) => CertificatesRepository(api: ref.watch(obdxCertificatesApiProvider)));

/// The branch date every list is built from (`GET common currentDate`).
/// When it fails the device date is used, so the screens still open.
final certificateBranchDateProvider = FutureProvider.autoDispose<DateTime>((ref) async {
  final result = await ref.read(certificatesRepositoryProvider).fetchBranchDate();
  if (result is Success<DateTime> && result.data != null) return result.data!;
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Interest Certificates' account list for one category.
final certificateAccountsProvider = FutureProvider.autoDispose
    .family<List<CertificateAccount>, CertificateCategory>((ref, category) async {
  final result = await ref.read(certificatesRepositoryProvider).fetchAccounts(category);
  if (result is Success<List<CertificateAccount>> && result.data != null) return result.data!;
  throw CertificatesLoadError(result is Error<List<CertificateAccount>> ? result.error : null);
});

final interestCertificateProvider =
    FutureProvider.autoDispose.family<List<InterestRow>, InterestQuery>((ref, query) async {
  final result = await ref.read(certificatesRepositoryProvider).fetchInterest(query);
  if (result is Success<List<InterestRow>> && result.data != null) return result.data!;
  throw CertificatesLoadError(result is Error<List<InterestRow>> ? result.error : null);
});

final balanceCertificateProvider =
    FutureProvider.autoDispose.family<BalanceCertificate, DateTime>((ref, month) async {
  final result = await ref.read(certificatesRepositoryProvider).fetchBalance(month);
  if (result is Success<BalanceCertificate> && result.data != null) return result.data!;
  throw CertificatesLoadError(result is Error<BalanceCertificate> ? result.error : null);
});

/// TDS for one financial year; the branch date fixes the current FY's end.
final tdsCertificateProvider =
    FutureProvider.autoDispose.family<List<TdsRow>, (FinancialYear, DateTime)>((ref, key) async {
  final result = await ref.read(certificatesRepositoryProvider).fetchTds(key.$1, key.$2);
  if (result is Success<List<TdsRow>> && result.data != null) return result.data!;
  throw CertificatesLoadError(result is Error<List<TdsRow>> ? result.error : null);
});

/// Load failure; [message] is OBDX's text when the server sent one.
class CertificatesLoadError implements Exception {
  const CertificatesLoadError(this.message);

  final String? message;

  @override
  String toString() => message ?? 'CertificatesLoadError';
}
