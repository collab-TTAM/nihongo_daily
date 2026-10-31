import 'package:flutter/material.dart';

class AppDestination {
  const AppDestination(this.path, this.label, this.icon);

  final String path;
  final String label;
  final IconData icon;
}

const appDestinations = [
  AppDestination('/', 'Hôm nay', Icons.today_outlined),
  AppDestination('/study', 'Học tập', Icons.menu_book_outlined),
  AppDestination('/kanji', 'Kanji', Icons.draw_outlined),
  AppDestination('/ai', 'Trợ lý AI', Icons.chat_bubble_outline),
  AppDestination('/progress', 'Tiến độ', Icons.insights_outlined),
  AppDestination('/settings', 'Cài đặt', Icons.settings_outlined),
];

int destinationIndex(String path) {
  return switch (path) {
    '/study' ||
    '/vocabulary' ||
    '/grammar' ||
    '/srs' ||
    '/quiz' ||
    '/listening' => 1,
    '/kanji' || '/kanji/characters' => 2,
    _ when path.startsWith('/kanji/practice/') => 2,
    '/ai' || '/conversation' => 3,
    '/progress' => 4,
    '/settings' || '/auth' => 5,
    _ => 0,
  };
}
