import 'package:blocs/blocs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ui/ui.dart';

import 'dependencies.dart';
import 'screens/dispatch_screen.dart';

class BackofficeApp extends StatelessWidget {
  const BackofficeApp({super.key, required this.dependencies});

  static const locale = Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn');

  final BackofficeDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    // Bloc je iznad MaterialApp-a, pa ga vidi i ekran detalja otvoren preko Navigator-a.
    return RepositoryProvider.value(
      value: dependencies,
      child: BlocProvider(
        create: (_) => DispatchBloc(
          getAllRequests: dependencies.getAllRequests,
          acceptRequest: dependencies.acceptRequest,
          releaseRequest: dependencies.releaseRequest,
          cancelRequest: dependencies.cancelRequest,
          clock: dependencies.clock,
          dispatcher: dependencies.user,
        )..add(const DispatchRequested()),
        child: MaterialApp(
          title: 'CarWash & Go · Dispečerska tabla',
          theme: CarWashTheme.light(),
          darkTheme: CarWashTheme.dark(),
          themeMode: ThemeMode.system,
          locale: locale,
          supportedLocales: const [locale],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const DispatchScreen(),
        ),
      ),
    );
  }
}
