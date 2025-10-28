import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'upload_progress_overlay.dart';

/// Converts a [UploadTask]'s [TaskSnapshot] events into a broadcast stream of
/// doubles in the range `[0.0, 1.0]`.
///
/// The `totalBytes == 0` case is guarded to avoid NaN / infinity values when
/// Firebase has not yet reported the upload size (or is indeterminate).
Stream<double> uploadTaskToProgressStream(UploadTask task) {
  final progressStream = task.snapshotEvents.map((snapshot) {
    final total = snapshot.totalBytes;
    if (total == 0) return 0.0;

    final transferred = snapshot.bytesTransferred;
    final progress = transferred / total;
    if (progress.isNaN || progress.isInfinite) return 0.0;

    return progress.clamp(0.0, 1.0);
  });

  return progressStream.isBroadcast ? progressStream : progressStream.asBroadcastStream();
}

/// Shows the [UploadProgressOverlay] for the provided [UploadTask].
///
/// The dialog automatically dismisses once the upload stream reports
/// completion, or in case the stream finishes/errs. Any error from the stream
/// is rethrown after the overlay is closed so callers can handle it normally.
Future<void> showUploadOverlayForTask(
  BuildContext context,
  UploadTask task, {
  String? title,
  String? description,
}) {
  return showUploadOverlayForStream(
    context,
    uploadTaskToProgressStream(task),
    title: title,
    description: description,
  );
}

/// Displays an [UploadProgressOverlay] for any custom progress [Stream].
Future<void> showUploadOverlayForStream(
  BuildContext context,
  Stream<double> progressStream, {
  String? title,
  String? description,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final stream = progressStream.isBroadcast ? progressStream : progressStream.asBroadcastStream();
  var dismissed = false;
  Object? streamError;
  StackTrace? streamStackTrace;

  void dismiss() {
    if (dismissed) return;
    dismissed = true;
    if (navigator.mounted) {
      navigator.pop();
    }
  }

  late final StreamSubscription<double> subscription;

  final dialogFuture = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => UploadProgressOverlay(
      progressStream: stream,
      title: title,
      description: description,
    ),
  );

  // Ensure the dialog has a chance to build before attempting to dismiss it.
  await Future<void>.delayed(Duration.zero);

  subscription = stream.listen(
    (progress) {
      if (progress >= 1.0) {
        dismiss();
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      streamError = error;
      streamStackTrace = stackTrace;
      dismiss();
    },
    onDone: dismiss,
  );

  await dialogFuture;
  await subscription.cancel();

  if (streamError != null) {
    Error.throwWithStackTrace(streamError!, streamStackTrace!);
  }
}

/// Signature for the asynchronous operation to run while an indeterminate
/// overlay is visible.
typedef IndeterminateOverlayOperation<T> = Future<T> Function(
  UploadOverlayController controller,
);

/// Controller exposed to callers when using [runWithIndeterminateOverlay].
///
/// It allows updating the optional descriptive text displayed by the overlay
/// while the background operation progresses.
class UploadOverlayController {
  UploadOverlayController._(this._setMessage);

  final void Function(String? message) _setMessage;

  /// Updates the descriptive message shown by the overlay.
  void updateMessage(String? message) => _setMessage(message);
}

/// Runs [operation] while presenting an indeterminate
/// [UploadProgressOverlay.indeterminate].
///
/// The overlay is dismissed automatically once the operation finishes (either
/// successfully or with an error). Callers can update the overlay's message via
/// the provided [UploadOverlayController].
Future<T> runWithIndeterminateOverlay<T>(
  BuildContext context,
  IndeterminateOverlayOperation<T> operation, {
  String? title,
  String? initialMessage,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final messageNotifier = ValueNotifier<String?>(initialMessage);
  var dismissed = false;

  void dismiss() {
    if (dismissed) return;
    dismissed = true;
    if (navigator.mounted) {
      navigator.pop();
    }
  }

  final dialogFuture = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => UploadProgressOverlay.indeterminate(
      title: title,
      message: messageNotifier.value,
      messageListenable: messageNotifier,
    ),
  );

  final controller = UploadOverlayController._((String? message) {
    messageNotifier.value = message;
  });

  try {
    final result = await operation(controller);
    dismiss();
    await dialogFuture;
    return result;
  } catch (error) {
    dismiss();
    await dialogFuture;
    rethrow;
  } finally {
    messageNotifier.dispose();
  }
}
