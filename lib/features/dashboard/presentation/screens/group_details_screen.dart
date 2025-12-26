import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../domain/entities/group.dart';
import '../../../expense/domain/entities/expense.dart';
import '../../../expense/presentation/providers/expense_providers.dart';
import '../../../expense/presentation/screens/add_expense_screen.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/member_provider.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/debt_calculator.dart';
import '../../../../core/presentation/widgets/shimmer_loading.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/expense_tile.dart';
import '../providers/group_providers.dart';

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

  /// Calculate personal expense (total paid - total received back)
  double _calculatePersonalExpense(
    List<Expense> expenses,
    String? currentUserId,
  ) {
    if (currentUserId == null) return 0.0;

    // Total amount paid by current user
    final totalPaid = expenses
        .where((e) => e.paidBy == currentUserId)
        .fold<double>(0, (sum, e) => sum + e.amount);

    // Total amount the current user owes others (from splitMap)
    final totalOwed = expenses.fold<double>(0, (sum, e) {
      return sum + (e.splitMap[currentUserId] ?? 0);  
    });

    // Personal expense = Total paid - Total owed by others (what I get back)
    // Which is: Total paid - (Total paid by me - Net balance I owe)
    // Simpler way: Personal expense = Total paid by me - Total received back from others
    // Total received = Total paid - (Total paid - what I'm paying my share on)
    
    // Actually: Personal Expense = Amount I paid that I didn't split = Total I paid - (Total paid by others that I was in split)
    final receivedFromOthers = expenses
        .where((e) => e.paidBy != currentUserId)
        .fold<double>(0, (sum, e) => sum + (e.splitMap[currentUserId] ?? 0));

    return totalPaid - receivedFromOthers;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(groupExpensesProvider(group.id));
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.value;
    // Live group stream for reactive balances/members
    final liveGroupAsync = ref.watch(groupByIdProvider(group.id));
    final effectiveGroup = liveGroupAsync.value ?? group;
    final membersAsync = ref.watch(memberProfilesProvider(effectiveGroup.members));

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
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'qr':
                      _showQrCode(context);
                      break;
                    case 'share':
                      _shareGroup(context);
                      break;
                    case 'info':
                      _showGroupInfo(context, membersAsync, ref);
                      break;
                    case 'delete':
                      await _confirmAndDeleteGroup(context, ref);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'qr', child: Text('Show QR Code')),
                  const PopupMenuItem(value: 'share', child: Text('Share')),
                  const PopupMenuItem(value: 'info', child: Text('Group Info')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete Group'),
                  ),
                ],
              ),
            ],
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
                  padding: const EdgeInsets.only(top: 60, left: 16, right: 16, bottom: 12),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Builder(
                      builder: (ctx) {
                        final balance = currentUser != null
                          ? effectiveGroup.getBalanceForUser(currentUser.id)
                          : 0.0;
                        final isOwe = balance < 0;
                        final displayText = isOwe ? 'You Owe' : 'You Lend';
                        final displayColor = isOwe ? Colors.red : Colors.green;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Your Balance Status
                              Text(
                                displayText,
                                style: GoogleFonts.lato(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                CurrencyFormatter.format(balance.abs()),
                                style: GoogleFonts.lato(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: displayColor,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _getBalanceText(balance),
                                style: GoogleFonts.lato(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Personal Expense
                              expensesAsync.when(
                                data: (expenses) {
                                  final personalExpense =
                                      _calculatePersonalExpense(expenses, currentUser?.id);
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'My Personal Expense',
                                        style: GoogleFonts.lato(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withValues(alpha: 0.7),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        CurrencyFormatter.format(personalExpense),
                                        style: GoogleFonts.lato(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                                loading: () => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'My Personal Expense',
                                      style: GoogleFonts.lato(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withValues(alpha: 0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    SizedBox(
                                      width: 50,
                                      height: 16,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                error: (_, __) => const SizedBox.shrink(),
                              ),
                              const SizedBox(height: 14),
                              // "Settle Up" Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () => _showSettlementPlan(context, ref, currentUser?.id),
                                  child: Text(
                                    'Settle Up',
                                    style: GoogleFonts.lato(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Settlement Plan Section (Expandable Header Summary)
          SliverToBoxAdapter(
            child: Container(
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: membersAsync.when(
                data: (members) {
                  final settlements = DebtCalculator.calculateSettlements(effectiveGroup.balances);
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

              final sortedExpenses = [...expenses]..sort((a, b) => b.date.compareTo(a.date));
              final Map<String, List<Expense>> groupedByMonth = {};

              for (final expense in sortedExpenses) {
                final monthKey = DateFormat('MMMM yyyy').format(expense.date);
                groupedByMonth.putIfAbsent(monthKey, () => []).add(expense);
              }

              final slivers = groupedByMonth.entries.expand((entry) {
                return [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _MonthHeaderDelegate(label: entry.key),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final expense = entry.value[index];
                        return membersAsync.when(
                          data: (members) => ExpenseTile(
                            expense: expense,
                            members: members,
                            currentUserId: currentUser?.id,
                            onEdit: () => _editExpense(context, ref, expense),
                            onDelete: () => _confirmAndDeleteExpense(context, ref, expense),
                          ),
                          loading: () => const ExpenseTileShimmer(),
                          error: (error, stackTrace) => ExpenseTile(
                            expense: expense,
                            members: {},
                            currentUserId: currentUser?.id,
                            onEdit: () => _editExpense(context, ref, expense),
                            onDelete: () => _confirmAndDeleteExpense(context, ref, expense),
                          ),
                        );
                      },
                      childCount: entry.value.length,
                    ),
                  ),
                ];
              }).toList();

              return SliverMainAxisGroup(slivers: slivers);
            },
            loading: () => SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => const ExpenseTileShimmer(),
                childCount: 6,
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
    final effectiveGroup = ref.read(groupByIdProvider(group.id)).value ?? group;
    ref.read(memberProfilesProvider(effectiveGroup.members)).when(
      data: (members) {
        final settlements = DebtCalculator.calculateSettlements(effectiveGroup.balances);
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

  /// Confirm and delete an expense
  Future<void> _confirmAndDeleteExpense(BuildContext context, WidgetRef ref, Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense? This will also revert balances.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repository = ref.read(expenseRepositoryProvider);
      await repository.deleteExpense(expense.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete expense: $e')),
        );
      }
    }
  }

  /// Get balance text
  String _getBalanceText(double balance) {
    if (balance > 0) return 'You will get back';
    if (balance < 0) return 'You need to pay';
    return 'All settled up';
  }

  /// Share group
  void _shareGroup(BuildContext context) {
    final deepLink = 'contri://join/${group.id}';
    final message =
        'Join my group "${group.name}" on Contri!\n\nUse this link: $deepLink';
    Share.share(message);
  }

  void _showQrCode(BuildContext context) {
    final deepLink = 'contri://join/${group.id}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Join via QR',
          style: GoogleFonts.lato(fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 260,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: QrImageView(
                  data: deepLink,
                  version: QrVersions.auto,
                  eyeStyle: const QrEyeStyle(color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(color: Colors.black),
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                deepLink,
                style: GoogleFonts.lato(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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

  /// Show group info dialog
  void _showGroupInfo(
    BuildContext context,
    AsyncValue<Map<String, AppUser>> membersAsync,
    WidgetRef ref,
  ) {
    final effectiveGroup = ref.read(groupByIdProvider(group.id)).value ?? group;
    showDialog(
      context: context,
      builder: (context) => membersAsync.when(
        data: (members) => AlertDialog(
          title: Text(
            effectiveGroup.name,
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
                  effectiveGroup.id,
                  style: GoogleFonts.lato(fontSize: 13),
                ),
                const SizedBox(height: 16),
                Text(
                  'Members (${effectiveGroup.members.length})',
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
                            effectiveGroup.getBalanceForUser(entry.key),
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
            effectiveGroup.name,
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
            effectiveGroup.name,
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

  /// Confirm and delete the group
  Future<void> _confirmAndDeleteGroup(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text('Deleting the group will remove all its expenses. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repository = ref.read(groupRepositoryProvider);
      await repository.deleteGroup(group.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group deleted')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete group: $e')),
        );
      }
    }
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

class _MonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String label;

  _MonthHeaderDelegate({required this.label});

  @override
  double get minExtent => 44;

  @override
  double get maxExtent => 44;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.secondaryBeige.withValues(alpha: overlapsContent ? 0.96 : 1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSecondary,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _MonthHeaderDelegate oldDelegate) => oldDelegate.label != label;
}

