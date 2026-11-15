import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/constants/branding_assets.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    final status = context.read<AuthBloc>().state.status;
    if (status == AuthStatus.unknown) {
      context.read<AuthBloc>().add(const AuthStarted());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Transparent logo straight on the page colour — same size and
            // place as the Android launch screen, so the hand-off from the
            // system splash is seamless (issue 12: no white card / box).
            Image.asset(
              BrandingAssets.logo,
              key: const Key('splash-logo'),
              width: 216,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
            const SizedBox(height: 16),
            Text(
              'For doctors. Built for India.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              color: AppColors.tealPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
