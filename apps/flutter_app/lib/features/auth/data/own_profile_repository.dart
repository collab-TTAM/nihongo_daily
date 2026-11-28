import 'dart:async';
import '../../srs/data/review_repository.dart';

/// Additive nd-own-profile-1. No caller ID, Auth metadata or direct table write.
final class OwnProfile {
  const OwnProfile._(
    this.id,
    this.displayName,
    this.level,
    this.dailyTargetMinutes,
    this.timezone,
  );
  final String id;
  final String displayName;
  final String level;
  final int dailyTargetMinutes;
  final String timezone;
  Map<String, Object> toJson() => {
    'id': id,
    'display_name': displayName,
    'preferred_jlpt': level,
    'daily_target_minutes': dailyTargetMinutes,
    'timezone': timezone,
  };
}

OwnProfile decodeOwnProfile(Object? raw, String expectedOwner) {
  try {
    if (raw is! Map<String, Object?> ||
        raw.length != 5 ||
        !const {
          'id',
          'display_name',
          'preferred_jlpt',
          'daily_target_minutes',
          'timezone',
        }.every(raw.containsKey)) {
      throw const FormatException();
    }
    final id = raw['id'];
    final name = raw['display_name'];
    final level = raw['preferred_jlpt'];
    final minutes = raw['daily_target_minutes'];
    final zone = raw['timezone'];
    if (id is! String ||
        id != ReviewSession(userId: expectedOwner).userId ||
        name is! String ||
        name.runes.length > 100 ||
        level is! String ||
        !const {'N5', 'N4', 'N3', 'N2', 'N1'}.contains(level) ||
        minutes is! int ||
        minutes < 7 ||
        minutes > 1440 ||
        zone is! String ||
        zone.isEmpty ||
        zone.length > 100 ||
        !RegExp(r'^[A-Za-z0-9_+-]+(?:/[A-Za-z0-9_+-]+)*$').hasMatch(zone)) {
      throw const FormatException();
    }
    return OwnProfile._(id, name, level, minutes, zone);
  } on Object {
    throw const ReviewTransportFailure(ReviewErrorCode.internalError);
  }
}

final class RpcOwnProfileRepository {
  RpcOwnProfileRepository({
    required this.auth,
    required this.transport,
    this.timeout = const Duration(seconds: 15),
  }) {
    if (timeout <= Duration.zero || timeout > const Duration(minutes: 2)) {
      throw ArgumentError('Expected timeout in (0, 2 minutes]');
    }
  }
  final ReviewAuth auth;
  final ReviewRpcTransport transport;
  final Duration timeout;
  Future<OwnProfile> ensure() async {
    final session = auth.currentSession;
    if (session == null) {
      throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
    }
    try {
      final raw = await transport
          .invoke(
            capturedSession: session,
            function: 'ensure_profile',
            params: const {'p_request': <String, Object>{}},
          )
          .timeout(timeout);
      if (!identical(auth.currentSession, session)) {
        throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
      }
      if (raw is Map<String, Object?> && raw.containsKey('code')) {
        final outcome = decodeReviewOutcome(raw);
        if (outcome is ReviewFailure) {
          throw ReviewTransportFailure(
            outcome.code,
            retryable: outcome.retryable,
          );
        }
      }
      return decodeOwnProfile(raw, session.userId);
    } on TimeoutException {
      throw ReviewTransportFailure(
        identical(auth.currentSession, session)
            ? ReviewErrorCode.networkUnavailable
            : ReviewErrorCode.unauthorized,
        retryable: identical(auth.currentSession, session),
      );
    } on ReviewTransportFailure {
      if (!identical(auth.currentSession, session)) {
        throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
      }
      rethrow;
    } on Object {
      throw ReviewTransportFailure(
        identical(auth.currentSession, session)
            ? ReviewErrorCode.internalError
            : ReviewErrorCode.unauthorized,
      );
    }
  }
}
