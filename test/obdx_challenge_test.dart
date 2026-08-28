import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/obdx_challenge.dart';

void main() {
  group('ObdxChallenge', () {
    test('parses X-Challenge header JSON', () {
      final challenge = ObdxChallenge.fromResponseHeaders({
        'x-challenge': [
          '{"authType":"OTP","referenceNo":"21303","attemptsLeft":4,'
          '"scope":"USERTASK","resendsLeft":3}',
        ],
      });

      expect(challenge, isNotNull);
      expect(challenge!.authType, 'OTP');
      expect(challenge.referenceNo, '21303');
      expect(challenge.attemptsLeft, 4);
      expect(challenge.resendsLeft, 3);
    });

    test('builds X-CHALLENGE_RESPONSE header value', () {
      const challenge = ObdxChallenge(
        authType: 'OTP',
        referenceNo: '21305',
        attemptsLeft: 3,
      );

      expect(
        challenge.toChallengeResponseHeader('1111'),
        '{"otp":"1111","referenceNo":"21305","authType":"OTP"}',
      );
    });

    test('falls back to status.referenceNumber when X-Challenge missing', () {
      final challenge = ObdxChallenge.fromResponse(
        headers: <String, List<String>>{},
        body: {
          'status': {
            'result': 'EXPECTATION_FAILED',
            'referenceNumber': '2026195004282079',
            'message': {'code': 'DIGX_AUTH_0003', 'type': 'INFO'},
          },
        },
      );

      expect(challenge, isNotNull);
      expect(challenge!.referenceNo, '2026195004282079');
      expect(challenge.authType, 'OTP');
    });
  });
}
