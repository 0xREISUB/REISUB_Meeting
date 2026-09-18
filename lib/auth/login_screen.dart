import 'package:flutter/material.dart';
import 'package:v_meeting/auth/register_screen.dart';
import 'package:v_meeting/auth/server_config.dart';
import 'package:v_meeting/home/home_screen.dart'; // Giriş başarılı olunca yönlendirilecek sayfa
import 'package:dio/dio.dart';
import 'package:v_meeting/l10n/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nickController = TextEditingController();
  final _passwordController = TextEditingController();

  void _handleLogin() async {
    final l10n = AppLocalizations.of(context);
    try {
      final serverUrl = await ServerConfig.readUrl();
      if (serverUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n?.connectionError ?? 'Bağlantı hatası!'),
            ),
          );
        }
        return;
      }
      final dio = Dio();
      final response = await dio.post(
        '$serverUrl/login',
        data: {
          'nick': _nickController.text,
          'password': _passwordController.text,
        },
      );

      if (response.statusCode == 200) {
        // 1. Go'dan gelen tokeni al
        final token = response.data['token'] as String?;
        if (token == null || token.isEmpty) {
          throw const FormatException('Missing authentication token');
        }

        // 2. Tokeni cihaz hafızasına kaydet (Beni hatırla mantığı)
        await ServerConfig.saveToken(token);

        // 3. Ana sayfaya yönlendir
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data['error'] ??
          (l10n?.connectionError ?? 'Bağlantı hatası!');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } on FormatException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.connectionError ?? 'Bağlantı hatası!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.video_chat_rounded,
                  size: 100,
                  color: Colors.deepPurpleAccent,
                ),
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
                TextField(
                  controller: _nickController,
                  decoration: InputDecoration(
                    labelText: l10n.nickname,
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.password,
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _handleLogin,
                  child: Text(l10n.login, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: Text(l10n.noAccountRegister),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
