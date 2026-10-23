import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/curriculum/domain/curriculum.dart';
import '../features/curriculum/presentation/curriculum_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/daily_plan/presentation/daily_plan_screen.dart';
import '../features/daily_plan/presentation/study_recovery_screen.dart';
import '../features/auth/presentation/account_screen.dart';
import '../features/kanji/presentation/kanji_capture_screen.dart';
import '../features/kanji/presentation/kanji_catalog_screen.dart';
import '../shared/models/preview_level.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/srs/presentation/srs_study_screen.dart';
import '../features/study/presentation/study_screen.dart';
import '../features/quiz/presentation/vocabulary_quiz_screen.dart';
import '../features/quiz/presentation/quiz_history_screen.dart';
import '../features/quiz/presentation/quiz_progress_screen.dart';
import '../features/reading/presentation/reading_screen.dart';
import '../shared/widgets/feature_preview_screen.dart';
import 'app_shell.dart';

const previewRoutes = <String, ({String title, String description})>{
  '/ai': (
    title: 'Trợ lý AI',
    description: 'Giải thích và sửa câu ở trình độ N5–N4.',
  ),
  '/conversation': (
    title: 'Hội thoại AI',
    description: 'Luyện hội thoại theo tình huống.',
  ),
};

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(path: state.uri.path, child: child);
        },
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/vocabulary',
            builder: (context, state) =>
                const CurriculumScreen(kind: CurriculumKind.vocabulary),
          ),
          GoRoute(
            path: '/grammar',
            builder: (context, state) =>
                const CurriculumScreen(kind: CurriculumKind.grammar),
          ),
          GoRoute(
            path: '/plan',
            builder: (context, state) => const DailyPlanScreen(),
          ),
          GoRoute(
            path: '/study-recovery',
            builder: (context, state) => const StudyRecoveryScreen(),
          ),
          GoRoute(
            path: '/auth',
            builder: (context, state) => const AccountScreen(),
          ),
          GoRoute(
            path: '/study',
            builder: (context, state) => const StudyScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/kanji',
            builder: (context, state) => const KanjiCaptureScreen(),
          ),
          GoRoute(
            path: '/kanji/characters',
            builder: (context, state) {
              final level = _kanjiLevel(
                state.uri.queryParameters['level'] ?? 'n5',
              );
              return level == null
                  ? const FeaturePreviewScreen(
                      title: 'Cấp độ Kanji chưa khả dụng',
                      description: 'Hãy chọn nội dung N5 hoặc N4.',
                    )
                  : KanjiCatalogScreen(
                      key: ValueKey(level),
                      initialLevel: level,
                    );
            },
          ),
          GoRoute(
            path: '/kanji/practice/:level/:id',
            builder: (context, state) {
              final level = _kanjiLevel(state.pathParameters['level']);
              return level == null
                  ? const FeaturePreviewScreen(
                      title: 'Cấp độ Kanji chưa khả dụng',
                      description: 'Hãy chọn nội dung N5 hoặc N4.',
                    )
                  : KanjiPracticeScreen(
                      level: level,
                      entryId: state.pathParameters['id']!,
                    );
            },
          ),
          GoRoute(
            path: '/quiz',
            builder: (context, state) => const VocabularyQuizScreen(),
          ),
          GoRoute(
            path: '/quiz/history',
            builder: (context, state) => const QuizHistoryScreen(),
          ),
          GoRoute(
            path: '/progress',
            builder: (context, state) => const QuizProgressScreen(),
          ),
          GoRoute(
            path: '/srs',
            builder: (context, state) => const SrsStudyScreen(),
          ),
          GoRoute(
            path: '/listening',
            builder: (context, state) => const ReadingScreen(),
          ),
          for (final entry in previewRoutes.entries)
            GoRoute(
              path: entry.key,
              builder: (context, state) => FeaturePreviewScreen(
                title: entry.value.title,
                description: entry.value.description,
              ),
            ),
        ],
      ),
    ],
    errorBuilder: (context, state) => AppShell(
      path: state.uri.path,
      child: const FeaturePreviewScreen(
        title: 'Không tìm thấy trang',
        description: 'Đường dẫn này chưa tồn tại. Hãy quay lại các phần học.',
      ),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});

PreviewLevel? _kanjiLevel(String? value) => switch (value) {
  'n5' => PreviewLevel.n5,
  'n4' => PreviewLevel.n4,
  _ => null,
};
