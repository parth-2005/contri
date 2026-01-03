import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/member_provider.dart';
import '../../../expense/domain/entities/expense.dart';
import '../../../expense/presentation/providers/expense_providers.dart';
import '../../../expense/presentation/screens/add_expense_screen.dart';
import '../../domain/entities/group.dart';
import '../providers/group_providers.dart';
import '../widgets/expense_tile.dart';
import '../../../../core/presentation/widgets/shimmer_loading.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/debt_calculator.dart';

/// Provider for expenses in a group
final groupExpensesProvider =
    StreamProvider.family<List<Expense>, String>((ref, groupId) {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.getExpensesForGroup(groupId);
});

class GroupDetailsScreen extends ConsumerWidget {
  final Group group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupByIdProvider(group.id));
    final effectiveGroup = groupAsync.value ?? group;
    final membersAsync = ref.watch(memberProfilesProvider(effectiveGroup.members));
    final expensesAsync = ref.watch(groupExpensesProvider(group.id));
    final currentUser = ref.watch(authStateProvider).value;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            effectiveGroup.name,
            style: GoogleFonts.lato(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Expenses'),
              Tab(text: 'Balances'),
              Tab(text: 'Analytics'),
              Tab(text: 'Members'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            expensesAsync.when(
              data: (expenses) => _buildExpensesTab(
                context,
                ref,
                effectiveGroup,
                membersAsync,
                currentUser,
                expenses,
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (error, _) => Center(
                child: Text(
                  'Failed to load expenses: $error',
                  style: GoogleFonts.lato(),
                ),
              ),
            ),
            membersAsync.when(
              data: (members) => _buildBalancesTab(effectiveGroup, members),
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (error, _) => Center(
                child: Text(
                  'Failed to load balances: $error',
                  style: GoogleFonts.lato(),
                ),
              ),
            ),
            expensesAsync.when(
              data: (expenses) => membersAsync.when(
                data: (members) => _buildGroupAnalytics(expenses, members, context),
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (error, _) => Center(
                  child: Text(
                    'Failed to load members: $error',
                    style: GoogleFonts.lato(),
                  ),
                ),
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (error, _) => Center(
                child: Text(
                  'Failed to load analytics: $error',
                  style: GoogleFonts.lato(),
                ),
              ),
            ),
            membersAsync.when(
              data: (members) => _buildMembersTab(effectiveGroup, members),
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (error, _) => Center(
                child: Text(
                  'Failed to load members: $error',
                  style: GoogleFonts.lato(),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _addExpense(context, ref),
          tooltip: 'Add Expense',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  /// Expenses Tab (existing experience preserved)
  Widget _buildExpensesTab(
    BuildContext context,
    WidgetRef ref,
    Group effectiveGroup,
    AsyncValue<Map<String, AppUser>> membersAsync,
    AppUser? currentUser,
    List<Expense> expenses,
  ) {
    final headerHeight = (MediaQuery.sizeOf(context).height * 0.3)
        .clamp(220.0, 360.0);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: headerHeight),
              child: Builder(
                builder: (ctx) {
                  final balance = currentUser != null
                      ? effectiveGroup.getBalanceForUser(currentUser.id)
                      : 0.0;
                  final isOwe = balance < 0;
                  final displayText = isOwe ? 'You Owe' : 'You Lend';
                  final displayColor = isOwe ? Colors.redAccent : Colors.lightGreenAccent;

                  final personalExpense = _calculatePersonalExpense(
                    expenses,
                    currentUser?.id,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayText,
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        CurrencyFormatter.format(balance.abs()),
                        style: GoogleFonts.lato(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: displayColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getBalanceText(balance),
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'My Personal Expense',
                        style: GoogleFonts.lato(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(personalExpense),
                        style: GoogleFonts.lato(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor:
                                Theme.of(context).colorScheme.primary,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                          onPressed: () => _showSettlementPlan(
                            context,
                            ref,
                            currentUser?.id,
                          ),
                          child: Text(
                            'Settle Up',
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _shareGroup(context),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor:
                                    Theme.of(context).colorScheme.primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 2,
                              ),
                              icon: const Icon(Icons.share_outlined),
                              label: Text(
                                'Share Group',
                                style: GoogleFonts.lato(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _confirmAndLeaveGroup(
                                context,
                                ref,
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 2,
                              ),
                              icon: const Icon(Icons.logout_rounded),
                              label: Text(
                                'Leave Group',
                                style: GoogleFonts.lato(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Container(
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: membersAsync.when(
              data: (members) {
                final settlements = DebtCalculator.calculateSettlements(
                  effectiveGroup.balances,
                );
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
                      final fromName =
                          members[settlement.fromUserId]?.name ??
                          settlement.fromUserId;
                      final toName =
                          members[settlement.toUserId]?.name ??
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
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (error, __) => Text(
                'Error loading settlements',
                style: GoogleFonts.lato(color: Colors.red),
              ),
            ),
          ),
        ),

        if (expenses.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(),
          )
        else ...[
          ..._buildMonthlyExpenseSlivers(
            expenses,
            membersAsync,
            currentUser?.id,
            context,
            ref,
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  List<Widget> _buildMonthlyExpenseSlivers(
    List<Expense> expenses,
    AsyncValue<Map<String, AppUser>> membersAsync,
    String? currentUserId,
    BuildContext context,
    WidgetRef ref,
  ) {
    final sortedExpenses = [...expenses]..sort((a, b) => b.date.compareTo(a.date));
    final Map<String, List<Expense>> groupedByMonth = {};

    for (final expense in sortedExpenses) {
      final monthKey = DateFormat('MMMM yyyy').format(expense.date);
      groupedByMonth.putIfAbsent(monthKey, () => []).add(expense);
    }

    return groupedByMonth.entries.expand((entry) {
      return [
        SliverPersistentHeader(
          pinned: true,
          delegate: _MonthHeaderDelegate(label: entry.key),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final expense = entry.value[index];
            return membersAsync.when(
              data: (members) => ExpenseTile(
                expense: expense,
                members: members,
                currentUserId: currentUserId,
                onEdit: () => _editExpense(context, ref, expense),
                onDelete: () => _confirmAndDeleteExpense(context, ref, expense),
              ),
              loading: () => const ExpenseTileShimmer(),
              error: (error, stackTrace) => ExpenseTile(
                expense: expense,
                members: {},
                currentUserId: currentUserId,
                onEdit: () => _editExpense(context, ref, expense),
                onDelete: () => _confirmAndDeleteExpense(context, ref, expense),
              ),
            );
          }, childCount: entry.value.length),
        ),
      ];
    }).toList();
  }

  /// Balances Tab
  Widget _buildBalancesTab(Group group, Map<String, AppUser> members) {
    if (group.balances.isEmpty) {
      return const Center(child: Text('No balances yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: group.balances.length,
      itemBuilder: (context, index) {
        final entry = group.balances.entries.elementAt(index);
        final balance = entry.value;
        final name = members[entry.key]?.name ?? entry.key;
        final isOwe = balance < 0;
        final color = isOwe ? Colors.red : Colors.green;
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(
                isOwe ? Icons.arrow_upward : Icons.arrow_downward,
                color: color,
              ),
            ),
            title: Text(
              name,
              style: GoogleFonts.lato(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              isOwe ? 'Owes the group' : 'Is owed by group',
              style: GoogleFonts.lato(color: Colors.grey.shade600),
            ),
            trailing: Text(
              CurrencyFormatter.format(balance.abs()),
              style: GoogleFonts.lato(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Members Tab
  Widget _buildMembersTab(Group group, Map<String, AppUser> members) {
    if (members.isEmpty) {
      return const Center(child: Text('No members yet'));
    }

    final memberEntries = members.entries.toList()
      ..sort((a, b) => a.value.name.compareTo(b.value.name));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: memberEntries.length,
      itemBuilder: (context, index) {
        final entry = memberEntries[index];
        final balance = group.getBalanceForUser(entry.key);
        final isOwe = balance < 0;
        final color = isOwe ? Colors.red : Colors.green;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.1),
              child: Text(
                entry.value.name.isNotEmpty
                    ? entry.value.name[0].toUpperCase()
                    : '?',
                style: GoogleFonts.lato(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            title: Text(
              entry.value.name,
              style: GoogleFonts.lato(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              entry.value.email,
              style: GoogleFonts.lato(color: Colors.grey.shade600),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(balance.abs()),
                  style: GoogleFonts.lato(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  isOwe ? 'Owes' : 'Is owed',
                  style: GoogleFonts.lato(fontSize: 11, color: color),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Analytics Tab for Group
  Widget _buildGroupAnalytics(
    List<Expense> groupExpenses,
    Map<String, AppUser> members,
    BuildContext context,
  ) {
    final paidByStats = <String, double>{};
    for (final expense in groupExpenses) {
      paidByStats[expense.paidBy] =
          (paidByStats[expense.paidBy] ?? 0) + expense.amount;
    }

    String? topContributorId;
    double topAmount = 0;
    paidByStats.forEach((id, amount) {
      if (amount > topAmount) {
        topAmount = amount;
        topContributorId = id;
      }
    });

    final categoryData = _calculateCategoryBreakdown(groupExpenses);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMvpCard(topContributorId, topAmount, members),
          const SizedBox(height: 16),
          _buildContributorBarChart(paidByStats, members),
          const SizedBox(height: 24),
          Text(
            'Category Breakdown',
            style: GoogleFonts.lato(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _buildCategoryListWithAds(categoryData, context),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildMvpCard(
    String? contributorId,
    double amount,
    Map<String, AppUser> members,
  ) {
    final name = contributorId != null
        ? (members[contributorId]?.name ?? contributorId)
        : 'No expenses yet';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The MVP',
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contributorId == null
                      ? 'No expenses recorded yet'
                      : '$name has paid the most (${CurrencyFormatter.format(amount)})',
                  style: GoogleFonts.lato(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContributorBarChart(
    Map<String, double> paidByStats,
    Map<String, AppUser> members,
  ) {
    if (paidByStats.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = paidByStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = entries.first.value;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contributors',
              style: GoogleFonts.lato(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final member = entries[group.x.toInt()].key;
                        final name = members[member]?.name ?? member;
                        return BarTooltipItem(
                          '$name\n${CurrencyFormatter.format(rod.toY)}',
                          GoogleFonts.lato(
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              CurrencyFormatter.format(value),
                              style: GoogleFonts.lato(fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= entries.length) {
                            return const SizedBox.shrink();
                          }
                          final memberId = entries[index].key;
                          final name = members[memberId]?.name ?? memberId;
                          final shortName = name.length > 3
                              ? name.substring(0, 3)
                              : name;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(shortName, style: GoogleFonts.lato(fontSize: 11)),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(entries.length, (index) {
                    final entry = entries[index];
                    final isTop = entry.value == maxValue;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value,
                          width: 18,
                          borderRadius: BorderRadius.circular(6),
                          color: isTop ? Colors.teal : Colors.grey.shade400,
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, double> _calculateCategoryBreakdown(List<Expense> expenses) {
    final Map<String, double> categoryData = {};
    for (final expense in expenses) {
      if (!expense.isDeleted) {
        categoryData[expense.category] =
            (categoryData[expense.category] ?? 0) + expense.amount;
      }
    }
    final sortedEntries = categoryData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sortedEntries);
  }

  Widget _buildCategoryListWithAds(
    Map<String, double> categoryData,
    BuildContext context,
  ) {
    if (categoryData.isEmpty) {
      return Text(
        'No category data yet',
        style: GoogleFonts.lato(color: Colors.grey.shade600),
      );
    }

    final entries = categoryData.entries.toList();
    final widgets = <Widget>[];

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final total = categoryData.values.fold<double>(0.0, (sum, v) => sum + v);
      final percentage = total > 0 ? (entry.value / total * 100) : 0;

      if (i > 0 && i % 7 == 0) {
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: Center(
              child: Text(
                'Ad Space',
                style: GoogleFonts.lato(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }

      widgets.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getCategoryColor(entry.key).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getCategoryIcon(entry.key),
                  color: _getCategoryColor(entry.key),
                  size: 24,
                ),
              ),
              title: Text(
                entry.key,
                style: GoogleFonts.lato(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${percentage.toStringAsFixed(1)}%',
                style: GoogleFonts.lato(color: Colors.grey.shade600),
              ),
              trailing: Text(
                CurrencyFormatter.format(entry.value),
                style: GoogleFonts.lato(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(children: widgets);
  }

  Color _getCategoryColor(String category) {
    final colors = {
      'Grocery': Colors.green,
      'Fuel': Colors.orange,
      'EMI': Colors.red,
      'School': Colors.blue,
      'Shopping': Colors.pink,
      'Dine-out': Colors.purple,
      'Healthcare': Colors.teal,
      'Entertainment': Colors.amber,
      'Travel': Colors.cyan,
      'Utilities': Colors.brown,
      'Other': Colors.grey,
    };
    return colors[category] ?? Colors.grey;
  }

  IconData _getCategoryIcon(String category) {
    final icons = {
      'Grocery': Icons.shopping_cart,
      'Fuel': Icons.local_gas_station,
      'EMI': Icons.account_balance,
      'School': Icons.school,
      'Shopping': Icons.shopping_bag,
      'Dine-out': Icons.restaurant,
      'Healthcare': Icons.medical_services,
      'Entertainment': Icons.movie,
      'Travel': Icons.flight,
      'Utilities': Icons.bolt,
      'Other': Icons.more_horiz,
    };
    return icons[category] ?? Icons.category;
  }

  double _calculatePersonalExpense(List<Expense> expenses, String? userId) {
    if (userId == null) return 0;
    double total = 0;
    for (final expense in expenses) {
      if (expense.split.containsKey(userId)) {
        total += expense.split[userId] ?? 0;
      }
    }
    return total;
  }

  /// Show Settlement Plan Dialog with Payment Interface
  void _showSettlementPlan(
    BuildContext context,
    WidgetRef ref,
    String? currentUserId,
  ) {
    final effectiveGroup = ref.read(groupByIdProvider(group.id)).value ?? group;
    ref
        .read(memberProfilesProvider(effectiveGroup.members))
        .when(
          data: (members) {
            final settlements = DebtCalculator.calculateSettlements(
              effectiveGroup.balances,
            );
            final myPayments = settlements
                .where((s) => s.fromUserId == currentUserId)
                .toList();

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
                          final toName =
                              members[settlement.toUserId]?.name ??
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                      CurrencyFormatter.format(
                                        settlement.amount,
                                      ),
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
      MaterialPageRoute(builder: (context) => AddExpenseScreen(group: group)),
    );
  }

  /// Edit existing expense
  void _editExpense(BuildContext context, WidgetRef ref, Expense expense) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddExpenseScreen(group: group, expenseToEdit: expense),
      ),
    );
  }

  /// Confirm and delete an expense
  Future<void> _confirmAndDeleteExpense(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text(
          'Are you sure you want to delete this expense? This will also revert balances.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repository = ref.read(expenseRepositoryProvider);
      await repository.deleteExpense(expense.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Expense deleted')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete expense: $e')));
      }
    }
  }

  /// Get balance text
  String _getBalanceText(double balance) {
    if (balance > 0) return 'You will get back';
    if (balance < 0) return 'You need to pay';
    return 'All settled up';
  }

  /// Share group with QR preview and system share
  void _shareGroup(BuildContext context) {
    final deepLink = 'https://contri-568d7.web.app/join/${group.id}';
    final message =
        'Join my group "${group.name}" on Contri!\n\nUse this link: $deepLink';

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
          'Share Group',
          style: GoogleFonts.lato(fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 280,
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    Share.share(message);
                  },
                  icon: const Icon(Icons.share_outlined),
                  label: Text(
                    'Share via apps (WhatsApp, etc.)',
                    style: GoogleFonts.lato(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Confirm and leave the group
  Future<void> _confirmAndLeaveGroup(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text(
          'You will be removed from this group and future updates. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave Group'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repository = ref.read(groupRepositoryProvider);
      await repository.removeMemberFromGroup(group.id, currentUser.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You left the group')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to leave group: $e')));
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
                TextFormField(
                  controller: paymentController,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixIcon: const Icon(Icons.currency_rupee),
                    hintText: '0.00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    helperText:
                        'Total owed: ${CurrencyFormatter.format(settlement.amount)}',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not authenticated')));
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
        Navigator.pop(context);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error recording payment: $e')));
      }
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(
          'No expenses yet',
          style: GoogleFonts.lato(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Add your first expense to get started',
          style: GoogleFonts.lato(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
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
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppTheme.secondaryBeige.withValues(
        alpha: overlapsContent ? 0.96 : 1,
      ),
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
  bool shouldRebuild(covariant _MonthHeaderDelegate oldDelegate) =>
      oldDelegate.label != label;
}
