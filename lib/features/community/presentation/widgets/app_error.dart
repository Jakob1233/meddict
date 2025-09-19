// COMMUNITY 2.0
import 'package:flutter/material.dart';

class AppError extends StatelessWidget {
  // COMMUNITY 2.0
  const AppError({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (onRetry != null)
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Erneut versuchen'),
              ),
          ],
        ),
      ),
    );
  }
}
