import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ui/ui.dart';

import '../dependencies.dart';

/// Glavni ekran: crta četiri stanja iz [MyRequestsBloc] i samo šalje događaje.
class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  void _showNotice(BuildContext context, MyRequestsNotice notice) {
    final message = switch (notice) {
      RequestCancelled() => 'Zahtev je otkazan.',
      CancellationRejected(:final error) => error.message,
      CancellationFailed() => 'Otkazivanje nije uspelo. Pokušajte ponovo.',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    context.read<MyRequestsBloc>().add(const MyRequestsNoticeAcknowledged());
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MyRequestsBloc>();
    return Scaffold(
      appBar: AppBar(title: const Text('Moji zahtevi'), actions: const [_DebugMenu()]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/new'),
        icon: const Icon(Icons.add),
        label: const Text('Novi zahtev'),
      ),
      body: BlocConsumer<MyRequestsBloc, MyRequestsState>(
        listenWhen: (previous, current) => current is MyRequestsLoaded && current.notice != null,
        listener: (context, state) => _showNotice(context, (state as MyRequestsLoaded).notice!),
        builder: (context, state) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: switch (state) {
              MyRequestsLoading() => ListView(padding: const EdgeInsets.all(16), children: const [ListSkeleton()]),
              MyRequestsFailure() => ListView(
                children: [FailureView(onRetry: () => bloc.add(const MyRequestsRequested()))],
              ),
              MyRequestsEmpty() => ListView(children: const [EmptyView(title: 'Još nemate zahteva za pranje.')]),
              MyRequestsLoaded() => _RequestList(state: state),
            },
          ),
        ),
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({required this.state});

  final MyRequestsLoaded state;

  Widget _card(BuildContext context, WashRequest request) {
    return Padding(
      key: ValueKey(request.id),
      padding: const EdgeInsets.only(bottom: 12),
      child: _RequestCard(
        request: request,
        washerLate: state.isWasherLate(request),
        busy: state.isCancelling(request),
        onOpen: () => context.push('/requests/${request.id.value}'),
        onCancel: state.canCancel(request) && !state.isBusy ? () => confirmCancellation(context, request) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        if (state.active.isNotEmpty) ...[
          const _SectionTitle('Aktivni'),
          for (final request in state.active) _card(context, request),
        ],
        if (state.past.isNotEmpty) ...[
          const _SectionTitle('Prethodni'),
          for (final request in state.past) _card(context, request),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleLarge)),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onOpen,
    required this.onCancel,
    this.washerLate = false,
    this.busy = false,
  });

  final WashRequest request;
  final VoidCallback onOpen;
  final VoidCallback? onCancel;
  final bool washerLate;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final cancel = onCancel;
    return Card(
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MergeSemantics(
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
                              Text(formatTime(request.slot.start), style: theme.textTheme.headlineMedium),
                              Text(formatDate(request.slot.start), style: muted),
                            ],
                          ),
                        ),
                        WashStatusBadge(status: request.status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${request.vehicle.type.label} · ${request.vehicle.plate.value} · ${request.tier.label}',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(request.address.text, style: muted),
                    if (washerLate) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Perač kasni — možete otkazati bez penala.',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                children: [
                  Text(formatPrice(request.price.priceRsd), style: theme.textTheme.titleMedium),
                  const Spacer(),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
                    )
                  else if (cancel != null)
                    TextButton(onPressed: cancel, child: const Text('Otkaži'))
                  else
                    const SizedBox(height: 48),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Otkazivanje je nepovratno, pa prvo pita. Posle „Da“ ekran samo šalje događaj Bloc-u.
Future<void> confirmCancellation(BuildContext context, WashRequest request) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      title: const Text('Otkazati zahtev?'),
      content: Text('${formatDateAndTime(request.slot.start)}\n${request.address.text}\n\nOvo ne može da se poništi.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Odustani')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Otkaži zahtev')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  context.read<MyRequestsBloc>().add(RequestCancellationRequested(request.id, reason: 'Otkazao klijent.'));
}

/// Dugmad za demo stanja greške i praznog prikaza; postoje samo u debug izdanju i samo uz lažni repozitorijum.
class _DebugMenu extends StatelessWidget {
  const _DebugMenu();

  @override
  Widget build(BuildContext context) {
    final fake = context.read<AppDependencies>().fakeCarWash;
    if (!kDebugMode || fake == null) return const SizedBox.shrink();
    void reload() => context.read<MyRequestsBloc>().add(const MyRequestsRequested());
    return PopupMenuButton<void>(
      tooltip: 'Simulacija',
      itemBuilder: (context) => [
        PopupMenuItem(
          child: const Text('Simuliraj grešku'),
          onTap: () {
            fake.failingRequests = 1;
            reload();
          },
        ),
        PopupMenuItem(
          child: const Text('Simuliraj prazan odgovor'),
          onTap: () {
            fake.emptyResponses = 1;
            reload();
          },
        ),
      ],
    );
  }
}
