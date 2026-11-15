import 'package:flutter/material.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';

/// Simple loading scaffold used by support and utility pages.
class AppLoadingScaffold extends StatelessWidget {
  const AppLoadingScaffold({
    required this.title,
    this.message,
    super.key,
  });

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.backgroundApp,
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            minHeight: 2,
            color: AppColors.tealPrimary,
            backgroundColor: AppColors.borderLight,
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  message ?? 'Loading…',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
