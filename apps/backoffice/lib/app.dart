import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ui/ui.dart';

import 'dependencies.dart';
import 'screens/dispatch_screen.dart';
import 'screens/login_screen.dart';

class BackofficeApp extends StatelessWidget {
  const BackofficeApp({super.key, required this.dependencies});

  static const locale = Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn');

  final BackofficeDependencies dependencies;

  static bool _phaseChanged(AuthState previous, AuthState current) =>
      previous.runtimeType != current.runtimeType ||
      (previous is AuthSignedIn && current is AuthSignedIn && previous.session != current.session);

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: dependencies,
      child: BlocProvider(
        create: (_) => AuthBloc(auth: dependencies.auth)..add(const AuthStarted()),
        child: BlocBuilder<AuthBloc, AuthState>(
          buildWhen: _phaseChanged,
          builder: (context, state) => switch (state) {
            AuthChecking() => const _App(key: ValueKey('checking'), home: CheckingView()),
            AuthRestoreFailed(:final cause) => _App(
              key: const ValueKey('restore'),
              home: Scaffold(
                body: Center(
                  child: SingleChildScrollView(
                    child: FailureView(
                      title: 'Prijava nije proverena.',
                      message: failureMessage(cause),
                      onRetry: () => context.read<AuthBloc>().add(const AuthStarted()),
                    ),
                  ),
                ),
              ),
            ),
            AuthSignedOut() => const _App(key: ValueKey('login'), home: LoginScreen()),
            AuthSignedIn(:final session) => _SignedInApp(key: ValueKey(session), user: session.user),
          },
        ),
      ),
    );
  }
}

class _App extends StatelessWidget {
  const _App({super.key, required this.home, this.messengerKey});

  final Widget home;
  final GlobalKey<ScaffoldMessengerState>? messengerKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarWash & Go · Dispečerska tabla',
      theme: CarWashTheme.light(),
      darkTheme: CarWashTheme.dark(),
      themeMode: ThemeMode.system,
      locale: BackofficeApp.locale,
      supportedLocales: const [BackofficeApp.locale],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      scaffoldMessengerKey: messengerKey,
      home: home,
    );
  }
}

class _SignedInApp extends StatefulWidget {
  const _SignedInApp({super.key, required this.user});

  final User user;

  @override
  State<_SignedInApp> createState() => _SignedInAppState();
}

class _SignedInAppState extends State<_SignedInApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    final dependencies = context.read<BackofficeDependencies>();
    // Bloc je iznad MaterialApp-a, pa ga vidi i ekran detalja otvoren preko Navigator-a.
    return RepositoryProvider.value(
      value: widget.user,
      child: BlocProvider(
        create: (_) => DispatchBloc(
          getAllRequests: dependencies.getAllRequests,
          getWashers: dependencies.getWashers,
          acceptRequest: dependencies.acceptRequest,
          releaseRequest: dependencies.releaseRequest,
          cancelRequest: dependencies.cancelRequest,
        )..add(const DispatchRequested()),
        child: BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) => current is AuthSignedIn && current.notice != null,
          listener: (context, state) {
            final notice = (state as AuthSignedIn).notice!;
            _messenger.currentState
              ?..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(notice.messageFor(ClientApplication.backoffice))));
            context.read<AuthBloc>().add(const AuthNoticeAcknowledged());
          },
          child: _App(home: const DispatchScreen(), messengerKey: _messenger),
        ),
      ),
    );
  }
}
