import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/expense_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/member_provider.dart';
import '../../../dashboard/domain/entities/group.dart';
import '../../domain/entities/expense.dart';
import '../../../../core/utils/currency_formatter.dart';

enum SplitType { equal, custom, family }

/// Unified screen to add/edit any expense (personal, family, or group)
/// - For personal/family: group is null, simple form without split calculator
/// - For group: group is provided, full split calculator UI
class AddExpenseScreen extends ConsumerStatefulWidget {
  final Group? group; // Optional: null for personal/family expenses
  final Expense? expenseToEdit;

  const AddExpenseScreen({super.key, this.group, this.expenseToEdit});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  final NumberFormat _amountFormat = NumberFormat.decimalPattern('en_IN');
  String? _paidBy;
  DateTime _selectedDate = DateTime.now();
  SplitType _splitType = SplitType.equal;
  final Map<String, double> _customSplits = {};
  final Map<String, double> _memberShares =
      {}; // {userId: shareCount} for family split
  bool _isLoading = false;

  // Personal expense fields
  String _selectedCategory = 'Other';
  String? _selectedMemberId; // Optional attribution (e.g., for family member)

  // Predefined categories
  static const List<Map<String, dynamic>> _categories = [
    {'name': 'Grocery', 'icon': Icons.shopping_cart},
    {'name': 'Fuel', 'icon': Icons.local_gas_station},
    {'name': 'EMI', 'icon': Icons.account_balance},
    {'name': 'School', 'icon': Icons.school},
    {'name': 'Shopping', 'icon': Icons.shopping_bag},
    {'name': 'Dine-out', 'icon': Icons.restaurant},
    {'name': 'Healthcare', 'icon': Icons.medical_services},
    {'name': 'Entertainment', 'icon': Icons.movie},
    {'name': 'Travel', 'icon': Icons.flight},
    {'name': 'Utilities', 'icon': Icons.bolt},
    {'name': 'Other', 'icon': Icons.more_horiz},
  ];
  
  // Smart Description Parsing: Keyword map for auto-category selection
  static const Map<String, List<String>> _categoryKeywords = {
    'Travel': ['uber', 'ola', 'rapido', 'taxi', 'cab', 'flight', 'train', 'bus'],
    'Dine-out': ['zomato', 'swiggy', 'tea', 'coffee', 'restaurant', 'food', 'dinner', 'lunch', 'breakfast'],
    'Grocery': ['supermarket', 'dmart', 'reliance', 'fresh', 'vegetables', 'fruits'],
    'Fuel': ['petrol', 'diesel', 'gas', 'fuel'],
    'Entertainment': ['movie', 'cinema', 'netflix', 'prime', 'spotify', 'game'],
    'Healthcare': ['pharmacy', 'medicine', 'doctor', 'hospital', 'clinic'],
    'Utilities': ['electricity', 'water', 'internet', 'wifi', 'mobile', 'recharge'],
  };

  bool get _isPersonalOrFamily => widget.group == null;
  bool get _isGroupExpense => widget.group != null;
  
