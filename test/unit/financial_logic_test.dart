import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contri/features/auth/domain/entities/app_user.dart';
import 'package:contri/features/auth/presentation/providers/auth_providers.dart';
import 'package:contri/features/expense/data/repositories/expense_repository_impl.dart';
import 'package:contri/features/expense/domain/entities/expense.dart';
import 'package:contri/features/expense/domain/repositories/expense_repository.dart';
import 'package:contri/features/expense/presentation/providers/expense_providers.dart';
import 'package:contri/features/dashboard/data/repositories/group_repository_impl.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

class FakeExpenseRepository implements ExpenseRepository {
  final _controller = StreamController<List<Expense>>.broadcast();
  List<Expense>? _latest;

  void emit(List<Expense> expenses) {
    _latest = expenses;
    _controller.add(expenses);
  }

  @override
  Stream<List<Expense>> getFilteredExpenses({DateTime? startDate, DateTime? endDate, String? category, String? memberId, String? type}) {
    return Stream<List<Expense>>.multi((emitter) {
      if (_latest != null) {
        emitter.add(_latest!);
      }

      final sub = _controller.stream.listen(emitter.add, onError: emitter.addError, onDone: emitter.close);
      emitter.onCancel = sub.cancel;
    });
  }

  // Unused in these math-only unit tests
  @override
  Future<void> createExpense({String? groupId, required String description, required double amount, required String paidBy, required Map<String, double> split, String? splitType, Map<String, double>? familyShares, required String category, required String type, String? attributedMemberId, DateTime? date}) async {}
  @override
  Future<void> updateExpense({String? groupId, required String expenseId, required String description, required double amount, required String paidBy, required Map<String, double> split, String? splitType, Map<String, double>? familyShares, required String category, required String type, String? attributedMemberId, DateTime? date}) async {}
  @override
  Future<void> deleteExpense(String expenseId) async {}
  @override
  Stream<List<Expense>> getExpensesForGroup(String groupId) => const Stream.empty();
  @override
  Stream<List<Expense>> getPersonalExpenses(String userId) => const Stream.empty();
  @override
  Stream<List<Expense>> getAllUserExpenses(String userId) => const Stream.empty();
  @override
  Future<void> recordPayment({required String groupId, required String fromUserId, required String toUserId, required double amount}) async {}
}

