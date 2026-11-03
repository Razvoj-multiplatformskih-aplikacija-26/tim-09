import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:blocs/blocs.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('sr_Latn');
  if (kDebugMode) Bloc.observer = ConsoleBlocObserver(debugPrint);
  runApp(BackofficeApp(dependencies: BackofficeDependencies.fake()));
}
