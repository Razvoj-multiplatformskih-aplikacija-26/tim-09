import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

extension VehicleTypeIcon on VehicleType {
  IconData get icon => switch (this) {
    VehicleType.hatchback => Icons.directions_car_outlined,
    VehicleType.sedan => Icons.time_to_leave_outlined,
    VehicleType.suv => Icons.directions_car_filled_outlined,
    VehicleType.van => Icons.airport_shuttle_outlined,
  };
}

extension ServiceTierIcon on ServiceTier {
  IconData get icon => switch (this) {
    ServiceTier.economy => Icons.water_drop_outlined,
    ServiceTier.professional => Icons.auto_awesome_outlined,
  };
}

/// Ikonica u obojenom krugu, kao u listama Revolut-a.
class IconBubble extends StatelessWidget {
  const IconBubble(this.icon, {super.key, this.color, this.size = 44});

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Icon(icon, color: tint, size: size * 0.5),
    );
  }
}

/// Naslov odeljka u listi, sa opcionim delom desno (npr. broj stavki).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trailing = this.trailing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Semantics(header: true, child: Text(title, style: theme.textTheme.titleLarge)),
          ),
          if (trailing != null)
            Text(trailing, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Pločica za izbor jedne opcije (tip vozila, usluga). Izabrana dobija plavu ivicu i blagu pozadinu.
class SelectableTile extends StatelessWidget {
  const SelectableTile({super.key, required this.selected, required this.onTap, required this.child});

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(CarWashTheme.radiusMd);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? scheme.primary.withValues(alpha: 0.08) : scheme.surfaceContainerLowest,
              borderRadius: radius,
              border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1.5),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
