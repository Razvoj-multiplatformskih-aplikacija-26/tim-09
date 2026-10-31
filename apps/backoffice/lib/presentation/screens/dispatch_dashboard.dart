import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';

import '../../data/fake_dispatch_repository.dart';
import '../widgets/details_panel.dart';

class DispatchDashboard extends StatefulWidget {
  const DispatchDashboard({super.key, required this.repository});
  final FakeDispatchRepository repository;

  @override
  State<DispatchDashboard> createState() => _DispatchDashboardState();
}

class _DispatchDashboardState extends State<DispatchDashboard> {
  int selectedIndex = 0;
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispečerska tabla (Backoffice - Tim 09)'),
        actions: [
          Row(
            children: [
              const Text('Simuliraj grešku:'),
              Switch(
                value: widget.repository.simulateError,
                onChanged: (val) {
                  setState(() {
                    widget.repository.simulateError = val;
                  });
                  context.read<DispatchBloc>().add(const DispatchRequested());
                },
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Osveži (Ctrl + R)',
            onPressed: () {
              context.read<DispatchBloc>().add(const DispatchRequested());
            },
          ),
        ],
      ),
      body: BlocBuilder<DispatchBloc, DispatchState>(
        builder: (context, state) {
          return switch (state) {
            DispatchLoading() =>
              const Center(child: CircularProgressIndicator()),
            DispatchEmpty() =>
              const Center(child: Text('Nema zahteva u sistemu.')),
            DispatchLoaded(:final requests) => _buildContent(context, requests),
            _ => Center(child: Text('Stanje: ${state.runtimeType}')),
          };
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<WashRequest> requests) {
    if (requests.isEmpty) {
      return const Center(child: Text('Nema zahteva u sistemu.'));
    }
    if (selectedIndex >= requests.length) {
      selectedIndex = requests.length - 1;
    }
    final selectedRequest = requests[selectedIndex];

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowDown): () {
          setState(() {
            if (selectedIndex < requests.length - 1) selectedIndex++;
          });
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp): () {
          setState(() {
            if (selectedIndex > 0) selectedIndex--;
          });
        },
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
          context.read<DispatchBloc>().add(const DispatchRequested());
        },
        const SingleActivator(LogicalKeyboardKey.keyA): () {
          _acceptRequest(context, selectedRequest.id);
        },
      },
      child: Focus(
        focusNode: _keyboardFocusNode,
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
                          final bool isSelected = index == selectedIndex;
                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: Colors.blue.withValues(alpha: 0.1),
                            title: Text('Zahtev: ${req.id.value} — ${req.vehicle.plate}'),
                            subtitle: Text('Adresa: ${req.address} | Status: ${req.status.runtimeType}'),
                            trailing: Text(req.tier.name.toUpperCase()),
                            onTap: () {
                              setState(() {
                                selectedIndex = index;
                              });
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
                        child: DetailsPanel(request: selectedRequest),
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
                    trailing: ElevatedButton(
                      onPressed: () => _acceptRequest(context, req.id),
                      child: const Text('Dodeli'),
                    ),
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: Text('Detalji ${req.id.value}')),
                            body: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: DetailsPanel(request: req),
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

  void _acceptRequest(BuildContext context, WashRequestId id) {
    context.read<DispatchBloc>().add(AcceptRequested(id, const WasherId('washer-1')));
    context.read<DispatchBloc>().add(const DispatchRequested());
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Zahtev ${id.value} dodeljen peraču!')),
    );
  }
}