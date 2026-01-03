import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/expense_providers.dart';
import '../../domain/entities/expense.dart';

/// Analytics Screen with filters for deep-dive insights
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  // Filter states
  String _selectedPeriod = 'This Month';
  String? _selectedCategory;
  String? _selectedMember;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Predefined categories
  static const List<String> _categories = [
    'Grocery',
    'Fuel',
    'EMI',
    'School',
    'Shopping',
    'Dine-out',
    'Healthcare',
    'Entertainment',
    'Travel',
    'Utilities',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final filterParams = _buildFilterParams();
    final expensesAsync = ref.watch(filteredExpensesProvider(filterParams));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: Column(
        children: [
          // Filter Bar
          _buildFilterBar(),
          // Content
          Expanded(
            child: expensesAsync.when(
              data: (expenses) => _buildAnalyticsContent(expenses),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Period Filter
          Row(
            children: [
              Icon(Icons.calendar_today, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedPeriod,
                  isExpanded: true,
                  items: [
                    'Today',
                    'This Week',
                    'This Month',
                    'Custom',
                  ].map((period) {
                    return DropdownMenuItem(
                      value: period,
                      child: Text(period),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPeriod = value!;
                      if (value == 'Custom') {
                        _showDateRangePicker();
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Category Filter
          Row(
            children: [
              Icon(Icons.category, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String?>(
                  value: _selectedCategory,
                  hint: const Text('All Categories'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Categories'),
                    ),
                    ..._categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No expenses found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Calculate statistics
    final categoryData = _calculateCategoryBreakdown(expenses);
    final totalAmount = expenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Spending Card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Total Spending',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${expenses.length} transactions',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Category Breakdown
          const Text(
            'Category Breakdown',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 250,
                child: PieChart(
                  PieChartData(
                    sections: _buildPieChartSections(categoryData, totalAmount),
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Category List
          const Text(
            'Category Details',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...categoryData.entries.map((entry) {
            final percentage = (entry.value / totalAmount * 100);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getCategoryColor(entry.key),
                  child: Icon(
                    _getCategoryIcon(entry.key),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(entry.key),
                subtitle: Text('${percentage.toStringAsFixed(1)}%'),
                trailing: Text(
                  '₹${entry.value.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(
    Map<String, double> categoryData,
    double total,
  ) {
    return categoryData.entries.map((entry) {
      final percentage = (entry.value / total * 100);
      return PieChartSectionData(
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%',
        color: _getCategoryColor(entry.key),
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Map<String, double> _calculateCategoryBreakdown(List<Expense> expenses) {
    final Map<String, double> categoryData = {};
    for (final expense in expenses) {
      categoryData[expense.category] =
          (categoryData[expense.category] ?? 0) + expense.amount;
    }
    // Sort by amount descending
    final sortedEntries = categoryData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sortedEntries);
  }

  FilterParams _buildFilterParams() {
    DateTime? startDate;
    DateTime? endDate;
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 'Today':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'This Week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'This Month':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'Custom':
        startDate = _customStartDate;
        endDate = _customEndDate;
        break;
    }

    return FilterParams(
      startDate: startDate,
      endDate: endDate,
      category: _selectedCategory,
      memberId: _selectedMember,
    );
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
    }
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
}
