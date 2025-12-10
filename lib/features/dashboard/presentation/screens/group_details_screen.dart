import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/group.dart';
import '../../../expense/domain/entities/expense.dart';
import '../../../expense/presentation/providers/expense_providers.dart';
import '../../../expense/presentation/screens/add_expense_screen.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/member_provider.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/debt_calculator.dart';
import '../widgets/expense_tile.dart';

/// Provider for expenses in a group
final groupExpensesProvider = StreamProvider.family<List<Expense>, String>((ref, groupId) {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.getExpensesForGroup(groupId);
});

/// Group Details Screen with Splitwise-like UX
/// Features:
/// - Shrinkable header with Settlement Plan
/// - Collapsible header shows net balance
/// - SliverAppBar for smooth scrolling
/// - Expandable expense tiles with edit functionality
class GroupDetailsScreen extends ConsumerWidget {
  final Group group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(groupExpensesProvider(group.id));
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.value;
    final membersAsync = ref.watch(memberProfilesProvider(group.members));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Shrinkable AppBar with Settlement Plan
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            elevation: 0,
            title: Text(
              group.name,
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 80, left: 16, right: 16, bottom: 16),
                  child: Builder(
                    builder: (ctx) {
                      final balance = currentUser != null
                          ? group.getBalanceForUser(currentUser.id)
                          : 0.0;
                      final isOwe = balance < 0;
                      final displayText = isOwe ? 'You Owe' : 'You Lend';
                      final displayColor = isOwe ? Colors.red : Colors.green;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Your Balance Status
                          Text(
                            displayText,
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            CurrencyFormatter.format(balance.abs()),
                            style: GoogleFonts.lato(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: displayColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getBalanceText(balance),
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // "Settle Up" Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Theme.of(context).colorScheme.primary,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _showSettlementPlan(context, ref, currentUser?.id),
                              child: Text(
                                'Settle Up',
                                style: GoogleFonts.lato(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _shareGroup(context),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showGroupInfo(context, membersAsync),
              ),
            ],
          ),

          // Settlement Plan Section (Expandable Header Summary)
          SliverToBoxAdapter(
            child: Container(
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: membersAsync.when(
                data: (members) {
                  final settlements = DebtCalculator.calculateSettlements(group.balances);
                  if (settlements.isEmpty) {
                    return Text(
                      'Everyone is settled up! 🎉',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.green.shade700,
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settlement Plan',
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...settlements.take(2).map((settlement) {
                        final fromName = members[settlement.fromUserId]?.name ?? 
                            settlement.fromUserId;
                        final toName = members[settlement.toUserId]?.name ?? 
                            settlement.toUserId;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '$fromName owes $toName ${CurrencyFormatter.format(settlement.amount)}',
                            style: GoogleFonts.lato(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }),
                      if (settlements.length > 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '+${settlements.length - 2} more',
                            style: GoogleFonts.lato(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const SizedBox(
                  height: 40,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (_, __) => Text(
                  'Error loading settlements',
                  style: GoogleFonts.lato(color: Colors.red),
                ),
              ),
            ),
          ),

          // Expenses List
          expensesAsync.when(
            data: (expenses) {
              if (expenses.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 80,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Expenses Yet',
                          style: GoogleFonts.lato(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first expense to get started',
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final expense = expenses[index];
                    return membersAsync.when(
                      data: (members) => ExpenseTile(
                        expense: expense,
                        members: members,
                        currentUserId: currentUser?.id,
                        onEdit: () => _editExpense(context, ref, expense),
                      ),
                      loading: () => const Card(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          title: LinearProgressIndicator(),
                        ),
                      ),
                      error: (error, stackTrace) => ExpenseTile(
                        expense: expense,
                        members: {},
                        currentUserId: currentUser?.id,
                        onEdit: () => _editExpense(context, ref, expense),
                      ),
                    );
                  },
                  childCount: expenses.length,
                ),
              );
            },
            loading: () => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Loading expenses...',
                      style: GoogleFonts.lato(),
                    ),
                  ],
                ),
              ),
            ),
            error: (error, stack) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 80,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load expenses',
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom spacing for FAB
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addExpense(context, ref),
        tooltip: 'Add Expense',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Show Settlement Plan Dialog with Payment Interface
  void _showSettlementPlan(BuildContext context, WidgetRef ref, String? currentUserId) {
    ref.read(memberProfilesProvider(group.members)).when(
      data: (members) {
        final settlements = DebtCalculator.calculateSettlements(group.balances);
        // Filter to show only settlements where current user owes
        final myPayments = settlements.where((s) => s.fromUserId == currentUserId).toList();

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Payments Due',
              style: GoogleFonts.lato(fontWeight: FontWeight.w700),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (myPayments.isEmpty) ...[
                    Icon(
                      Icons.check_circle,
                      size: 48,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'You don\'t owe anyone!',
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ] else
                    ...myPayments.map((settlement) {
                      final toName = members[settlement.toUserId]?.name ?? 
                          settlement.toUserId;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _showPaymentDialog(
                            context,
                            ref,
                            settlement,
                            toName,
                            currentUserId,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.red.shade300,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.red.shade50,
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pay $toName',
                                        style: GoogleFonts.lato(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tap to make payment',
                                        style: GoogleFonts.lato(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(settlement.amount),
                                  style: GoogleFonts.lato(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: GoogleFonts.lato(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
      loading: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Payments Due',
              style: GoogleFonts.lato(fontWeight: FontWeight.w700),
            ),
            content: const CircularProgressIndicator(),
          ),
        );
      },
      error: (error, stack) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading settlement plan: $error',
              style: GoogleFonts.lato(),
            ),
          ),
        );
      },
    );
  }

  /// Add new expense
  void _addExpense(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(group: group),
      ),
    );
  }

  /// Edit existing expense
  void _editExpense(BuildContext context, WidgetRef ref, Expense expense) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(
          group: group,
          expenseToEdit: expense,
        ),
      ),
    );
  }

