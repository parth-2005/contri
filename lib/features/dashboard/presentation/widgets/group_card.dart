import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/group.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../screens/group_details_screen.dart';

/// Card widget to display a group in the dashboard
class GroupCard extends ConsumerWidget {
  final Group group;

  const GroupCard({
    super.key,
    required this.group,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userBalance = authState.when(
      data: (user) => user != null ? group.getBalanceForUser(user.id) : 0.0,
      loading: () => 0.0,
      error: (_, err) => 0.0,
    );

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroupDetailsScreen(group: group),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group Name
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Icon(
                      Icons.group,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      group.name,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              
              // Balance Information
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Balance',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(userBalance.abs()),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _getBalanceColor(userBalance, context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  
                  // Balance Status Chip
                  _buildBalanceChip(userBalance, context),
                ],
              ),
              
              // Members Count
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 16,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${group.members.length} members',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceChip(double balance, BuildContext context) {
    String label;
    Color backgroundColor;
    Color textColor;

    if (balance > 0) {
      label = 'Gets Back';
      backgroundColor = Colors.green.shade100;
      textColor = Colors.green.shade900;
    } else if (balance < 0) {
      label = 'Owes';
      backgroundColor = Colors.orange.shade100;
      textColor = Colors.orange.shade900;
    } else {
      label = 'Settled';
      backgroundColor = Theme.of(context).colorScheme.secondary;
      textColor = Theme.of(context).colorScheme.onSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getBalanceColor(double balance, BuildContext context) {
    if (balance > 0) {
      return Colors.green.shade700;
    } else if (balance < 0) {
      return Colors.orange.shade700;
    }
    return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;
  }
}
