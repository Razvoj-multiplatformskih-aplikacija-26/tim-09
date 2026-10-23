import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ui/ui.dart';

import 'my_requests_screen.dart';

/// Detalj jednog zahteva na adresi /requests/:id. Zahtev čita iz Bloc stanja po ID-ju,
/// pa adresa radi i bez podataka prosleđenih sa liste.
class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key, required this.id});

  final WashRequestId id;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyRequestsBloc, MyRequestsState>(
      builder: (context, state) {
        final request = state is MyRequestsLoaded ? state.find(id) : null;
        if (state is! MyRequestsLoaded || request == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Zahtev')),
            body: const Center(child: Text('Zahtev nije pronađen.')),
          );
        }
        return _DetailBody(
          request: request,
          washerLate: state.isWasherLate(request),
          busy: state.isCancelling(request),
          onCancel: state.canCancel(request) && !state.isBusy ? () => confirmCancellation(context, request) : null,
        );
      },
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.request, required this.onCancel, required this.washerLate, required this.busy});

  final WashRequest request;
  final VoidCallback? onCancel;
  final bool washerLate;
  final bool busy;

  /// Šta se desilo zahtevu, po stanju. Bez `default`: novo stanje traži red i ovde.
  _Row? _statusRow(WashStatus status) => switch (status) {
    Submitted() => null,
    Accepted(:final at) => _Row(Icons.person_pin_circle_outlined, 'Perač dodeljen', formatDateAndTime(at)),
    InProgress(:final arrivedAt) => _Row(Icons.water_drop_outlined, 'Perač stigao', 'U ${formatTime(arrivedAt)}'),
    Completed(:final finishedAt) => _Row(Icons.check_circle_outline, 'Završeno', formatDateAndTime(finishedAt)),
    Cancelled(:final reason, :final at) => _Row(Icons.cancel_outlined, 'Otkazano ${formatDateAndTime(at)}', reason),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slot = request.slot;
    final note = request.note;
    final statusRow = _statusRow(request.status);
    final cancel = onCancel;
    return Scaffold(
      appBar: AppBar(title: const Text('Zahtev za pranje')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(formatTime(slot.start), style: theme.textTheme.displayMedium),
                    ),
                  ),
                  WashStatusBadge(status: request.status),
                ],
              ),
              Text(formatDate(slot.start), style: theme.textTheme.titleMedium),
              if (washerLate) ...[
                const SizedBox(height: 12),
                Text(
                  'Perač kasni više od ${washerLateAfter.inMinutes} min. Možete otkazati bez penala.',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    _Row(
                      Icons.directions_car_outlined,
                      'Vozilo',
                      '${request.vehicle.type.label}, ${request.vehicle.plate.value}',
                    ),
                    _Row(Icons.local_car_wash_outlined, 'Usluga', request.tier.label),
                    _Row(Icons.place_outlined, 'Adresa', request.address.text),
                    _Row(
                      Icons.schedule_outlined,
                      'Trajanje',
                      '${formatDuration(slot.duration)}, do ${formatTime(slot.end)}',
                    ),
                    _Row(Icons.payments_outlined, 'Cena', formatPrice(request.price.priceRsd)),
                    if (note != null) _Row(Icons.notes_outlined, 'Napomena', note.text),
                    ?statusRow, // dodaje red samo ako nije null
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: cancel == null && !busy
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: busy ? null : cancel,
                icon: busy
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Icon(Icons.close),
                label: Text(busy ? 'Otkazivanje…' : 'Otkaži zahtev'),
              ),
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      subtitle: Text(value, style: theme.textTheme.titleMedium),
    );
  }
}
