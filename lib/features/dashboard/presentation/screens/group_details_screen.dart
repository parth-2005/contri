import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/group.dart';
import '../../../expense/domain/entities/expense.dart';
import '../../../expense/presentation/providers/expense_providers.dart';
import '../../../expense/presentation/screens/add_expense_screen.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:intl/intl.dart';

/// Provider for expenses in a group
final groupExpensesProvider = StreamProvider.family<List<Expense>, String>((ref, groupId) {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.getExpensesForGroup(groupId);
});

/// Group Details Screen showing expenses and balances
class GroupDetailsScreen extends ConsumerWidget {
  final Group group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(groupExpensesProvider(group.id));
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showGroupInfo(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Balance Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.secondary,
            child: Column(
              children: [
                Text(
                  'Your Balance',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  currentUser != null
                      ? CurrencyFormatter.format(group.getBalanceForUser(currentUser.id).abs())
                      : '₹0.00',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: _getBalanceColor(
                          currentUser != null ? group.getBalanceForUser(currentUser.id) : 0.0,
                          context,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getBalanceText(
                    currentUser != null ? group.getBalanceForUser(currentUser.id) : 0.0,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _getBalanceColor(
                          currentUser != null ? group.getBalanceForUser(currentUser.id) : 0.0,
                          context,
                        ),
                      ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBalanceInfo(
                      context,
                      'Members',
                      '${group.members.length}',
                      Icons.people,
                    ),
                    _buildBalanceInfo(
                      context,
                      'Expenses',
                      expensesAsync.value?.length.toString() ?? '0',
                      Icons.receipt,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Expenses List
          Expanded(
            child: expensesAsync.when(
              data: (expenses) {
                if (expenses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 80,
                          color: Theme.of(context).colorScheme.primary.withValues(alpha:0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Expenses Yet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first expense',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return _buildExpenseCard(context, expense, currentUser?.id);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddExpenseScreen(group: group),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  Widget _buildBalanceInfo(BuildContext context, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildExpenseCard(BuildContext context, Expense expense, String? currentUserId) {
    final isPaidByCurrentUser = expense.paidBy == currentUserId;
    final userShare = currentUserId != null ? (expense.splitMap[currentUserId] ?? 0.0) : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha:0.2),
          child: Icon(
            Icons.receipt,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          expense.description,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Paid by ${isPaidByCurrentUser ? "You" : "Member"}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              DateFormat('MMM dd, yyyy').format(expense.date),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              CurrencyFormatter.format(expense.amount),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (userShare > 0) ...[
              const SizedBox(height: 4),
              Text(
                'You owe ${CurrencyFormatter.formatCompact(userShare)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange.shade700,
                    ),
              ),
            ] else if (isPaidByCurrentUser) ...[
              const SizedBox(height: 4),
              Text(
                'You paid',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.green.shade700,
                    ),
              ),
            ],
          ],
        ),
        onTap: () {
          _showExpenseDetails(context, expense);
        },
      ),
    );
  }

  void _showExpenseDetails(BuildContext context, Expense expense) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                expense.description,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Amount', style: Theme.of(context).textTheme.bodyLarge),
                  Text(
                    CurrencyFormatter.format(expense.amount),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Date: ${DateFormat('MMMM dd, yyyy').format(expense.date)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Split Details',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...expense.splitMap.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Member ${entry.key}'), // TODO: Show actual names
                      Text(CurrencyFormatter.format(entry.value)),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  void _showGroupInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(group.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Group ID: ${group.id}'),
            const SizedBox(height: 8),
            Text('Members: ${group.members.length}'),
            const SizedBox(height: 16),
            const Text('Balances:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...group.balances.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Member ${entry.key}: ${CurrencyFormatter.formatWithSign(entry.value)}',
                ),
              );
            }).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _getBalanceText(double balance) {
    if (balance > 0) return 'You get back';
    if (balance < 0) return 'You owe';
    return 'Settled up';
  }

  Color _getBalanceColor(double balance, BuildContext context) {
    if (balance > 0) return Colors.green.shade700;
    if (balance < 0) return Colors.orange.shade700;
    return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;
  }
}
