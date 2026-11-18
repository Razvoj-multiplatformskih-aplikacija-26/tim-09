import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ui/ui.dart';

import 'my_requests_screen.dart';

/// Detalj jednog zahteva na adresi /requests/:id. Zahtev čita sa servera po ID-ju,
/// pa adresa radi i kada zapis nije na učitanoj stranici liste.
class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key, required this.id});

  final WashRequestId id;

  void _onState(BuildContext context, RequestDetailState state) {
    if (state is! RequestDetailLoaded) return;
    final notice = state.notice;
    if (notice == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(cancellationMessage(notice))));
    context.read<RequestDetailBloc>().add(const RequestDetailNoticeAcknowledged());
    if (notice is RequestCancelled || notice is CancellationRejected) {
      context.read<MyRequestsBloc>().add(const MyRequestsRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<RequestDetailBloc>();
    return BlocConsumer<RequestDetailBloc, RequestDetailState>(
      listenWhen: (previous, current) => current is RequestDetailLoaded && current.notice != null,
      listener: _onState,
      builder: (context, state) => switch (state) {
        RequestDetailLoaded(:final request, :final canCancel, :final washerLate, :final cancelling) => _DetailBody(
          request: request,
          washerLate: washerLate,
          busy: cancelling,
          onCancel: canCancel && !cancelling
              ? () async {
                  if (await askCancellation(context, request)) {
                    bloc.add(const RequestDetailCancelRequested(reason: 'Otkazao klijent.'));
                  }
                }
              : null,
          onRefresh: () async => bloc.add(const RequestDetailRequested(quiet: true)),
        ),
        RequestDetailLoading() => Scaffold(
          appBar: AppBar(title: const Text('Zahtev')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        RequestDetailUnavailable() => Scaffold(
          appBar: AppBar(title: const Text('Zahtev')),
          body: const Center(child: EmptyView(title: 'Zahtev nije pronađen ili nije dostupan.')),
        ),
        RequestDetailFailure(:final cause) => Scaffold(
          appBar: AppBar(title: const Text('Zahtev')),
          body: Center(
            child: SingleChildScrollView(
              child: FailureView(
                message: failureMessage(cause),
                onRetry: () => bloc.add(const RequestDetailRequested()),
              ),
            ),
          ),
        ),
      },
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.request,
    required this.onCancel,
    required this.washerLate,
    required this.busy,
    required this.onRefresh,
  });

  final WashRequest request;
  final VoidCallback? onCancel;
  final bool washerLate;
  final bool busy;
  final Future<void> Function() onRefresh;

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
    final scheme = theme.colorScheme;
    final slot = request.slot;
    final note = request.note;
    final statusRow = _statusRow(request.status);
    final cancel = onCancel;
    final rows = [
      _Row(request.vehicle.type.icon, 'Vozilo', '${request.vehicle.type.label}, ${request.vehicle.plate.value}'),
      _Row(request.tier.icon, 'Usluga', request.tier.label),
      _Row(Icons.place_outlined, 'Adresa', request.address.text),
      _Row(Icons.schedule_outlined, 'Trajanje', '${formatDuration(slot.duration)}, do ${formatTime(slot.end)}'),
      if (note != null) _Row(Icons.notes_outlined, 'Napomena', note.text),
      ?statusRow,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Zahtev za pranje')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(CarWashTheme.gutter, 4, CarWashTheme.gutter, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Semantics(
                                    header: true,
                                    child: Text(formatTime(slot.start), style: theme.textTheme.displaySmall),
                                  ),
                                  Text(
                                    formatDate(slot.start),
                                    style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            WashStatusBadge(status: request.status),
                          ],
                        ),
                        if (request.status.step != null) ...[
                          const SizedBox(height: 20),
                          WashProgress(status: request.status),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Ukupno',
                                style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                            Text(formatPrice(request.price.priceRsd), style: theme.textTheme.headlineSmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (washerLate) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(CarWashTheme.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, color: scheme.onErrorContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Perač kasni više od ${washerLateAfter.inMinutes} min. Možete otkazati bez penala.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SectionHeader('Detalji'),
                Card(
                  child: Column(
                    children: [
                      for (final (index, row) in rows.indexed) ...[if (index > 0) const Divider(indent: 76), row],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: cancel == null && !busy
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(CarWashTheme.gutter, 8, CarWashTheme.gutter, 16),
              child: OutlinedButton.icon(
                onPressed: busy ? null : cancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error.withValues(alpha: 0.4), width: 1.5),
                ),
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
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            IconBubble(icon),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(value, style: theme.textTheme.titleMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
