import 'dart:async';

import '../../srs/data/review_repository.dart';
import '../domain/ai_text_models.dart';
import 'captured_ai_text_repository.dart';

/// Internal public-column projection, not a new frozen API operation. Never
/// include system_context, provider configuration, credentials or private joins.
final class ConversationScenario {
  const ConversationScenario._(
    this.id,
    this.level,
    this.titleVi,
    this.titleJa,
    this.descriptionVi,
    this.contentVersion,
  );
  final String id;
  final AiTextLevel level;
  final String titleVi;
  final String titleJa;
  final String descriptionVi;
  final int contentVersion;
}

/// Borrowed trusted read port: fixed conversation_scenarios public columns,
/// active + exact level filter, stable id order and limit101 (overflow sentinel).
/// Concrete SDK must use captured credentials, bounded HTTP/JSON and no retry.
abstract interface class ConversationScenarioReadPort {
  Future<Object?> read({
    required ReviewSession capturedSession,
    required AiTextLevel level,
  });
}

/// One captured ready generation, no cache/automatic loading/default activation.
/// The host owns revocation, transport drain and SDK resources. Returned rows
/// remain untrusted for mutation authorization; backend revalidates start.
final class CapturedConversationScenarios {
  CapturedConversationScenarios({
    required ReviewAuth auth,
    required ConversationScenarioReadPort port,
    required bool Function() isReady,
    Duration timeout = const Duration(seconds: 15),
  }) : _auth = auth,
       _port = port,
       _ready = isReady,
       _timeout = timeout,
       _session = _capture(auth) {
    if (timeout <= Duration.zero || timeout > const Duration(seconds: 15)) {
      throw ArgumentError('Invalid scenario read timeout');
    }
    _requireCurrent();
  }
  final ReviewAuth _auth;
  final ConversationScenarioReadPort _port;
  final bool Function() _ready;
  final Duration _timeout;
  final ReviewSession _session;
  bool _revoked = false;
  bool _checking = false;
  bool _busy = false;
  bool get isBusy => _busy;
  bool get isCurrent {
    if (_revoked || _checking) return false;
    _checking = true;
    try {
      if (_ready() &&
          identical(_auth.currentSession, _session) &&
          _ready() &&
          !_revoked) {
        return true;
      }
    } on Object {
      // Raw getter errors are never learner data.
    } finally {
      _checking = false;
    }
    revoke();
    return false;
  }

  void revoke() => _revoked = true;
  void _requireCurrent() {
    if (!isCurrent) {
      throw const AiTextFailure(AiTextErrorCode.unauthorized);
    }
  }

  Future<List<ConversationScenario>> load(AiTextLevel level) async {
    if (_busy || _checking) throw const AiTextRequestPending();
    _busy = true; // Reserve before any supplied getter/port can reenter.
    var settled = false;
    var returned = false;
    var dispatched = false;
    void release() {
      if (settled && returned) _busy = false;
    }

    try {
      _requireCurrent();
      if (level != AiTextLevel.n5 && level != AiTextLevel.n4) {
        throw const AiTextFailure(AiTextErrorCode.validationFailure);
      }
      dispatched = true;
      final work = Future<Object?>.sync(() {
        _requireCurrent();
        return _port.read(capturedSession: _session, level: level);
      });
      unawaited(
        work.then<void>(
          (_) {
            settled = true;
            release();
          },
          onError: (Object _, StackTrace _) {
            settled = true;
            release();
          },
        ),
      );
      final raw = await work.timeout(_timeout);
      _requireCurrent();
      final result = _decode(raw, level);
      _requireCurrent();
      return result;
    } on AiTextFailure catch (failure) {
      if (failure.code == AiTextErrorCode.unauthorized) revoke();
      _requireCurrent();
      rethrow;
    } on TimeoutException {
      _requireCurrent();
      throw const AiTextFailure(AiTextErrorCode.networkUnavailable);
    } on Object {
      _requireCurrent();
      throw const AiTextFailure(AiTextErrorCode.internalError);
    } finally {
      returned = true;
      // No wire was dispatched on local validation/readiness failure.
      if (!dispatched) settled = true;
      release();
    }
  }
}

ReviewSession _capture(ReviewAuth auth) {
  try {
    final session = auth.currentSession;
    if (session != null) return session;
  } on Object {
    // Safe failure only.
  }
  throw const AiTextFailure(AiTextErrorCode.unauthorized);
}

List<ConversationScenario> _decode(Object? raw, AiTextLevel level) {
  Never invalid() => throw const AiTextFailure(AiTextErrorCode.internalError);
  if (raw is! List || raw.length > 100) invalid();
  final ids = <String>{};
  final result = <ConversationScenario>[];
  final uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  String text(Object? value, int max) {
    if (value is! String ||
        value.length > max * 2 ||
        value.trim().isEmpty ||
        value.runes.length > max) {
      invalid();
    }
    return value;
  }

  const keys = {
    'id',
    'jlpt_level',
    'title_vi',
    'title_ja',
    'description_vi',
    'content_version',
    'is_active',
  };
  for (final row in raw) {
    if (row is! Map ||
        row.length != keys.length ||
        row.keys.any((k) => !keys.contains(k))) {
      invalid();
    }
    final id = row['id'];
    final version = row['content_version'];
    if (id is! String ||
        id.length != 36 ||
        !uuid.hasMatch(id) ||
        !ids.add(id.toLowerCase()) ||
        row['jlpt_level'] != level.wireName ||
        row['is_active'] != true ||
        version is! int ||
        version < 1 ||
        version > 2147483647) {
      invalid();
    }
    result.add(
      ConversationScenario._(
        id,
        level,
        text(row['title_vi'], 200),
        text(row['title_ja'], 200),
        text(row['description_vi'], 2000),
        version,
      ),
    );
  }
  return List.unmodifiable(result);
}
