import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../text/labels.dart';

class WashStatusBadge extends StatelessWidget {
  const WashStatusBadge({super.key, required this.status});

  final WashStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final (background, foreground) = switch (status) {
      Submitted() => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      Accepted() => (scheme.primaryContainer, scheme.onPrimaryContainer),
      InProgress() => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      Completed() =>
        isDark
            ? (const Color(0xFF1E4D2B), const Color(0xFFB6F2C3))
            : (const Color(0xFFD3F5DC), const Color(0xFF0F4A22)),
      Cancelled() => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(status.label, style: theme.textTheme.labelMedium?.copyWith(color: foreground)),
    );
  }
}
