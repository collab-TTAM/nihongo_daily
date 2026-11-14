import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/feature_preview_screen.dart';
import '../../../shared/widgets/page_body.dart';
import '../application/ai_text_controller.dart';
import '../application/ai_text_view_binding.dart';
import '../domain/ai_text_models.dart';

const _description = 'Giải thích và sửa câu ở trình độ N5–N4.';

class AiTutorScreen extends ConsumerWidget {
  const AiTutorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final binding = ref.watch(aiTextViewBindingProvider);
    return binding == null
        ? const FeaturePreviewScreen(
            title: 'Trợ lý AI',
            description: _description,
          )
        : _BoundTutor(key: ObjectKey(binding), binding: binding);
  }
}

class _BoundTutor extends StatefulWidget {
  const _BoundTutor({super.key, required this.binding});
  final AiTextViewBinding binding;
  @override
  State<_BoundTutor> createState() => _BoundTutorState();
}

class _BoundTutorState extends State<_BoundTutor> {
  late final AiTextController _controller;
  StreamSubscription<void>? _subscription;
  final _draft = TextEditingController();
  final _focus = FocusNode();
  AiTextLevel _level = AiTextLevel.n5;
  AiTextOperation _operation = AiTextOperation.explain;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    _controller = AiTextController(
      repository: widget.binding.repository,
      availabilityChanges: widget.binding.availabilityChanges,
    );
    _subscription = _controller.changes.listen(
      (_) => _changed(),
      onDone: _changed,
    );
  }

  void _changed() {
    if (!mounted) return;
    if (_controller.state.phase == AiTextPhase.unavailable) {
      _epoch++;
      _draft.clear();
      _focus.unfocus();
    }
    setState(() {});
  }

  bool _accept(int epoch) =>
      mounted && epoch == _epoch && _controller.canSubmit;

  void _choose(int epoch, AiTextLevel level, AiTextOperation operation) {
    if (!_accept(epoch) || !_controller.clearResult()) return;
    setState(() {
      _epoch++;
      _draft.clear();
      _level = level;
      _operation = operation;
    });
  }

  void _send(
    int epoch,
    AiTextLevel level,
    AiTextOperation operation,
    String text,
  ) {
    if (!_accept(epoch) ||
        _level != level ||
        _operation != operation ||
        _draft.text != text ||
        text.trim().isEmpty) {
      return;
    }
    _focus.unfocus();
    final work = operation == AiTextOperation.explain
        ? _controller.explain(level: level, questionVi: text)
        : _controller.correct(level: level, sentenceJa: text);
    setState(() {});
    unawaited(work);
  }

  @override
  void dispose() {
    _epoch++;
    unawaited(_subscription?.cancel());
    _controller.dispose();
    _draft.clear();
    _draft.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    if (state.phase == AiTextPhase.unavailable) {
      return const PageBody(
        children: [
          PageHeading(title: 'Trợ lý AI', subtitle: _description),
          Text('Trợ lý chưa khả dụng cho phiên hiện tại.'),
          Text('Hãy mở lại trợ lý sau khi đăng nhập và kết nối sẵn sàng.'),
          Text('Hội thoại giọng nói chưa khả dụng.'),
        ],
      );
    }
    final canSubmit = _controller.canSubmit;
    final epoch = _epoch;
    final level = _level;
    final operation = _operation;
    final text = _draft.text;
    return PageBody(
      children: [
        const PageHeading(title: 'Trợ lý AI', subtitle: _description),
        DropdownButtonFormField<AiTextLevel>(
          key: const Key('ai-level'),
          initialValue: level,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Trình độ'),
          items: [
            for (final l in [AiTextLevel.n5, AiTextLevel.n4])
              DropdownMenuItem(value: l, child: Text(l.wireName)),
          ],
          onChanged: canSubmit
              ? (value) {
                  if (value != null) _choose(epoch, value, operation);
                }
              : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<AiTextOperation>(
          key: const Key('ai-operation'),
          initialValue: operation,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Cách luyện tập'),
          items: const [
            DropdownMenuItem(
              value: AiTextOperation.explain,
              child: Text('Giải thích'),
            ),
            DropdownMenuItem(
              value: AiTextOperation.correct,
              child: Text('Sửa câu'),
            ),
          ],
          onChanged: canSubmit
              ? (value) {
                  if (value != null) _choose(epoch, level, value);
                }
              : null,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('ai-draft'),
          controller: _draft,
          focusNode: _focus,
          enabled: canSubmit,
          minLines: 3,
          maxLines: 8,
          enableSuggestions: false,
          autocorrect: false,
          inputFormatters: [
            TextInputFormatter.withFunction((oldValue, newValue) {
              return newValue.text.length > 10000 ||
                      newValue.text.runes.length > 5000
                  ? oldValue
                  : newValue;
            }),
          ],
          decoration: InputDecoration(
            labelText: operation == AiTextOperation.explain
                ? 'Câu hỏi bằng tiếng Việt'
                : 'Câu tiếng Nhật cần sửa',
            helperText: '${text.runes.length}/5000 ký tự',
          ),
          onChanged: (_) {
            if (!mounted || epoch != _epoch || !_controller.canSubmit) return;
            _epoch++;
            _controller.clearResult();
            setState(() {});
          },
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              key: const Key('ai-send'),
              onPressed: canSubmit && text.trim().isNotEmpty
                  ? () => _send(epoch, level, operation, text)
                  : null,
              child: const Text('Gửi yêu cầu'),
            ),
            OutlinedButton(
              key: const Key('ai-clear'),
              onPressed: canSubmit
                  ? () => _choose(epoch, level, operation)
                  : null,
              child: const Text('Xóa nội dung'),
            ),
            if (state.phase == AiTextPhase.error ||
                state.phase == AiTextPhase.pending ||
                (!canSubmit && state.phase != AiTextPhase.loading))
              OutlinedButton(
                key: const Key('ai-recheck'),
                onPressed: () {
                  if (mounted && epoch == _epoch) _controller.recheck();
                },
                child: const Text('Kiểm tra trạng thái'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Gửi lại có thể tạo yêu cầu AI mới. Hãy kiểm tra trước khi gửi.',
        ),
        const Text('Hội thoại giọng nói chưa khả dụng.'),
        const SizedBox(height: 16),
        if (state.phase == AiTextPhase.idle)
          const Text('Nhập câu hỏi hoặc câu cần sửa để bắt đầu.'),
        if (state.phase == AiTextPhase.loading)
          Semantics(
            liveRegion: true,
            child: const Text('Đang chờ kết quả AI…'),
          ),
        if (state.phase == AiTextPhase.pending ||
            (!canSubmit && state.phase != AiTextPhase.loading))
          const Text('Yêu cầu AI trước vẫn đang xử lý.'),
        if (state.failure != null)
          Semantics(liveRegion: true, child: Text(state.failure!.messageVi)),
        if (state.phase == AiTextPhase.success) _Result(state: state),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.state});
  final AiTextState state;
  @override
  Widget build(BuildContext context) {
    final explanation = state.explanation;
    final correction = state.correction;
    return Column(
      key: const Key('ai-result'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Kết quả ${state.level!.wireName}'),
        const Text('Kết quả tham khảo. Chưa lưu vào tiến độ.'),
        Text(state.submittedText!),
        if (explanation != null) ...[
          Text(explanation.answerVi),
          for (final e in explanation.examples) ...[
            const Divider(),
            Text(e.sentenceJa),
            Text(e.readingJa),
            Text(e.translationVi),
          ],
          for (final p in explanation.practice) ...[
            const Divider(),
            Text(p.questionJa),
            Text(p.answerJa),
            Text(p.explanationVi),
          ],
        ],
        if (correction != null) ...[
          const Text('Câu đã sửa'),
          Text(correction.correctedSentence),
          const Text('Cách nói tự nhiên'),
          Text(correction.naturalSentence),
          if (correction.grammarErrors.isEmpty &&
              correction.vocabularyErrors.isEmpty)
            const Text('Không có lỗi được dịch vụ trả về.'),
          for (final e in [
            ...correction.grammarErrors,
            ...correction.vocabularyErrors,
          ]) ...[
            const Divider(),
            Text(e.originalText),
            Text(e.correctedText),
            Text(e.explanationVi),
          ],
        ],
      ],
    );
  }
}
