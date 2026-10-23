import 'package:flutter/material.dart';

/// Učitavanje: sivi „kosturi“ kartica dok podaci ne stignu.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.cards = 4});

  final int cards;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      label: 'Učitavanje',
      child: ExcludeSemantics(
        child: Column(
          children: [
            for (var i = 0; i < cards; i++)
              Container(
                height: 110,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
              ),
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_car_wash_outlined, size: 72, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

class FailureView extends StatelessWidget {
  const FailureView({super.key, required this.onRetry, this.title = 'Podaci trenutno nisu dostupni.'});

  final VoidCallback onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 72, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Pokušaj ponovo'),
          ),
        ],
      ),
    );
  }
}