  /// Get balance text
  String _getBalanceText(double balance) {
    if (balance > 0) return 'You will get back';
    if (balance < 0) return 'You need to pay';
    return 'All settled up';
  }

  /// Share group
  void _shareGroup(BuildContext context) {
    final message =
        'Join my group "${group.name}" on Contri!\n\nGroup ID: ${group.id}\n\nInstall Contri and use this ID to join the group.';
    Share.share(message);
  }

  /// Show group info dialog
  void _showGroupInfo(
    BuildContext context,
    AsyncValue<Map<String, AppUser>> membersAsync,
  ) {
    showDialog(
      context: context,
      builder: (context) => membersAsync.when(
        data: (members) => AlertDialog(
          title: Text(
            group.name,
            style: GoogleFonts.lato(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Group ID',
                  style: GoogleFonts.lato(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  group.id,
                  style: GoogleFonts.lato(fontSize: 13),
                ),
                const SizedBox(height: 16),
                Text(
                  'Members (${group.members.length})',
                  style: GoogleFonts.lato(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                ...members.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.value.name,
                          style: GoogleFonts.lato(fontSize: 13),
                        ),
                        Text(
                          CurrencyFormatter.formatWithSign(
                            group.getBalanceForUser(entry.key),
                          ),
                          style: GoogleFonts.lato(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: GoogleFonts.lato(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        loading: () => AlertDialog(
          title: Text(
            group.name,
            style: GoogleFonts.lato(fontWeight: FontWeight.w700),
          ),
          content: const CircularProgressIndicator(),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: GoogleFonts.lato(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        error: (error, stack) => AlertDialog(
          title: Text(
            group.name,
            style: GoogleFonts.lato(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Error loading members: $error',
            style: GoogleFonts.lato(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: GoogleFonts.lato(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show Payment Dialog for settling individual debt
  void _showPaymentDialog(
    BuildContext context,
    WidgetRef ref,
    Settlement settlement,
    String toName,
    String? currentUserId,
  ) {
    final paymentController = TextEditingController(
      text: settlement.amount.toStringAsFixed(2),
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Make Payment',
          style: GoogleFonts.lato(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pay To (Read-only with editable option)
                TextFormField(
                  initialValue: toName,
                  decoration: InputDecoration(
                    labelText: 'Pay To',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  enabled: false,
                ),
                const SizedBox(height: 16),

                // Payment Amount (Editable)
                TextFormField(
                  controller: paymentController,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixIcon: const Icon(Icons.currency_rupee),
                    hintText: '0.00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    helperText: 'Total owed: ${CurrencyFormatter.format(settlement.amount)}',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter amount';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Invalid amount';
                    }
                    if (amount > settlement.amount) {
                      return 'Cannot pay more than owed';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.lato(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final paymentAmount = double.parse(paymentController.text);
                _recordPayment(
                  context,
                  ref,
                  settlement,
                  paymentAmount,
                  currentUserId,
                  toName,
                );
                Navigator.pop(context);
              }
            },
            child: Text(
              'Confirm Payment',
              style: GoogleFonts.lato(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Record payment using the expense system
  /// Creates a payment transaction that reduces the settlement
  void _recordPayment(
    BuildContext context,
    WidgetRef ref,
    Settlement settlement,
    double paymentAmount,
    String? currentUserId,
    String toName,
  ) async {
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    try {
      final repository = ref.read(expenseRepositoryProvider);
      
      await repository.recordPayment(
        groupId: group.id,
        fromUserId: currentUserId,
        toUserId: settlement.toUserId,
        amount: paymentAmount,
      );

      if (context.mounted) {
        Navigator.pop(context); // Close settlement plan dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment of ${CurrencyFormatter.format(paymentAmount)} recorded with $toName!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording payment: $e')),
        );
      }
    }
  }
}

