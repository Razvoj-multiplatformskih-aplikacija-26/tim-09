import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:ui/ui.dart';
import 'package:backoffice/dependencies.dart';

import '../widgets/details_panel.dart';

class DispatchDashboard extends StatelessWidget {
  const DispatchDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<DispatchBloc>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispečerska tabla (Backoffice - Tim 09)'),
        actions: [
          const _DebugMenu(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Osveži (Ctrl + R)',
            onPressed: () {
              bloc.add(const DispatchRequested());
            },
          ),
        ],
      ),
      body: BlocConsumer<DispatchBloc, DispatchState>(
        listenWhen: (previous, current) => current is DispatchLoaded && current.notice != null,
        listener: (context, state) => _showNotice(context, (state as DispatchLoaded).notice!),
        builder: (context, state) {
          return switch (state) {
            DispatchLoading() => const Padding(padding: EdgeInsets.all(16), child: ListSkeleton()),
            DispatchFailure() => Center(child: FailureView(onRetry: () => bloc.add(const DispatchRequested()))),
            DispatchEmpty() => const Center(child: EmptyView(title: 'Nema zahteva u sistemu.')),
            DispatchLoaded() => _buildContent(context, state),
          };
        },
      ),
    );
  }

  void _showNotice(BuildContext context, DispatchNotice notice) {
    final message = switch (notice) {
      RequestAssigned() => 'Zahtev je uspešno dodeljen peraču.',
      RequestReleased() => 'Zahtev je vraćen u red.',
      RequestCancelledByStaff() => 'Zahtev je otkazan.',
      DispatchActionRejected(:final error) => error.message,
      DispatchActionFailed() => 'Radnja nije uspela. Pokušajte ponovo.',
      _ => 'Akcija završena.',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    context.read<DispatchBloc>().add(const DispatchNoticeAcknowledged());
  }

  Future<void> _pickWasherAndAssign(BuildContext context, WashRequest request) async {
    final washer = await showDialog<WasherId>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Dodeli perača'),
        children: [
          for (final w in BackofficeDependencies.washers)
            SimpleDialogOption(onPressed: () => Navigator.pop(context, w.id), child: Text(w.name)),
        ],
      ),
    );
    if (washer == null || !context.mounted) return;
    context.read<DispatchBloc>().add(AcceptRequested(request.id, washer));
  }

  Widget _buildContent(BuildContext context, DispatchLoaded state) {
    final bloc = context.read<DispatchBloc>();
    final requests = state.requests;
    final selectedRequest = state.selected;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowDown): () {
          if (requests.isEmpty) return;
          final currentIndex = requests.indexWhere((r) => r.id == state.selectedId);
          final nextIndex = currentIndex < requests.length - 1 ? currentIndex + 1 : 0;
          bloc.add(DispatchRequestSelected(requests[nextIndex].id));
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp): () {
          if (requests.isEmpty) return;
          final currentIndex = requests.indexWhere((r) => r.id == state.selectedId);
          final prevIndex = currentIndex > 0 ? currentIndex - 1 : requests.length - 1;
          bloc.add(DispatchRequestSelected(requests[prevIndex].id));
        },
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
          bloc.add(const DispatchRequested());
        },
        const SingleActivator(LogicalKeyboardKey.keyA): () {
          if (selectedRequest != null && selectedRequest.status is Submitted) {
            _pickWasherAndAssign(context, selectedRequest);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide = constraints.maxWidth >= 900;

            if (isWide) {
              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Card(
                      margin: const EdgeInsets.all(8),
                      child: ListView.builder(
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          final req = requests[index];
                          final bool isSelected = req.id == state.selectedId;
                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: Colors.blue.withValues(alpha: 0.1),
                            title: Text('Zahtev: ${req.id.value} — ${req.vehicle.plate}'),
                            subtitle: Text('Adresa: ${req.address} | Status: ${req.status.runtimeType}'),
                            trailing: Text(req.tier.name.toUpperCase()),
                            onTap: () {
                              bloc.add(DispatchRequestSelected(req.id));
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Card(
                      margin: const EdgeInsets.all(8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: selectedRequest == null
                            ? const Center(child: Text('Izaberite zahtev iz liste.'))
                            : DetailsPanel(request: selectedRequest, isBusy: state.busyId == selectedRequest.id),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final req = requests[index];
                  return ListTile(
                    title: Text('Zahtev: ${req.id.value}'),
                    subtitle: Text('Status: ${req.status.runtimeType}'),
                    trailing: req.status is Submitted
                        ? ElevatedButton(
                            onPressed: () => _pickWasherAndAssign(context, req),
                            child: const Text('Dodeli'),
                          )
                        : null,
                    onTap: () {
                      bloc.add(DispatchRequestSelected(req.id));
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: Text('Detalji ${req.id.value}')),
                            body: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: DetailsPanel(request: req, isBusy: state.busyId == req.id),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}

class _DebugMenu extends StatelessWidget {
  const _DebugMenu();

  @override
  Widget build(BuildContext context) {
    final fake = context.read<BackofficeDependencies>().fakeRepository;
    if (!kDebugMode || fake == null) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.science),
      tooltip: 'Debug meni',
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'error', child: Text('Simuliraj grešku')),
        const PopupMenuItem(value: 'empty', child: Text('Simuliraj prazan odgovor')),
      ],
      onSelected: (value) {
        if (value == 'error') {
          fake.failingRequests = 1;
        } else if (value == 'empty') {
          fake.emptyResponses = 1;
        }
        context.read<DispatchBloc>().add(const DispatchRequested());
      },
    );
  }
}
