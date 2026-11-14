import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/page_body.dart';
import '../../auth/application/account_controller.dart';
import '../../auth/application/account_provider.dart';
import '../../daily_plan/application/daily_plan_provider.dart';
import '../../daily_plan/data/daily_plan_repository.dart';
import '../../daily_plan/domain/daily_plan.dart';
import '../../daily_plan/presentation/daily_plan_labels.dart';
import '../../daily_plan/presentation/study_day_button.dart';
import '../../quiz/application/grammar_quiz_history_provider.dart';
import '../../quiz/application/quiz_history_provider.dart';
import '../../quiz/data/grammar_quiz_history_repository.dart';
import '../../quiz/data/vocabulary_quiz_history_repository.dart';
import '../../quiz/domain/grammar_quiz_attempt.dart';
import '../../quiz/domain/vocabulary_quiz_attempt.dart';

final class _QuizHistoryTotals {
  const _QuizHistoryTotals({
    required this.attempts,
    required this.answers,
    required this.correct,
  });

  final int attempts;
  final int answers;
  final int correct;
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

_QuizHistoryTotals _vocabularyTotals(List<OwnedVocabularyQuizAttempt> records) {
  final answers = records
      .expand((record) => record.attempt.answers)
      .toList(growable: false);
  return _QuizHistoryTotals(
    attempts: records.length,
    answers: answers.length,
    correct: answers.where((answer) => answer.isCorrect).length,
  );
}

_QuizHistoryTotals _grammarTotals(List<OwnedGrammarQuizAttempt> records) {
  final answers = records
      .expand((record) => record.attempt.answers)
      .toList(growable: false);
  return _QuizHistoryTotals(
    attempts: records.length,
    answers: answers.length,
    correct: answers.where((answer) => answer.isCorrect).length,
  );
}

String _quizTotalsLabel(String title, _QuizHistoryTotals totals) =>
    '$title · ${totals.attempts} lượt · ${totals.correct}/${totals.answers} câu đúng';

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
          'Báo cáo quiz hiện là lịch sử cục bộ theo tài khoản. '
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
          const Text(
            'Số liệu chỉ phản ánh lượt đã lưu trên thiết bị; không xác nhận '
            'mức thành thạo, thời gian học hoặc đồng bộ máy chủ.',
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
