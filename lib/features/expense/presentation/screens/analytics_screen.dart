import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../providers/expense_providers.dart';
import '../../domain/entities/expense.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/utils/currency_formatter.dart';

/// View Mode Enum
enum AnalyticsViewMode { insights, calendar }

/// Analytics Screen with Indian FinTech Minimalist Design
/// Features: Donut Chart, ChoiceChip filters, Pulse Check insight card, Calendar view, Oracle forecasting
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  // View mode
  AnalyticsViewMode _viewMode = AnalyticsViewMode.insights;

  // Filter states
  String _selectedPeriod = 'Month';
  String? _selectedCategory;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String _previousPeriodSelection = 'Month';

  // Calendar states
  late DateTime _focusedDay;
  late DateTime _selectedCalendarDate;
  
  // Month caching: {monthKey: expenses}
  // monthKey format: "2026-01" (YYYY-MM)
  final Map<String, List<Expense>> _monthCache = {};
  final Set<String> _loadingMonths = {};

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
  static const List<String> _periodOptions = [
    'Today',
    'Week',
    'Month',
    '3 Months',
    '6 Months',
    'Custom'
  ];

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedCalendarDate = DateTime.now();
  }

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

    return Scaffold(
      body: Column(
        children: [
          // View Mode Toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SegmentedButton<AnalyticsViewMode>(
              segments: const [
                ButtonSegment(
                  value: AnalyticsViewMode.insights,
                  label: Text('Insights'),
                  icon: Icon(Icons.show_chart),
                ),
                ButtonSegment(
                  value: AnalyticsViewMode.calendar,
                  label: Text('Calendar'),
                  icon: Icon(Icons.calendar_month),
                ),
              ],
              selected: {_viewMode},
              onSelectionChanged: (Set<AnalyticsViewMode> newSelection) {
                setState(() => _viewMode = newSelection.first);
              },
            ),
          ),
          // Content based on view mode
          Expanded(
            child: _viewMode == AnalyticsViewMode.insights
                ? _buildInsightsView(context, currentUser.id)
                : _buildCalendarView(context, currentUser.id),
          ),
        ],
      ),
    );
  }

  /// Build Insights View (Original Analytics with Oracle Card)
  Widget _buildInsightsView(BuildContext context, String userId) {
    final filterParams = _buildFilterParams(userId);
    final expensesAsync = ref.watch(filteredExpensesProvider(filterParams));
    
    // Fetch previous month data for comparison (Pulse Check)
    final previousFilterParams = buildPreviousMonthFilterParams(userId);
    final previousExpensesAsync = ref.watch(filteredExpensesProvider(previousFilterParams));

    return expensesAsync.when(
      data: (expenses) {
        return previousExpensesAsync.when(
          data: (previousExpenses) =>
              _buildInsightsContent(expenses, previousExpenses),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, stack) => _buildInsightsContent(expenses, []),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  /// Build Calendar View with TableCalendar
  Widget _buildCalendarView(BuildContext context, String userId) {
    return _buildCachedCalendarContent(context, userId);
  }

  /// Build Cached Calendar Content with Month-Based Lazy Loading
  Widget _buildCachedCalendarContent(BuildContext context, String userId) {
    // Get the key for the current focused month
    final monthKey = _getMonthKey(_focusedDay);

    // Always watch the stream so we can transition from loading → data → error
    // even if a rebuild happens mid-load.
    final startDate = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final endDate = DateTime(_focusedDay.year, _focusedDay.month + 1, 0, 23, 59, 59);

    final monthFilterParams = FilterParams(
      startDate: startDate,
      endDate: endDate,
      category: null,
      memberId: userId,
      type: 'personal',
    );

    final expensesAsync = ref.watch(filteredExpensesProvider(monthFilterParams));
    final cachedExpenses = _monthCache[monthKey];

    return expensesAsync.when(
      data: (expenses) {
        // Cache the result
        _monthCache[monthKey] = expenses;
        _loadingMonths.remove(monthKey);

        // Prefetch next and previous months in background
        _prefetchAdjacentMonths(userId);

        // Rebuild with cached data
        return _buildCalendarUI(context, expenses, userId);
      },
      loading: () {
        _loadingMonths.add(monthKey);
        // Show cached data (if any) while loading new data
        return _buildCalendarUI(
          context,
          cachedExpenses ?? const [],
          userId,
          isLoading: true,
        );
      },
      error: (error, stack) {
        // Cache empty result so the UI can render gracefully instead of
        // repeatedly re-fetching a missing month.
        _monthCache[monthKey] = cachedExpenses ?? const [];
        _loadingMonths.remove(monthKey);
        return _buildCalendarUI(
          context,
          cachedExpenses ?? const [],
          userId,
          isError: true,
        );
      },
    );
  }

  /// Get month key for caching (format: "2026-01")
  String _getMonthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  /// Build Insights Content
  Widget _buildInsightsContent(
    List<Expense> expenses,
    List<Expense> previousExpenses,
  ) {
    final totalAmount = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final previousTotal =
        previousExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final categoryData = _calculateCategoryBreakdown(expenses);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modern ChoiceChip Filter Bar
          _buildModernFilterBar(),

          const SizedBox(height: 16),

          // The Oracle (Forecasting Card) - only show for Month view
          if (_selectedPeriod == 'Month') ...[
            _buildOracleCard(totalAmount),
            const SizedBox(height: 16),
          ],

          // Pulse Check Insight Card (Compare with previous period)
          if (_selectedPeriod == 'Month')
            _buildPulseCheckCard(totalAmount, previousTotal),

          const SizedBox(height: 24),

          // Donut Chart with Center Text
          if (categoryData.isNotEmpty)
            _buildDonutChart(categoryData, totalAmount),

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

  /// Prefetch adjacent months in background
  void _prefetchAdjacentMonths(String userId) {
    final previousMonth = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
    final nextMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
    
    for (final month in [previousMonth, nextMonth]) {
      final key = _getMonthKey(month);
      if (!_monthCache.containsKey(key) && !_loadingMonths.contains(key)) {
        // Silently prefetch in background
        _loadingMonths.add(key);
        final startDate = DateTime(month.year, month.month, 1);
        final endDate = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
        
        final monthFilterParams = FilterParams(
          startDate: startDate,
          endDate: endDate,
          category: null,
          memberId: userId,
          type: 'personal',
        );
        
        ref.read(filteredExpensesProvider(monthFilterParams)).whenData((expenses) {
          _monthCache[key] = expenses;
          _loadingMonths.remove(key);
        });
      }
    }
  }

  /// Build Calendar UI (shared between cached and loading states)
  Widget _buildCalendarUI(
    BuildContext context,
    List<Expense> allExpenses,
    String userId, {
    bool isLoading = false,
    bool isError = false,
  }) {
    final selectedDayExpenses = _getExpensesForDate(allExpenses, _selectedCalendarDate);
    final dailyTotal = selectedDayExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);

    return Column(
      children: [
        // TableCalendar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              TableCalendar(
                firstDay: DateTime(2020),
                lastDay: DateTime.now(),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedCalendarDate, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedCalendarDate = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedDay = focusedDay;
                  });
                  // Trigger loading of new month (will use cache if available)
                },
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.monday,
                eventLoader: (day) {
                  return _getExpensesForDate(allExpenses, day);
                },
                headerStyle: HeaderStyle(
                  formatButtonDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  formatButtonTextStyle: GoogleFonts.lato(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  titleCentered: true,
                  titleTextStyle: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: GoogleFonts.lato(fontWeight: FontWeight.w500),
                  weekendStyle: GoogleFonts.lato(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  markersMaxCount: 1,
                  cellMargin: const EdgeInsets.all(4),
                  cellPadding: const EdgeInsets.all(8),
                ),
                rowHeight: 60,
              ),
              // Loading overlay for month
              if (isLoading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (isError)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                'Couldn\'t load this month. Showing cached data if available.',
                style: GoogleFonts.lato(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
            ),
          ),

        // Day Details Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${DateFormat('EEE, MMM d').format(_selectedCalendarDate)} • Total: ${CurrencyFormatter.format(dailyTotal)}',
                style: GoogleFonts.lato(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Day Expenses List
        Expanded(
          child: selectedDayExpenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.done_all,
                        size: 48,
                        color: Colors.green.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No spending on this day! 🎉',
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: selectedDayExpenses.length,
                  itemBuilder: (context, index) {
                    final expense = selectedDayExpenses[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(expense.category)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _getCategoryIcon(expense.category),
                              color: _getCategoryColor(expense.category),
                              size: 24,
                            ),
                          ),
                          title: Text(
                            expense.description,
                            style: GoogleFonts.lato(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            expense.category,
                            style: GoogleFonts.lato(color: Colors.grey.shade600),
                          ),
                          trailing: Text(
                            CurrencyFormatter.format(expense.amount),
                            style: GoogleFonts.lato(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// The Oracle: Forecasting Card
  Widget _buildOracleCard(double currentTotal) {
    final now = DateTime.now();
    final daysPassed = now.day;
    final totalDaysInMonth =
        DateTime(now.year, now.month + 1, 0).day;
    final dailyAvg = daysPassed > 0 ? (currentTotal / daysPassed) : 0.0;
    final projectedTotal = dailyAvg * totalDaysInMonth;

    // Get previous month total for comparison (using current user context)
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.value;
    
    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    final previousExpensesStream = ref.watch(
      filteredExpensesProvider(buildPreviousMonthFilterParams(currentUser.id)),
    );

    return previousExpensesStream.when(
      data: (previousExpenses) {
        final previousTotal = previousExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
        final isExceeding = projectedTotal > previousTotal;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade50,
                Colors.purple.shade50,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.blue.shade200,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isExceeding
                      ? Colors.orange.shade200
                      : Colors.green.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isExceeding ? Icons.warning_rounded : Icons.check_circle,
                  color: isExceeding
                      ? Colors.orange.shade700
                      : Colors.green.shade700,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The Oracle',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        text: 'At this pace, you\'ll spend ',
                        style: GoogleFonts.lato(
                          fontSize: 15,
                          color: Colors.grey.shade800,
                        ),
                        children: [
                          TextSpan(
                            text: CurrencyFormatter.format(projectedTotal),
                            style: GoogleFonts.lato(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          TextSpan(
                            text: ' by month end.',
                            style: GoogleFonts.lato(fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
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
                final displayLabel = _getDisplayLabel();

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(period == 'Custom' ? displayLabel : period),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        if (period == 'Custom') {
                          _showCustomDateRangePicker();
                        } else {
                          setState(() {
                            _previousPeriodSelection = _selectedPeriod;
                            _selectedPeriod = period;
                            _customStartDate = null;
                            _customEndDate = null;
                          });
                        }
                      }
                    },
                    selectedColor: Theme.of(context).colorScheme.primary,
                    labelStyle: GoogleFonts.lato(
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
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
                    color: _selectedCategory == null
                        ? Colors.white
                        : Colors.grey.shade700,
                    fontWeight: _selectedCategory == null
                        ? FontWeight.w600
                        : FontWeight.w500,
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
                          _selectedCategory =
                              selected ? category : null;
                        });
                      },
                      selectedColor: Theme.of(context).colorScheme.primary,
                      labelStyle: GoogleFonts.lato(
                        color: isSelected
                            ? Colors.white
                            : Colors.grey.shade700,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
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

  /// Show Date Range Picker for Custom period
  Future<void> _showCustomDateRangePicker() async {
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
        _selectedPeriod = 'Custom';
      });
    } else {
      // Revert to previous selection if cancelled
      setState(() {
        _selectedPeriod = _previousPeriodSelection;
      });
    }
  }

  /// Get display label for period
  String _getDisplayLabel() {
    if (_selectedPeriod == 'Custom' &&
        _customStartDate != null &&
        _customEndDate != null) {
      final startFormat = DateFormat('MMM d').format(_customStartDate!);
      final endFormat = DateFormat('MMM d').format(_customEndDate!);
      return '$startFormat - $endFormat';
    }
    return 'Custom';
  }

  /// Get expenses for a specific date
  List<Expense> _getExpensesForDate(List<Expense> expenses, DateTime date) {
    return expenses
        .where((expense) =>
            expense.date.year == date.year &&
            expense.date.month == date.month &&
            expense.date.day == date.day)
        .toList();
  }

  /// Pulse Check Card: Compare with previous period
  Widget _buildPulseCheckCard(double currentTotal, double previousTotal) {
    final difference = currentTotal - previousTotal;
    final percentageChange = previousTotal > 0
        ? (difference / previousTotal * 100)
        : 0.0;
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
                    style: GoogleFonts.lato(
                        fontSize: 15, color: Colors.grey.shade800),
                    children: [
                      TextSpan(
                        text:
                            '${percentageChange.abs().toStringAsFixed(0)}% ${isLess ? 'less' : 'more'}',
                        style: GoogleFonts.lato(
                          fontWeight: FontWeight.w700,
                          color: isLess
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
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
                        sections: _buildDonutChartSections(
                            categoryData, totalAmount),
                        sectionsSpace: 2,
                        centerSpaceRadius: 70,
                        borderData: FlBorderData(show: false),
                      ),
                    ),
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
  Widget _buildCategoryListWithAds(
      Map<String, double> categoryData, double totalAmount) {
    final entries = categoryData.entries.toList();
    final widgets = <Widget>[];

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final percentage = (entry.value / totalAmount * 100);

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

  /// AdMob Placeholder
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
        radius: 55,
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
      if (!expense.isDeleted) {
        categoryData[expense.category] =
            (categoryData[expense.category] ?? 0) + expense.amount;
      }
    }
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
        // Go back to Monday of current week
        final daysToMonday = now.weekday - 1; // 0 for Monday, 6 for Sunday
        final weekStart = now.subtract(Duration(days: daysToMonday));
        startDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'Month':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case '3 Months':
        // Calculate start date 3 months ago
        final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
        startDate = DateTime(threeMonthsAgo.year, threeMonthsAgo.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case '6 Months':
        // Calculate start date 6 months ago
        final sixMonthsAgo = DateTime(now.year, now.month - 6, now.day);
        startDate = DateTime(sixMonthsAgo.year, sixMonthsAgo.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'Custom':
        // Safety check: ensure custom dates are set before querying
        if (_customStartDate != null && _customEndDate != null) {
          startDate = _customStartDate;
          endDate = _customEndDate;
        } else {
          // Fallback to Month if custom dates not set (shouldn't happen)
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        }
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
    final startDate =
        DateTime(previousMonth.year, previousMonth.month, 1);
    final endDate =
        DateTime(previousMonth.year, previousMonth.month + 1, 0, 23, 59, 59);

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
