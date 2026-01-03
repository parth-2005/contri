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
  
  final NumberFormat _amountFormat = NumberFormat.decimalPattern('en_IN');
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
      _amountController.text = _formatAmount(widget.expenseToEdit!.amount.toStringAsFixed(2));
      _paidBy = widget.expenseToEdit!.paidBy;
      _customSplits.addAll(widget.expenseToEdit!.splitMap);
      
      // Prefer stored splitType/familyShares when available
      if (widget.expenseToEdit!.splitType != null) {
        switch (widget.expenseToEdit!.splitType) {
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
        _splitType = _detectSplitType(widget.expenseToEdit!);
      }

      // Populate member shares if stored, else reverse-engineer
      if (_splitType == SplitType.family) {
        if (widget.expenseToEdit!.familyShares != null && widget.expenseToEdit!.familyShares!.isNotEmpty) {
          _memberShares
            ..clear()
            ..addAll(widget.expenseToEdit!.familyShares!);
        } else {
          _calculateMemberSharesFromSplitMap(
            widget.expenseToEdit!.amount,
            widget.expenseToEdit!.splitMap,
          );
        }
      }
    } else {
      _paidBy = currentUser?.id ?? widget.group.members.first;
    }
  }

  /// Detect which split type was used for an expense
  SplitType _detectSplitType(Expense expense) {
    final amount = expense.amount;
    final splitMap = expense.splitMap;
    
    // Check if it's an equal split
    final memberCount = widget.group.members.length;
    final equalAmount = amount / memberCount;
    final isEqual = splitMap.values.every(
      (split) => (split - equalAmount).abs() < 0.01,
    );
    if (isEqual) return SplitType.equal;
    
    // Check if it's a family split (proportional to default shares)
    final totalDefaultShares = widget.group.defaultShares.values.fold<double>(
      0.0,
      (sum, share) => sum + share,
    );
    
    if (totalDefaultShares > 0) {
      final isFamilySplit = splitMap.entries.every((entry) {
        final memberId = entry.key;
        final actualSplit = entry.value;
        final defaultShare = widget.group.defaultShares[memberId] ?? 1.0;
        final expectedSplit = (amount * defaultShare) / totalDefaultShares;
        return (actualSplit - expectedSplit).abs() < 0.01;
      });
      
      if (isFamilySplit) return SplitType.family;
    }
    
    // Otherwise, it's custom
    return SplitType.custom;
  }

  /// Calculate member shares from split map (for family split editing)
  void _calculateMemberSharesFromSplitMap(double amount, Map<String, double> splitMap) {
    if (amount == 0) return;
    
    // Find the total of all splits
    final totalSplit = splitMap.values.fold<double>(0.0, (sum, val) => sum + val);
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
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  double _parseAmountText(String value) {
    final sanitized = value.replaceAll(',', '');
    return double.tryParse(sanitized) ?? 0.0;
  }

  double _parseAmount() => _parseAmountText(_amountController.text);

  String _formatAmount(String value) {
    final cleaned = value.replaceAll(',', '');
    if (cleaned.isEmpty) return '';

    final parts = cleaned.split('.');
    final integerPart = parts.first.replaceAll(RegExp(r'[^0-9]'), '');
    final decimalsRaw = parts.length > 1 ? parts[1].replaceAll(RegExp(r'[^0-9]'), '') : '';

    if (integerPart.isEmpty && decimalsRaw.isEmpty) return '';

    final integerValue = int.tryParse(integerPart) ?? 0;
    final formattedInt = _amountFormat.format(integerValue);
    final decimals = decimalsRaw.isEmpty ? '' : '.${decimalsRaw.substring(0, min(2, decimalsRaw.length))}';

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
    final amount = _parseAmount();
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
    final amount = _parseAmount();
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
          amount: amountValue,
          paidBy: _paidBy!,
          splitMap: splitMap,
          splitType: _splitTypeString(),
          familyShares: _familySharesForPersistence(),
          category: widget.expenseToEdit!.category,
          type: widget.expenseToEdit!.type,
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
          amount: amountValue,
          paidBy: _paidBy!,
          splitMap: splitMap,
          splitType: _splitTypeString(),
          familyShares: _familySharesForPersistence(),
          category: 'Other',
          type: 'group',
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
    final amount = _parseAmount();
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
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.35),
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
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                                : Theme.of(context).colorScheme.primary,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: '0.00',
                            hintStyle: GoogleFonts.lato(
                              fontSize: 42,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                            ),
                            contentPadding: EdgeInsets.zero,
                            suffixIcon: _splitType == SplitType.custom
                                ? Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Icon(
                                      Icons.lock,
                                      size: 20,
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                                    ),
                                  )
                                : null,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
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
                color: Theme.of(context).colorScheme.onBackground,
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

            // Paid By chips
            Text(
              'Paid By',
              style: GoogleFonts.lato(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            membersAsync.when(
              data: (members) {
                return SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final memberId = widget.group.members[index];
                      final memberName = members[memberId]?.name ?? memberId;
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
                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                          child: Text(
                            memberName[0].toUpperCase(),
                            style: GoogleFonts.lato(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _paidBy = memberId),
                        selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        backgroundColor: Colors.white,
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade300,
                          ),
                        ),
                        elevation: isSelected ? 3 : 0,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemCount: widget.group.members.length,
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
              error: (_, __) => Wrap(
                spacing: 8,
                children: widget.group.members.map((memberId) {
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
                  // When switching to custom, clear amount field to be filled by custom splits
                  if (_splitType == SplitType.custom) {
                    _amountController.clear();
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
                                        // Auto-update main amount field
                                        _updateAmountFromCustomSplits();
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
                                        // Auto-update main amount field
                                        _updateAmountFromCustomSplits();
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
