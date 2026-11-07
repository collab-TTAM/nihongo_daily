import '../domain/daily_plan.dart';

String dailyPlanAreaLabel(DailyPlanArea area) => switch (area) {
  DailyPlanArea.srs => 'Ôn tập SRS',
  DailyPlanArea.vocabulary => 'Từ vựng',
  DailyPlanArea.kanji => 'Hán tự',
  DailyPlanArea.grammar => 'Ngữ pháp',
  DailyPlanArea.listeningReading => 'Nghe và đọc',
  DailyPlanArea.aiConversation => 'Hội thoại AI',
  DailyPlanArea.quizReview => 'Kiểm tra và ôn lại',
};

String dailyPlanStatusLabel(DailyPlanStatus status) => switch (status) {
  DailyPlanStatus.ready => 'Sẵn sàng',
  DailyPlanStatus.inProgress => 'Đang học',
  DailyPlanStatus.done => 'Hoàn thành',
  DailyPlanStatus.blocked => 'Chưa khả dụng',
};
