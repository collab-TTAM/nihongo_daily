/// TEST ONLY proof that an Auth response's exact refresh token reached the
/// Windows vault before the caller's own-profile request. Never logs or returns
/// either token; each proof is consumed once.
final class HostedSessionTokenProof {
  String? _grant;
  String? _submittedRefreshToken;
  String? _returnedRefreshToken;

  void clear() {
    _grant = null;
    _submittedRefreshToken = null;
    _returnedRefreshToken = null;
  }

  bool capture({
    required String grant,
    required int statusCode,
    required String? submittedRefreshToken,
    required String? returnedRefreshToken,
  }) {
    clear();
    if (statusCode != 200 ||
        !const {'password', 'refresh_token'}.contains(grant) ||
        !_validToken(returnedRefreshToken)) {
      return false;
    }
    if (grant == 'password' && submittedRefreshToken != null) {
      return false;
    }
    if (grant == 'refresh_token' &&
        (!_validToken(submittedRefreshToken) ||
            submittedRefreshToken == returnedRefreshToken)) {
      return false;
    }
    _grant = grant;
    _submittedRefreshToken = submittedRefreshToken;
    _returnedRefreshToken = returnedRefreshToken;
    return true;
  }

  bool verifyPersistedPasswordToken(String? persisted) {
    final returned = _returnedRefreshToken;
    final verified =
        _grant == 'password' && returned != null && persisted == returned;
    clear();
    return verified;
  }

  bool verifyRotatedRefreshToken(String? persisted) {
    final submitted = _submittedRefreshToken;
    final returned = _returnedRefreshToken;
    final verified =
        _grant == 'refresh_token' &&
        submitted != null &&
        returned != null &&
        submitted != returned &&
        persisted == returned;
    clear();
    return verified;
  }

  static bool _validToken(String? token) =>
      token != null &&
      token.isNotEmpty &&
      token.length <= 2048 &&
      token.codeUnits.every((unit) => unit >= 0x21 && unit <= 0x7e);
}
