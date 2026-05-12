import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'main_shell_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _errorMessage = '';
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primary400,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary400.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: const Icon(Icons.menu_book_rounded, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome back!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Log in to continue your learning journey',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 48),
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade400, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: TextStyle(color: Colors.red.shade900, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: authProvider.isLoading
                    ? null
                    : () async {
                        final success = await authProvider.login(
                          _emailController.text,
                          _passwordController.text,
                        );
                        if (success) {
                          if (context.mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const MainShellScreen()),
                            );
                          }
                        } else {
                          setState(() {
                            _errorMessage = authProvider.authError ?? 'Invalid email or password.';
                          });
                        }
                      },
                child: authProvider.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Log In'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
                child: const Text(
                  'Don\'t have an account? Register',
                  style: TextStyle(color: AppTheme.primary600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
