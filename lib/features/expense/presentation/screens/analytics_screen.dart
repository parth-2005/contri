import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/expense_providers.dart';
import '../../domain/entities/expense.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/utils/currency_formatter.dart';

/// Analytics Screen with Indian FinTech Minimalist Design
/// Features: Donut Chart, ChoiceChip filters, Pulse Check insight card, AdMob prep
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  // Filter states
  String _selectedPeriod = 'Month';
  String? _selectedCategory;

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
  
  // Period options for ChoiceChip
  static const List<String> _periodOptions = ['Today', 'Week', 'Month'];

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.value;
    
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Analytics', style: GoogleFonts.lato())),
        body: const Center(child: Text('Sign in to view analytics')),
      );
    }

    final filterParams = _buildFilterParams(currentUser.id);
    final expensesAsync = ref.watch(filteredExpensesProvider(filterParams));
    
    // Fetch previous month data for comparison (Pulse Check)
    final previousFilterParams = buildPreviousMonthFilterParams(currentUser.id);
    final previousExpensesAsync = ref.watch(filteredExpensesProvider(previousFilterParams));

    return Scaffold(
      body: expensesAsync.when(
        data: (expenses) {
          return previousExpensesAsync.when(
            data: (previousExpenses) => _buildAnalyticsContent(expenses, previousExpenses),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, stack) => _buildAnalyticsContent(expenses, []), // Graceful fallback
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildAnalyticsContent(List<Expense> expenses, List<Expense> previousExpenses) {
    final totalAmount = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final previousTotal = previousExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final categoryData = _calculateCategoryBreakdown(expenses);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modern ChoiceChip Filter Bar
          _buildModernFilterBar(),
          
          const SizedBox(height: 16),
          
          // Pulse Check Insight Card (Compare with previous period)
          if (_selectedPeriod == 'Month')
            _buildPulseCheckCard(totalAmount, previousTotal),
          
          // Total Summary Card
          // _buildTotalSummaryCard(totalAmount, expenses.length),
          
          const SizedBox(height: 24),
          
          // Donut Chart with Center Text
          if (categoryData.isNotEmpty) _buildDonutChart(categoryData, totalAmount),
          
          const SizedBox(height: 24),
          
          // Category List with AdMob placeholders
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Spending Breakdown',
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          _buildCategoryListWithAds(categoryData, totalAmount),
          
          const SizedBox(height: 80), // Bottom spacing
        ],
      ),
    );
  }

  /// Modern ChoiceChip Filter Bar
  Widget _buildModernFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Filter with ChoiceChips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Time Period',
              style: GoogleFonts.lato(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _periodOptions.map((period) {
                final isSelected = _selectedPeriod == period;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(period),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedPeriod = period);
                      }
                    },
                    selectedColor: Theme.of(context).colorScheme.primary,
                    labelStyle: GoogleFonts.lato(
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Category Filter (Horizontal Scroll with chips)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Category',
              style: GoogleFonts.lato(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _selectedCategory == null,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = null);
                  },
                  selectedColor: Theme.of(context).colorScheme.primary,
                  labelStyle: GoogleFonts.lato(
                    color: _selectedCategory == null ? Colors.white : Colors.grey.shade700,
                    fontWeight: _selectedCategory == null ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                ..._categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = selected ? category : null;
                        });
                      },
                      selectedColor: Theme.of(context).colorScheme.primary,
                      labelStyle: GoogleFonts.lato(
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Pulse Check Card: Compare with previous period
  Widget _buildPulseCheckCard(double currentTotal, double previousTotal) {
    final difference = currentTotal - previousTotal;
    final percentageChange = previousTotal > 0 ? (difference / previousTotal * 100) : 0.0;
    final isLess = difference < 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLess 
            ? [Colors.green.shade50, Colors.green.shade100] 
            : [Colors.orange.shade50, Colors.orange.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLess ? Colors.green.shade200 : Colors.orange.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isLess ? Colors.green.shade200 : Colors.orange.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLess ? Icons.trending_down : Icons.trending_up,
              color: isLess ? Colors.green.shade700 : Colors.orange.shade700,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pulse Check',
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    text: 'You spent ',
                    style: GoogleFonts.lato(fontSize: 15, color: Colors.grey.shade800),
                    children: [
                      TextSpan(
                        text: '${percentageChange.abs().toStringAsFixed(0)}% ${isLess ? 'less' : 'more'}',
                        style: GoogleFonts.lato(
                          fontWeight: FontWeight.w700,
                          color: isLess ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                      const TextSpan(text: ' than last month'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Total Summary Card
  Widget _buildTotalSummaryCard(double totalAmount, int transactionCount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Total Spending',
            style: GoogleFonts.lato(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(totalAmount),
            style: GoogleFonts.lato(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$transactionCount transactions',
            style: GoogleFonts.lato(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  /// Donut Chart with Center Text
  Widget _buildDonutChart(Map<String, double> categoryData, double totalAmount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Category Distribution',
                style: GoogleFonts.lato(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sections: _buildDonutChartSections(categoryData, totalAmount),
                        sectionsSpace: 2,
                        centerSpaceRadius: 70, // Larger center for Donut effect
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                    // Center Text
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total',
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.format(totalAmount),
                          style: GoogleFonts.lato(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Category List with AdMob Placeholders (every 7th item)
  Widget _buildCategoryListWithAds(Map<String, double> categoryData, double totalAmount) {
    final entries = categoryData.entries.toList();
    final widgets = <Widget>[];
    
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final percentage = (entry.value / totalAmount * 100);
      
      // Insert AdMob placeholder every 7th item
      if (i > 0 && i % 7 == 0) {
        widgets.add(_buildAdPlaceholder());
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  /// AdMob Placeholder (will be replaced with actual ad banner later)
  Widget _buildAdPlaceholder() {
    return Container(
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
    );
  }

  List<PieChartSectionData> _buildDonutChartSections(
    Map<String, double> categoryData,
    double total,
  ) {
    return categoryData.entries.map((entry) {
      final percentage = (entry.value / total * 100);
      return PieChartSectionData(
        value: entry.value,
        title: '${percentage.toStringAsFixed(0)}%',
        color: _getCategoryColor(entry.key),
        radius: 55, // Thickness of donut ring
        titleStyle: GoogleFonts.lato(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Map<String, double> _calculateCategoryBreakdown(List<Expense> expenses) {
    final Map<String, double> categoryData = {};
    for (final expense in expenses) {
      if (!expense.isDeleted) { // Respect soft delete
        categoryData[expense.category] =
            (categoryData[expense.category] ?? 0) + expense.amount;
      }
    }
    // Sort by amount descending
    final sortedEntries = categoryData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sortedEntries);
  }

  FilterParams _buildFilterParams(String userId) {
    DateTime? startDate;
    DateTime? endDate;
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 'Today':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'Week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'Month':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
    }

    return FilterParams(
      startDate: startDate,
      endDate: endDate,
      category: _selectedCategory,
      memberId: userId,
      type: 'personal',
    );
  }

  FilterParams buildPreviousMonthFilterParams(String userId) {
    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1, 1);
    final startDate = DateTime(previousMonth.year, previousMonth.month, 1);
    final endDate = DateTime(previousMonth.year, previousMonth.month + 1, 0, 23, 59, 59);

    return FilterParams(
      startDate: startDate,
      endDate: endDate,
      category: _selectedCategory,
      memberId: userId,
      type: 'personal',
    );
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
