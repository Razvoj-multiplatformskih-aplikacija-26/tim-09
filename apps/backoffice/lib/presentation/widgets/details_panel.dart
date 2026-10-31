import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';

class DetailsPanel extends StatelessWidget {
  const DetailsPanel({super.key, required this.request});
  final WashRequest request;

  @override
  Widget build(BuildContext context) {
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
        Text('Status: ${request.status.runtimeType}'),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Dodeli (A)'),
              onPressed: () {
                // 1. Pošalji zahtev za prihvatanje
                context.read<DispatchBloc>().add(
                      AcceptRequested(request.id, const WasherId('washer-1')),
                    );
                // 2. Odmah zatraži osvežavanje liste da se status promeni u Accepted
                context.read<DispatchBloc>().add(const DispatchRequested());
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Zahtev ${request.id.value} dodeljen peraču!')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}