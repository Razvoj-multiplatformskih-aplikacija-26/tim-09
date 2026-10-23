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
      appBar: AppBar(title: const Text('Cenovnik')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final type in VehicleType.values) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(type.label, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        for (final tier in ServiceTier.values)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text(tier.label, style: theme.textTheme.bodyLarge)),
                                Text(
                                  '${formatPrice(estimate(type, tier).priceRsd)} · '
                                  '${formatDuration(estimate(type, tier).duration)}',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
