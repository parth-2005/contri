import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../expense/domain/entities/expense.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../../core/utils/currency_formatter.dart';

/// Splitwise-style expense tile with expandable details
/// Features:
/// - Date box on the left (e.g., "OCT\n24")
/// - Description + "Paid by [Name]" in the center
/// - Color-coded status on the right (lent/owed/not involved)
/// - Expandable to show full breakdown
/// - Edit button in expanded view
class ExpenseTile extends StatefulWidget {
  final Expense expense;
  final Map<String, AppUser> members;
  final String? currentUserId;
  final VoidCallback onEdit;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.members,
    this.currentUserId,
    required this.onEdit,
  });

  @override
  State<ExpenseTile> createState() => _ExpenseTileState();
}

class _ExpenseTileState extends State<ExpenseTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final payer = widget.members[widget.expense.paidBy];
    final payerName = payer?.name ?? widget.expense.paidBy;
    final (status, amount, color) = _getUserExpenseStatus();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(
          color: _isExpanded 
              ? Theme.of(context).colorScheme.primary 
              : Colors.grey.shade200,
        ),
        borderRadius: BorderRadius.circular(12),
        color: _isExpanded 
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
            : Colors.white,
      ),
      child: Column(
        children: [
          // Main tile content
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  // Date Box (Left)
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('MMM').format(widget.expense.date).toUpperCase(),
                            style: GoogleFonts.lato(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            DateFormat('dd').format(widget.expense.date),
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Description + Payer (Center)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.expense.description,
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Paid by $payerName',
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Status + Amount (Right)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        status,
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        amount,
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),

                  // Expand indicator
                  Icon(
                    _isExpanded 
                        ? Icons.expand_less 
                        : Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total amount
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount',
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(widget.expense.amount),
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Date',
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        DateFormat('MMM dd, yyyy').format(widget.expense.date),
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Split breakdown
                  Text(
                    'Split Details',
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        ...widget.expense.splitMap.entries.map((entry) {
                          final member = widget.members[entry.key];
                          final memberName = member?.name ?? entry.key;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  memberName,
                                  style: GoogleFonts.lato(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(entry.value),
                                  style: GoogleFonts.lato(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Edit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: Text(
                        'Edit Expense',
                        style: GoogleFonts.lato(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: widget.onEdit,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Determine user's expense status and color
  /// Returns: (statusText, amountText, color)
  (String, String, Color) _getUserExpenseStatus() {
    if (widget.currentUserId == null) {
      return ('Not involved', '', Colors.grey.shade600);
    }

    final currentUserId = widget.currentUserId!;

    // User is the payer
    if (widget.expense.paidBy == currentUserId) {
      // Calculate how much others owe them
      double othersOwe = 0;
      for (final entry in widget.expense.splitMap.entries) {
        if (entry.key != currentUserId) {
          othersOwe += entry.value;
        }
      }

      if (othersOwe > 0) {
        return (
          'You lent',
          CurrencyFormatter.format(othersOwe),
          Colors.green.shade700,
        );
      } else {
        return (
          'You paid',
          CurrencyFormatter.format(widget.expense.amount),
          Colors.green.shade700,
        );
      }
    }

    // User owes someone
    if (widget.expense.splitMap.containsKey(currentUserId)) {
      final amount = widget.expense.splitMap[currentUserId]!;
      return (
        'You borrowed',
        CurrencyFormatter.format(amount),
        Colors.orange.shade700,
      );
    }

    // User not involved
    return (
      'Not involved',
      '',
      Colors.grey.shade600,
    );
  }
}
