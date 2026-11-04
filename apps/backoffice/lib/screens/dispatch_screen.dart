import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ui/ui.dart';

import '../dependencies.dart';
import '../widgets/request_details.dart';
import 'request_detail_screen.dart';

/// Dispečerska tabla: crta stanja iz [DispatchBloc] i samo šalje događaje.
/// Na širokom ekranu lista i detalji stoje jedno pored drugog, na uskom se detalji otvaraju posebno.
class DispatchScreen extends StatelessWidget {
  const DispatchScreen({super.key});

  static const wideBreakpoint = 900.0;

  void _showNotice(BuildContext context, DispatchNotice notice) {
    final message = switch (notice) {
      RequestAssigned() => 'Zahtev je dodeljen peraču.',
      RequestReleased() => 'Zahtev je vraćen u red.',
      RequestCancelledByStaff() => 'Zahtev je otkazan.',
      DispatchActionRejected(:final error) => error.message,
      DispatchActionFailed() => 'Radnja nije uspela. Pokušajte ponovo.',
    };
    // Uska traka na sredini, da ne prekrije dugmad u panelu sa detaljima.
    final width = MediaQuery.sizeOf(context).width - 2 * CarWashTheme.gutter;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), width: width.clamp(0, 440)));
    context.read<DispatchBloc>().add(const DispatchNoticeAcknowledged());
  }

  /// Strelice idu kroz zahteve redom kojim su prikazani; bez izbora počinju od prvog, odnosno poslednjeg.
  void _moveSelection(DispatchBloc bloc, int step) {
    final state = bloc.state;
    if (state is! DispatchLoaded) return;
    final ordered = _Sections.of(state.requests).ordered;
    final index = ordered.indexWhere((r) => r.id == state.selectedId);
    final next = index == -1 ? (step > 0 ? 0 : ordered.length - 1) : (index + step).clamp(0, ordered.length - 1);
    bloc.add(DispatchRequestSelected(ordered[next].id));
  }

  void _assignSelected(BuildContext context) {
    final state = context.read<DispatchBloc>().state;
    if (state is! DispatchLoaded || state.busyId != null) return;
    final selected = state.selected;
    if (selected != null && selected.status is Submitted) assignWasher(context, selected);
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<DispatchBloc>();
    void refresh() => bloc.add(const DispatchRequested());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispečerska tabla'),
        actions: [
          const _DebugMenu(),
          IconButton(onPressed: refresh, tooltip: 'Osveži (F5)', icon: const Icon(Icons.refresh)),
          const SizedBox(width: 8),
        ],
      ),
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => _moveSelection(bloc, 1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => _moveSelection(bloc, -1),
          const SingleActivator(LogicalKeyboardKey.escape): () => bloc.add(const DispatchRequestSelected(null)),
          const SingleActivator(LogicalKeyboardKey.keyA): () => _assignSelected(context),
          const SingleActivator(LogicalKeyboardKey.f5): refresh,
        },
        child: Focus(
          autofocus: true,
          child: BlocConsumer<DispatchBloc, DispatchState>(
            listenWhen: (previous, current) => current is DispatchLoaded && current.notice != null,
            listener: (context, state) => _showNotice(context, (state as DispatchLoaded).notice!),
            builder: (context, state) => switch (state) {
              DispatchLoading() => const SingleChildScrollView(
                padding: EdgeInsets.all(CarWashTheme.gutter),
                child: ListSkeleton(cards: 5),
              ),
              DispatchFailure() => Center(
                child: SingleChildScrollView(child: FailureView(onRetry: refresh)),
              ),
              DispatchEmpty() => const Center(
                child: EmptyView(
                  title: 'Nema zahteva u sistemu.',
                  subtitle: 'Novi zahtevi klijenata pojaviće se ovde.',
                ),
              ),
              DispatchLoaded() => LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth >= wideBreakpoint
                    ? _WideLayout(state: state)
                    : _RequestList(
                        state: state,
                        onOpen: (request) {
                          bloc.add(DispatchRequestSelected(request.id));
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute(builder: (_) => RequestDetailScreen(id: request.id)),
                          );
                        },
                      ),
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.state});

  final DispatchLoaded state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<DispatchBloc>();
    final selected = state.selected;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: _RequestList(state: state, onOpen: (request) => bloc.add(DispatchRequestSelected(request.id))),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: selected == null
              ? const Center(
                  child: SingleChildScrollView(
                    child: EmptyView(
                      title: 'Izaberite zahtev iz liste.',
                      subtitle: '↑ / ↓ bira zahtev · A dodeljuje perača · F5 osvežava',
                    ),
                  ),
                )
              : Column(
                  key: ValueKey(selected.id),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: RequestDetails(request: selected)),
                    RequestActions(request: selected, busy: state.isBusy(selected)),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Zahtevi podeljeni kao što ih dispečer gleda: prvo red čekanja, pa aktivni, pa prethodni.
