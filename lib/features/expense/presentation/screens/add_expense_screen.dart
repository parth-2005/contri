import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/expense_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/member_provider.dart';
import '../../../dashboard/domain/entities/group.dart';
import '../../domain/entities/expense.dart';
import '../../../../core/utils/currency_formatter.dart';

enum SplitType { equal, custom, family }

/// Screen to add/edit an expense with split calculator
class AddExpenseScreen extends ConsumerStatefulWidget {
  final Group group;
  final Expense? expenseToEdit;

  const AddExpenseScreen({
    super.key,
    required this.group,
    this.expenseToEdit,
  });

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  
  String? _paidBy;
  SplitType _splitType = SplitType.equal;
  final Map<String, double> _customSplits = {};
  final Map<String, double> _memberShares = {}; // {userId: shareCount} for family split (e.g., 0.5 for child, 1 for adult)
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authStateProvider);
    final currentUser = authState.value;
    
    // Initialize custom splits and member shares
    for (final memberId in widget.group.members) {
      _customSplits[memberId] = 0.0;
      // Use defaultShares if available, otherwise default to 1
      _memberShares[memberId] = widget.group.defaultShares[memberId] ?? 1;
    }

    // If editing, populate fields with existing expense data
    if (widget.expenseToEdit != null) {
      _descriptionController.text = widget.expenseToEdit!.description;
      _amountController.text = widget.expenseToEdit!.amount.toString();
      _paidBy = widget.expenseToEdit!.paidBy;
      _customSplits.addAll(widget.expenseToEdit!.splitMap);
    } else {
      _paidBy = currentUser?.id ?? widget.group.members.first;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Map<String, double> _calculateSplitMap() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final Map<String, double> splitMap = {};

    switch (_splitType) {
      case SplitType.equal:
        final perPerson = amount / widget.group.members.length;
        for (final memberId in widget.group.members) {
          splitMap[memberId] = double.parse(perPerson.toStringAsFixed(2));
        }
        break;

      case SplitType.custom:
        splitMap.addAll(_customSplits);
        break;

      case SplitType.family:
        // Split based on family shares (defaultShares) - supports decimals (0.5 for child, 1 for adult)
        final totalShares = _memberShares.values.fold<double>(0.0, (sum, val) => sum + val);
        if (totalShares > 0) {
          for (final memberId in widget.group.members) {
            final shareCount = _memberShares[memberId] ?? 1.0;
            splitMap[memberId] = double.parse(((amount * shareCount) / totalShares).toStringAsFixed(2));
          }
        }
        break;
    }

    return splitMap;
  }

  bool _validateSplit() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final splitMap = _calculateSplitMap();
    final totalSplit = splitMap.values.fold<double>(0.0, (sum, val) => sum + val);

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

  Future<void> _addExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_validateSplit()) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(expenseRepositoryProvider);
      final splitMap = _calculateSplitMap();

      if (widget.expenseToEdit != null) {
        // Update existing expense
        await repository.updateExpense(
          groupId: widget.group.id,
          expenseId: widget.expenseToEdit!.id,
          description: _descriptionController.text.trim(),
          amount: double.parse(_amountController.text),
          paidBy: _paidBy!,
          splitMap: splitMap,
        );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense updated successfully!')),
          );
        }
      } else {
        // Create new expense
        await repository.createExpense(
          groupId: widget.group.id,
          description: _descriptionController.text.trim(),
          amount: double.parse(_amountController.text),
          paidBy: _paidBy!,
          splitMap: splitMap,
        );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense added successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final membersAsync = ref.watch(memberProfilesProvider(widget.group.members));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expenseToEdit != null ? 'Edit Expense' : 'Add Expense'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g., Groceries, Electricity Bill',
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

            // Amount
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: '0.00',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Paid By
            membersAsync.when(
              data: (members) {
                return DropdownButtonFormField<String>(
                  value: _paidBy,
                  decoration: const InputDecoration(
                    labelText: 'Paid By',
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: widget.group.members.map((memberId) {
                    final memberName = members.containsKey(memberId) 
                        ? members[memberId]!.name 
                        : memberId;
                    return DropdownMenuItem(
                      value: memberId,
                      child: Text(memberName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _paidBy = value);
                  },
                );
              },
              loading: () => const SizedBox(
                height: 60,
                child: Center(child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )),
              ),
              error: (_, __) => DropdownButtonFormField<String>(
                value: _paidBy,
                decoration: const InputDecoration(
                  labelText: 'Paid By',
                  prefixIcon: Icon(Icons.person),
                ),
                items: widget.group.members.map((memberId) {
                  return DropdownMenuItem(
                    value: memberId,
                    child: Text(memberId),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _paidBy = value);
                },
              ),
            ),
            const SizedBox(height: 24),

            // Split Type Selector
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
                  if (_splitType == SplitType.equal && amount > 0) {
                    final perPerson = amount / widget.group.members.length;
                    for (final memberId in widget.group.members) {
                      _customSplits[memberId] = double.parse(perPerson.toStringAsFixed(2));
                    }
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            // Split Details Card
            membersAsync.when(
              data: (members) {
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
                        ...widget.group.members.map((memberId) {
                          final split = _splitType == SplitType.equal
                              ? amount / widget.group.members.length
                              : _splitType == SplitType.family
                                  ? _calculateSplitMap()[memberId] ?? 0.0
                                  : _customSplits[memberId] ?? 0.0;
                          final memberName = members.containsKey(memberId)
                              ? members[memberId]!.name
                              : memberId;

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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(memberName),
                                      if (_splitType == SplitType.family)
                                        Text(
                                          'Share: ${(_memberShares[memberId] ?? 1.0).toStringAsFixed(1)}',
                                          style: Theme.of(context).textTheme.bodySmall,
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
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _customSplits[memberId] = double.tryParse(value) ?? 0.0;
                                        });
                                      },
                                    ),
                                  )
                                else if (_splitType == SplitType.family)
                                  SizedBox(
                                    width: 90,
                                    child: TextFormField(
                                      initialValue: (_memberShares[memberId] ?? 1.0).toString(),
                                      decoration: const InputDecoration(
                                        labelText: 'Share',
                                        isDense: true,
                                        hintText: '1 or 0.5',
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _memberShares[memberId] = double.tryParse(value) ?? 1.0;
                                        });
                                      },
                                    ),
                                  )
                                else
                                  Text(
                                    CurrencyFormatter.format(split),
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
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
              error: (_, __) {
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
                        ...widget.group.members.map((memberId) {
                          final split = _splitType == SplitType.equal
                              ? amount / widget.group.members.length
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(memberId),
                                      if (_splitType == SplitType.family)
                                        Text(
                                          'Share: ${(_memberShares[memberId] ?? 1.0).toStringAsFixed(1)}',
                                          style: Theme.of(context).textTheme.bodySmall,
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
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _customSplits[memberId] = double.tryParse(value) ?? 0.0;
                                        });
                                      },
                                    ),
                                  )
                                else if (_splitType == SplitType.family)
                                  SizedBox(
                                    width: 90,
                                    child: TextFormField(
                                      initialValue: (_memberShares[memberId] ?? 1.0).toString(),
                                      decoration: const InputDecoration(
                                        labelText: 'Share',
                                        isDense: true,
                                        hintText: '1 or 0.5',
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _memberShares[memberId] = double.tryParse(value) ?? 1.0;
                                        });
                                      },
                                    ),
                                  )
                                else
                                  Text(
                                    CurrencyFormatter.format(split),
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Add Button
            ElevatedButton(
              onPressed: _isLoading ? null : _addExpense,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add Expense'),
            ),
          ],
        ),
      ),
    );
  }
}
