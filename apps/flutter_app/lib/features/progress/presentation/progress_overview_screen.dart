import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/preview_level.dart';
import '../../../shared/widgets/page_body.dart';
import '../../auth/application/account_controller.dart';
import '../../auth/application/account_provider.dart';
import '../../curriculum/application/curriculum_provider.dart';
import '../../curriculum/domain/curriculum.dart';
import '../../daily_plan/application/daily_plan_provider.dart';
import '../../daily_plan/data/daily_plan_repository.dart';
import '../../daily_plan/domain/daily_plan.dart';
import '../../daily_plan/presentation/daily_plan_labels.dart';
import '../../daily_plan/presentation/study_day_button.dart';
import '../../quiz/application/grammar_quiz_history_provider.dart';
import '../../quiz/application/quiz_history_provider.dart';
import '../../quiz/application/quiz_report_v2_provider.dart';
import '../../quiz/data/grammar_quiz_history_repository.dart';
import '../../quiz/data/quiz_report_v2_adapter.dart';
import '../../quiz/data/quiz_report_v2_transport.dart';
import '../../quiz/data/vocabulary_quiz_history_repository.dart';
import '../../quiz/domain/grammar_quiz_attempt.dart';
import '../../quiz/domain/vocabulary_quiz_attempt.dart';
import '../../quiz/application/quiz_report_v2_weak_points.dart';

final class _ServerQuizWeakPointSnapshot {
  const _ServerQuizWeakPointSnapshot({
    required this.currentContent,
    required this.points,
    required this.unavailable,
  });

  final Map<String, List<CurriculumEntry>> currentContent;
  final List<QuizReportV2WeakPoint> points;
  final bool unavailable;
}

final class _QuizLevelTotals {
  const _QuizLevelTotals({
    required this.attempts,
    required this.answers,
    required this.correct,
  });

  final int attempts;
  final int answers;
  final int correct;
}

final class _QuizHistoryTotals {
  const _QuizHistoryTotals({required this.n5, required this.n4});

  final _QuizLevelTotals n5;
  final _QuizLevelTotals n4;

  int get attempts => n5.attempts + n4.attempts;
  int get answers => n5.answers + n4.answers;
  int get correct => n5.correct + n4.correct;
}

final class _QuizHistorySummary {
  const _QuizHistorySummary({
    required this.vocabulary,
    required this.grammarPrimary,
    required this.grammarCorrection,
  });

  final _QuizHistoryTotals? vocabulary;
  final _QuizHistoryTotals? grammarPrimary;
  final _QuizHistoryTotals? grammarCorrection;
}

final class _ServerQuizTotals {
  const _ServerQuizTotals({
    required this.receipts,
    required this.answers,
    required this.correct,
  });

  final int receipts;
  final int answers;
  final int correct;
}

final class _ServerQuizPageSummary {
  const _ServerQuizPageSummary({
    required this.vocabularyN5,
    required this.vocabularyN4,
    required this.grammarPrimaryN5,
    required this.grammarPrimaryN4,
    required this.grammarCorrectionN5,
    required this.grammarCorrectionN4,
  });

  final _ServerQuizTotals vocabularyN5;
  final _ServerQuizTotals vocabularyN4;
  final _ServerQuizTotals grammarPrimaryN5;
  final _ServerQuizTotals grammarPrimaryN4;
  final _ServerQuizTotals grammarCorrectionN5;
  final _ServerQuizTotals grammarCorrectionN4;

  int get answers =>
      vocabularyN5.answers +
      vocabularyN4.answers +
      grammarPrimaryN5.answers +
      grammarPrimaryN4.answers +
      grammarCorrectionN5.answers +
      grammarCorrectionN4.answers;

  int get correct =>
      vocabularyN5.correct +
      vocabularyN4.correct +
      grammarPrimaryN5.correct +
      grammarPrimaryN4.correct +
      grammarCorrectionN5.correct +
      grammarCorrectionN4.correct;
}

_QuizLevelTotals _vocabularyLevelTotals(
  Iterable<OwnedVocabularyQuizAttempt> records,
) {
  final rows = records.toList(growable: false);
  final answers = rows
      .expand((record) => record.attempt.answers)
      .toList(growable: false);
  return _QuizLevelTotals(
    attempts: rows.length,
    answers: answers.length,
    correct: answers.where((answer) => answer.isCorrect).length,
  );
}

_QuizHistoryTotals _vocabularyTotals(
  List<OwnedVocabularyQuizAttempt> records,
) => _QuizHistoryTotals(
  n5: _vocabularyLevelTotals(
    records.where((record) => record.attempt.level == PreviewLevel.n5),
  ),
  n4: _vocabularyLevelTotals(
    records.where((record) => record.attempt.level == PreviewLevel.n4),
  ),
);

_QuizLevelTotals _grammarLevelTotals(
  Iterable<OwnedGrammarQuizAttempt> records,
) {
  final rows = records.toList(growable: false);
  final answers = rows
      .expand((record) => record.attempt.answers)
      .toList(growable: false);
  return _QuizLevelTotals(
    attempts: rows.length,
    answers: answers.length,
    correct: answers.where((answer) => answer.isCorrect).length,
  );
}

