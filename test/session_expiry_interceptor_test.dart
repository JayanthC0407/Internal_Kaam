import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/interceptors/session_expiry_interceptor.dart';
import 'package:ubci_bank/src/infra/session/session_expiry_coordinator.dart';

void main() {
  late SessionExpiryCoordinator coordinator;

  setUp(() {
    coordinator = SessionExpiryCoordinator.instance;
    coordinator.reset();
  });

  tearDown(() {
    coordinator.reset();
  });

  DioException unauthorized({
    required String path,
    Map<String, dynamic>? body,
  }) {
    final options = RequestOptions(path: path);
    return DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: options,
        statusCode: StatusCode.UNAUTHORIZED,
        data: body ??
            {
              'detail': 'Invalid authentication token.',
              'code': 'DIGX_AU_035',
              'type': 'ERROR',
            },
      ),
    );
  }

  test('notifyExpired is debounced until reset', () async {
    var count = 0;
    final sub = coordinator.events.listen((_) => count++);

    coordinator.notifyExpired();
    coordinator.notifyExpired();
    await Future<void>.delayed(Duration.zero);
    expect(count, 1);
    expect(coordinator.isHandling, isTrue);

    coordinator.reset();
    coordinator.notifyExpired();
    await Future<void>.delayed(Duration.zero);
    expect(count, 2);

    await sub.cancel();
  });

  test('detects DIGX_AU_035 on protected CASA path', () {
    final err = unauthorized(path: ApiConst.accountsApiDemandDeposit);
    expect(SessionExpiryInterceptor.isInvalidTokenResponse(err), isTrue);
  });

  test('ignores 401 on auth-free login path', () {
    final err = unauthorized(path: ApiConst.loginApi);
    expect(SessionExpiryInterceptor.isInvalidTokenResponse(err), isFalse);
  });

  test('detects invalid authentication token detail without code', () {
    final err = unauthorized(
      path: ApiConst.profileApi,
      body: {'detail': 'Invalid authentication token.'},
    );
    expect(SessionExpiryInterceptor.isInvalidTokenResponse(err), isTrue);
  });

  test('ignores non-401 failures', () {
    final options = RequestOptions(path: ApiConst.accountsApiDemandDeposit);
    final err = DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: options,
        statusCode: StatusCode.INTERNAL_SERVER_ERROR,
        data: {'detail': 'boom'},
      ),
    );
    expect(SessionExpiryInterceptor.isInvalidTokenResponse(err), isFalse);
  });
}
