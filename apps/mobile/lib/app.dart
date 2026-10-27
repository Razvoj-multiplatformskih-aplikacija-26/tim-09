import 'package:blocs/blocs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:ui/ui.dart';

import 'dependencies.dart';
import 'router.dart';

class CarWashApp extends StatefulWidget {
  const CarWashApp({super.key, required this.dependencies});

  static const locale = Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn');

  final AppDependencies dependencies;

  @override
  State<CarWashApp> createState() => _CarWashAppState();
}

class _CarWashAppState extends State<CarWashApp> {
  late final GoRouter _router = createRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = widget.dependencies;
    // Globalni Bloc je iznad rutera, pa ga vide i lista i detalj.
    return RepositoryProvider.value(
      value: dependencies,
      child: BlocProvider(
        create: (_) => MyRequestsBloc(
          getMyRequests: dependencies.getMyRequests,
          cancelRequest: dependencies.cancelRequest,
          clock: dependencies.clock,
          client: dependencies.user,
        )..add(const MyRequestsRequested()),
        child: MaterialApp.router(
          title: 'CarWash & Go',
          theme: CarWashTheme.light(),
          darkTheme: CarWashTheme.dark(),
          themeMode: ThemeMode.system,
          locale: CarWashApp.locale,
          supportedLocales: const [CarWashApp.locale],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: _router,
        ),
      ),
    );
  }
}
