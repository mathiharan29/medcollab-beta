import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/core/utils/phone_utils.dart';
import 'package:medcollab_app/core/utils/qr_decode_utils.dart';
import 'package:medcollab_app/features/spaces/presentation/widgets/live_qr_scanner.dart';

/// Join via live QR scan, photo, or manual invite code.
class ScanInviteQrPage extends StatefulWidget {
  const ScanInviteQrPage({super.key});

  @override
  State<ScanInviteQrPage> createState() => _ScanInviteQrPageState();
}

class _ScanInviteQrPageState extends State<ScanInviteQrPage> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  String? _error;
  bool _busy = false;
  bool _liveScan = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _tryOpenCode(String raw) {
    final code = PhoneUtils.extractInviteCode(raw);
    if (code == null || code.length < 4) {
      setState(
        () => _error =
            'QR did not contain a Vocle invite. Enter the code manually below.',
      );
      return;
    }
    context.pushReplacement(AppRoutes.joinInvitePath(code));
  }

  Future<void> _decodeFromGallery() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1600,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      final raw = QrDecodeUtils.decodeFromBytes(bytes);
      if (raw == null || raw.isEmpty) {
        setState(
          () => _error =
              'No QR found in that image. Try live scan or enter the code.',
        );
        return;
      }
      _tryOpenCode(raw);
    } catch (_) {
      setState(() => _error = 'Could not read that image');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _continueManual() {
    final code = PhoneUtils.extractInviteCode(_controller.text);
    if (code == null || code.length < 4) {
      setState(
        () => _error = 'Enter a valid invite code or full Vocle join link',
      );
      return;
    }
    context.pushReplacement(AppRoutes.joinInvitePath(code));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(title: const Text('Join with invite')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Scan QR code',
              style: AppTextStyles.doctorName.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Live scan detects the QR automatically when you point at it. '
              'You can also pick a screenshot or type the invite code.',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 260,
              child: _liveScan
                  ? LiveQrScanner(onCodeFound: _tryOpenCode)
                  : Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceInput,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderDefault),
                      ),
                      child: Text(
                        'Live scan paused',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _liveScan = !_liveScan),
                  child: Text(_liveScan ? 'Pause live scan' : 'Resume live scan'),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _decodeFromGallery,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('From photo'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Or enter invite code / link',
              style: AppTextStyles.cardTitle,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Invite code or link',
                hintText: 'https://…/join/… or code',
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _continueManual(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.statusError,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _continueManual,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
