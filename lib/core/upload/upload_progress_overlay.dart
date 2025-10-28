import 'package:flutter/material.dart';

enum _OverlayMode { progress, indeterminate }

class UploadProgressOverlay extends StatelessWidget {
  const UploadProgressOverlay({
    super.key,
    required Stream<double> progressStream,
    this.title,
    this.description,
    this.progressLabelBuilder,
  })  : _progressStream = progressStream,
        _messageListenable = null,
        _initialMessage = description,
        _mode = _OverlayMode.progress;

  const UploadProgressOverlay.indeterminate({
    super.key,
    this.title,
    String? message,
    ValueListenable<String?>? messageListenable,
  })  : _progressStream = null,
        description = null,
        progressLabelBuilder = null,
        _messageListenable = messageListenable,
        _initialMessage = message,
        _mode = _OverlayMode.indeterminate;

  final Stream<double>? _progressStream;
  final String? title;
  final String? description;
  final ValueListenable<String?>? _messageListenable;
  final _OverlayMode _mode;
  final String Function(double progress)? progressLabelBuilder;
  final String? _initialMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dialog = Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.black.withOpacity(0.85),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: _mode == _OverlayMode.progress
            ? _ProgressContent(
                stream: _progressStream!,
                title: title,
                description: description,
                labelBuilder: progressLabelBuilder,
                theme: theme,
              )
            : _IndeterminateContent(
                title: title,
                messageListenable: _messageListenable,
                initialMessage: _initialMessage,
                theme: theme,
              ),
      ),
    );

    return dialog;
  }
}

class _ProgressContent extends StatelessWidget {
  const _ProgressContent({
    required this.stream,
    required this.theme,
    this.title,
    this.description,
    this.labelBuilder,
  });

  final Stream<double> stream;
  final ThemeData theme;
  final String? title;
  final String? description;
  final String Function(double progress)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    final textTheme = theme.textTheme;
    final accent = theme.colorScheme.secondary;

    return StreamBuilder<double>(
      stream: stream,
      initialData: 0.0,
      builder: (context, snapshot) {
        final value = (snapshot.data ?? 0.0).clamp(0.0, 1.0);
        final label = (labelBuilder ?? _defaultLabelBuilder)(value);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              height: 68,
              width: 68,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 6,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
                backgroundColor: accent.withOpacity(0.18),
              ),
            ),
            const SizedBox(height: 18),
            if (title != null)
              Text(
                title!,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (title != null) const SizedBox(height: 6),
            Text(
              label,
              style: textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 10),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ],
          ],
        );
      },
    );
  }

  static String _defaultLabelBuilder(double progress) => '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%';
}

class _IndeterminateContent extends StatelessWidget {
  const _IndeterminateContent({
    required this.theme,
    this.title,
    this.messageListenable,
    this.initialMessage,
  });

  final ThemeData theme;
  final String? title;
  final ValueListenable<String?>? messageListenable;
  final String? initialMessage;

  @override
  Widget build(BuildContext context) {
    final textTheme = theme.textTheme;
    final accent = theme.colorScheme.secondary;

    Widget buildMessage(String? message) {
      if ((message ?? initialMessage)?.isEmpty ?? true) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          message ?? initialMessage!,
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 68,
          width: 68,
          child: CircularProgressIndicator(
            strokeWidth: 6,
            valueColor: AlwaysStoppedAnimation<Color>(accent),
            backgroundColor: accent.withOpacity(0.18),
          ),
        ),
        const SizedBox(height: 18),
        if (title != null)
          Text(
            title!,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (title != null) const SizedBox(height: 6),
        if (messageListenable != null)
          ValueListenableBuilder<String?>(
            valueListenable: messageListenable!,
            builder: (_, message, __) => buildMessage(message),
          )
        else
          buildMessage(initialMessage),
      ],
    );
  }
}
