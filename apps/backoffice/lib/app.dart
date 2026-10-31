import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:use_cases/use_cases.dart';

import 'data/fake_dispatch_repository.dart';
import 'presentation/screens/dispatch_dashboard.dart';

class BackofficeApp extends StatelessWidget {
  const BackofficeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = FakeDispatchRepository();
    const dispatcher = User(
      id: UserId('disp-1'),
      username: 'Glavni Dispečer',
      role: Role.dispatcher,
    );
    final clock = LocalClock();

    return MaterialApp(
      title: 'Car Wash Backoffice',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: BlocProvider(
        create: (context) => DispatchBloc(
          getAllRequests: GetAllRequests(requests: repository),
          acceptRequest: AcceptRequest(requests: repository),
          releaseRequest: ReleaseRequest(requests: repository),
          cancelRequest: CancelRequest(requests: repository, clock: clock),
          clock: clock,
          dispatcher: dispatcher,
        )..add(const DispatchRequested()),
        child: DispatchDashboard(repository: repository),
      ),
    );
  }
}