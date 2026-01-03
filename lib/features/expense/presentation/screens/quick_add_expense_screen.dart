import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/expense_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/presentation/providers/group_providers.dart';

/// Quick Add Expense Screen for Personal/Family/Group expenses
class QuickAddExpenseScreen extends ConsumerStatefulWidget {
  const QuickAddExpenseScreen({super.key});

  @override
  ConsumerState<QuickAddExpenseScreen> createState() =>
      _QuickAddExpenseScreenState();
}

class _QuickAddExpenseScreenState
    extends ConsumerState<QuickAddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  String _expenseType = 'personal';
  String _selectedCategory = 'Other';
  String? _selectedGroupId;
  String? _selectedMemberId;
  bool _isLoading = false;

  // Predefined categories with icons
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

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authStateProvider);
    final currentUser = authState.value;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(expenseRepositoryProvider);
      final amount = double.parse(_amountController.text);

        // For personal expenses, groupId is null (unified model)
        final String? groupId = _expenseType == 'group' && _selectedGroupId != null
          ? _selectedGroupId!
          : null;

      await repository.createExpense(
        groupId: groupId,
        description: _descriptionController.text.trim(),
        amount: amount,
        paidBy: currentUser.id,
        split: {currentUser.id: amount}, // Personal: user pays and owes themselves
        category: _selectedCategory,
        type: _expenseType,
        attributedMemberId: _selectedMemberId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense added successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(userGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Expense Type Selector
              const Text(
                'Expense Type',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'personal',
                    label: Text('Personal'),
                    icon: Icon(Icons.person),
                  ),
                  ButtonSegment(
                    value: 'family',
                    label: Text('Family'),
                    icon: Icon(Icons.family_restroom),
                  ),
                  ButtonSegment(
                    value: 'group',
                    label: Text('Group'),
                    icon: Icon(Icons.group),
                  ),
                ],
                selected: {_expenseType},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _expenseType = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Description Field
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Amount Field
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Category Selector
              const Text(
                'Category',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: GridView.builder(
                  scrollDirection: Axis.horizontal,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.4,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = _selectedCategory == category['name'];

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = category['name'] as String;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
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
              const SizedBox(height: 24),

              // Group Selector (for group expenses)
              if (_expenseType == 'group')
                groupsAsync.when(
                  data: (groups) {
                    if (groups.isEmpty) {
                      return const Text(
                        'No groups available. Create a group first.',
                        style: TextStyle(color: Colors.orange),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      value: _selectedGroupId,
                      decoration: const InputDecoration(
                        labelText: 'Select Group',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.group),
                      ),
                      items: groups.map((group) {
                        return DropdownMenuItem(
                          value: group.id,
                          child: Text(group.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedGroupId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a group';
                        }
                        return null;
                      },
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (error, stack) => Text('Error loading groups: $error'),
                ),

              // Member Selector (for family expenses)
              if (_expenseType == 'family')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attributed To (Optional)',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Member Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                        hintText: 'e.g., Dad, Mom, Child 1',
                      ),
                      onChanged: (value) {
                        _selectedMemberId = value.trim();
                      },
                    ),
                  ],
                ),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveExpense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save Expense',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
