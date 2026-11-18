import 'package:flutter/material.dart';

import '../theme.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
    required this.title,
    required this.subtitle,
    required this.submitting,
    required this.onSubmit,
    this.error,
    this.footer,
  });

  final String title;
  final String subtitle;
  final bool submitting;
  final String? error;
  final Widget? footer;
  final void Function(String username, String password) onSubmit;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _hidden = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.submitting || !_formKey.currentState!.validate()) return;
    widget.onSubmit(_username.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final error = widget.error;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CarWashTheme.gutter),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.local_car_wash, size: 56, color: scheme.primary),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text(widget.title, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  if (error != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(CarWashTheme.radiusMd),
                        ),
                        child: Text(error, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _username,
                    enabled: !widget.submitting,
                    autofillHints: const [AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Korisničko ime',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty ? 'Unesite korisničko ime.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    enabled: !widget.submitting,
                    obscureText: _hidden,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Lozinka',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _hidden ? 'Prikaži lozinku' : 'Sakrij lozinku',
                        icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _hidden = !_hidden),
                      ),
                    ),
                    validator: (value) => (value ?? '').isEmpty ? 'Unesite lozinku.' : null,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: widget.submitting ? null : _submit,
                    child: widget.submitting
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Text('Prijavi se'),
                  ),
                  if (widget.footer case final footer?) ...[const SizedBox(height: 12), footer],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CheckingView extends StatelessWidget {
  const CheckingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(label: 'Provera prijave', child: const CircularProgressIndicator()),
      ),
    );
  }
}

class PageBar extends StatelessWidget {
  const PageBar({
    super.key,
    required this.first,
    required this.last,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final int first;
  final int last;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconButton(onPressed: onPrevious, tooltip: 'Prethodna strana', icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Text(
              '$first–$last od $total',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          IconButton(onPressed: onNext, tooltip: 'Sledeća strana', icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}
