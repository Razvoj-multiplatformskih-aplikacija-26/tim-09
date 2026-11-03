import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:backoffice/dependencies.dart';

class DetailsPanel extends StatelessWidget {
  const DetailsPanel({super.key, required this.request, required this.isBusy});
  final WashRequest request;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final status = request.status;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Detalji zahteva', style: Theme.of(context).textTheme.headlineSmall),
        const Divider(),
        Text('ID: ${request.id.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Klijent: ${request.clientId.value}'),
        const SizedBox(height: 8),
        Text('Vozilo: ${request.vehicle.type.name} (${request.vehicle.plate})'),
        const SizedBox(height: 8),
        Text('Paket: ${request.tier.name}'),
        const SizedBox(height: 8),
        Text('Adresa: ${request.address}'),
        const SizedBox(height: 8),
        Text('Status: ${status.runtimeType}'),
        const Spacer(),
        if (isBusy)
          const Center(child: CircularProgressIndicator())
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (status is Submitted) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Dodeli'),
                  onPressed: () => _pickWasherAndAssign(context, request),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cancel),
                  label: const Text('Otkaži'),
                  onPressed: () => _confirmAndCancel(context, request.id),
                ),
              ] else if (status is Accepted) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.undo),
                  label: const Text('Vrati u red'),
                  onPressed: () => context.read<DispatchBloc>().add(ReleaseRequested(request.id)),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cancel),
                  label: const Text('Otkaži'),
                  onPressed: () => _confirmAndCancel(context, request.id),
                ),
              ] else if (status is InProgress) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.cancel),
                  label: const Text('Otkaži'),
                  onPressed: () => _confirmAndCancel(context, request.id),
                ),
              ],
            ],
          ),
      ],
    );
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

  Future<void> _confirmAndCancel(BuildContext context, WashRequestId id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Otkaži zahtev'),
        content: const Text('Da li ste sigurni da želite da otkažete ovaj zahtev?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Odustani')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Otkaži')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<DispatchBloc>().add(DispatchCancelRequested(id));
    }
  }
}
