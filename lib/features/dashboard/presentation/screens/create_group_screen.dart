import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/group_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Screen to create a new group
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();
  final List<String> _memberEmails = [];
  final Map<String, double> _memberShares = {}; // {email: shareCount} - supports decimals (e.g., 0.5 for child)
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _addMember() {
    final email = _emailController.text.trim();
    if (email.isNotEmpty && email.contains('@')) {
      setState(() {
        _memberEmails.add(email);
        _memberShares[email] = 1.0; // Default share count is 1.0 (supports decimals like 0.5)
        _emailController.clear();
      });
    }
  }

  void _removeMember(int index) {
    setState(() {
      final email = _memberEmails[index];
      _memberEmails.removeAt(index);
      _memberShares.remove(email);
    });
  }

  void _updateMemberShare(String email, double share) {
    setState(() {
      _memberShares[email] = share;
    });
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authStateProvider);
    final currentUser = authState.value;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(groupRepositoryProvider);

      // Create list of member IDs (for now, using current user's ID)
      // In production, you'd look up users by email
      final memberIds = [currentUser.id];

      // For now using email as userId - mapping will be implemented later
      // Build a map of userId -> share count (supports decimals like 0.5 for children)
      final Map<String, double> defaultShares = {};
      for (final email in _memberEmails) {
        defaultShares[email] = _memberShares[email] ?? 1.0;
      }
      // Add current user's default share (1.0)
      defaultShares[currentUser.id] = 1.0;

      await repository.createGroup(
        name: _groupNameController.text.trim(),
        members: memberIds,
        defaultShares: defaultShares,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Group Name
            TextFormField(
              controller: _groupNameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'e.g., Flat 402, College Friends',
                prefixIcon: Icon(Icons.group),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a group name';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Create Button
            ElevatedButton(
              onPressed: _isLoading ? null : _createGroup,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Group'),
            ),
          ],
        ),
      ),
    );
  }
}
