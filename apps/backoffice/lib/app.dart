import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:blocs/blocs.dart';
import 'package:ui/ui.dart';

import 'dependencies.dart';
import 'presentation/screens/dispatch_dashboard.dart';

class BackofficeApp extends StatefulWidget {
  const BackofficeApp({super.key, required this.dependencies});

  final BackofficeDependencies dependencies;

  @override
  State<BackofficeApp> createState() => _BackofficeAppState();
}

class _BackofficeAppState extends State<BackofficeApp> {
  late final DispatchBloc _dispatchBloc;

  @override
  void initState() {
    super.initState();
    _dispatchBloc = DispatchBloc(
      getAllRequests: widget.dependencies.getAllRequests,
      acceptRequest: widget.dependencies.acceptRequest,
      releaseRequest: widget.dependencies.releaseRequest,
      cancelRequest: widget.dependencies.cancelRequest,
      dispatcher: widget.dependencies.user,
      clock: widget.dependencies.clock,
    )..add(const DispatchRequested());
  }

  @override
  void dispose() {
    _dispatchBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: widget.dependencies,
      child: MaterialApp(
        title: 'Dispečerska tabla',
        theme: CarWashTheme.light(),
        darkTheme: CarWashTheme.dark(),
        themeMode: ThemeMode.system,
        locale: const Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn'),
        supportedLocales: const [Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: BlocProvider.value(value: _dispatchBloc, child: const DispatchDashboard()),
      ),
    );
  }
}
