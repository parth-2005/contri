import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/group_providers.dart';
import '../widgets/group_card.dart';
import 'create_group_screen.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Dashboard Screen - Main screen showing list of groups
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _showProfileMenu(BuildContext context, WidgetRef ref) {
    final authState = ref.read(authStateProvider);
    final user = authState.value;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (user != null) ...[
              ListTile(
                leading: user.photoUrl != null
                    ? CircleAvatar(backgroundImage: NetworkImage(user.photoUrl!))
                    : const CircleAvatar(child: Icon(Icons.person)),
                title: Text(user.name),
                subtitle: Text(user.email),
              ),
              const Divider(),
            ],
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(authRepositoryProvider).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(userGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => _showProfileMenu(context, ref),
          ),
        ],
      ),
      body: groupsAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.group_add,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha:0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Groups Yet',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a group to start splitting expenses',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return GroupCard(group: group);
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) {
          final isIndexError = error.toString().contains('FAILED_PRECONDITION') ||
              error.toString().contains('requires an index');

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Couldn\'t Load Groups',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (isIndexError)
                    Text(
                      'Firestore is setting up. This usually takes a few minutes.\n\nTap retry to check again.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    )
                  else
                    Text(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.invalidate(userGroupsProvider);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateGroupScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Group'),
      ),
    );
  }
}
