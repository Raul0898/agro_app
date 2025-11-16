import 'package:flutter/material.dart';

class TransferProgressController extends ChangeNotifier {
  double _progress = 0.0;
  bool _visible = false;
  String? _label;
  OverlayEntry? _entry;

  double get progress => _progress;
  bool get isVisible => _visible;
  String? get label => _label;

  void show(BuildContext context, {String? label}) {
    _label = label ?? _label;
    if (_visible) {
      notifyListeners();
      return;
    }

    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;

    _visible = true;
    _entry = OverlayEntry(
      builder: (_) => TransferProgressOverlay(controller: this),
    );
    overlay.insert(_entry!);
    notifyListeners();
  }

  void updateProgress(double value, {String? label}) {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    var shouldNotify = false;

    if ((_progress - normalized).abs() > 1e-6) {
      _progress = normalized;
      shouldNotify = true;
    }

    if (label != null && label != _label) {
      _label = label;
      shouldNotify = true;
    }

    if (shouldNotify && _visible) {
      notifyListeners();
    }
  }

  void hide() {
    if (!_visible) return;
    _visible = false;
    notifyListeners();
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    hide();
    super.dispose();
  }
}

class TransferProgressOverlay extends StatelessWidget {
  const TransferProgressOverlay({
    super.key,
    required this.controller,
    this.label,
  });

  final TransferProgressController controller;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.isVisible) return const SizedBox.shrink();
        final progress = controller.progress.clamp(0.0, 1.0);
        final percent = (progress * 100).clamp(0, 100).toStringAsFixed(0);
        final resolvedLabel = controller.label ?? label ?? 'Procesando…';

        return Material(
          color: Colors.black.withOpacity(0.65),
          child: Center(
            child: Container(
              width: 320,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/IMG/Logo1.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    resolvedLabel,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 10),
                  Text(
                    '$percent%',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
