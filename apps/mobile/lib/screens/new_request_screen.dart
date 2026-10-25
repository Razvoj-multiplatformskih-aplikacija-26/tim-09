import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ui/ui.dart';
import 'package:use_cases/use_cases.dart';

import '../dependencies.dart';

/// Forma „Novi zahtev“. Svako polje proverava pravilo iz domena (`parse`) pri unosu;
/// ekran samo bira tekst poruke (`error.message` iz paketa ui).
class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plate = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();
  VehicleType _type = VehicleType.sedan;
  ServiceTier _tier = ServiceTier.economy;
  DateTime? _start;

  @override
  void dispose() {
    _plate.dispose();
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Cena i trajanje se računaju u domenu dok korisnik bira vozilo i uslugu.
  PriceEstimate get _estimate => estimate(_type, _tier);

  String? _validateSlot(DateTime? start) {
    if (start == null) return 'Izaberite datum i vreme.';
    final now = context.read<AppDependencies>().clock.now();
    return WashSlot.parse(start, duration: _estimate.duration, now: now).errorOrNull?.message;
  }

  Future<void> _pickStart(FormFieldState<DateTime> field) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 30)),
      initialDate: _start ?? now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (time == null || !mounted) return;
    final start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => _start = start);
    field.didChange(start);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final now = context.read<AppDependencies>().clock.now();
    // Polja su već prošla proveru, pa parse ovde sigurno uspeva.
    final draft = WashRequestDraft(
      clientId: context.read<AppDependencies>().user.id,
      vehicle: Vehicle(type: _type, plate: LicensePlate.parse(_plate.text).valueOrNull!),
      tier: _tier,
      address: Address.parse(_address.text).valueOrNull!,
      slot: WashSlot.parse(_start!, duration: _estimate.duration, now: now).valueOrNull!,
      note: _note.text.trim().isEmpty ? null : WashNote.parse(_note.text).valueOrNull,
    );
    context.read<WashRequestFormBloc>().add(WashRequestFormSubmitted(draft));
  }

  void _onFormState(BuildContext context, WashRequestFormState state) {
    final messenger = ScaffoldMessenger.of(context);
    switch (state) {
      case WashRequestFormDone():
        context.read<MyRequestsBloc>().add(const MyRequestsRequested());
        messenger.showSnackBar(const SnackBar(content: Text('Zahtev je poslat.')));
        context.pop();
      case WashRequestFormRejected(:final error):
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      case WashRequestFormFailed():
        messenger.showSnackBar(const SnackBar(content: Text('Slanje nije uspelo. Pokušajte ponovo.')));
      case WashRequestFormEditing() || WashRequestFormSubmitting():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = _start;
    return BlocConsumer<WashRequestFormBloc, WashRequestFormState>(
      listener: _onFormState,
      builder: (context, state) {
        final submitting = state is WashRequestFormSubmitting;
        return Scaffold(
          appBar: AppBar(title: const Text('Novi zahtev')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(CarWashTheme.gutter, 0, CarWashTheme.gutter, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader('Vozilo'),
                      Row(
                        children: [
                          for (final (index, type) in VehicleType.values.indexed) ...[
                            if (index > 0) const SizedBox(width: 8),
                            Expanded(
                              child: SelectableTile(
                                selected: type == _type,
                                onTap: () => setState(() => _type = type),
                                child: Column(
                                  children: [
                                    Icon(type.icon, size: 28, color: type == _type ? theme.colorScheme.primary : null),
                                    const SizedBox(height: 6),
                                    Text(
                                      type.label,
                                      style: theme.textTheme.labelMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _plate,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Registarska oznaka',
                          hintText: LicensePlate.example,
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                        validator: (value) => LicensePlate.parse(value ?? '').errorOrNull?.message,
                      ),
                      const SectionHeader('Usluga'),
                      Row(
                        children: [
                          for (final (index, tier) in ServiceTier.values.indexed) ...[
                            if (index > 0) const SizedBox(width: 12),
                            Expanded(
                              child: _TierTile(
                                tier: tier,
                                type: _type,
                                selected: tier == _tier,
                                onTap: () => setState(() => _tier = tier),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SectionHeader('Gde i kada'),
                      TextFormField(
                        controller: _address,
                        decoration: const InputDecoration(
                          labelText: 'Adresa vozila',
                          hintText: 'Ulica i broj, grad',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                        validator: (value) => Address.parse(value ?? '').errorOrNull?.message,
                      ),
                      const SizedBox(height: 12),
                      FormField<DateTime>(
                        validator: _validateSlot,
                        builder: (field) => InkWell(
                          onTap: () => _pickStart(field),
                          borderRadius: BorderRadius.circular(CarWashTheme.radiusMd),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Termin',
                              errorText: field.errorText,
                              prefixIcon: const Icon(Icons.event_outlined),
                              suffixIcon: const Icon(Icons.chevron_right),
                            ),
                            child: Text(start == null ? 'Izaberite datum i vreme' : formatDateAndTime(start)),
                          ),
                        ),
                      ),
                      const SectionHeader('Napomena'),
                      TextFormField(
                        controller: _note,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Napomena za perača (nije obavezna)',
                          helperText: 'Najviše ${WashNote.maxLength} znakova',
                          alignLabelWithHint: true,
                        ),
                        validator: (value) => WashNote.parse(value ?? '').errorOrNull?.message,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: _SummaryBar(estimate: _estimate, submitting: submitting, onSubmit: _submit),
        );
      },
    );
  }
}

/// Pločica usluge sa cenom i trajanjem za trenutno izabrano vozilo.
class _TierTile extends StatelessWidget {
  const _TierTile({required this.tier, required this.type, required this.selected, required this.onTap});

  final ServiceTier tier;
  final VehicleType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = estimate(type, tier);
    return SelectableTile(
      selected: selected,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(tier.icon, size: 36),
              const Spacer(),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(tier.label, style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(formatPrice(price.priceRsd), style: theme.textTheme.bodyMedium),
          Text(
            formatDuration(price.duration),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Traka na dnu: ukupna procena uvek na vidiku i dugme za slanje, kao korpa u aplikacijama za dostavu.
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.estimate, required this.submitting, required this.onSubmit});

  final PriceEstimate estimate;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(CarWashTheme.gutter, 12, CarWashTheme.gutter, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Procena', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  Text(
                    '${formatPrice(estimate.priceRsd)} · ${formatDuration(estimate.duration)}',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: submitting ? null : onSubmit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24)),
              child: Text(submitting ? 'Slanje…' : 'Pošalji zahtev'),
            ),
          ],
        ),
      ),
    );
  }
}
