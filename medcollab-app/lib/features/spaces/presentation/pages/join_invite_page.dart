import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/features/spaces/data/repositories/space_repository.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_empty_state.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_loading_scaffold.dart';
import 'package:medcollab_app/shared/presentation/widgets/clinical_card.dart';
import 'package:medcollab_app/shared/presentation/widgets/error_banner.dart';

/// Deep-link landing page for space invite codes.
class JoinInvitePage extends StatefulWidget {
  const JoinInvitePage({required this.code, super.key});

  final String code;

  @override
  State<JoinInvitePage> createState() => _JoinInvitePageState();
}

class _JoinInvitePageState extends State<JoinInvitePage> {
  late Future<SpaceInvitePreview> _previewFuture;
  bool _joining = false;
  bool _pendingApproval = false;

  @override
  void initState() {
    super.initState();
    _previewFuture =
        AppDependencies.instance.spaceRepository.previewInvite(widget.code);
  }

  Future<void> _join(SpaceInvitePreview preview) async {
    if (_joining || _pendingApproval) return;
    setState(() => _joining = true);
    try {
      if (preview.alreadyMember) {
        final spaces =
            await AppDependencies.instance.spaceRepository.getMySpaces();
        final match =
            spaces.where((s) => s.inviteCode == preview.inviteCode).firstOrNull;
        if (match != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening ${preview.name}')),
          );
          context.go(AppRoutes.spaceDetailPath(match.id));
          return;
        }
      }

      final result =
          await AppDependencies.instance.spaceRepository.joinSpace(widget.code);
      if (result.isPending) {
        if (!mounted) return;
        setState(() {
          _joining = false;
          _pendingApproval = true;
        });
        return;
      }
      final space = result.space!;
      AppDependencies.instance.socketClient.syncSpaceRooms();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined ${space.name}')),
      );
      context.go(AppRoutes.spaceDetailPath(space.id));
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not join — check the code and try again'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SpaceInvitePreview>(
      future: _previewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppLoadingScaffold(
            title: 'Join space',
            message: 'Checking invite ${widget.code.toUpperCase()}…',
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Join space'),
            backgroundColor: AppColors.background,
          ),
          body: _buildBody(context, snapshot),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<SpaceInvitePreview> snapshot,
  ) {
    if (snapshot.hasError || !snapshot.hasData) {
      final message = snapshot.error is AppException
          ? (snapshot.error as AppException).message
          : 'This invite link is invalid or has expired.';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ErrorBanner(message: message),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Ask a colleague for a fresh invite code, or browse groups '
                'you already belong to.',
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => context.go(AppRoutes.spacesList),
                child: const Text('Browse spaces'),
              ),
            ],
          ),
        ),
      );
    }

    final preview = snapshot.data!;
    if (preview.alreadyMember) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: AppEmptyState(
          icon: Icons.check_circle_outline,
          title: 'You are already in this group',
          subtitle:
              '${preview.name} is already on your list. Open it to continue.',
          action: FilledButton(
            onPressed: _joining ? null : () => _join(preview),
            child: _joining
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Open space'),
          ),
        ),
      );
    }

    if (_pendingApproval) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: AppEmptyState(
          icon: Icons.hourglass_top_outlined,
          title: 'Pending',
          subtitle:
              'Your request to join ${preview.name} is waiting for admin approval.',
          action: FilledButton(
            onPressed: () => context.go(AppRoutes.spacesList),
            child: const Text('Back to spaces'),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const Text(
          'You have been invited to join this clinical group.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: AppSpacing.md),
        ClinicalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preview.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (preview.description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  preview.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${preview.memberCount} member${preview.memberCount == 1 ? '' : 's'} · ${preview.type}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _joining ? null : () => _join(preview),
          child: _joining
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Join space'),
        ),
      ],
    );
  }
}
