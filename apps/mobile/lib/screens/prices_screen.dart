import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:ui/ui.dart';

/// Cenovnik: iste cene koje forma računa, iz funkcije [estimate] u domenu.
class PricesScreen extends StatelessWidget {
  const PricesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(CarWashTheme.gutter, 8, CarWashTheme.gutter, 32),
              children: [
                Semantics(header: true, child: Text('Cenovnik', style: theme.textTheme.headlineMedium)),
                const SizedBox(height: 4),
                Text(
                  'Cena zavisi od vozila i usluge. Perač dolazi na vašu adresu.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                for (final type in VehicleType.values) ...[_VehicleCard(type: type), const SizedBox(height: 12)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.type});

  final VehicleType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBubble(type.icon),
                const SizedBox(width: 12),
                Text(type.label, style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final (index, tier) in ServiceTier.values.indexed) ...[
                  if (index > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _TierPrice(type: type, tier: tier),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TierPrice extends StatelessWidget {
  const _TierPrice({required this.type, required this.tier});

  final VehicleType type;
  final ServiceTier tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final price = estimate(type, tier);
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(CarWashTheme.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(tier.icon, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    tier.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(formatPrice(price.priceRsd), style: theme.textTheme.titleLarge),
            Text(
              formatDuration(price.duration),
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
