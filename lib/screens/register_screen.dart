import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'main_shell_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _errorMessage = '';
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    // Basic validation
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }

    if (name.length < 2) {
      setState(() => _errorMessage = 'Name must be at least 2 characters.');
      return;
    }

    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.register(name, email, password);

    if (!mounted) return;

    if (result == null) {
      // Success — navigate to main shell
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShellScreen()),
        (route) => false,
      );
    } else {
      // Error — show message
      setState(() {
        _isSubmitting = false;
        _errorMessage = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Create Account'),
      ),
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
                child: const Icon(Icons.person_add_rounded, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 32),
              Text(
                'Join Qweez!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Create your student account to start learning',
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
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                obscureText: _obscureConfirm,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _handleRegister,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Create Account'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Already have an account? Log In',
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