  /// Smart Description Parsing: Auto-select category based on keywords
  void _onDescriptionChanged() {
    final description = _descriptionController.text.toLowerCase().trim();
    if (description.isEmpty) return;
    
    // Check each category's keywords
    for (final entry in _categoryKeywords.entries) {
      final category = entry.key;
      final keywords = entry.value;
      
      // If any keyword matches, auto-select that category
      for (final keyword in keywords) {
        if (description.contains(keyword)) {
          if (_selectedCategory != category) {
            setState(() {
              _selectedCategory = category;
            });
          }
          return; // Stop after first match
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authStateProvider);
    final currentUser = authState.value;

    // Smart Description Parsing: Listen to description changes
    _descriptionController.addListener(_onDescriptionChanged);

    // Initialize for group expenses
    // Audit 3: Null safety - safe access instead of force unwrap
    final group = widget.group;
    if (group != null) {
      for (final memberId in group.members) {
        _customSplits[memberId] = 0.0;
        _memberShares[memberId] = group.defaultShares[memberId] ?? 1;
      }
    }

    // If editing, populate fields with existing expense data
    if (widget.expenseToEdit != null) {
      final expense = widget.expenseToEdit!;
      _selectedCategory = expense.category;
      _selectedMemberId = expense.attributedMemberId;
      _descriptionController.text = expense.description;
      _amountController.text = _formatAmount(expense.amount.toStringAsFixed(2));
      _paidBy = expense.paidBy;
      _selectedDate = expense.date;

      // Only handle split details for group expenses
      if (_isGroupExpense) {
        _customSplits.addAll(expense.split);

        // Prefer stored splitType/familyShares when available
        // Audit 3: Null safety - safe null check
        final expenseSplitType = expense.splitType;
        if (expenseSplitType != null) {
          switch (expenseSplitType) {
            case 'equal':
              _splitType = SplitType.equal;
              break;
            case 'family':
              _splitType = SplitType.family;
              break;
            case 'custom':
            default:
              _splitType = SplitType.custom;
              break;
          }
        } else {
          // Fallback: detect split type
          _splitType = _detectSplitType(expense);
        }

        // Populate member shares if stored, else reverse-engineer
        if (_splitType == SplitType.family) {
          // Audit 3: Null safety - safe null check
          final familyShares = expense.familyShares;
          if (familyShares != null && familyShares.isNotEmpty) {
            _memberShares
              ..clear()
              ..addAll(familyShares);
          } else {
            _calculateMemberSharesFromSplitMap(
              expense.amount,
              expense.split,
            );
          }
        }
      }
    } else {
      _paidBy =
          currentUser?.id ?? (widget.group?.members.first ?? currentUser?.id);
    }
  }

  /// Detect which split type was used for an expense
  SplitType _detectSplitType(Expense expense) {
    // Audit 3: Null safety - safe access with early return
    final group = widget.group;
    if (group == null) {
      return SplitType.equal; // Fallback for personal expenses
    }

    final amount = expense.amount;
    final splitMap = expense.split;

    // Check if it's an equal split
    final memberCount = group.members.length;
    // Audit 2: Division safety - prevent division by zero
    if (memberCount == 0) {
      return SplitType.equal;
    }
    final equalAmount = amount / memberCount;
    final isEqual = splitMap.values.every(
      (split) => (split - equalAmount).abs() < 0.01,
    );
    if (isEqual) return SplitType.equal;

    // Check if it's a family split (proportional to default shares)
    // Audit 3: Null safety - safe access
    final totalDefaultShares = group.defaultShares.values.fold<double>(
      0.0,
      (sum, share) => sum + share,
    );

    // Audit 2: Division safety - prevent division by zero
    if (totalDefaultShares > 0) {
      final isFamilySplit = splitMap.entries.every((entry) {
        final memberId = entry.key;
        final actualSplit = entry.value;
        // Audit 3: Null safety - safe access
        final defaultShare = group.defaultShares[memberId] ?? 1.0;
        final expectedSplit = (amount * defaultShare) / totalDefaultShares;
        return (actualSplit - expectedSplit).abs() < 0.01;
      });

      if (isFamilySplit) return SplitType.family;
    }

    // Otherwise, it's custom
    return SplitType.custom;
  }

  /// Calculate member shares from split map (for family split editing)
  void _calculateMemberSharesFromSplitMap(
    double amount,
    Map<String, double> splitMap,
  ) {
    // Audit 2: Division safety - prevent division by zero
    if (amount == 0) return;

    // Find the total of all splits
    final totalSplit = splitMap.values.fold<double>(
      0.0,
      (sum, val) => sum + val,
    );
    // Audit 2: Division safety - prevent division by zero
    if (totalSplit == 0) return;

    // Calculate what share each member must have had
    // Formula: share = (split / amount) * totalShares
    // We need to find totalShares first
    // Let's use the first member as reference: share1 = (split1 / amount) * totalShares
    // We can normalize assuming the smallest split represents 0.5 or 1 share

    final splits = splitMap.entries.toList();
    if (splits.isEmpty) return;

    // Find minimum split (this will be our base unit)
    final minSplit = splits.map((e) => e.value).reduce((a, b) => a < b ? a : b);
    // Audit 2: Division safety - prevent division by zero
    if (minSplit == 0) return;

    // Calculate shares relative to minimum
    for (final entry in splits) {
      final memberId = entry.key;
      final split = entry.value;
      // Calculate the share ratio
      final shareRatio = split / minSplit;
      _memberShares[memberId] = double.parse(shareRatio.toStringAsFixed(2));
    }
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_onDescriptionChanged);
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  double _parseAmountText(String value) {
    final sanitized = value.replaceAll(',', '');
    return double.tryParse(sanitized) ?? 0.0;
  }
  
  /// Sticky Date Feature: Ask if user wants to add another expense
  void _showAddAnotherDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Expense Added!',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        content: const Text('Do you want to add another expense?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close expense screen
            },
            child: const Text('No, Done'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Reset form but keep date and category for batch entry
              _resetFormForBatchEntry();
            },
            child: const Text('Add Another'),
          ),
        ],
      ),
    );
  }
  
  /// Reset form fields but preserve date for batch entry (Sticky Date)
  void _resetFormForBatchEntry() {
    setState(() {
      _descriptionController.clear();
      _amountController.clear();
      // Keep _selectedDate unchanged (Sticky Date)
      // Keep _selectedCategory unchanged (helps with similar expenses)
      // Reset split fields for group expenses
      if (_isGroupExpense) {
        _splitType = SplitType.equal;
        // Audit 3: Null safety - safe access
        final group = widget.group;
        if (group != null) {
          for (final memberId in group.members) {
            _customSplits[memberId] = 0.0;
            _memberShares[memberId] = group.defaultShares[memberId] ?? 1;
          }
        }
      }
    });
  }

  double _parseAmount() => _parseAmountText(_amountController.text);

  String _formatAmount(String value) {
    final cleaned = value.replaceAll(',', '');
    if (cleaned.isEmpty) return '';

    final parts = cleaned.split('.');
    final integerPart = parts.first.replaceAll(RegExp(r'[^0-9]'), '');
    final decimalsRaw = parts.length > 1
        ? parts[1].replaceAll(RegExp(r'[^0-9]'), '')
        : '';

    if (integerPart.isEmpty && decimalsRaw.isEmpty) return '';

    final integerValue = int.tryParse(integerPart) ?? 0;
    final formattedInt = _amountFormat.format(integerValue);
    final decimals = decimalsRaw.isEmpty
        ? ''
        : '.${decimalsRaw.substring(0, min(2, decimalsRaw.length))}';

    if (formattedInt == '0' && decimals.isEmpty) return '';

    return '$formattedInt$decimals';
  }

  void _handleAmountChanged(String value) {
    // Prevent manual editing when in custom split mode
    if (_splitType == SplitType.custom) {
      // Reset to previous value
      _amountController.clear();
      setState(() {});
      return;
    }

    final formatted = _formatAmount(value);
    if (formatted != value) {
      _amountController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    setState(() {});
  }

  /// Calculate total from custom splits
  double _calculateCustomSplitTotal() {
    return _customSplits.values.fold<double>(0.0, (sum, val) => sum + val);
  }

  /// Update amount field based on custom splits
  void _updateAmountFromCustomSplits() {
    final total = _calculateCustomSplitTotal();
    final formatted = total > 0 ? _formatAmount(total.toStringAsFixed(2)) : '';
    _amountController.text = formatted;
    setState(() {});
  }

  Map<String, double> _calculateSplitMap() {
    if (widget.group == null) {
      return {}; // Should not be called for personal expenses
    }

    final amount = _parseAmount();
    final Map<String, double> splitMap = {};

    switch (_splitType) {
      case SplitType.equal:
        // Audit 2: Division safety - prevent division by zero
        // Audit 3: Null safety - safe access with null check
        final group = widget.group;
        if (group == null || group.members.isEmpty) {
          break;
        }
        final perPerson = amount / group.members.length;
        for (final memberId in group.members) {
          splitMap[memberId] = double.parse(perPerson.toStringAsFixed(2));
        }
        break;

      case SplitType.custom:
        splitMap.addAll(_customSplits);
        break;

      case SplitType.family:
        // Split based on family shares (defaultShares) - supports decimals (0.5 for child, 1 for adult)
        // Audit 2: Division safety - prevent division by zero
        final totalShares = _memberShares.values.fold<double>(
          0.0,
          (sum, val) => sum + val,
        );
        // Audit 3: Null safety - safe access with null check
        final group = widget.group;
        if (totalShares > 0 && group != null) {
          for (final memberId in group.members) {
            final shareCount = _memberShares[memberId] ?? 1.0;
            splitMap[memberId] = double.parse(
              ((amount * shareCount) / totalShares).toStringAsFixed(2),
            );
          }
        }
        break;
    }

    return splitMap;
  }

  bool _validateSplit() {
    final amount = _parseAmount();
    final splitMap = _calculateSplitMap();
    final totalSplit = splitMap.values.fold<double>(
      0.0,
      (sum, val) => sum + val,
    );

    if ((totalSplit - amount).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Split total (${CurrencyFormatter.format(totalSplit)}) doesn\'t match amount (${CurrencyFormatter.format(amount)})',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    return true;
  }

  String _splitTypeString() {
    switch (_splitType) {
      case SplitType.equal:
        return 'equal';
      case SplitType.family:
        return 'family';
      case SplitType.custom:
        return 'custom';
    }
  }

  Map<String, double>? _familySharesForPersistence() {
    if (_splitType != SplitType.family) return null;
    // Persist the exact shares entered for family split
    return Map<String, double>.from(_memberShares);
  }

  Future<void> _addExpense() async {
    final amountValue = _parseAmount();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Only validate split for group expenses
    if (_isGroupExpense && !_validateSplit()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(expenseRepositoryProvider);
      final authState = ref.read(authStateProvider);
      final currentUser = authState.value;

      // For personal expenses: simple split (user pays and owes themselves)
      // For group expenses: use calculated split map
      // Audit 3: Null safety - safe null access
      final currentUserId = currentUser?.id;
      final splitMap = _isPersonalOrFamily
          ? (currentUserId != null ? {currentUserId: amountValue} : <String, double>{})
          : _calculateSplitMap();

      // For personal: groupId is null
      // For group expenses: use widget.group.id
      final groupId = _isPersonalOrFamily ? null : widget.group?.id;
      
      // Auto-determine expense type based on context
      final expenseType = _isPersonalOrFamily ? 'personal' : 'group';

      // Audit 3: Null safety - safe null access with fallback
      final paidById = _isPersonalOrFamily 
          ? (currentUserId ?? '') 
          : (_paidBy ?? currentUserId ?? '');

      if (widget.expenseToEdit != null) {
        // Update existing expense
        // Audit 3: Null safety - safe null access
        final expenseId = widget.expenseToEdit!.id;
        await repository.updateExpense(
          groupId: groupId,
          expenseId: expenseId,
          description: _descriptionController.text.trim(),
          amount: amountValue,
          paidBy: paidById,
          split: splitMap,
          splitType: _isGroupExpense ? _splitTypeString() : null,
          familyShares: _isGroupExpense ? _familySharesForPersistence() : null,
          category: _selectedCategory,
          type: expenseType,
          attributedMemberId: _selectedMemberId,
          date: _selectedDate,
        );
        // Audit 5: Async safety - check mounted before using context
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense updated successfully!')),
        );
      } else {
        // Create new expense
        await repository.createExpense(
          groupId: groupId,
          description: _descriptionController.text.trim(),
          amount: amountValue,
          paidBy: paidById,
          split: splitMap,
          splitType: _isGroupExpense ? _splitTypeString() : null,
          familyShares: _isGroupExpense ? _familySharesForPersistence() : null,
          category: _selectedCategory,
          type: expenseType,
          attributedMemberId: _selectedMemberId,
          date: _selectedDate,
        );
        // Audit 5: Async safety - check mounted before using context
        if (!mounted) return;
        // Sticky Date: Show dialog asking if user wants to add another expense
        _showAddAnotherDialog();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense added successfully!')),
        );
      }
    } catch (e) {
      // Audit 5: Async safety - check mounted before using context
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      // Audit 5: Async safety - check mounted before setState
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = _parseAmount();
    // Audit 3: Null safety - safe access instead of force unwrap
    final group = widget.group;
    final membersAsync = _isGroupExpense && group != null
        ? ref.watch(memberProfilesProvider(group.members))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.expenseToEdit != null ? 'Edit Expense' : 'Add Expense',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Amount (calculator display)
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Amount',
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '₹',
                        style: GoogleFonts.lato(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _amountController,
                          textAlign: TextAlign.center,
                          readOnly: _splitType == SplitType.custom,
                          style: GoogleFonts.lato(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: _splitType == SplitType.custom
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.5)
                                : Theme.of(context).colorScheme.primary,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: '0.00',
                            hintStyle: GoogleFonts.lato(
                              fontSize: 42,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.3),
                            ),
                            contentPadding: EdgeInsets.zero,
                            suffixIcon: _splitType == SplitType.custom
                                ? Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Icon(
                                      Icons.lock,
                                      size: 20,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.5),
                                    ),
                                  )
                                : null,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                          validator: (value) {
                            final parsed = _parseAmountText(value ?? '');
                            if (parsed <= 0) {
                              return 'Please enter an amount';
                            }
                            return null;
                          },
                          onChanged: _handleAmountChanged,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Description
            Text(
              'Description',
              style: GoogleFonts.lato(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descriptionController,
              style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'e.g., Groceries, Electricity Bill',
                hintStyle: GoogleFonts.lato(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
                prefixIcon: const Icon(Icons.description_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Category Selector (now for all expense types, including group)
            const Text(
              'Category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category['name'];
                  return GestureDetector(
                    onTap: () => setState(
                      () => _selectedCategory = category['name'] as String,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.secondary,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              )
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            category['icon'] as IconData,
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSecondary,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            category['name'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Member Attribution (optional - for personal expenses)
            if (_isPersonalOrFamily) ...[
              const Text(
                'Attributed To (Optional)',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _selectedMemberId,
                decoration: const InputDecoration(
                  labelText: 'Member Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                  hintText: 'e.g., Dad, Mom, Child 1',
                ),
                onChanged: (value) => _selectedMemberId = value.trim(),
              ),
              const SizedBox(height: 20),
            ],

            // Date selector
            Text(
              'Expense Date',
              style: GoogleFonts.lato(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('MMM dd, yyyy').format(_selectedDate),
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Paid By chips (only for group expenses)
            if (_isGroupExpense) ...[
              Text(
                'Paid By',
                style: GoogleFonts.lato(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              if (membersAsync != null)
                membersAsync.when(
                  data: (members) {
                    // Audit 3: Null safety - safe access
                    final group = widget.group;
                    if (group == null) return const SizedBox.shrink();
                    return SizedBox(
                      height: 76,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final memberId = group.members[index];
                          final memberName =
                              members[memberId]?.name ?? memberId;
                          final isSelected = _paidBy == memberId;

                          return ChoiceChip(
                            label: Text(
                              memberName,
                              style: GoogleFonts.lato(
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade800,
                              ),
                            ),
                            avatar: CircleAvatar(
                              radius: 16,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.12),
                              child: Text(
                                memberName[0].toUpperCase(),
                                style: GoogleFonts.lato(
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (_) =>
                                setState(() => _paidBy = memberId),
                            selectedColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.12),
                            backgroundColor: Colors.white,
                            shape: StadiumBorder(
                              side: BorderSide(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade300,
                              ),
                            ),
                            elevation: isSelected ? 3 : 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          );
                        },
                        separatorBuilder: (_, idx) => const SizedBox(width: 10),
                        // Audit 3: Null safety - safe access
                        itemCount: group.members.length,
                      ),
                    );
                  },
                  loading: () => const SizedBox(
                    height: 72,
                    child: Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  error: (_, err) => Wrap(
                    spacing: 8,
                    // Audit 3: Null safety - safe access with fallback
                    children: (widget.group?.members ?? []).map((memberId) {
                      return ChoiceChip(
                        label: Text(
                          memberId,
                          style: GoogleFonts.lato(fontWeight: FontWeight.w600),
                        ),
                        selected: _paidBy == memberId,
                        onSelected: (_) => setState(() => _paidBy = memberId),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 24),
            ],

            // Split Type Selector (only for group expenses)
            if (_isGroupExpense) ...[
              Text(
                'Split Type',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<SplitType>(
                segments: const [
                  ButtonSegment(
                    value: SplitType.equal,
                    label: Text('Equal'),
                    icon: Icon(Icons.people),
                  ),
                  ButtonSegment(
                    value: SplitType.family,
                    label: Text('Family'),
                    icon: Icon(Icons.family_restroom),
                  ),
                  ButtonSegment(
                    value: SplitType.custom,
                    label: Text('Custom'),
                    icon: Icon(Icons.edit),
                  ),
                ],
                selected: {_splitType},
                onSelectionChanged: (Set<SplitType> newSelection) {
                  setState(() {
                    _splitType = newSelection.first;
                    // Audit 3: Null safety - safe access
                    // Audit 2: Division safety - check for empty members
                    final group = widget.group;
                    if (_splitType == SplitType.equal && amount > 0 && group != null && group.members.isNotEmpty) {
                      final perPerson = amount / group.members.length;
                      for (final memberId in group.members) {
                        _customSplits[memberId] = double.parse(
                          perPerson.toStringAsFixed(2),
                        );
                      }
                    }
                    // When switching to custom, clear amount field to be filled by custom splits
                    if (_splitType == SplitType.custom) {
                      _amountController.clear();
                    }
                  });
                },
              ),
              const SizedBox(height: 16),

              // Split Details Card
              if (membersAsync != null)
                membersAsync.when(
                  data: (members) {
                    // Audit 3: Null safety - safe access
                    final group = widget.group;
                    if (group == null) return const SizedBox.shrink();
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Split Details',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                if (amount > 0)
                                  Text(
                                    'Total: ${CurrencyFormatter.format(amount)}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                            const Divider(),
                            // Audit 3: Null safety - safe access to group members
                            ...group.members.map((memberId) {
                              // Audit 2: Division safety - check for empty members
                              final split = _splitType == SplitType.equal
                                  ? (group.members.isNotEmpty ? amount / group.members.length : 0.0)
                                  : _splitType == SplitType.family
                                  ? _calculateSplitMap()[memberId] ?? 0.0
                                  : _customSplits[memberId] ?? 0.0;
                              // Audit 3: Null safety - safe access with fallback
                              final memberName = members[memberId]?.name ?? memberId;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    child: Text(memberName[0].toUpperCase()),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(memberName),
                                        if (_splitType == SplitType.family)
                                          Text(
                                            'Share: ${(_memberShares[memberId] ?? 1.0).toStringAsFixed(1)}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (_splitType == SplitType.custom)
                                    SizedBox(
                                      width: 100,
                                      child: TextFormField(
                                        initialValue: split.toStringAsFixed(2),
                                        decoration: const InputDecoration(
                                          prefixText: '₹',
                                          isDense: true,
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d+\.?\d{0,2}'),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          setState(() {
                                            _customSplits[memberId] =
                                                double.tryParse(value) ?? 0.0;
                                          });
                                          // Auto-update main amount field
                                          _updateAmountFromCustomSplits();
                                        },
                                      ),
                                    )
                                  else if (_splitType == SplitType.family)
                                    SizedBox(
                                      width: 90,
                                      child: TextFormField(
                                        initialValue:
                                            (_memberShares[memberId] ?? 1.0)
                                                .toString(),
                                        decoration: const InputDecoration(
                                          labelText: 'Share',
                                          isDense: true,
                                          hintText: '1 or 0.5',
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d+\.?\d{0,2}'),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          setState(() {
                                            _memberShares[memberId] =
                                                double.tryParse(value) ?? 1.0;
                                          });
                                        },
                                      ),
                                    )
                                  else
                                    Text(
                                      CurrencyFormatter.format(split),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
                error: (_, err) {
                  // Audit 3: Null safety - safe access
                  final group = widget.group;
                  if (group == null) return const SizedBox.shrink();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Split Details',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              if (amount > 0)
                                Text(
                                  'Total: ${CurrencyFormatter.format(amount)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                          const Divider(),
                          // Audit 3: Null safety - safe access to group members
                          ...group.members.map((memberId) {
                            // Audit 2: Division safety - check for empty members
                            final split = _splitType == SplitType.equal
                                ? (group.members.isNotEmpty ? amount / group.members.length : 0.0)
                                : _splitType == SplitType.family
                                ? _calculateSplitMap()[memberId] ?? 0.0
                                : _customSplits[memberId] ?? 0.0;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    child: Text(memberId[0].toUpperCase()),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(memberId),
                                        if (_splitType == SplitType.family)
                                          Text(
                                            'Share: ${(_memberShares[memberId] ?? 1.0).toStringAsFixed(1)}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (_splitType == SplitType.custom)
                                    SizedBox(
                                      width: 100,
                                      child: TextFormField(
                                        initialValue: split.toStringAsFixed(2),
                                        decoration: const InputDecoration(
                                          prefixText: '₹',
                                          isDense: true,
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d+\.?\d{0,2}'),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          setState(() {
                                            _customSplits[memberId] =
                                                double.tryParse(value) ?? 0.0;
                                          });
                                          // Auto-update main amount field
                                          _updateAmountFromCustomSplits();
                                        },
                                      ),
                                    )
                                  else if (_splitType == SplitType.family)
                                    SizedBox(
                                      width: 90,
                                      child: TextFormField(
                                        initialValue:
                                            (_memberShares[memberId] ?? 1.0)
                                                .toString(),
                                        decoration: const InputDecoration(
                                          labelText: 'Share',
                                          isDense: true,
                                          hintText: '1 or 0.5',
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d+\.?\d{0,2}'),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          setState(() {
                                            _memberShares[memberId] =
                                                double.tryParse(value) ?? 1.0;
                                          });
                                        },
                                      ),
                                    )
                                  else
                                    Text(
                                      CurrencyFormatter.format(split),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ], // End of _isGroupExpense conditional
            // Add/Save Button (for all expense types)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _addExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.expenseToEdit != null
                            ? 'Update Expense'
                            : 'Add Expense',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
