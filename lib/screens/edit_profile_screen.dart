import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final error = await authProvider.updateProfile(_nameController.text);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      // Sukses — kembali ke halaman sebelumnya
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profil berhasil diperbarui'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profil'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingXl),
          children: [
            const SizedBox(height: AppTheme.spacingXl),

            // Avatar preview
            Center(
              child: Consumer<AuthProvider>(
                builder: (_, auth, _) {
                  final initial = _nameController.text.isNotEmpty
                      ? _nameController.text[0].toUpperCase()
                      : (auth.user?.name.isNotEmpty == true
                          ? auth.user!.name[0].toUpperCase()
                          : 'U');
                  return CircleAvatar(
                    radius: 48,
                    backgroundColor: AppTheme.primary100,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 36,
                        color: AppTheme.primary600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: AppTheme.spacingXxl),

            // Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Label
                  Text(
                    'Nama Tampilan',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTheme.spacingSm),

                  // Name input
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Masukkan nama Anda',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Nama tidak boleh kosong';
                      }
                      if (value.trim().length < 2) {
                        return 'Nama minimal 2 karakter';
                      }
                      if (value.trim().length > 100) {
                        return 'Nama maksimal 100 karakter';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}), // refresh avatar preview
                  ),

                  const SizedBox(height: AppTheme.spacingXxl),

                  // Save button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Simpan Perubahan'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
