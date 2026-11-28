import 'package:flutter_test/flutter_test.dart';
import '../../../tool/hosted_session_token_proof.dart';

void main() {
  group('TEST ONLY hosted Windows refresh-token proof', () {
    test('password grant requires the exact persisted response token', () {
      final proof = HostedSessionTokenProof();
      expect(
        proof.capture(
          grant: 'password',
          statusCode: 200,
          submittedRefreshToken: null,
          returnedRefreshToken: 'TEST_ONLY_A_PASSWORD_ROTATED',
        ),
        isTrue,
      );
      expect(
        proof.verifyPersistedPasswordToken('TEST_ONLY_A_PASSWORD_ROTATED'),
        isTrue,
      );
    });

    test('password mismatch consumes the proof and cannot be retried', () {
      final proof = HostedSessionTokenProof();
      expect(
        proof.capture(
          grant: 'password',
          statusCode: 200,
          submittedRefreshToken: null,
          returnedRefreshToken: 'TEST_ONLY_PASSWORD_ROTATED',
        ),
        isTrue,
      );
      expect(
        proof.verifyPersistedPasswordToken('TEST_ONLY_WRONG_TOKEN'),
        isFalse,
      );
      expect(
        proof.verifyPersistedPasswordToken('TEST_ONLY_PASSWORD_ROTATED'),
        isFalse,
      );
    });

    test('refresh proof requires a changed token and exact persistence', () {
      final proof = HostedSessionTokenProof();
      expect(
        proof.capture(
          grant: 'refresh_token',
          statusCode: 200,
          submittedRefreshToken: 'TEST_ONLY_OLD_REFRESH',
          returnedRefreshToken: 'TEST_ONLY_NEW_REFRESH',
        ),
        isTrue,
      );
      expect(proof.verifyRotatedRefreshToken('TEST_ONLY_NEW_REFRESH'), isTrue);
    });

    test('unchanged refresh token cannot prove rotation', () {
      final proof = HostedSessionTokenProof();
      expect(
        proof.capture(
          grant: 'refresh_token',
          statusCode: 200,
          submittedRefreshToken: 'TEST_ONLY_SAME_REFRESH',
          returnedRefreshToken: 'TEST_ONLY_SAME_REFRESH',
        ),
        isFalse,
      );
      expect(
        proof.verifyRotatedRefreshToken('TEST_ONLY_SAME_REFRESH'),
        isFalse,
      );
    });

    test('failed or malformed response clears an earlier proof', () {
      final proof = HostedSessionTokenProof();
      expect(
        proof.capture(
          grant: 'password',
          statusCode: 200,
          submittedRefreshToken: null,
          returnedRefreshToken: 'TEST_ONLY_PREVIOUS',
        ),
        isTrue,
      );
      expect(
        proof.capture(
          grant: 'password',
          statusCode: 401,
          submittedRefreshToken: null,
          returnedRefreshToken: 'TEST_ONLY_REJECTED',
        ),
        isFalse,
      );
      expect(proof.verifyPersistedPasswordToken('TEST_ONLY_PREVIOUS'), isFalse);
      expect(
        proof.capture(
          grant: 'password',
          statusCode: 200,
          submittedRefreshToken: null,
          returnedRefreshToken: null,
        ),
        isFalse,
      );
      expect(
        proof.capture(
          grant: 'password',
          statusCode: 200,
          submittedRefreshToken: null,
          returnedRefreshToken: List<String>.filled(2049, 'X').join(),
        ),
        isFalse,
      );
    });

    test('proof is grant-specific and consumed exactly once', () {
      final proof = HostedSessionTokenProof();
      expect(
        proof.capture(
          grant: 'password',
          statusCode: 200,
          submittedRefreshToken: null,
          returnedRefreshToken: 'TEST_ONLY_PASSWORD',
        ),
        isTrue,
      );
      expect(proof.verifyRotatedRefreshToken('TEST_ONLY_PASSWORD'), isFalse);
      expect(proof.verifyPersistedPasswordToken('TEST_ONLY_PASSWORD'), isFalse);
    });
  });
}
