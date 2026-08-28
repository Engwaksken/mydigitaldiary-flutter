import 'package:flutter/material.dart';

class AppErrorScreen extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;
  final VoidCallback? onHome;
  final bool compact;

  const AppErrorScreen({
    super.key,
    this.title = 'Something went wrong',
    this.message =
        'We could not complete this action. Please try again.',
    this.onRetry,
    this.onBack,
    this.onHome,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: EdgeInsets.all(compact ? 18 : 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .04),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: compact ? 60 : 76,
                  height: compact ? 60 : 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context)
                        .colorScheme
                        .error
                        .withValues(alpha: .08),
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: compact ? 30 : 38,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 18 : 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.45,
                  ),
                ),
                if (onRetry != null || onBack != null || onHome != null) ...[
                  const SizedBox(height: 22),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (onBack != null)
                        OutlinedButton.icon(
                          onPressed: onBack,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back'),
                        ),
                      if (onHome != null)
                        OutlinedButton.icon(
                          onPressed: onHome,
                          icon: const Icon(Icons.dashboard_outlined),
                          label: const Text('Dashboard'),
                        ),
                      if (onRetry != null)
                        FilledButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (compact) {
      return Material(
        color: const Color(0xFFF5F7F9),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text('Hotel HMS'),
      ),
      body: SafeArea(child: content),
    );
  }
}
