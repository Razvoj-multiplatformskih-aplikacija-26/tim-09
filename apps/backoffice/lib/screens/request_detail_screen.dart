import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ui/ui.dart';

import '../widgets/request_details.dart';

/// Detalji na uskom ekranu. Zahtev čita sa servera po id-u, pa posle svake radnje prikazuje novo stanje.
class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key, required this.id});

  final WashRequestId id;

  @override
  Widget build(BuildContext context) {
    final detail = context.read<RequestDetailBloc>();
    return BlocListener<DispatchBloc, DispatchState>(
      listenWhen: (previous, current) => current.notice != null,
      listener: (context, state) => detail.add(const RequestDetailRequested(quiet: true)),
      child: BlocBuilder<RequestDetailBloc, RequestDetailState>(
        builder: (context, state) {
          final dispatch = context.watch<DispatchBloc>().state;
          final board = dispatch is DispatchReady ? dispatch : null;
          String washerName(WasherId washer) => board?.washerName(washer) ?? washer.value;
          return Scaffold(
            appBar: AppBar(title: Text('Zahtev ${id.value}')),
            body: switch (state) {
              RequestDetailLoaded(:final request) => RequestDetails(request: request, washerName: washerName),
              RequestDetailLoading() => const Center(child: CircularProgressIndicator()),
              RequestDetailUnavailable() => const Center(child: EmptyView(title: 'Zahtev nije pronađen.')),
              RequestDetailFailure(:final cause) => Center(
                child: SingleChildScrollView(
                  child: FailureView(
                    message: failureMessage(cause),
                    onRetry: () => detail.add(const RequestDetailRequested()),
                  ),
                ),
              ),
            },
            // Dugmad su u donjoj traci, pa obaveštenje iskače iznad njih umesto da ih prekrije.
            bottomNavigationBar: switch ((state, board)) {
              (RequestDetailLoaded(:final request), final DispatchReady board) => RequestActions(
                request: request,
                busy: board.busyId == request.id,
              ),
              _ => null,
            },
          );
        },
      ),
    );
  }
}
