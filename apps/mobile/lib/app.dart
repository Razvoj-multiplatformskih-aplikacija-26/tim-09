import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:ui/ui.dart';

import 'dependencies.dart';
import 'router.dart';

class CarWashApp extends StatelessWidget {
  const CarWashApp({super.key, required this.dependencies});

  static const locale = Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn');

  final AppDependencies dependencies;

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
            AuthChecking() => const _App(home: CheckingView()),
            AuthRestoreFailed(:final cause) => _App(
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
            AuthSignedOut() => const _PublicApp(key: ValueKey('public')),
            AuthSignedIn(:final session) => _SignedInApp(key: ValueKey(session), user: session.user),
          },
        ),
      ),
    );
  }
}

class _App extends StatelessWidget {
  const _App({this.home, this.router, this.messengerKey});

  final Widget? home;
  final GoRouter? router;
  final GlobalKey<ScaffoldMessengerState>? messengerKey;

  @override
  Widget build(BuildContext context) {
    const delegates = [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];
    final router = this.router;
    if (router != null) {
      return MaterialApp.router(
        title: 'CarWash & Go',
        theme: CarWashTheme.light(),
        darkTheme: CarWashTheme.dark(),
        themeMode: ThemeMode.system,
        locale: CarWashApp.locale,
        supportedLocales: const [CarWashApp.locale],
        localizationsDelegates: delegates,
        scaffoldMessengerKey: messengerKey,
        routerConfig: router,
      );
    }
    return MaterialApp(
      title: 'CarWash & Go',
      theme: CarWashTheme.light(),
      darkTheme: CarWashTheme.dark(),
      themeMode: ThemeMode.system,
      locale: CarWashApp.locale,
      supportedLocales: const [CarWashApp.locale],
      localizationsDelegates: delegates,
      home: home,
    );
  }
}

class _PublicApp extends StatefulWidget {
  const _PublicApp({super.key});

  @override
  State<_PublicApp> createState() => _PublicAppState();
}

class _PublicAppState extends State<_PublicApp> {
  late final GoRouter _router = createPublicRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _App(router: _router);
}

class _SignedInApp extends StatefulWidget {
  const _SignedInApp({super.key, required this.user});

  final User user;

  @override
  State<_SignedInApp> createState() => _SignedInAppState();
}

class _SignedInAppState extends State<_SignedInApp> {
  late final GoRouter _router = createRouter(widget.user);
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = context.read<AppDependencies>();
    return RepositoryProvider.value(
      value: widget.user,
      child: BlocProvider(
        create: (_) => MyRequestsBloc(
          getMyRequests: dependencies.getMyRequests,
          cancelRequest: dependencies.cancelRequest,
          clock: dependencies.clock,
          user: widget.user,
        )..add(const MyRequestsRequested()),
        child: BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) => current is AuthSignedIn && current.notice != null,
          listener: (context, state) {
            final notice = (state as AuthSignedIn).notice!;
            _messenger.currentState
              ?..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(notice.messageFor(ClientApplication.mobile))));
            context.read<AuthBloc>().add(const AuthNoticeAcknowledged());
          },
          child: _App(router: _router, messengerKey: _messenger),
        ),
      ),
    );
  }
}
