import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Route discovery only; each destination owns its readiness and explicit load.
class QuizProgressNavigation extends StatelessWidget {
  const QuizProgressNavigation({super.key, required this.grammar});

  final bool grammar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Từ vựng và ngữ pháp được thống kê riêng.'),
        OutlinedButton(
          key: const Key('progress-vocabulary'),
          onPressed: grammar ? () => context.go('/progress') : null,
          child: const Text('Tiến độ quiz từ vựng'),
        ),
        OutlinedButton(
          key: const Key('progress-grammar'),
          onPressed: grammar
              ? null
              : () => context.go('/quiz/grammar/progress'),
          child: const Text('Tiến độ quiz ngữ pháp'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
