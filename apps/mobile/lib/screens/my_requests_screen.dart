import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ui/ui.dart';
import 'package:use_cases/use_cases.dart';

import '../dependencies.dart';

/// Glavni ekran: crta četiri stanja iz [MyRequestsBloc] i samo šalje događaje.
class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  void _showNotice(BuildContext context, MyRequestsNotice notice) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(cancellationMessage(notice))));
    context.read<MyRequestsBloc>().add(const MyRequestsNoticeAcknowledged());
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MyRequestsBloc>();
    final user = context.read<User>();
    final washer = user.role == Role.washer;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocConsumer<MyRequestsBloc, MyRequestsState>(
          listenWhen: (previous, current) => current.notice != null,
          listener: (context, state) => _showNotice(context, state.notice!),
          builder: (context, state) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: RefreshIndicator(
                onRefresh: () async => bloc.add(const MyRequestsRequested()),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(CarWashTheme.gutter, 8, CarWashTheme.gutter, 32),
                  children: [
                    const _Greeting(),
                    const SizedBox(height: 20),
                    if (mayCreateRequest(user)) const _OrderHero(),
                    ...switch (state) {
                      MyRequestsLoading() => const [SizedBox(height: 28), ListSkeleton(cards: 3)],
                      MyRequestsFailure(:final cause) => [
                        FailureView(
                          message: failureMessage(cause),
                          onRetry: () => bloc.add(const MyRequestsRequested()),
                        ),
                      ],
                      MyRequestsEmpty() => [
                        washer
                            ? const EmptyView(
                                title: 'Nemate dodeljenih aktivnih poslova.',
                                subtitle: 'Dispečer vam dodeljuje poslove; povucite nadole da osvežite.',
                              )
                            : const EmptyView(
                                title: 'Još nemate zahteva za pranje.',
                                subtitle: 'Naručite prvo pranje i perač dolazi do vašeg vozila.',
                              ),
                      ],
                      MyRequestsLoaded() => _requestList(context, state),
                    },
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _requestList(BuildContext context, MyRequestsLoaded state) {
    VoidCallback? cancelFor(WashRequest request) =>
        state.canCancel(request) && !state.isBusy ? () => confirmCancellation(context, request) : null;
    void open(WashRequest request) => context.push('/requests/${request.id.value}');
    return [
      if (state.active.isNotEmpty) ...[
        const SectionHeader('Aktivni'),
        for (final request in state.active)
          Padding(
            key: ValueKey(request.id),
            padding: const EdgeInsets.only(bottom: 12),
            child: _ActiveCard(
              request: request,
              washerLate: state.isWasherLate(request),
              busy: state.isCancelling(request),
              onOpen: () => open(request),
              onCancel: cancelFor(request),
            ),
          ),
      ],
      if (state.past.isNotEmpty) ...[
        const SectionHeader('Prethodni'),
        Card(
          child: Column(
            children: [
              for (final (index, request) in state.past.indexed) ...[
                if (index > 0) const Divider(indent: 76),
                _PastRow(
                  key: ValueKey(request.id),
                  request: request,
                  busy: state.isCancelling(request),
                  onOpen: () => open(request),
                  onCancel: cancelFor(request),
                ),
              ],
            ],
          ),
        ),
      ],
      PageBar(
        first: state.page.firstNumber,
        last: state.page.lastNumber,
        total: state.page.total,
        onPrevious: state.page.hasPrevious && !state.isBusy
            ? () => context.read<MyRequestsBloc>().add(MyRequestsPageRequested(state.page.previousOffset))
            : null,
        onNext: state.page.hasNext && !state.isBusy
            ? () => context.read<MyRequestsBloc>().add(MyRequestsPageRequested(state.page.nextOffset))
            : null,
      ),
    ];
  }
}

String cancellationMessage(MyRequestsNotice notice) => switch (notice) {
  RequestCancelled() => 'Zahtev je otkazan.',
  CancellationRejected(:final error) => error.message,
  CancellationFailed(cause: NetworkException(outcomeUnknown: true) && final cause) => failureMessage(cause),
  CancellationFailed() => 'Otkazivanje nije uspelo. Pokušajte ponovo.',
};

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.read<User>();
    final name = capitalize(user.username);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Zdravo, $name · ${user.role.label}',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Semantics(
                header: true,
                child: Text(
                  user.role == Role.washer ? 'Vaši poslovi' : 'Vaša pranja',
                  style: theme.textTheme.headlineMedium,
                ),
              ),
            ],
          ),
        ),
        const _DebugMenu(),
        PopupMenuButton<void>(
          tooltip: 'Nalog',
          itemBuilder: (context) => [
            PopupMenuItem(
              onTap: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
              child: const ListTile(leading: Icon(Icons.logout), title: Text('Odjavi se')),
            ),
          ],
          child: CircleAvatar(
            radius: 22,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            child: Text(
              name.isEmpty ? '?' : name[0],
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderHero extends StatelessWidget {
  const _OrderHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: CarWashTheme.heroGradient,
        borderRadius: BorderRadius.circular(CarWashTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: CarWashTheme.brandColor.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -20,
            child: Icon(Icons.local_car_wash, size: 150, color: Colors.white.withValues(alpha: 0.12)),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pranje na vašoj adresi', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  'Perač dolazi do vozila — vi ne morate nigde.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => context.push('/new'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: CarWashTheme.brandColor,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Novi zahtev'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({
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
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    return Card(
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconBubble(request.vehicle.type.icon),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(formatTime(request.slot.start), style: theme.textTheme.headlineSmall),
                              Text(formatDate(request.slot.start), style: muted),
                            ],
                          ),
                        ),
                        WashStatusBadge(status: request.status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    WashProgress(status: request.status),
                    const SizedBox(height: 16),
                    _IconLine(
                      Icons.directions_car_outlined,
                      '${request.vehicle.type.label} · ${request.vehicle.plate.value} · ${request.tier.label}',
                    ),
                    const SizedBox(height: 6),
                    _IconLine(Icons.place_outlined, request.address.text),
                    if (washerLate) ...[const SizedBox(height: 12), const _LateBanner()],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Divider(),
              Row(
                children: [
                  Expanded(child: Text(formatPrice(request.price.priceRsd), style: theme.textTheme.titleMedium)),
                  const SizedBox(width: 8),
                  _CancelAction(busy: busy, onCancel: onCancel),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PastRow extends StatelessWidget {
  const _PastRow({super.key, required this.request, required this.onOpen, this.onCancel, this.busy = false});

  final WashRequest request;
  final VoidCallback onOpen;
  final VoidCallback? onCancel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final accent = request.status.colors(theme.brightness).accent;
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            IconBubble(request.vehicle.type.icon, color: accent),
            const SizedBox(width: 16),
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${request.vehicle.type.label} · ${request.tier.label}', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(formatDateAndTime(request.slot.start), style: muted),
                    const SizedBox(height: 8),
                    WashStatusBadge(status: request.status),
                  ],
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatPrice(request.price.priceRsd), style: theme.textTheme.titleSmall),
                if (onCancel != null || busy) _CancelAction(busy: busy, onCancel: onCancel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: color)),
        ),
      ],
    );
  }
}

class _LateBanner extends StatelessWidget {
  const _LateBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(CarWashTheme.radiusSm),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Perač kasni — možete otkazati bez penala.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelAction extends StatelessWidget {
  const _CancelAction({required this.busy, required this.onCancel});

  final bool busy;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final cancel = onCancel;
    if (busy) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }
    if (cancel == null) return const SizedBox(height: 48);
    return TextButton(
      onPressed: cancel,
      style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
      child: const Text('Otkaži'),
    );
  }
}

/// Otkazivanje je nepovratno, pa prvo pita. Posle „Da“ ekran samo šalje događaj Bloc-u.
Future<void> confirmCancellation(BuildContext context, WashRequest request) async {
  if (await askCancellation(context, request) && context.mounted) {
    context.read<MyRequestsBloc>().add(RequestCancellationRequested(request.id, reason: 'Otkazao klijent.'));
  }
}

Future<bool> askCancellation(BuildContext context, WashRequest request) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      title: const Text('Otkazati zahtev?'),
      content: Text('${formatDateAndTime(request.slot.start)}\n${request.address.text}\n\nOvo ne može da se poništi.'),
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
  return confirmed == true;
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