_QuizHistoryTotals _grammarTotals(List<OwnedGrammarQuizAttempt> records) =>
    _QuizHistoryTotals(
      n5: _grammarLevelTotals(
        records.where((record) => record.attempt.level == PreviewLevel.n5),
      ),
      n4: _grammarLevelTotals(
        records.where((record) => record.attempt.level == PreviewLevel.n4),
      ),
    );

_ServerQuizTotals _serverQuizTotals(
  Iterable<QuizReportV2HistoryEntry> entries,
) {
  final rows = entries.toList(growable: false);
  var answers = 0;
  var correct = 0;
  for (final entry in rows) {
    answers += entry.response.answerCount;
    correct += entry.response.correctCount;
  }
  return _ServerQuizTotals(
    receipts: rows.length,
    answers: answers,
    correct: correct,
  );
}

_ServerQuizPageSummary _serverQuizPageSummary(
  Iterable<QuizReportV2HistoryEntry> entries,
) {
  final items = entries.toList(growable: false);

  _ServerQuizTotals totals(String quizType, String level, [String? kind]) =>
      _serverQuizTotals(
        items.where(
          (entry) =>
              entry.request.quizType == quizType &&
              entry.request.jlptLevel == level &&
              entry.request.practiceKind == kind,
        ),
      );

  return _ServerQuizPageSummary(
    vocabularyN5: totals('vocabulary_reading', 'N5'),
    vocabularyN4: totals('vocabulary_reading', 'N4'),
    grammarPrimaryN5: totals('grammar_meaning', 'N5', 'primary'),
    grammarPrimaryN4: totals('grammar_meaning', 'N4', 'primary'),
    grammarCorrectionN5: totals('grammar_meaning', 'N5', 'correction'),
    grammarCorrectionN4: totals('grammar_meaning', 'N4', 'correction'),
  );
}

String _serverQuizLevelTotalsLabel(
  String title,
  _ServerQuizTotals n5,
  _ServerQuizTotals n4,
) =>
    '$title · N5 ${n5.receipts} biên nhận · ${n5.correct}/${n5.answers} câu đúng'
    ' · N4 ${n4.receipts} biên nhận · ${n4.correct}/${n4.answers} câu đúng';

String _quizTotalsLabel(String title, _QuizHistoryTotals totals) =>
    '$title · ${totals.attempts} lượt · ${totals.correct}/${totals.answers} câu đúng';

String _quizLevelTotalsLabel(_QuizHistoryTotals totals) =>
    'N5 · ${totals.n5.attempts} lượt · ${totals.n5.correct}/${totals.n5.answers} câu đúng; '
    'N4 · ${totals.n4.attempts} lượt · ${totals.n4.correct}/${totals.n4.answers} câu đúng';

String _serverWeakPointTitle(QuizReportV2WeakPoint point) {
  final type = point.quizType == 'vocabulary_reading'
      ? 'Từ vựng'
      : point.practiceKind == 'correction'
      ? 'Ngữ pháp sửa'
      : 'Ngữ pháp chính';
  return '${point.jlptLevel} · $type · ${point.entry.heading}';
}

String _serverWeakPointSubtitle(QuizReportV2WeakPoint point) {
  final detail = point.quizType == 'vocabulary_reading'
      ? '${point.entry.reading ?? ''} · ${point.entry.meaningVi}'
      : point.entry.meaningVi;
  return '$detail · Sai ${point.incorrectCount} lần trong các trang đã tải';
}

class ProgressOverviewScreen extends ConsumerStatefulWidget {
  const ProgressOverviewScreen({super.key});

  @override
  ConsumerState<ProgressOverviewScreen> createState() =>
      _ProgressOverviewScreenState();
}

