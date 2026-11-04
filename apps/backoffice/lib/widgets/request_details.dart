import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ui/ui.dart';

import '../dependencies.dart';

/// Podaci jednog zahteva. Isti widget je desni panel na širokom ekranu i telo posebnog ekrana na uskom.
class RequestDetails extends StatelessWidget {
  const RequestDetails({super.key, required this.request});

  final WashRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = request.status;
    final slot = request.slot;
    final rows = [
      _Row(Icons.event_outlined, 'Termin', '${formatDateAndTime(slot.start)} · ${formatDuration(slot.duration)}'),
      _Row(request.vehicle.type.icon, 'Vozilo', '${request.vehicle.type.label} · ${request.vehicle.plate.value}'),
      _Row(request.tier.icon, 'Usluga', '${request.tier.label} · ${formatPrice(request.price.priceRsd)}'),
      _Row(Icons.place_outlined, 'Adresa', request.address.text),
      _Row(Icons.person_outline, 'Klijent', request.clientId.value),
      if (request.note case final note?) _Row(Icons.sticky_note_2_outlined, 'Napomena', note.text),
      ...switch (status) {
        Accepted(:final washerId, :final at) => [
          _Row(Icons.badge_outlined, 'Perač', BackofficeDependencies.washerName(washerId)),
          _Row(Icons.check_circle_outline, 'Dodeljen', formatDateAndTime(at)),
        ],
        InProgress(:final washerId, :final arrivedAt) => [
          _Row(Icons.badge_outlined, 'Perač', BackofficeDependencies.washerName(washerId)),
          _Row(Icons.local_car_wash_outlined, 'Stigao', formatDateAndTime(arrivedAt)),
        ],
        Completed(:final finishedAt) => [_Row(Icons.done_all, 'Završeno', formatDateAndTime(finishedAt))],
        Cancelled(:final reason, :final at) => [
          _Row(Icons.cancel_outlined, 'Otkazano', formatDateAndTime(at)),
          if (reason.isNotEmpty) _Row(Icons.info_outline, 'Razlog', reason),
        ],
        Submitted() => const <Widget>[],
      },
    ];
    return ListView(
      padding: const EdgeInsets.all(CarWashTheme.gutter),
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text('Zahtev ${request.id.value}', style: theme.textTheme.headlineSmall),
              ),
            ),
            WashStatusBadge(status: status),
          ],
        ),
        const SizedBox(height: 16),
        WashProgress(status: status),
        const SizedBox(height: 8),
        for (final (index, row) in rows.indexed) ...[if (index > 0) const Divider(indent: 76), row],
      ],
    );
  }
}

/// Radnje koje dispečer sme nad zahtevom u njegovom stanju; dok radnja traje, umesto dugmadi je indikator.
class RequestActions extends StatelessWidget {
  const RequestActions({super.key, required this.request, required this.busy});

  final WashRequest request;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<DispatchBloc>();
    final error = Theme.of(context).colorScheme.error;
    final cancel = OutlinedButton.icon(
      onPressed: () => confirmCancellation(context, request),
      style: OutlinedButton.styleFrom(
        foregroundColor: error,
        side: BorderSide(color: error.withValues(alpha: 0.4)),
      ),
      icon: const Icon(Icons.close),
      label: const Text('Otkaži zahtev'),
    );
    final actions = switch (request.status) {
      Submitted() => [
        FilledButton.icon(
          onPressed: () => assignWasher(context, request),
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Dodeli perača'),
        ),
        cancel,
      ],
      Accepted() => [
        OutlinedButton.icon(
          onPressed: () => bloc.add(DispatchReleaseRequested(request.id)),
          icon: const Icon(Icons.undo),
          label: const Text('Vrati u red'),
        ),
        cancel,
      ],
      InProgress() => [cancel],
      Completed() || Cancelled() => const <Widget>[],
    };
    if (actions.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(CarWashTheme.gutter, 8, CarWashTheme.gutter, 16),
      child: busy
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3)),
              ),
            )
          : Wrap(alignment: WrapAlignment.end, spacing: 12, runSpacing: 8, children: actions),
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
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

/// Bira perača i šalje dodelu. Perača koji već ima aktivan posao ne nudi; ako ga za to vreme
/// zauzme neko drugi, domen svejedno odbije dodelu i ekran javi zašto.
Future<void> assignWasher(BuildContext context, WashRequest request) async {
  final bloc = context.read<DispatchBloc>();
  final state = bloc.state;
  bool isBusy(WasherId washer) => state is DispatchLoaded && state.isWasherBusy(washer);
  final washer = await showDialog<WasherId>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Dodeli perača'),
      children: [
        for (final w in BackofficeDependencies.washers)
          ListTile(
            enabled: !isBusy(w.id),
            leading: const Icon(Icons.badge_outlined),
            title: Text(w.name),
            subtitle: Text(isBusy(w.id) ? 'Ima aktivan posao' : 'Slobodan'),
            onTap: () => Navigator.pop(context, w.id),
          ),
      ],
    ),
  );
  if (washer == null || !context.mounted) return;
  bloc.add(DispatchAcceptRequested(request.id, washer));
}

/// Otkazivanje je nepovratno, pa prvo pita. Posle „Otkaži zahtev“ ekran samo šalje događaj Bloc-u.
Future<void> confirmCancellation(BuildContext context, WashRequest request) async {
  final bloc = context.read<DispatchBloc>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      title: const Text('Otkazati zahtev?'),
      content: Text(
        '${request.vehicle.plate.value} · ${formatDateAndTime(request.slot.start)}\n'
        '${request.address.text}\n\nOvo ne može da se poništi.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Odustani')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          child: const Text('Otkaži zahtev'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  bloc.add(DispatchCancelRequested(request.id, reason: 'Otkazao dispečer.'));
}
