import 'package:ubci_bank/src/core/models/common/statement_format.dart';
import 'package:ubci_bank/src/core/models/retail/certificate_models.dart';
import 'package:ubci_bank/src/infra/network/apis/retail/obdx_certificates_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/statement_download.dart';
import 'package:ubci_bank/src/infra/repositories/common/obdx_repository_base.dart';

/// Certificates (Interest, Balance, TDS): parses [ObdxCertificatesApi]
/// answers; the PDFs go through the shared statement decoder.
/// docs/obdx/features/certificates.md.
class CertificatesRepository extends ObdxRepositoryBase {
  CertificatesRepository({required ObdxCertificatesApi api}) : _api = api;

  final ObdxCertificatesApi _api;

  /// OBDX downloads PDF only (`media=application/pdf`).
  static const pdf = StatementFormat(code: 'pdf', mimeType: 'application/pdf');

  /// `branchDateDefinitionDTO.currentDate`, date only.
  Future<ResponseHandler<DateTime>> fetchBranchDate() async => parseBody(await _api.fetchCurrentDate(), (body) {
        final raw = ObdxApiUtils.asMap(body['branchDateDefinitionDTO'])['currentDate']?.toString();
        final d = DateTime.tryParse(raw ?? '');
        if (d == null) throw StateError('No branch date');
        return DateTime(d.year, d.month, d.day);
      });

  Future<ResponseHandler<List<CertificateAccount>>> fetchAccounts(CertificateCategory category) async =>
      parseBody(await _api.fetchAccounts(category), CertificateAccount.listFromPayload);

  Future<ResponseHandler<List<InterestRow>>> fetchInterest(InterestQuery q) async =>
      parseBody(await _api.fetchInterest(_interestRequest(q)), InterestRow.listFromPayload);

  Future<ResponseHandler<StatementFile>> downloadInterest(InterestQuery q) async => decodeStatementDownload(
        await _api.downloadInterest(_interestRequest(q), q.category),
        format: pdf,
        fileName: statementFileName(q.category.name, 'pdf', prefix: 'interest_certificate'),
      );

  Future<ResponseHandler<BalanceCertificate>> fetchBalance(DateTime month) async =>
      parseBody(await _api.fetchBalance(month), BalanceCertificate.fromPayload);

  Future<ResponseHandler<StatementFile>> downloadBalance(DateTime month) async => decodeStatementDownload(
        await _api.downloadBalance(month),
        format: pdf,
        fileName: statementFileName('${month.year}${month.month.toString().padLeft(2, '0')}', 'pdf',
            prefix: 'balance_certificate'),
      );

  Future<ResponseHandler<List<TdsRow>>> fetchTds(FinancialYear year, DateTime branchDate) async {
    final (from, to) = year.range(branchDate);
    return parseBody(await _api.fetchTds(from, to), TdsRow.listFromPayload);
  }

  Future<ResponseHandler<StatementFile>> downloadTds(FinancialYear year, DateTime branchDate) async {
    final (from, to) = year.range(branchDate);
    return decodeStatementDownload(
      await _api.downloadTds(from, to),
      format: pdf,
      fileName: statementFileName(year.label, 'pdf', prefix: 'tds_certificate'),
    );
  }

  (String, Map<String, dynamic>) _interestRequest(InterestQuery q) => ObdxCertificatesApi.interestRequest(
        category: q.category,
        accountId: q.account?.id,
        module: q.account?.module,
        fromDate: q.fromDate,
        toDate: q.toDate,
      );
}

/// One Interest Certificates search. [account] null = All Accounts.
class InterestQuery {
  const InterestQuery({required this.category, required this.fromDate, required this.toDate, this.account});

  final CertificateCategory category;
  final CertificateAccount? account;
  final String fromDate;
  final String toDate;

  @override
  bool operator ==(Object other) =>
      other is InterestQuery &&
      other.category == category &&
      other.account?.id == account?.id &&
      other.fromDate == fromDate &&
      other.toDate == toDate;

  @override
  int get hashCode => Object.hash(category, account?.id, fromDate, toDate);
}
