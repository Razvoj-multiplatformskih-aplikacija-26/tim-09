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
    return Scaffold(
      appBar: AppBar(title: const Text('Novi zahtev')),
      body: BlocConsumer<WashRequestFormBloc, WashRequestFormState>(
        listener: _onFormState,
        builder: (context, state) {
          final submitting = state is WashRequestFormSubmitting;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    DropdownButtonFormField<VehicleType>(
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: 'Tip vozila'),
                      items: [
                        for (final type in VehicleType.values) DropdownMenuItem(value: type, child: Text(type.label)),
                      ],
                      onChanged: (type) => setState(() => _type = type ?? _type),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _plate,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Registarska oznaka',
                        hintText: LicensePlate.example,
                      ),
                      validator: (value) => LicensePlate.parse(value ?? '').errorOrNull?.message,
                    ),
                    const SizedBox(height: 16),
                    Text('Usluga', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SegmentedButton<ServiceTier>(
                      segments: [
                        for (final tier in ServiceTier.values) ButtonSegment(value: tier, label: Text(tier.label)),
                      ],
                      selected: {_tier},
                      onSelectionChanged: (selection) => setState(() => _tier = selection.first),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _address,
                      decoration: const InputDecoration(labelText: 'Adresa vozila', hintText: 'Ulica i broj, grad'),
                      validator: (value) => Address.parse(value ?? '').errorOrNull?.message,
                    ),
                    const SizedBox(height: 16),
                    FormField<DateTime>(
                      validator: _validateSlot,
                      builder: (field) => InkWell(
                        onTap: () => _pickStart(field),
                        borderRadius: BorderRadius.circular(14),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Termin',
                            errorText: field.errorText,
                            suffixIcon: const Icon(Icons.event_outlined),
                          ),
                          child: Text(start == null ? 'Izaberite datum i vreme' : formatDateAndTime(start)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _note,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Napomena za perača (nije obavezna)',
                        helperText: 'Najviše ${WashNote.maxLength} znakova',
                      ),
                      validator: (value) => WashNote.parse(value ?? '').errorOrNull?.message,
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.payments_outlined, color: theme.colorScheme.primary),
                        title: const Text('Procena'),
                        subtitle: Text(
                          '${formatPrice(_estimate.priceRsd)} · ${formatDuration(_estimate.duration)}',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: submitting ? null : _submit,
                      child: Text(submitting ? 'Slanje…' : 'Pošalji zahtev'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
