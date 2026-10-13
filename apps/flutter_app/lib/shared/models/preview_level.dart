// Levels offered in the preview. Full curriculum/API adapters use v0.1 schemas.
enum PreviewLevel { n5, n4 }

extension PreviewLevelLabel on PreviewLevel {
  String get label => name.toUpperCase();
}
