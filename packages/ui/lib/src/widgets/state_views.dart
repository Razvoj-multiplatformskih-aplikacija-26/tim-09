import 'package:flutter/material.dart';

import '../theme.dart';

/// Učitavanje: „kosturi“ kartica koji blago pulsiraju dok podaci ne stignu.
class ListSkeleton extends StatefulWidget {
  const ListSkeleton({super.key, this.cards = 4});

  final int cards;

  @override
  State<ListSkeleton> createState() => _ListSkeletonState();
}

class _ListSkeletonState extends State<ListSkeleton> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHigh;
    return Semantics(
      label: 'Učitavanje',
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: Tween(begin: 0.5, end: 1.0).animate(_pulse),
          child: Column(
            children: [
              for (var i = 0; i < widget.cards; i++)
                Container(
                  height: i == 0 ? 168 : 88,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(CarWashTheme.radiusLg)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Zajednički izgled praznog i neuspelog prikaza: velika ikonica u krugu, naslov, opis i akcija.
class _MessageView extends StatelessWidget {
  const _MessageView({required this.icon, required this.color, required this.title, this.subtitle, this.action});

  final IconData icon;
  final Color color;
  final Widget title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;
    final action = this.action;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 44, color: color),
          ),
          const SizedBox(height: 24),
          DefaultTextStyle.merge(style: theme.textTheme.titleLarge, textAlign: TextAlign.center, child: title),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[const SizedBox(height: 24), action],
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.title, this.subtitle, this.action});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return _MessageView(
      icon: Icons.local_car_wash_outlined,
      color: Theme.of(context).colorScheme.primary,
      title: Text(title),
      subtitle: subtitle,
      action: action,
    );
  }
}

class FailureView extends StatelessWidget {
  const FailureView({super.key, required this.onRetry, this.title = 'Podaci trenutno nisu dostupni.'});

  final VoidCallback onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    return _MessageView(
      icon: Icons.cloud_off_outlined,
      color: Theme.of(context).colorScheme.error,
      title: Semantics(liveRegion: true, child: Text(title)),
      subtitle: 'Proverite internet vezu i pokušajte ponovo.',
      action: FilledButton.tonalIcon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Pokušaj ponovo'),
      ),
    );
  }
}
