import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/constants/app_constants.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/theme/app_theme.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';

class MedCollabApp extends StatelessWidget {
  const MedCollabApp({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.instance;

    return BlocProvider<AuthBloc>.value(
      value: deps.authBloc,
      child: MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: deps.appRouter.router,
      ),
    );
  }
}
