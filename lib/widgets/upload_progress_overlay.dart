import 'dart:async';

import 'package:flutter/material.dart';

class UploadProgressOverlay extends StatefulWidget {
  const UploadProgressOverlay({
    super.key,
    required this.progressStream,
    this.label,
    this.dismissOnComplete = true,
    this.showLinearIndicator = true,
  });

  final Stream<double> progressStream;
  final String? label;
  final bool dismissOnComplete;
  final bool showLinearIndicator;

  @override
  State<UploadProgressOverlay> createState() => _UploadProgressOverlayState();
}

class _UploadProgressOverlayState extends State<UploadProgressOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _rotationAnimation;
  StreamSubscription<double>? _progressSubscription;
  double _progress = 0;
  bool _hasCompleted = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    final curve = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(curve);
    _rotationAnimation = Tween<double>(begin: -0.03, end: 0.03).animate(curve);

    _progressSubscription = widget.progressStream.listen(_onProgressUpdate);
  }

  @override
  void didUpdateWidget(covariant UploadProgressOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progressStream != widget.progressStream) {
      _progressSubscription?.cancel();
      _progressSubscription = widget.progressStream.listen(_onProgressUpdate);
    }
  }

  void _onProgressUpdate(double value) {
    final progressValue = value.clamp(0.0, 1.0).toDouble();
    if (!mounted) return;
    setState(() {
      _progress = progressValue;
    });

    if (!_hasCompleted && progressValue >= 1.0) {
      _hasCompleted = true;
      if (widget.dismissOnComplete) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        });
      }
    } else if (_hasCompleted && progressValue < 1.0) {
      _hasCompleted = false;
    }
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_progress * 100).clamp(0, 100).toDouble();
    final label = widget.label ?? 'Subiendo… ${percent.toStringAsFixed(0)}%';

    return Material(
      color: Colors.black54,
      child: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: AnimatedBuilder(
                    animation: _rotationAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationAnimation.value,
                        child: child,
                      );
                    },
                    child: Image.asset(
                      'IMG/Logo1.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (widget.showLinearIndicator) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 220,
                    child: LinearProgressIndicator(value: _progress),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
