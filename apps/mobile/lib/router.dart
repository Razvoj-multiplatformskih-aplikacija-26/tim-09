import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'dependencies.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/my_requests_screen.dart';
import 'screens/new_request_screen.dart';
import 'screens/prices_screen.dart';
import 'screens/request_detail_screen.dart';

GoRouter createPublicRouter() => GoRouter(
  initialLocation: '/login',
  redirect: (context, state) => const {'/login', '/prices'}.contains(state.matchedLocation) ? null : '/login',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/prices',
      builder: (context, state) => Scaffold(appBar: AppBar(), body: const PricesScreen()),
    ),
  ],
);

/// Prijavljen korisnik: /  ·  /requests/:id  ·  /new  ·  /prices
GoRouter createRouter(User user) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) => state.matchedLocation == '/login' ? '/' : null,
    routes: [
      GoRoute(path: '/login', redirect: (context, state) => '/'),
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
                    builder: (context, state) {
                      final id = WashRequestId(state.pathParameters['id']!);
                      final dependencies = context.read<AppDependencies>();
                      return BlocProvider(
                        create: (_) => RequestDetailBloc(
                          id: id,
                          getRequest: dependencies.getRequest,
                          cancelRequest: dependencies.cancelRequest,
                          clock: dependencies.clock,
                          user: user,
                        )..add(const RequestDetailRequested()),
                        child: RequestDetailScreen(id: id),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    redirect: (context, state) => mayCreateRequest(user) ? null : '/',
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
