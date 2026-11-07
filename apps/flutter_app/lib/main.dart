import 'package:flutter/material.dart';
import 'app/staging_bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(selectBootstrapApp(StagingBuildSettings.compiled));
}
