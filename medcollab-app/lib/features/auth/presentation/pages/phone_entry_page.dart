import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/config/env_config.dart';
import 'package:medcollab_app/core/constants/app_constants.dart';
import 'package:medcollab_app/core/utils/phone_utils.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:medcollab_app/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:medcollab_app/features/auth/presentation/widgets/auth_scaffold.dart';

class PhoneEntryPage extends StatefulWidget {
  const PhoneEntryPage({super.key});

  @override
  State<PhoneEntryPage> createState() => _PhoneEntryPageState();
}

class _PhoneEntryPageState extends State<PhoneEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
          AuthPhoneSubmitted(_phoneController.text.trim()),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return AuthScaffold(
          title: 'Welcome',
          subtitle: 'Enter your mobile number to sign in or create an account.',
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.errorMessage != null) ...[
                  AuthErrorBanner(
                    message: state.errorMessage!,
                    onDismiss: () => context
                        .read<AuthBloc>()
                        .add(const AuthErrorDismissed()),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  enabled: !state.isLoading,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    prefixText: '${AppConstants.defaultCountryCode} ',
                    hintText: '9876543210',
                  ),
                  validator: PhoneUtils.validateLocalNumber,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: state.isLoading ? null : _submit,
                  child: state.isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
                const SizedBox(height: 16),
                Text(
                  'We will send a 6-digit OTP to verify your number.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Dev API: ${EnvConfig.apiBaseUrl}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
