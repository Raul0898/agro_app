import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class UploadOverlayStatus {
  final double? progress;
  final String? detail;

  const UploadOverlayStatus({this.progress, this.detail});

  UploadOverlayStatus copyWith({double? progress, String? detail}) {
    return UploadOverlayStatus(
      progress: progress ?? this.progress,
      detail: detail ?? this.detail,
    );
  }
}

typedef OverlayDisposer = void Function();

OverlayDisposer showUploadOverlayForTask(
  BuildContext context,
  UploadTask task, {
  String? label,
}) {
  final stream = task.snapshotEvents.map((snapshot) {
    final total = snapshot.totalBytes;
    final transferred = snapshot.bytesTransferred;
    final double? progress = total > 0
        ? (transferred / total).clamp(0.0, 1.0)
        : null;
    return UploadOverlayStatus(progress: progress);
  });

  final dispose = showUploadOverlayForStream(
    context,
    stream,
    label: label ?? 'Subiendo archivo…',
  );

  task.whenComplete(() {
    dispose();
  });

  return dispose;
}

OverlayDisposer showUploadOverlayForStream(
  BuildContext context,
  Stream<UploadOverlayStatus> stream, {
  String? label,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);

  final notifier = ValueNotifier<UploadOverlayStatus>(const UploadOverlayStatus());

  late final OverlayEntry entry;
  void listener() {
    if (entry.mounted) {
      entry.markNeedsBuild();
    }
  }

  entry = OverlayEntry(
    builder: (ctx) {
      final status = notifier.value;
      return _ProgressOverlay(
        label: label ?? 'Procesando…',
        status: status,
      );
    },
  );

  notifier.addListener(listener);
  overlay.insert(entry);

  late final StreamSubscription<UploadOverlayStatus> sub;
  bool disposed = false;

  void cleanup() {
    if (disposed) return;
    disposed = true;
    sub.cancel();
    notifier.removeListener(listener);
    notifier.dispose();
    if (entry.mounted) {
      entry.remove();
    }
  }

  sub = stream.listen(
    (event) {
      notifier.value = event;
    },
    onError: (_) {
      cleanup();
    },
    onDone: () {
      Future.microtask(cleanup);
    },
    cancelOnError: false,
  );

  return cleanup;
}

Future<T> runWithIndeterminateOverlay<T>(
  BuildContext context,
  Future<T> Function() action, {
  String? label,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);

  final entry = OverlayEntry(
    builder: (_) => _ProgressOverlay(
      label: label ?? 'Procesando…',
      status: const UploadOverlayStatus(),
    ),
  );

  overlay.insert(entry);
  try {
    return await action();
  } finally {
    if (entry.mounted) {
      entry.remove();
    }
  }
}

class _ProgressOverlay extends StatelessWidget {
  final String label;
  final UploadOverlayStatus status;

  const _ProgressOverlay({
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final progress = status.progress;
    final bool determinate =
        progress != null && progress.isFinite && progress >= 0.0;
    final double clampedProgress = determinate
        ? progress.clamp(0.0, 1.0)
        : 0.0;
    final percentText = determinate
        ? '${(clampedProgress * 100).clamp(0, 100).toStringAsFixed(0)}%'
        : null;

    return Stack(
      children: [
        const ModalBarrier(dismissible: false, color: Colors.black54),
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 280,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.82),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: determinate ? clampedProgress : null,
                      strokeWidth: 5,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                      backgroundColor:
                          determinate ? Colors.white24 : Colors.transparent,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if ((status.detail != null && status.detail!.isNotEmpty) ||
                      percentText != null)
                    Column(
                      children: [
                        if (status.detail != null && status.detail!.isNotEmpty)
                          Text(
                            status.detail!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        if (percentText != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              percentText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
