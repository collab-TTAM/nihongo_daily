import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/preview_level.dart';

export '../../../shared/models/preview_level.dart';

// Preview-only preferences: no account, storage, or server settings are changed.
final previewLevelProvider = StateProvider<PreviewLevel>(
  (ref) => PreviewLevel.n5,
);
final previewThemeProvider = StateProvider<ThemeMode>(
  (ref) => ThemeMode.system,
);
