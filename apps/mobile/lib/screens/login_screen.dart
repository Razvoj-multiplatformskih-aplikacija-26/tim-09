import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ui/ui.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final signedOut = state is AuthSignedOut ? state : const AuthSignedOut();
            return LoginForm(
              title: 'CarWash & Go',
              subtitle: 'Prijavite se kao klijent ili perač.',
              submitting: signedOut.submitting,
              error: signedOut.notice?.messageFor(ClientApplication.mobile),
              onSubmit: (username, password) =>
                  context.read<AuthBloc>().add(AuthLoginSubmitted(username: username, password: password)),
              footer: TextButton.icon(
                onPressed: () => context.push('/prices'),
                icon: const Icon(Icons.sell_outlined),
                label: const Text('Cenovnik'),
              ),
            );
          },
        ),
      ),
    );
  }
}