void main() {
  const user = AppUser(id: 'me', name: 'Me', email: 'me@test.com');

  Future<PersonalOverview> firstOverview(ProviderContainer container) {
    final completer = Completer<PersonalOverview>();
    ProviderSubscription<AsyncValue<PersonalOverview>>? sub;

    sub = container.listen<AsyncValue<PersonalOverview>>(personalOverviewProvider, (previous, next) {
      next.whenData((value) {
        if (!completer.isCompleted) {
          completer.complete(value);
          sub?.close();
        }
      });
    }, fireImmediately: true);

    return completer.future;
  }

  ProviderContainer containerWith(FakeExpenseRepository repo) {
    return ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(user)),
        expenseRepositoryProvider.overrideWithValue(repo),
      ],
    );
  }

  Expense buildExpense({
    required double amount,
    String? paidBy,
    Map<String, double>? split,
    String type = 'group',
    String category = 'Other',
    String? groupId = 'g1',
  }) {
    return Expense(
      id: 'e-${DateTime.now().microsecondsSinceEpoch}',
      groupId: groupId,
      description: 'test',
      amount: amount,
      paidBy: paidBy ?? 'me',
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

  group('personalOverviewProvider math', () {
    test('Simple add personal expense', () async {
      final repo = FakeExpenseRepository();
      final container = containerWith(repo);

      final overviewFuture = firstOverview(container);
      repo.emit([
        buildExpense(amount: 100, type: 'personal', split: {'me': 100}, groupId: null),
      ]);

      final overview = await overviewFuture;
      expect(overview.totalSpentThisMonth, 100);
      expect(overview.totalOwed, 0);
      expect(overview.totalOwing, 0);
      expect(overview.netBalance, 0);
    });

    test('Group split - payer', () async {
      final repo = FakeExpenseRepository();
      final container = containerWith(repo);

      final overviewFuture = firstOverview(container);
      repo.emit([
        buildExpense(
          amount: 1000,
          paidBy: 'me',
          split: {'me': 500, 'friend': 500},
          type: 'group',
        ),
      ]);

      final overview = await overviewFuture;
      expect(overview.totalSpentThisMonth, 500);
      expect(overview.totalOwed, closeTo(500, 0.01));
      expect(overview.totalOwing, 0);
      expect(overview.netBalance, closeTo(500, 0.01));
    });

    test('Group split - receiver', () async {
      final repo = FakeExpenseRepository();
      final container = containerWith(repo);

      final overviewFuture = firstOverview(container);
      repo.emit([
        buildExpense(
          amount: 1000,
          paidBy: 'friend',
          split: {'me': 500, 'friend': 500},
          type: 'group',
        ),
      ]);

      final overview = await overviewFuture;
      expect(overview.totalSpentThisMonth, 500);
      expect(overview.totalOwed, 0);
      expect(overview.totalOwing, closeTo(500, 0.01));
      expect(overview.netBalance, closeTo(-500, 0.01));
    });

    test('Settlement receiving reduces owed', () async {
      final repo = FakeExpenseRepository();
      final container = containerWith(repo);

      final overviewFuture = firstOverview(container);
      repo.emit([
        buildExpense(
          amount: 1000,
          paidBy: 'me',
          split: {'me': 500, 'friend': 500},
          type: 'group',
        ),
        buildExpense(
          amount: 500,
          paidBy: 'friend',
          split: {'me': 500},
          type: 'group',
          category: 'Settlement',
        ),
      ]);

      final overview = await overviewFuture;
      expect(overview.totalOwed, closeTo(0, 0.01));
      expect(overview.netBalance, closeTo(0, 0.01));
    });

    test('Settlement paying reduces owing', () async {
      final repo = FakeExpenseRepository();
      final container = containerWith(repo);

      final overviewFuture = firstOverview(container);
      repo.emit([
        buildExpense(
          amount: 1000,
          paidBy: 'friend',
          split: {'me': 500, 'friend': 500},
          type: 'group',
        ),
        buildExpense(
          amount: 500,
          paidBy: 'me',
          split: {'friend': 500},
          type: 'group',
          category: 'Settlement',
        ),
      ]);

      final overview = await overviewFuture;
      expect(overview.totalOwing, closeTo(0, 0.01));
      expect(overview.netBalance, closeTo(0, 0.01));
    });

    test('Complex multi-user split', () async {
      final repo = FakeExpenseRepository();
      final container = containerWith(repo);

      final overviewFuture = firstOverview(container);
      repo.emit([
        buildExpense(
          amount: 3000,
          paidBy: 'me',
          split: {'me': 1000, 'a': 1000, 'b': 1000},
          type: 'group',
        ),
      ]);

      final overview = await overviewFuture;
      expect(overview.totalSpentThisMonth, 1000);
      expect(overview.totalOwed, closeTo(2000, 0.01));
      expect(overview.totalOwing, 0);
    });
  });

  group('ExpenseRepositoryImpl filters', () {
    test('Unified filter returns personal and group when type is null', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ExpenseRepositoryImpl(firestore: firestore, uuid: const Uuid());

      await firestore.collection('expenses').add({
        'description': 'personal',
        'amount': 100.0,
        'paidBy': 'me',
        'splitMap': {'me': 100.0},
        'date': Timestamp.fromDate(DateTime.now()),
        'category': 'Other',
        'type': 'personal',
        'isDeleted': false,
      });

      await firestore.collection('expenses').add({
        'groupId': 'g1',
        'description': 'group',
        'amount': 200.0,
        'paidBy': 'me',
        'splitMap': {'me': 100.0, 'friend': 100.0},
        'date': Timestamp.fromDate(DateTime.now()),
        'category': 'Other',
        'type': 'group',
        'isDeleted': false,
      });

      final result = await repo.getFilteredExpenses(type: null).first;
      expect(result.length, 2);
    });

    test('Participant visibility includes split members', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ExpenseRepositoryImpl(firestore: firestore, uuid: const Uuid());

      await firestore.collection('expenses').add({
        'groupId': 'g1',
        'description': 'friend paid',
        'amount': 300.0,
        'paidBy': 'friend',
        'splitMap': {'me': 150.0, 'friend': 150.0},
        'date': Timestamp.fromDate(DateTime.now()),
        'category': 'Food',
        'type': 'group',
        'isDeleted': false,
      });

      await firestore.collection('expenses').add({
        'groupId': 'g1',
        'description': 'unrelated',
        'amount': 300.0,
        'paidBy': 'friend',
        'splitMap': {'friend': 300.0},
        'date': Timestamp.fromDate(DateTime.now()),
        'category': 'Food',
        'type': 'group',
        'isDeleted': false,
      });

      final result = await repo.getFilteredExpenses(memberId: 'me').first;
      expect(result.map((e) => e.description), ['friend paid']);
    });

    test('Delete marks expense deleted and reverts balances', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('groups').doc('g1').set({
        'members': ['me', 'friend'],
        'balances': {'me': 0.0, 'friend': 0.0},
        'totalExpense': 0.0,
      });

      await firestore.collection('expenses').doc('exp1').set({
        'groupId': 'g1',
        'description': 'dinner',
        'amount': 200.0,
        'paidBy': 'me',
        'splitMap': {'me': 100.0, 'friend': 100.0},
        'date': Timestamp.fromDate(DateTime.now()),
        'category': 'Food',
        'type': 'group',
        'isDeleted': false,
      });

      final repo = ExpenseRepositoryImpl(firestore: firestore, uuid: const Uuid());
      await repo.deleteExpense('exp1');

      final expenseAfter = await firestore.collection('expenses').doc('exp1').get();
      expect(expenseAfter.data()!['isDeleted'], isTrue);

      final groupAfter = await firestore.collection('groups').doc('g1').get();
      final balances = Map<String, dynamic>.from(groupAfter.data()!['balances'] as Map);
      expect(balances['me'], closeTo(-100.0, 0.01));
      expect(balances['friend'], closeTo(100.0, 0.01));
    });
  });

  group('GroupRepositoryImpl basics', () {
    test('Create group seeds balances and uses generated id', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = GroupRepositoryImpl(firestore: firestore, uuid: const Uuid());

      await repo.createGroup(name: 'Goa Trip', members: ['me']);
      final groups = await firestore.collection('groups').get();

      expect(groups.docs.length, 1);
      final data = groups.docs.first.data();
      expect(data['balances'], {'me': 0.0});
    });

    test('Join group adds member', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = GroupRepositoryImpl(firestore: firestore, uuid: const Uuid());

      await firestore.collection('groups').doc('g1').set({
        'name': 'Goa',
        'members': ['me'],
        'balances': {'me': 0.0},
        'defaultShares': {},
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'type': 'other',
        'settings': {},
        'totalExpense': 0.0,
      });

      await repo.joinGroup('g1', 'friend');

      final updated = await firestore.collection('groups').doc('g1').get();
      expect(List<String>.from(updated.data()!['members']).contains('friend'), isTrue);
    });
  });
}
