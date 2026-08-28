import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/core/models/obdx_error.dart';
import 'package:ubci_bank/src/infra/network/obdx_error_mapper.dart';

void main() {
  group('ObdxErrorMapper', () {
    test('parses OBDX status.message.detail', () {
      final error = ObdxErrorMapper.fromPayload({
        'status': {
          'code': 'DIGX_AUTH_0001',
          'message': {
            'detail': 'Invalid credentials provided',
          },
        },
      }, statusCode: StatusCode.BAD_REQUEST);

      expect(error, isNotNull);
      expect(error!.obdxCode, 'DIGX_AUTH_0001');
      expect(error.userMessage, 'Invalid credentials provided');
      expect(error.category, ObdxErrorCategory.unauthorized);
    });

    test('maps known OBDX code when detail is absent', () {
      final error = ObdxErrorMapper.fromPayload({
        'status': {'code': 'USER_LOCKED'},
      }, statusCode: StatusCode.UNAUTHORIZED);

      expect(error?.userMessage,
          'Your account is locked. Please contact the bank.');
    });

    test('maps DIGX_AU_035 invalid token to session expired (localized fallback)', () {
      final error = ObdxErrorMapper.fromPayload({
        'title': null,
        'detail': 'Invalid authentication token.',
        'code': 'DIGX_AU_035',
        'validationError': null,
        'type': 'ERROR',
      }, statusCode: StatusCode.UNAUTHORIZED);

      expect(error, isNotNull);
      expect(error!.obdxCode, 'DIGX_AU_035');
      expect(error.l10nKey, 'errorSessionExpired');
      expect(error.category, ObdxErrorCategory.unauthorized);
      expect(
        error.userMessage,
        'For your security, you have been signed out. Please sign in again.',
      );
    });

    test('maps invalid authentication token detail without code', () {
      final error = ObdxErrorMapper.fromPayload({
        'detail': 'Invalid authentication token.',
      }, statusCode: StatusCode.UNAUTHORIZED);

      expect(error?.l10nKey, 'errorSessionExpired');
      expect(error?.category, ObdxErrorCategory.unauthorized);
    });

    test('maps DIGX_DB_AUTH_005 from jwt error body', () {
      final error = ObdxErrorMapper.fromPayload({
        'result': 'SUCCESSFUL',
        'message': {'code': 'DIGX_DB_AUTH_005', 'type': 'ERROR'},
      }, statusCode: StatusCode.BAD_REQUEST);

      expect(error?.obdxCode, 'DIGX_DB_AUTH_005');
      expect(
        error?.userMessage,
        contains('Mobile quick access is not enabled'),
      );
    });

    test('extracts title from top-level DIGX_PROD_DEF_0000 message object', () {
      final error = ObdxErrorMapper.fromPayload({
        'title':
            'System cannot process the request currently. Please try later.',
        'detail':
            'System cannot process the request currently. Please try later.',
        'code': 'DIGX_PROD_DEF_0000',
        'type': 'ERROR',
      }, statusCode: StatusCode.BAD_REQUEST);

      expect(error?.obdxCode, 'DIGX_PROD_DEF_0000');
      expect(error?.l10nKey, isNull);
      expect(
        error?.userMessage,
        'System cannot process the request currently. Please try later.',
      );
      expect(error?.userMessage.contains('{title:'), isFalse);
    });

    test('extracts detail from nested message map without Map.toString', () {
      final error = ObdxErrorMapper.fromPayload({
        'message': {
          'title':
              'System cannot process the request currently. Please try later.',
          'detail':
              'System cannot process the request currently. Please try later.',
          'code': 'DIGX_PROD_DEF_0000',
          'type': 'ERROR',
        },
      }, statusCode: StatusCode.BAD_REQUEST);

      expect(error?.obdxCode, 'DIGX_PROD_DEF_0000');
      expect(error?.l10nKey, isNull);
      expect(error?.userMessage.contains('{title:'), isFalse);
      expect(
        error?.userMessage,
        'System cannot process the request currently. Please try later.',
      );
    });

    test('uses API detail for SUCCESSFUL result with ERROR message', () {
      final error = ObdxErrorMapper.fromHttpResponse(200, {
        'result': 'SUCCESSFUL',
        'contextID': 'abc',
        'message': {
          'title':
              'System cannot process the request currently. Please try later.',
          'detail':
              'System cannot process the request currently. Please try later.',
          'code': 'DIGX_PROD_DEF_0000',
          'type': 'ERROR',
        },
      });

      expect(error.obdxCode, 'DIGX_PROD_DEF_0000');
      expect(error.l10nKey, isNull);
      expect(
        error.userMessage,
        'System cannot process the request currently. Please try later.',
      );
      expect(error.userMessage, isNot('Something went wrong. Please try again.'));
    });

    test('falls back to HTTP status message', () {
      final error = ObdxErrorMapper.fromHttpResponse(
        StatusCode.NOT_FOUND,
        const {},
      );

      expect(error.userMessage, 'The requested resource was not found.');
      expect(error.category, ObdxErrorCategory.notFound);
    });

    test('maps connection timeout DioException', () {
      final error = ObdxErrorMapper.fromDioException(
        DioException(
          requestOptions: RequestOptions(path: '/login'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(error.category, ObdxErrorCategory.timeout);
      expect(error.isNetworkIssue, isTrue);
      expect(error.l10nKey, 'errorTimeout');
    });

    test('maps connection refused to service unavailable', () {
      final error = ObdxErrorMapper.fromDioException(
        DioException(
          requestOptions: RequestOptions(path: '/login'),
          type: DioExceptionType.connectionError,
          message: 'The connection errored: Connection refused',
        ),
      );

      expect(error.category, ObdxErrorCategory.server);
      expect(error.l10nKey, 'errorServerUnavailable');
      expect(error.isNetworkIssue, isFalse);
    });

    test('parses plain message field', () {
      final error = ObdxErrorMapper.fromPayload(
        {'message': 'Username not found'},
        statusCode: StatusCode.BAD_REQUEST,
      );

      expect(error?.userMessage, 'Username not found');
    });

    test('parses JSON string body', () {
      final message = ObdxErrorMapper.messageFromBody(
        '{"status":{"message":{"detail":"Service unavailable"}}}',
        statusCode: StatusCode.SERVICE_UNAVAILABLE,
      );

      expect(message, 'Service unavailable');
    });

    test('maps profile 417 DIGX_AUTH_0003 to invalid OTP', () {
      final error = ObdxErrorMapper.fromProfileResponse(
        417,
        {
          'status': {
            'result': 'EXPECTATION_FAILED',
            'message': {'code': 'DIGX_AUTH_0003', 'type': 'INFO'},
          },
        },
      );

      expect(error.l10nKey, 'errorOtpInvalid');
      expect(error.httpStatusCode, 417);
    });

    test('extracts OBDX code from status.message.code', () {
      final error = ObdxErrorMapper.fromPayload({
        'status': {
          'result': 'EXPECTATION_FAILED',
          'message': {'code': 'DIGX_AUTH_0003', 'type': 'INFO'},
        },
      }, statusCode: 417);

      expect(error?.obdxCode, 'DIGX_AUTH_0003');
    });

    test('maps HTTP 423 to account locked', () {
      final error = ObdxErrorMapper.fromHttpResponse(423, const {});

      expect(error.l10nKey, 'errorAccountLocked');
    });

    test('prefers validationError DIGX_AUTH_0012 over Validations Failed title', () {
      final error = ObdxErrorMapper.fromHttpResponse(400, {
        'result': 'SUCCESSFUL',
        'message': {
          'title': 'Validations Failed.',
          'detail': 'Validations Failed.',
          'code': '10011',
          'validationError': [
            {
              'objectName': 'authInfo',
              'attributeName': 'authInfo',
              'errorCode': 'DIGX_AUTH_0012',
              'errorMessage':
                  'You have exceeded maximum allowed limit for generating authorization tokens. Please try after some time.',
            },
          ],
          'type': 'ERROR',
        },
      });

      expect(error.obdxCode, 'DIGX_AUTH_0012');
      expect(error.l10nKey, 'errorTooManyAttempts');
      expect(
        error.userMessage,
        contains('exceeded maximum allowed limit'),
      );
    });
  });
}
