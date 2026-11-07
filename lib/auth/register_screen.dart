import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/app/theme.dart';
import 'package:v_meeting/auth/auth_api.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/widgets/language_menu_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nickController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _handleRegister() async {
    if (_isSubmitting) return;
    final l10n = AppLocalizations.of(context)!;
    final nick = _nickController.text.trim();
    final password = _passwordController.text;

    if (nick.isEmpty || password.isEmpty) {
      showErrorSnackBar(context, l10n.credentialsRequired);
      return;
    }
    if (password != _passwordConfirmController.text) {
      showErrorSnackBar(context, l10n.passwordsNotMatch);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(authApiProvider).register(nick: nick, password: password);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.registerSuccess)));
      Navigator.pop(context);
    } on AuthException catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error.serverMessage ?? l10n.connectionError);
      }
    } catch (_) {
      if (mounted) showErrorSnackBar(context, l10n.connectionError);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _nickController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [LanguageMenuButton(), SizedBox(width: 8)],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AutofillGroup(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.createAccount,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    key: const Key('register-nick'),
                    controller: _nickController,
                    enabled: !_isSubmitting,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newUsername],
                    decoration: InputDecoration(
                      labelText: l10n.nickname,
                      prefixIcon: const Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('register-password'),
                    controller: _passwordController,
                    enabled: !_isSubmitting,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      prefixIcon: const Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('register-password-confirm'),
                    controller: _passwordConfirmController,
                    enabled: !_isSubmitting,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleRegister(),
                    decoration: InputDecoration(
                      labelText: l10n.confirmPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    key: const Key('register-submit'),
                    onPressed: _isSubmitting ? null : _handleRegister,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            l10n.register,
                            style: const TextStyle(fontSize: 18),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
