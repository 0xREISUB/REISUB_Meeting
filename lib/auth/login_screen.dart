import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/app/theme.dart';
import 'package:v_meeting/auth/account.dart';
import 'package:v_meeting/auth/auth_api.dart';
import 'package:v_meeting/auth/host_screen.dart';
import 'package:v_meeting/auth/register_screen.dart';
import 'package:v_meeting/app/invite.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/widgets/app_logo.dart';
import 'package:v_meeting/widgets/language_menu_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.guestsRefused = false});

  /// Opened because the server takes no guests: says so, and offers another
  /// server when there is no screen to go back to.
  final bool guestsRefused;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nickController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _handleLogin() async {
    if (_isSubmitting) return;
    final l10n = AppLocalizations.of(context)!;
    final nick = _nickController.text.trim();
    final password = _passwordController.text;
    if (nick.isEmpty || password.isEmpty) {
      showErrorSnackBar(context, l10n.credentialsRequired);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(authApiProvider).login(nick: nick, password: password);
      ref.read(signedInProvider.notifier).markSignedIn();
      if (!mounted) return;
      // Login is opened from the app; go back to where the user came from.
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
        return;
      }
      final next = startHome(ref);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => next),
      );
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
                  const AppLogo(),
                  const SizedBox(height: 24),
                  Text(
                    l10n.welcome,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  if (widget.guestsRefused) ...[
                    Container(
                      key: const Key('login-guests-refused'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lock_person_rounded,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(l10n.guestsRefusedLogin)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  TextField(
                    key: const Key('login-nick'),
                    controller: _nickController,
                    enabled: !_isSubmitting,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration: InputDecoration(
                      labelText: l10n.nickname,
                      prefixIcon: const Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('login-password'),
                    controller: _passwordController,
                    enabled: !_isSubmitting,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _handleLogin(),
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      prefixIcon: const Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    key: const Key('login-submit'),
                    onPressed: _isSubmitting ? null : _handleLogin,
                    child: _isSubmitting
                        ? const _ButtonProgress()
                        : Text(
                            l10n.login,
                            style: const TextStyle(fontSize: 18),
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          ),
                    child: Text(l10n.noAccountRegister),
                  ),
                  // With nowhere to go back to, another server is the only
                  // way out besides logging in.
                  if (widget.guestsRefused && !Navigator.canPop(context))
                    TextButton(
                      key: const Key('login-change-server'),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HostScreen(),
                              ),
                            ),
                      child: Text(l10n.changeServer),
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

class _ButtonProgress extends StatelessWidget {
  const _ButtonProgress();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 22,
    height: 22,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