final class _Sections {
  _Sections.of(List<WashRequest> requests)
    : waiting = requests.where((r) => r.status is Submitted).toList(),
      active = requests.where((r) => r.status is Accepted || r.status is InProgress).toList(),
      past = requests.where((r) => !r.isActive).toList();

  final List<WashRequest> waiting;
  final List<WashRequest> active;
  final List<WashRequest> past;

  List<WashRequest> get ordered => [...waiting, ...active, ...past];
}

class _RequestList extends StatelessWidget {
  const _RequestList({required this.state, required this.onOpen});

  final DispatchLoaded state;
  final ValueChanged<WashRequest> onOpen;

  @override
  Widget build(BuildContext context) {
    final sections = _Sections.of(state.requests);
    List<Widget> section(String title, List<WashRequest> requests) => [
      if (requests.isNotEmpty) ...[
        SectionHeader(title, trailing: '${requests.length}'),
        Card(
          child: Column(
            children: [
              for (final (index, request) in requests.indexed) ...[
                if (index > 0) const Divider(indent: 76),
                _RequestTile(
                  key: ValueKey(request.id),
                  request: request,
                  selected: request.id == state.selectedId,
                  busy: state.isBusy(request),
                  onTap: () => onOpen(request),
                ),
              ],
            ],
          ),
        ),
      ],
    ];
    return RefreshIndicator(
      onRefresh: () async => context.read<DispatchBloc>().add(const DispatchRequested()),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(CarWashTheme.gutter, 0, CarWashTheme.gutter, 32),
        children: [
          ...section('Čekaju perača', sections.waiting),
          ...section('Aktivni', sections.active),
          ...section('Prethodni', sections.past),
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    super.key,
    required this.request,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final WashRequest request;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final washer = switch (request.status) {
      Accepted(:final washerId) || InProgress(:final washerId) => BackofficeDependencies.washerName(washerId),
      _ => null,
    };
    return ListTile(
      selected: selected,
      selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: IconBubble(request.vehicle.type.icon, color: request.status.colors(theme.brightness).accent),
      title: Text(
        '${request.vehicle.plate.value} · ${request.vehicle.type.label} · ${request.tier.label}',
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        [formatDateAndTime(request.slot.start), request.address.text, if (washer != null) 'Perač: $washer'].join('\n'),
        style: muted,
      ),
      isThreeLine: true,
      trailing: busy
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
          : WashStatusBadge(status: request.status),
      onTap: onTap,
    );
  }
}

/// Dugmad za demo stanja greške i praznog prikaza; postoje samo u debug izdanju i samo uz lažni repozitorijum.
class _DebugMenu extends StatelessWidget {
  const _DebugMenu();

  @override
  Widget build(BuildContext context) {
    final fake = context.read<BackofficeDependencies>().fakeRepository;
    if (!kDebugMode || fake == null) return const SizedBox.shrink();
    void reload() => context.read<DispatchBloc>().add(const DispatchRequested());
    return PopupMenuButton<void>(
      tooltip: 'Simulacija',
      icon: const Icon(Icons.science_outlined),
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
