import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../text/labels.dart';

/// Boje jednog stanja: [accent] za tačku i traku napretka, [background]/[foreground] za čip.
typedef WashStatusColors = ({Color accent, Color background, Color foreground});

extension WashStatusStyle on WashStatus {
  /// Svako stanje ima svoju boju, u obe teme. Bez `default`: novo stanje traži boju i ovde.
  WashStatusColors colors(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (this) {
      Submitted() =>
        dark
            ? (
                accent: const Color(0xFFFBBF24),
                background: const Color(0xFF3A2C0C),
                foreground: const Color(0xFFFCD97D),
              )
            : (
                accent: const Color(0xFFF59E0B),
                background: const Color(0xFFFEF3C7),
                foreground: const Color(0xFF8A4B08),
              ),
      Accepted() =>
        dark
            ? (
                accent: const Color(0xFF60A5FA),
                background: const Color(0xFF172C4D),
                foreground: const Color(0xFFA9CDFD),
              )
            : (
                accent: const Color(0xFF2563EB),
                background: const Color(0xFFDBEAFE),
                foreground: const Color(0xFF1E3F9E),
              ),
      InProgress() =>
        dark
            ? (
                accent: const Color(0xFFA78BFA),
                background: const Color(0xFF2A2049),
                foreground: const Color(0xFFCDBEFD),
              )
            : (
                accent: const Color(0xFF7C3AED),
                background: const Color(0xFFEDE9FE),
                foreground: const Color(0xFF5521B5),
              ),
      Completed() =>
        dark
            ? (
                accent: const Color(0xFF4ADE80),
                background: const Color(0xFF12331F),
                foreground: const Color(0xFF9DF0BA),
              )
            : (
                accent: const Color(0xFF16A34A),
                background: const Color(0xFFDCFCE7),
                foreground: const Color(0xFF14603A),
              ),
      Cancelled() =>
        dark
            ? (
                accent: const Color(0xFF8394A8),
                background: const Color(0xFF1F2B3A),
                foreground: const Color(0xFFA9B6C6),
              )
            : (
                accent: const Color(0xFF94A3B8),
                background: const Color(0xFFEEF2F6),
                foreground: const Color(0xFF4B5869),
              ),
    };
  }

  /// Korak na putu Prijavljen → Prihvaćen → U toku → Završen; otkazan zahtev nema korak.
  int? get step => switch (this) {
    Submitted() => 0,
    Accepted() => 1,
    InProgress() => 2,
    Completed() => 3,
    Cancelled() => null,
  };
}

/// Čip stanja: obojena tačka i naziv na blagoj pozadini iste boje.
class WashStatusBadge extends StatelessWidget {
  const WashStatusBadge({super.key, required this.status});

  final WashStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = status.colors(theme.brightness);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(color: colors.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Traka napretka u četiri dela, kao praćenje dostave. Za otkazan zahtev se ne crta.
class WashProgress extends StatelessWidget {
  const WashProgress({super.key, required this.status});

  final WashStatus status;

  static const steps = 4;

  @override
  Widget build(BuildContext context) {
    final step = status.step;
    if (step == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final accent = status.colors(theme.brightness).accent;
    return Semantics(
      label: 'Korak ${step + 1} od $steps',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < steps; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 5,
                  decoration: BoxDecoration(
                    color: i <= step ? accent : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
