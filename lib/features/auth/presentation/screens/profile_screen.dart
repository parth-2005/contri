import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_providers.dart';
import '../../../../core/theme/app_theme.dart';
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _isLoading = false;
  bool _hasChanges = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _initializeControllers(String name, String? phone) {
    _nameController.text = name;
    _phoneController.text = phone ?? '';
    _hasChanges = false;
  }

  void _onNameChanged() {
    setState(() => _hasChanges = true);
    setState(() => _errorMessage = null);
  }

  void _onPhoneChanged() {
    setState(() => _hasChanges = true);
    setState(() => _errorMessage = null);
  }

  Future<void> _saveProfile(String userId, String originalName, String? originalPhone) async {
    final newName = _nameController.text.trim();
    final newPhone = _phoneController.text.trim();

    // Validation
    if (newName.isEmpty) {
      setState(() => _errorMessage = 'Name cannot be empty');
      return;
    }

    if (newName.length < 2) {
      setState(() => _errorMessage = 'Name must be at least 2 characters');
      return;
    }

    if (newPhone.isNotEmpty && newPhone.length < 10) {
      setState(() => _errorMessage = 'Phone number must be at least 10 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final repository = ref.read(authRepositoryProvider);
      
      // Only update if values changed
      String? nameToUpdate = newName != originalName ? newName : null;
      String? phoneToUpdate = newPhone != (originalPhone ?? '') ? newPhone : null;

      if (nameToUpdate == null && phoneToUpdate == null) {
        setState(() => _successMessage = 'No changes to save');
        return;
      }

      await repository.updateUserProfile(
        userId: userId,
        name: nameToUpdate,
        phoneNumber: phoneToUpdate,
      );

      // Refresh user data
      ref.invalidate(authStateProvider);
      await ref.read(authStateProvider.future);

      if (mounted) {
        setState(() {
          _successMessage = 'Profile updated successfully!';
          _hasChanges = false;
        });
        // Clear success message after 2 seconds
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          setState(() => _successMessage = null);
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error updating profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: const Center(child: Text('Not logged in')),
          );
        }

        // Initialize controllers only once on first build
        if (_nameController.text.isEmpty && user.name.isNotEmpty) {
          _initializeControllers(user.name, user.phoneNumber);
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'My Profile',
              style: GoogleFonts.lato(fontWeight: FontWeight.w700),
            ),
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error Message
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.lato(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (_errorMessage != null) const SizedBox(height: 16),

                  // Success Message
                  if (_successMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _successMessage!,
                        style: GoogleFonts.lato(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (_successMessage != null) const SizedBox(height: 16),

                  // Profile Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryBeige,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Email (Read-only)
                        _buildReadOnlyField(
                          label: 'Email',
                          value: user.email,
                          icon: Icons.email_outlined,
                        ),
                        const SizedBox(height: 16),

                        // Name (Editable)
                        _buildEditableField(
                          label: 'Name',
                          controller: _nameController,
                          hintText: 'Enter your full name',
                          icon: Icons.person_outlined,
                          onChanged: _onNameChanged,
                        ),
                        const SizedBox(height: 16),

                        // Phone Number (Editable)
                        _buildEditableField(
                          label: 'Phone Number',
                          controller: _phoneController,
                          hintText: 'Enter your phone number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          onChanged: _onPhoneChanged,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _hasChanges && !_isLoading
                          ? () => _saveProfile(user.id, user.name, user.phoneNumber)
                          : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: _hasChanges
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Text(
                              'Save Changes',
                              style: GoogleFonts.lato(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: _hasChanges ? Colors.white : Colors.grey.shade600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Sign Out Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _showSignOutDialog,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: Colors.red.shade300,
                        ),
                      ),
                      child: Text(
                        'Sign Out',
                        style: GoogleFonts.lato(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              Icon(Icons.lock, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required VoidCallback onChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, size: 18),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          ),
          style: GoogleFonts.lato(fontSize: 14),
        ),
      ],
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Sign Out',
          style: GoogleFonts.lato(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: GoogleFonts.lato(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final repository = ref.read(authRepositoryProvider);
              await repository.signOut();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
