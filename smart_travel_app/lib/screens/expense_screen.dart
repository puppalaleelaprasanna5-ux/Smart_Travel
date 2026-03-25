import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../services/sms_expense_service.dart';
import '../services/travel_data_service.dart';

class ExpenseScreen extends StatefulWidget {
  final bool embedded;

  const ExpenseScreen({super.key, this.embedded = false});

  @override
  _ExpenseScreenState createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TravelDataService travelData = TravelDataService.instance;
  final SmsExpenseService smsExpenseService = SmsExpenseService();

  List<Expense> expenses = [];
  bool loading = false;
  bool addingExpense = false;
  bool importingSms = false;
  String selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    fetchExpenses();
    travelData.addListener(_handleTravelDataChanged);
  }

  @override
  void dispose() {
    travelData.removeListener(_handleTravelDataChanged);
    amountController.dispose();
    categoryController.dispose();
    noteController.dispose();
    dateController.dispose();
    super.dispose();
  }

  void _handleTravelDataChanged() {
    if (!mounted) return;
    setState(() {
      expenses = travelData.currentTripExpenses;
    });
  }

  Future<void> fetchExpenses() async {
    try {
      setState(() => loading = true);
      await travelData.initialize();
      setState(() {
        expenses = travelData.currentTripExpenses;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load expenses: $e')));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> addExpense() async {
    final amountText = amountController.text.trim();
    final category = categoryController.text.trim();
    final note = noteController.text.trim();
    final date = dateController.text.trim();

    if (amountText.isEmpty || category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount and category are required')),
      );
      return;
    }

    try {
      setState(() => addingExpense = true);
      final amount = double.parse(amountText);
      await travelData.addExpense(
        amount: amount,
        category: category,
        note: note,
        date: date.isEmpty ? DateTime.now().toIso8601String() : date,
      );

      if (!mounted) return;

      amountController.clear();
      categoryController.clear();
      noteController.clear();
      dateController.clear();

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense added successfully')),
      );

      await fetchExpenses();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => addingExpense = false);
      }
    }
  }

  Future<void> importFromSms() async {
    try {
      setState(() => importingSms = true);
      final result = kIsWeb
          ? null
          : await smsExpenseService.syncExpensesFromSms();
      final importedCount = kIsWeb
          ? await travelData.importDemoSmsExpenses()
          : result?.importedExpenses ?? 0;

      if (!mounted) return;

      if (!kIsWeb && result?.error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result!.error!)));
        return;
      }

      await fetchExpenses();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Imported $importedCount demo travel expenses from SMS.'
                : 'Imported $importedCount expenses from SMS.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SMS import failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => importingSms = false);
      }
    }
  }

  double get totalAmount {
    return expenses.fold<double>(0, (sum, expense) => sum + expense.amount);
  }

  double get remainingAmount => travelData.remainingBudget;

  int get spentPercent => (travelData.spentPercentage * 100).round();

  List<Expense> get filteredExpenses {
    if (selectedFilter == 'All') return expenses;
    return expenses.where((expense) {
      final value = expense.category.toLowerCase();
      switch (selectedFilter) {
        case 'Dining':
          return value.contains('food') ||
              value.contains('dining') ||
              value.contains('restaurant');
        case 'Stay':
          return value.contains('hotel') || value.contains('stay');
        case 'Transport':
          return value.contains('travel') ||
              value.contains('transport') ||
              value.contains('metro');
        default:
          return true;
      }
    }).toList();
  }

  String get insightText {
    return expenses.isEmpty
        ? 'Looks like your spending is more on dining today than usual. Consider exploring local markets for dinner.'
        : 'Looks like your spending is more on ${filteredExpenses.isEmpty ? expenses.first.category.toLowerCase() : filteredExpenses.first.category.toLowerCase()} today than usual. Consider exploring local markets for dinner.';
  }

  Color _categoryColor(String category) {
    final value = category.toLowerCase();
    if (value.contains('food') || value.contains('dining')) {
      return const Color(0xFF85E4C8);
    }
    if (value.contains('travel') || value.contains('transport')) {
      return const Color(0xFFB7D9FF);
    }
    if (value.contains('hotel') || value.contains('stay')) {
      return const Color(0xFFD9D3FF);
    }
    return const Color(0xFFE4E8EE);
  }

  IconData _categoryIcon(String category) {
    final value = category.toLowerCase();
    if (value.contains('food') || value.contains('dining')) {
      return Icons.restaurant_rounded;
    }
    if (value.contains('travel') || value.contains('transport')) {
      return Icons.train_rounded;
    }
    if (value.contains('hotel') || value.contains('stay')) {
      return Icons.hotel_rounded;
    }
    if (value.contains('shopping')) {
      return Icons.shopping_bag_rounded;
    }
    return Icons.receipt_long_rounded;
  }

  void _showAddExpenseSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Add Expense',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    hintText: 'YYYY-MM-DD',
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: addingExpense ? null : addExpense,
                    child: Text(addingExpense ? 'Adding...' : 'Add Expense'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label) {
    final active = selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = label;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0B5F8E) : const Color(0xFFF0F2F6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: active ? Colors.white : const Color(0xFF737B87),
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseTile(Expense expense, int index) {
    final amount = expense.amount.toStringAsFixed(2);
    final chipColor = _categoryColor(expense.category);
    final icon = _categoryIcon(expense.category);
    final timeText = expense.date.isNotEmpty
        ? expense.date.split('T').first
        : index == 0
            ? 'Today, 2:45 PM'
            : index == 1
                ? 'Today, 10:15 AM'
                : index == 2
                    ? 'Yesterday'
                    : 'Earlier';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F3F7),
              borderRadius: BorderRadius.circular(21),
            ),
            child: Icon(icon, color: const Color(0xFF2F5E7D)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.note.isEmpty ? expense.category : expense.note,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E2530),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeText,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black.withOpacity(0.45),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹$amount',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF243342),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  expense.category.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF29465B),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final visibleExpenses = filteredExpenses;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: fetchExpenses,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: const [
                        CircleAvatar(
                          radius: 8,
                          backgroundColor: Color(0xFFF3B09E),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'TravelPilot AI',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF355264),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: fetchExpenses,
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFF0F567F),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Total Spending',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black.withOpacity(0.45),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0B5F8E),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CurrencyChip('INR', true),
                  const SizedBox(width: 6),
                  _CurrencyChip('USD', false),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Remaining: ₹${remainingAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F252D),
                        ),
                      ),
                    ),
                    Text(
                      'Estimated: ₹${travelData.estimatedBudget.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0B5F8E),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$spentPercent% used',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black.withOpacity(0.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1977AB), Color(0xFF0C6B9D)],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI Spending Insight',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            insightText,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.82),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFD7FAF1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8BE6D3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.sms_rounded,
                        color: Color(0xFF0B5F6D),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'New transaction detected',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF27505E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            importingSms
                                ? 'Scanning messages...'
                                : 'Import your latest travel-related SMS transactions.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black.withOpacity(0.55),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 34,
                      child: ElevatedButton(
                        onPressed: importingSms ? null : importFromSms,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1EAF8D),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(importingSms ? '...' : 'Import SMS'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All'),
                    _buildFilterChip('Dining'),
                    _buildFilterChip('Stay'),
                    _buildFilterChip('Transport'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1F252D),
                    ),
                  ),
                  Text(
                    'View Reports',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4D87AA),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (visibleExpenses.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'No expenses found',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                ...visibleExpenses.asMap().entries.map(
                  (entry) => _buildExpenseTile(entry.value, entry.key),
                ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: _showAddExpenseSheet,
            backgroundColor: const Color(0xFF0B5F8E),
            foregroundColor: Colors.white,
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: const Text('Expenses')),
      body: SafeArea(child: _buildBody()),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  final String label;
  final bool active;

  const _CurrencyChip(this.label, this.active);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE9F4FA) : const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: active ? const Color(0xFF0B5F8E) : const Color(0xFF818B97),
        ),
      ),
    );
  }
}
