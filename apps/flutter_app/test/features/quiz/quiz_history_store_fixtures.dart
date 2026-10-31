// TEST ONLY fault/await controls around a supplied real local store.
import 'dart:async';

import 'package:nihongo_daily/features/quiz/data/vocabulary_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_attempt.dart';

final class ControlledQuizStore implements VocabularyQuizAttemptStore {
  ControlledQuizStore(this.base);
  final VocabularyQuizAttemptStore base;
  int appends = 0;
  int loads = 0;
  final owners = <String>[];
  Object? appendFailure;
  Object? listFailure;
  bool synchronousFailure = false;
  Completer<void>? appendWait;
  Completer<void>? listWait;
  Completer<void>? appended;
  Completer<void>? listed;
  OwnedVocabularyQuizAttempt? appendOverride;
  List<OwnedVocabularyQuizAttempt>? listOverride;
  void Function()? onAppend;

  @override
  Future<OwnedVocabularyQuizAttempt> append(
    String ownerId,
    VocabularyQuizAttempt attempt,
  ) {
    appends++;
    owners.add(ownerId);
    if (synchronousFailure && appendFailure != null) throw appendFailure!;
    onAppend?.call();
    return _append(ownerId, attempt);
  }

  Future<OwnedVocabularyQuizAttempt> _append(
    String ownerId,
    VocabularyQuizAttempt attempt,
  ) async {
    final result = await base.append(ownerId, attempt);
    if (!(appended?.isCompleted ?? true)) appended!.complete();
    await appendWait?.future;
    if (appendFailure != null) throw appendFailure!;
    return appendOverride ?? result;
  }

  @override
  Future<List<OwnedVocabularyQuizAttempt>> list(String ownerId) {
    loads++;
    owners.add(ownerId);
    if (synchronousFailure && listFailure != null) throw listFailure!;
    return _list(ownerId);
  }

  Future<List<OwnedVocabularyQuizAttempt>> _list(String ownerId) async {
    final result = await base.list(ownerId);
    if (!(listed?.isCompleted ?? true)) listed!.complete();
    await listWait?.future;
    if (listFailure != null) throw listFailure!;
    return listOverride ?? result;
  }

  void release() {
    for (final pending in [appendWait, listWait]) {
      if (pending != null && !pending.isCompleted) pending.complete();
    }
  }
}