class _ProgressOverviewScreenState
    extends ConsumerState<ProgressOverviewScreen> {
  final _date = TextEditingController();
  DailyPlan? _plan;
  DailyPlanRepository? _planRepository;
  String? _planOwner;
  String? _planTimezone;
  String? _message;
  bool _loading = false;
  _QuizHistorySummary? _quizSummary;
  bool _quizLoading = false;
  bool _quizFailed = false;
  List<QuizReportV2HistoryPage> _serverQuizPages = const [];
  List<QuizReportV2HistoryEntry> _serverQuizEntries = const [];
  Map<String, List<CurriculumEntry>> _serverQuizCurrentContent = const {};
  QuizReportV2HistoryReader? _serverQuizReader;
  bool _serverQuizLoading = false;
  bool _serverQuizLoadingMore = false;
  bool _serverQuizFailed = false;
  bool _serverQuizMoreFailed = false;
  List<QuizReportV2WeakPoint>? _serverQuizWeakPoints;
  bool _serverQuizWeakPointsUnavailable = false;
  CurriculumRepository? _serverQuizCurriculum;
  int _generation = 0;

  void _clearForReplacement() {
    _generation++;
    _date.clear();
    _plan = null;
    _planRepository = null;
    _planOwner = null;
    _planTimezone = null;
    _message = null;
    _loading = false;
    _quizSummary = null;
    _quizLoading = false;
    _quizFailed = false;
    _serverQuizPages = const [];
    _serverQuizEntries = const [];
    _serverQuizCurrentContent = const {};
    _serverQuizReader = null;
    _serverQuizLoading = false;
    _serverQuizLoadingMore = false;
    _serverQuizFailed = false;
    _serverQuizMoreFailed = false;
    _serverQuizWeakPoints = null;
    _serverQuizWeakPointsUnavailable = false;
    _serverQuizCurriculum = null;
  }

  bool _isCurrent({
    required DailyPlanRepository repository,
    required String owner,
    required String timezone,
    required int generation,
  }) {
    if (!mounted || generation != _generation) return false;
    final account = ref.read(accountStateProvider);
    return account.phase == AccountPhase.ready &&
        account.profile?.id == owner &&
        account.profile?.timezone == timezone &&
        identical(ref.read(dailyPlanRepositoryProvider), repository) &&
        repository.isCurrent;
  }

  Future<void> _load() async {
    if (_loading) return;
    final account = ref.read(accountStateProvider);
    final profile = account.profile;
    final repository = ref.read(dailyPlanRepositoryProvider);
    if (account.phase != AccountPhase.ready ||
        profile == null ||
        repository == null) {
      return;
    }

    final DailyPlanDate date;
    try {
      date = DailyPlanDate(_date.text.trim());
    } on FormatException {
      setState(() {
        _plan = null;
        _planRepository = null;
        _planOwner = null;
        _planTimezone = null;
        _message = 'Nhập ngày hợp lệ theo dạng YYYY-MM-DD.';
      });
      return;
    }

    final owner = profile.id;
    final timezone = profile.timezone;
    final generation = _generation;
    setState(() {
      _loading = true;
      _plan = null;
      _planRepository = null;
      _planOwner = null;
      _planTimezone = null;
      _message = null;
    });

    try {
      final plan = await repository.load(date);
      if (!_isCurrent(
        repository: repository,
        owner: owner,
        timezone: timezone,
        generation: generation,
      )) {
        return;
      }
      setState(() {
        _plan = plan;
        _planRepository = repository;
        _planOwner = owner;
        _planTimezone = timezone;
      });
    } on DailyPlanFailure catch (failure) {
      if (!_isCurrent(
        repository: repository,
        owner: owner,
        timezone: timezone,
        generation: generation,
      )) {
        return;
      }
      setState(() => _message = failure.messageVi);
    } on Object {
      if (!_isCurrent(
        repository: repository,
        owner: owner,
        timezone: timezone,
        generation: generation,
      )) {
        return;
      }
      setState(() => _message = 'Chưa thể tải tiến độ học. Vui lòng thử lại.');
    } finally {
      if (_isCurrent(
        repository: repository,
        owner: owner,
        timezone: timezone,
        generation: generation,
      )) {
        setState(() => _loading = false);
      }
    }
  }

  bool _isQuizCurrent({
    required String owner,
    required int generation,
    required VocabularyQuizHistoryRepository? vocabulary,
    required GrammarQuizHistoryRepository? grammar,
  }) {
    if (!mounted || generation != _generation) return false;
    final account = ref.read(accountStateProvider);
    return account.phase == AccountPhase.ready &&
        account.profile?.id == owner &&
        identical(ref.read(quizHistoryRepositoryProvider), vocabulary) &&
        identical(ref.read(grammarQuizHistoryRepositoryProvider), grammar);
  }

  bool _isServerQuizCurrent({
    required String owner,
    required int generation,
    required QuizReportV2HistoryReader reader,
    required CurriculumRepository? curriculum,
  }) {
    if (!mounted || generation != _generation) return false;
    final account = ref.read(accountStateProvider);
    return account.phase == AccountPhase.ready &&
        account.profile?.id == owner &&
        identical(ref.read(quizReportV2HistoryReaderProvider), reader) &&
        identical(ref.read(curriculumRepositoryProvider), curriculum);
  }

  Future<void> _loadQuizSummary() async {
    if (_quizLoading) return;
    final account = ref.read(accountStateProvider);
    final owner = account.profile?.id;
    final vocabulary = ref.read(quizHistoryRepositoryProvider);
    final grammar = ref.read(grammarQuizHistoryRepositoryProvider);
    if (account.phase != AccountPhase.ready ||
        owner == null ||
        (vocabulary == null && grammar == null)) {
      return;
    }

    final generation = _generation;
    setState(() {
      _quizLoading = true;
      _quizFailed = false;
      _quizSummary = null;
    });

    try {
      final vocabularyRecords = vocabulary == null
          ? null
          : await vocabulary.load();
      if (!_isQuizCurrent(
        owner: owner,
        generation: generation,
        vocabulary: vocabulary,
        grammar: grammar,
      )) {
        return;
      }

      final grammarRecords = grammar == null ? null : await grammar.load();
      if (!_isQuizCurrent(
        owner: owner,
        generation: generation,
        vocabulary: vocabulary,
        grammar: grammar,
      )) {
        return;
      }

      final primary = grammarRecords
          ?.where(
            (record) => record.attempt.kind == GrammarQuizAttemptKind.primary,
          )
          .toList(growable: false);
      final correction = grammarRecords
          ?.where(
            (record) =>
                record.attempt.kind == GrammarQuizAttemptKind.correction,
          )
          .toList(growable: false);
      setState(() {
        _quizSummary = _QuizHistorySummary(
          vocabulary: vocabularyRecords == null
              ? null
              : _vocabularyTotals(vocabularyRecords),
          grammarPrimary: primary == null ? null : _grammarTotals(primary),
          grammarCorrection: correction == null
              ? null
              : _grammarTotals(correction),
        );
      });
    } on Object {
      if (_isQuizCurrent(
        owner: owner,
        generation: generation,
        vocabulary: vocabulary,
        grammar: grammar,
      )) {
        setState(() => _quizFailed = true);
      }
    } finally {
      if (_isQuizCurrent(
        owner: owner,
        generation: generation,
        vocabulary: vocabulary,
        grammar: grammar,
      )) {
        setState(() => _quizLoading = false);
      }
    }
  }

  Future<_ServerQuizWeakPointSnapshot?>
  _loadServerQuizWeakPointSnapshot({
    required List<QuizReportV2HistoryEntry> entries,
    required Map<String, List<CurriculumEntry>> existingContent,
    required String owner,
    required int generation,
    required QuizReportV2HistoryReader reader,
    required CurriculumRepository? curriculum,
  }) async {
    final currentContent = Map<String, List<CurriculumEntry>>.of(
      existingContent,
    );
    if (entries.isEmpty) {
      return _ServerQuizWeakPointSnapshot(
        currentContent: Map.unmodifiable(currentContent),
        points: const [],
        unavailable: false,
      );
    }
    if (curriculum == null) {
      return _ServerQuizWeakPointSnapshot(
        currentContent: Map.unmodifiable(currentContent),
        points: const [],
        unavailable: true,
      );
    }

    final keys = <String>{
      for (final item in entries)
        quizReportV2ContentKey(item.request.quizType, item.request.jlptLevel),
    }.toList()..sort();
    try {
      for (final key in keys) {
        if (currentContent.containsKey(key)) continue;
        final split = key.split(':');
        if (split.length != 2) {
          throw const FormatException('Invalid quiz content scope');
        }
        final kind = switch (split[0]) {
          'vocabulary_reading' => CurriculumKind.vocabulary,
          'grammar_meaning' => CurriculumKind.grammar,
          _ => throw const FormatException('Invalid quiz content type'),
        };
        final level = switch (split[1]) {
          'N5' => PreviewLevel.n5,
          'N4' => PreviewLevel.n4,
          _ => throw const FormatException('Invalid quiz content level'),
        };
        currentContent[key] = await curriculum.load(kind, level);
        if (!_isServerQuizCurrent(
          owner: owner,
          generation: generation,
          reader: reader,
          curriculum: curriculum,
        )) {
          return null;
        }
      }
      return _ServerQuizWeakPointSnapshot(
        currentContent: Map.unmodifiable(currentContent),
        points: deriveQuizReportV2WeakPointsFromEntries(
          entries: entries,
          currentContent: currentContent,
        ),
        unavailable: false,
      );
    } on Object {
      if (!_isServerQuizCurrent(
        owner: owner,
        generation: generation,
        reader: reader,
        curriculum: curriculum,
      )) {
        return null;
      }
      return _ServerQuizWeakPointSnapshot(
        currentContent: Map.unmodifiable(currentContent),
        points: const [],
        unavailable: true,
      );
    }
  }

  Future<void> _loadServerQuizSummary() async {
    if (_serverQuizLoading || _serverQuizLoadingMore) return;
    final account = ref.read(accountStateProvider);
    final owner = account.profile?.id;
    final reader = ref.read(quizReportV2HistoryReaderProvider);
    final curriculum = ref.read(curriculumRepositoryProvider);
    if (account.phase != AccountPhase.ready ||
        owner == null ||
        reader == null) {
      return;
    }

    final generation = _generation;
    setState(() {
      _serverQuizReader = reader;
      _serverQuizCurriculum = curriculum;
      _serverQuizLoading = true;
      _serverQuizFailed = false;
      _serverQuizMoreFailed = false;
      _serverQuizPages = const [];
      _serverQuizEntries = const [];
      _serverQuizCurrentContent = const {};
      _serverQuizWeakPoints = null;
      _serverQuizWeakPointsUnavailable = false;
    });

    try {
      final page = await reader.readHistory(
        QuizReportV2HistoryQuery(limit: 20),
      );
      if (!_isServerQuizCurrent(
        owner: owner,
        generation: generation,
        reader: reader,
        curriculum: curriculum,
      )) {
        return;
      }
      final pages = <QuizReportV2HistoryPage>[page];
      final entries = mergeQuizReportV2HistoryPages(pages);
      final weakPointSnapshot = await _loadServerQuizWeakPointSnapshot(
        entries: entries,
        existingContent: const {},
        owner: owner,
        generation: generation,
        reader: reader,
        curriculum: curriculum,
      );
      if (weakPointSnapshot == null ||
          !_isServerQuizCurrent(
            owner: owner,
            generation: generation,
            reader: reader,
            curriculum: curriculum,
          )) {
        return;
      }
      setState(() {
        _serverQuizPages = List.unmodifiable(pages);
        _serverQuizEntries = entries;
        _serverQuizCurrentContent = weakPointSnapshot.currentContent;
        _serverQuizWeakPoints = weakPointSnapshot.points;
        _serverQuizWeakPointsUnavailable = weakPointSnapshot.unavailable;
      });
    } on Object {
      if (_isServerQuizCurrent(
        owner: owner,
        generation: generation,
        reader: reader,
        curriculum: curriculum,
      )) {
        setState(() => _serverQuizFailed = true);
      }
    } finally {
      if (_isServerQuizCurrent(
        owner: owner,
        generation: generation,
        reader: reader,
        curriculum: curriculum,
      )) {
        setState(() => _serverQuizLoading = false);
      }
    }
  }

  Future<void> _loadMoreServerQuizHistory() async {
    if (_serverQuizLoading ||
        _serverQuizLoadingMore ||
        _serverQuizPages.isEmpty) {
      return;
    }
    final account = ref.read(accountStateProvider);
    final owner = account.profile?.id;
    final reader = ref.read(quizReportV2HistoryReaderProvider);
    final curriculum = ref.read(curriculumRepositoryProvider);
    final pages = List<QuizReportV2HistoryPage>.of(_serverQuizPages);
    final cursor = pages.last.nextCursor;
    if (account.phase != AccountPhase.ready ||
        owner == null ||
        reader == null ||
        cursor == null ||
        _serverQuizEntries.length >= maxQuizReportV2OverviewReceipts) {
      return;
    }

    final generation = _generation;
    final remaining =
        maxQuizReportV2OverviewReceipts - _serverQuizEntries.length;
    final limit = remaining < 20 ? remaining : 20;
    setState(() {
      _serverQuizLoadingMore = true;
      _serverQuizMoreFailed = false;
    });

    try {
      final page = await reader.readHistory(
        QuizReportV2HistoryQuery(limit: limit, cursor: cursor),
      );
      if (!_isServerQuizCurrent(
        owner: owner,
        generation: generation,
        reader: reader,
        curriculum: curriculum,
      )) {
        return;
      }
      final nextPages = <QuizReportV2HistoryPage>[...pages, page];
      final entries = mergeQuizReportV2HistoryPages(nextPages);
      final weakPointSnapshot = await _loadServerQuizWeakPointSnapshot(
        entries: entries,
        existingContent: _serverQuizCurrentContent,
        owner: owner,
        generation: generation,
        reader: reader,
        curriculum: curriculum,
      );
      if (weakPointSnapshot == null ||
          !_isServerQuizCurrent(
            owner: owner,
            generation: generation,
            reader: reader,
            curriculum: curriculum,
          )) {
        return;
      }
      setState(() {
        _serverQuizPages = List.unmodifiable(nextPages);
        _serverQuizEntries = entries;
        _serverQuizCurrentContent = weakPointSnapshot.currentContent;
        _serverQuizWeakPoints = weakPointSnapshot.points;
        _serverQuizWeakPointsUnavailable = weakPointSnapshot.unavailable;
        _serverQuizMoreFailed = false;
      });
    } on Object {
      if (_isServerQuizCurrent(
        owner: owner,
        generation: generation,
        reader: reader,
        curriculum: curriculum,
      )) {
        setState(() => _serverQuizMoreFailed = true);
      }
    } finally {
      if (_isServerQuizCurrent(
        owner: owner,
        generation: generation,
        reader: reader,
        curriculum: curriculum,
      )) {
        setState(() => _serverQuizLoadingMore = false);
      }
    }
  }

  @override
  void dispose() {
    _date.clear();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dailyPlanRepositoryProvider, (_, _) {
      _clearForReplacement();
    });
    ref.listen(quizHistoryRepositoryProvider, (_, _) {
      _clearForReplacement();
    });
    ref.listen(grammarQuizHistoryRepositoryProvider, (_, _) {
      _clearForReplacement();
    });
    ref.listen(quizReportV2HistoryReaderProvider, (_, _) {
      _clearForReplacement();
    });
    ref.listen(curriculumRepositoryProvider, (_, _) {
      _clearForReplacement();
    });
    ref.listen(accountStateProvider, (previous, next) {
      if (previous?.phase != next.phase ||
          previous?.profile?.id != next.profile?.id ||
          previous?.profile?.timezone != next.profile?.timezone) {
        _clearForReplacement();
      }
    });

    final account = ref.watch(accountStateProvider);
    final repository = ref.watch(dailyPlanRepositoryProvider);
    final vocabularyHistory = ref.watch(quizHistoryRepositoryProvider);
    final grammarHistory = ref.watch(grammarQuizHistoryRepositoryProvider);
    final serverHistoryReader = ref.watch(quizReportV2HistoryReaderProvider);
    final curriculum = ref.watch(curriculumRepositoryProvider);
    final serverHistoryStateCurrent =
        identical(_serverQuizReader, serverHistoryReader) &&
        identical(_serverQuizCurriculum, curriculum);
    final serverQuizPages = serverHistoryStateCurrent
        ? _serverQuizPages
        : const <QuizReportV2HistoryPage>[];
    final serverQuizPage = serverQuizPages.isEmpty
        ? null
        : serverQuizPages.last;
    final serverQuizEntries = serverHistoryStateCurrent
        ? _serverQuizEntries
        : const <QuizReportV2HistoryEntry>[];
    final serverQuizLoading = serverHistoryStateCurrent && _serverQuizLoading;
    final serverQuizLoadingMore =
        serverHistoryStateCurrent && _serverQuizLoadingMore;
    final serverQuizFailed = serverHistoryStateCurrent && _serverQuizFailed;
    final serverQuizMoreFailed =
        serverHistoryStateCurrent && _serverQuizMoreFailed;
    final serverQuizHasMore =
        serverQuizPage?.nextCursor != null &&
        serverQuizEntries.length < maxQuizReportV2OverviewReceipts;
    final serverQuizAtLimit =
        serverQuizPage?.nextCursor != null &&
        serverQuizEntries.length >= maxQuizReportV2OverviewReceipts;
    final serverQuizWeakPoints = serverHistoryStateCurrent
        ? _serverQuizWeakPoints
        : null;
    final serverQuizWeakPointsUnavailable =
        serverHistoryStateCurrent && _serverQuizWeakPointsUnavailable;
    final serverQuizSummary = serverQuizPage == null
        ? null
        : _serverQuizPageSummary(serverQuizEntries);
    final profile = account.profile;
    final ready =
        account.phase == AccountPhase.ready &&
        profile != null &&
        repository != null;
    final plan =
        ready &&
            _planOwner == profile.id &&
            _planTimezone == profile.timezone &&
            identical(_planRepository, repository)
        ? _plan
        : null;

    return PageBody(
      children: [
        const PageHeading(
          title: 'Tiến độ học tập',
          subtitle:
              'Phút học lấy từ kế hoạch máy chủ. Lịch sử quiz được xem riêng '
              'và chưa đại diện cho mức thành thạo hoặc đồng bộ thiết bị.',
        ),
        if (account.phase != AccountPhase.ready || profile == null) ...[
          const Text(
            'Cần phiên đăng nhập và hồ sơ học tập đã sẵn sàng để xem tiến độ.',
          ),
          OutlinedButton(
            onPressed: () => context.go('/auth'),
            child: const Text('Mở tài khoản'),
          ),
        ] else if (repository == null) ...[
          const Text(
            'Tiến độ máy chủ chưa được cấu hình cho phiên này. '
            'Không có số liệu học tập giả lập.',
          ),
          OutlinedButton(
            onPressed: () => context.go('/plan'),
            child: const Text('Mở kế hoạch học'),
          ),
        ] else ...[
          Text(
            'Thời gian học theo hồ sơ · ${profile.timezone}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          TextField(
            key: const Key('progress-date'),
            controller: _date,
            enabled: ready && !_loading,
            maxLength: 10,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Ngày học (YYYY-MM-DD)',
              hintText: '2026-10-20',
            ),
            onChanged: (_) {
              if (_plan != null || _message != null) {
                setState(() {
                  _plan = null;
                  _planRepository = null;
                  _planOwner = null;
                  _planTimezone = null;
                  _message = null;
                });
              }
            },
            onSubmitted: ready && !_loading ? (_) => unawaited(_load()) : null,
          ),
          StudyDayButton(
            key: const Key('progress-today'),
            repository: repository,
            timezone: profile.timezone,
            enabled: ready && !_loading,
            currentDate: () => _date.text,
            onDate: (date) {
              if (!mounted || _loading) return;
              setState(() {
                _date.text = date.value;
                _plan = null;
                _planRepository = null;
                _planOwner = null;
                _planTimezone = null;
                _message = null;
              });
            },
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('progress-load'),
            onPressed: ready && !_loading ? () => unawaited(_load()) : null,
            icon: const Icon(Icons.refresh),
            label: const Text('Tải tiến độ'),
          ),
          if (_loading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Đang tải tiến độ…'),
          ],
          if (_message != null)
            Text(_message!, key: const Key('progress-error')),
          if (plan != null) ...[
            const SizedBox(height: 16),
            Text(
              'Ngày ${plan.date.value}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${plan.completedMinutes}/${plan.targetMinutes} phút',
              key: const Key('progress-study-minutes'),
            ),
            LinearProgressIndicator(
              value: (plan.completedMinutes / plan.targetMinutes).clamp(
                0.0,
                1.0,
              ),
              semanticsLabel: 'Tiến độ học theo máy chủ',
            ),
            if (plan.completedMinutes > plan.targetMinutes)
              const Text('Thời gian vượt mục tiêu vẫn được giữ nguyên.'),
            for (final block in plan.blocks)
              Card(
                child: ListTile(
                  title: Text(dailyPlanAreaLabel(block.area)),
                  subtitle: Text(
                    '${block.plannedMinutes} phút · '
                    '${dailyPlanStatusLabel(block.status)}',
                  ),
                  trailing: Text('${block.itemCount} mục'),
                ),
              ),
          ],
        ],
        const SizedBox(height: 24),
        Text(
          'Luyện tập và lịch sử',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Lịch sử cục bộ và biên nhận máy chủ được hiển thị riêng. '
          'Không cộng điểm quiz thành thời gian học hoặc trạng thái MASTERED.',
        ),
        if (vocabularyHistory == null && grammarHistory == null)
          const Text('Lịch sử quiz trên thiết bị chưa được cấu hình.'),
        if (vocabularyHistory != null || grammarHistory != null)
          FilledButton.icon(
            key: const Key('progress-load-quiz'),
            onPressed: _quizLoading
                ? null
                : () => unawaited(_loadQuizSummary()),
            icon: const Icon(Icons.assessment_outlined),
            label: Text(
              _quizLoading
                  ? 'Đang tải lịch sử quiz…'
                  : 'Tải tóm tắt quiz trên thiết bị',
            ),
          ),
        if (_quizLoading) ...[
          const LinearProgressIndicator(),
          const Text('Đang đọc lịch sử quiz trên thiết bị…'),
        ],
        if (_quizFailed)
          const Text(
            'Không thể đọc lịch sử quiz. Bạn có thể thử tải lại.',
            key: Key('progress-quiz-error'),
          ),
        if (_quizSummary != null) ...[
          if (_quizSummary!.vocabulary == null)
            const Text('Từ vựng: lịch sử chưa được cấu hình.')
          else
            Text(
              _quizTotalsLabel('Từ vựng (N5 + N4)', _quizSummary!.vocabulary!),
              key: const Key('progress-quiz-vocabulary-summary'),
            ),
          if (_quizSummary!.vocabulary != null)
            Text(
              _quizLevelTotalsLabel(_quizSummary!.vocabulary!),
              key: const Key('progress-quiz-vocabulary-level-summary'),
            ),
          if (_quizSummary!.grammarPrimary == null)
            const Text('Ngữ pháp chính: lịch sử chưa được cấu hình.')
          else
            Text(
              _quizTotalsLabel(
                'Ngữ pháp chính (N5 + N4)',
                _quizSummary!.grammarPrimary!,
              ),
              key: const Key('progress-quiz-grammar-primary-summary'),
            ),
          if (_quizSummary!.grammarPrimary != null)
            Text(
              _quizLevelTotalsLabel(_quizSummary!.grammarPrimary!),
              key: const Key('progress-quiz-grammar-primary-level-summary'),
            ),
          if (_quizSummary!.grammarCorrection == null)
            const Text('Ngữ pháp sửa: lịch sử chưa được cấu hình.')
          else
            Text(
              _quizTotalsLabel(
                'Ngữ pháp sửa (N5 + N4)',
                _quizSummary!.grammarCorrection!,
              ),
              key: const Key('progress-quiz-grammar-correction-summary'),
            ),
          if (_quizSummary!.grammarCorrection != null)
            Text(
              _quizLevelTotalsLabel(_quizSummary!.grammarCorrection!),
              key: const Key('progress-quiz-grammar-correction-level-summary'),
            ),
          const Text(
            'Số liệu chỉ phản ánh lượt đã lưu trên thiết bị; không xác nhận '
            'mức thành thạo, thời gian học hoặc đồng bộ máy chủ.',
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Biên nhận quiz trên máy chủ',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Chỉ đọc biên nhận của phiên đã sẵn sàng. Trang tóm tắt không phải '
          'tổng lịch sử, mức thành thạo hay thời gian học.',
        ),
        if (serverHistoryReader == null)
          const Text('Biên nhận máy chủ chưa được cấu hình cho phiên này.')
        else ...[
          FilledButton.icon(
            key: const Key('progress-load-server-quiz'),
            onPressed: serverQuizLoading || serverQuizLoadingMore
                ? null
                : () => unawaited(_loadServerQuizSummary()),
            icon: const Icon(Icons.cloud_download_outlined),
            label: Text(
              serverQuizFailed
                  ? 'Thử tải lại biên nhận quiz trên máy chủ'
                  : serverQuizPage == null
                  ? 'Tải biên nhận quiz trên máy chủ'
                  : 'Làm mới biên nhận quiz trên máy chủ',
            ),
          ),
          if (serverQuizLoading) ...[
            const LinearProgressIndicator(),
            const Text('Đang đọc biên nhận quiz trên máy chủ…'),
          ],
          if (serverQuizFailed)
            const Text(
              'Không thể đọc biên nhận quiz trên máy chủ. Bạn có thể thử lại.',
              key: Key('progress-server-quiz-error'),
            ),
          if (serverQuizPage != null && serverQuizSummary != null) ...[
            if (serverQuizEntries.isEmpty)
              const Text(
                'Chưa có biên nhận quiz trên máy chủ.',
                key: Key('progress-server-quiz-empty'),
              )
            else
              Text(
                '${serverQuizEntries.length} biên nhận đã tải · '
                '${serverQuizSummary.correct}/'
                '${serverQuizSummary.answers} câu đúng',
                key: const Key('progress-server-quiz-summary'),
              ),
            Text(
              _serverQuizLevelTotalsLabel(
                'Từ vựng',
                serverQuizSummary.vocabularyN5,
                serverQuizSummary.vocabularyN4,
              ),
              key: const Key('progress-server-quiz-vocabulary-summary'),
            ),
            Text(
              _serverQuizLevelTotalsLabel(
                'Ngữ pháp chính',
                serverQuizSummary.grammarPrimaryN5,
                serverQuizSummary.grammarPrimaryN4,
              ),
              key: const Key('progress-server-quiz-grammar-primary-summary'),
            ),
            Text(
              _serverQuizLevelTotalsLabel(
                'Ngữ pháp sửa',
                serverQuizSummary.grammarCorrectionN5,
                serverQuizSummary.grammarCorrectionN4,
              ),
              key: const Key('progress-server-quiz-grammar-correction-summary'),
            ),
            Text(
              serverQuizAtLimit
                  ? 'Đã đạt giới hạn 100 biên nhận cho tóm tắt này. Mở lịch sử để xem các trang cũ hơn.'
                  : serverQuizHasMore
                  ? 'Đã tải ${serverQuizEntries.length}/100 biên nhận trong tóm tắt này. Bạn có thể tải thêm; mở lịch sử để xem toàn bộ.'
                  : 'Đã tải hết biên nhận hiện có trong truy vấn này.',
            ),
            if (serverQuizHasMore)
              OutlinedButton(
                key: const Key('progress-load-more-server-quiz'),
                onPressed: serverQuizLoadingMore
                    ? null
                    : () => unawaited(_loadMoreServerQuizHistory()),
                child: Text(
                  serverQuizMoreFailed
                      ? 'Thử tải trang tiếp theo'
                      : 'Tải thêm biên nhận',
                ),
              ),
            if (serverQuizLoadingMore) ...[
              const LinearProgressIndicator(),
              const Text('Đang tải trang biên nhận tiếp theo…'),
            ],
            if (serverQuizMoreFailed)
              const Text(
                'Không thể tải trang tiếp theo. Các trang đã tải vẫn được giữ; bạn có thể thử lại.',
                key: Key('progress-server-quiz-more-error'),
              ),
            if (serverQuizWeakPointsUnavailable)
              const Text(
                'Chưa thể đối chiếu nội dung hiện tại nên không hiển thị gợi ý ôn lại.',
                key: Key('progress-server-quiz-weak-points-unavailable'),
              )
            else if (serverQuizWeakPoints != null) ...[
              const Text(
                'Gợi ý ôn lại từ câu sai còn khớp nội dung hiện tại trong các trang đã tải:',
                key: Key('progress-server-quiz-weak-points-heading'),
              ),
              if (serverQuizWeakPoints.isEmpty)
                const Text(
                  'Không có mục sai còn khớp nội dung hiện tại trong các trang đã tải.',
                  key: Key('progress-server-quiz-weak-points-empty'),
                ),
              for (final point in serverQuizWeakPoints.take(5))
                ListTile(
                  key: ValueKey(
                    'progress-server-quiz-weak-point-${point.quizType}-${point.practiceKind ?? 'none'}-${point.jlptLevel}-${point.entry.id}',
                  ),
                  title: Text(_serverWeakPointTitle(point)),
                  subtitle: Text(_serverWeakPointSubtitle(point)),
                ),
              const Text(
                'Đây là gợi ý ôn lại từ biên nhận tự báo cáo, không phải xác nhận thành thạo, trạng thái SRS hay thời gian học.',
              ),
            ],
          ],
          OutlinedButton(
            key: const Key('progress-open-server-quiz-history'),
            onPressed: () => context.go('/quiz/history'),
            child: const Text('Mở lịch sử quiz trên máy chủ'),
          ),
        ],
        OutlinedButton(
          key: const Key('progress-vocabulary'),
          onPressed: () => context.go('/progress'),
          child: const Text('Tiến độ quiz từ vựng'),
        ),
        OutlinedButton(
          key: const Key('progress-grammar'),
          onPressed: () => context.go('/quiz/grammar/progress'),
          child: const Text('Tiến độ quiz ngữ pháp'),
        ),
        OutlinedButton(
          key: const Key('progress-plan'),
          onPressed: () => context.go('/plan'),
          child: const Text('Mở kế hoạch học chi tiết'),
        ),
      ],
    );
  }
}
