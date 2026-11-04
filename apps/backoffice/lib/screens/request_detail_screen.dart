import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ui/ui.dart';

import '../widgets/request_details.dart';

/// Detalji na uskom ekranu. Zahtev čita iz Bloc-a po id-u, pa posle svake radnje prikazuje novo stanje.
class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key, required this.id});

  final WashRequestId id;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DispatchBloc, DispatchState>(
      builder: (context, state) {
        final request = state is DispatchLoaded ? state.find(id) : null;
        return Scaffold(
          appBar: AppBar(title: Text('Zahtev ${id.value}')),
          body: switch ((state, request)) {
            (DispatchLoaded(), final request?) => RequestDetails(request: request),
            (DispatchLoading(), _) => const Center(child: CircularProgressIndicator()),
            _ => const Center(child: EmptyView(title: 'Zahtev nije pronađen.')),
          },
          // Dugmad su u donjoj traci, pa obaveštenje iskače iznad njih umesto da ih prekrije.
          bottomNavigationBar: switch ((state, request)) {
            (final DispatchLoaded loaded, final request?) => RequestActions(
              request: request,
              busy: loaded.isBusy(request),
            ),
            _ => null,
          },
        );
      },
    );
  }
}
