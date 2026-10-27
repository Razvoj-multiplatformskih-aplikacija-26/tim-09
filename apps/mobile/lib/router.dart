import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'dependencies.dart';
import 'screens/home_shell.dart';
import 'screens/my_requests_screen.dart';
import 'screens/new_request_screen.dart';
import 'screens/prices_screen.dart';
import 'screens/request_detail_screen.dart';

/// Adrese: /  ·  /requests/:id  ·  /new  ·  /prices
GoRouter createRouter() {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const MyRequestsScreen(),
                routes: [
                  GoRoute(
                    path: 'requests/:id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => RequestDetailScreen(id: WashRequestId(state.pathParameters['id']!)),
                  ),
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    // Lokalni Bloc forme živi samo dok je forma otvorena.
                    builder: (context, state) => BlocProvider(
                      create: (context) =>
                          WashRequestFormBloc(submitRequest: context.read<AppDependencies>().submitRequest),
                      child: const NewRequestScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/prices', builder: (context, state) => const PricesScreen())],
          ),
        ],
      ),
    ],
  );
}
