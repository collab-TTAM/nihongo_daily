import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/curriculum/domain/curriculum.dart';
import '../features/curriculum/presentation/curriculum_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/kanji/presentation/kanji_capture_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/study/presentation/study_screen.dart';
import '../shared/widgets/feature_preview_screen.dart';
import 'app_shell.dart';

const previewRoutes = <String, ({String title, String description})>{
  '/srs': (
    title: 'Ôn tập SRS',
    description: 'Ôn đúng thời điểm để ghi nhớ lâu hơn.',
  ),
  '/quiz': (
    title: 'Kiểm tra nhanh',
    description: 'Củng cố kiến thức qua các câu hỏi ngắn.',
  ),
  '/listening': (
    title: 'Nghe và đọc',
    description: 'Luyện hiểu tiếng Nhật trong ngữ cảnh.',
  ),
  '/ai': (
    title: 'Trợ lý AI',
    description: 'Giải thích và sửa câu ở trình độ N5–N4.',
  ),
  '/conversation': (
    title: 'Hội thoại AI',
    description: 'Luyện hội thoại theo tình huống.',
  ),
  '/progress': (
    title: 'Tiến độ học tập',
    description: 'Theo dõi thói quen và điểm cần ôn lại.',
  ),
  '/auth': (
    title: 'Tài khoản',
    description: 'Đăng nhập và đồng bộ sẽ có khi tích hợp Supabase.',
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
