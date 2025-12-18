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

            // Add Members Section
            Text(
              'Add Members (Optional)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'You can add members now or invite them later',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            // Email Input
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Member Email',
                      hintText: 'email@example.com',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addMember,
                  icon: const Icon(Icons.add_circle),
                  color: Theme.of(context).colorScheme.primary,
                  iconSize: 32,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Members List
            if (_memberEmails.isNotEmpty) ...[
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.people),
                      title: Text(
                        'Members (${_memberEmails.length})',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const Divider(height: 1),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _memberEmails.length,
                      itemBuilder: (context, index) {
                        final email = _memberEmails[index];
                        final share = _memberShares[email] ?? 1;
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(email[0].toUpperCase()),
                          ),
                          title: Text(email),
                          subtitle: const Text('Share count'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 70,
                                child: TextFormField(
                                  initialValue: share.toString(),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(),
                                    helperText: '1=adult\n0.5=child',
                                    helperMaxLines: 2,
                                  ),
                                  onChanged: (value) {
                                    final shares = double.tryParse(value) ?? 1.0;
                                    _updateMemberShare(email, shares);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => _removeMember(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Info Card
            Card(
              color: Theme.of(context).colorScheme.primary.withValues(alpha:0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Note: Member invites will be implemented in next update. For now, you can create the group and share the group code.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
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
