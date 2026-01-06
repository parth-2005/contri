import 'package:contri/features/auth/domain/entities/app_user.dart';
import 'package:contri/features/auth/presentation/providers/auth_providers.dart';
import 'package:contri/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:contri/features/expense/domain/entities/expense.dart';
import 'package:contri/features/expense/presentation/providers/expense_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = AppUser(id: 'me', name: 'Me', email: 'me@test.com');

  PersonalOverview makeOverview({double spent = 0, double owed = 0, double owing = 0}) =>
      PersonalOverview(totalSpentThisMonth: spent, totalOwed: owed, totalOwing: owing);

  Expense buildExpense({
    required String id,
    required double amount,
    String type = 'personal',
    String category = 'Other',
    String? groupId,
    String description = 'desc',
    String paidBy = 'me',
    Map<String, double>? split,
  }) {
    return Expense(
      id: id,
      groupId: groupId,
      description: description,
      amount: amount,
      paidBy: paidBy,
      split: split ?? {'me': amount},
      splitType: 'equal',
      familyShares: null,
      date: DateTime.now(),
      category: category,
      type: type,
      attributedMemberId: null,
      localAttachmentPath: null,
      isDeleted: false,
    );
  }

  testWidgets('Dashboard shows empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          personalOverviewProvider.overrideWith((ref) => Stream.value(makeOverview())),
          filteredExpensesProvider.overrideWith((ref, params) => Stream.value(<Expense>[])),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('No expenses yet'), findsOneWidget);
  });

  testWidgets('Dashboard renders data', (tester) async {
    final expenses = [
      buildExpense(id: 'p1', amount: 200, type: 'personal', description: 'Coffee'),
      buildExpense(id: 'g1', amount: 1000, type: 'group', groupId: 'g1', description: 'Trip • Paid by You', split: {'me': 500, 'f': 500}),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          personalOverviewProvider.overrideWith((ref) => Stream.value(makeOverview(spent: 700, owed: 500, owing: 0))),
          filteredExpensesProvider.overrideWith((ref, params) => Stream.value(expenses)),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Total Spent'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('Trip • Paid by You'), findsOneWidget);
  });
}
