// lib/screens/budget_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/expense.dart';
import '../repositories/wedding_repository.dart';
import '../models/wedding_info.dart';
import '../services/budget_manager.dart';
import '../providers/subscription_provider.dart';
import '../widgets/subscription_offer_dialog.dart';
import 'package:uuid/uuid.dart';

class Logger {
  static void log(String message) {
    debugPrint("[LOG] $message");
  }
}

class BudgetSettingsWidget extends StatelessWidget {
  final double currentBudget;
  final Function(double) onBudgetChanged;

  const BudgetSettingsWidget({
    super.key,
    required this.currentBudget,
    required this.onBudgetChanged,
  });

  @override
  Widget build(BuildContext context) {
    final TextEditingController controller =
        TextEditingController(text: currentBudget.toStringAsFixed(2));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${tr('current_budget')}: ${currentBudget.toStringAsFixed(2)} ${tr('currency')}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '${tr('new_budget')} (${tr('currency')})',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final double newBudget =
                  double.tryParse(controller.text.trim()) ?? currentBudget;
              onBudgetChanged(newBudget);
              Navigator.pop(context);
            },
            child: Text(tr('save_settings')),
          ),
        ],
      ),
    );
  }
}

class AddExpenseForm extends StatefulWidget {
  final Function(Expense) onExpenseAdded;
  const AddExpenseForm({super.key, required this.onExpenseAdded});

  @override
  _AddExpenseFormState createState() => _AddExpenseFormState();
}

class _AddExpenseFormState extends State<AddExpenseForm> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _paidController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _paidController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submitExpense() {
    final String title = _titleController.text.trim();
    final String category = _categoryController.text.trim();
    final double paid = double.tryParse(_paidController.text.trim()) ?? 0;
    final String note = _noteController.text.trim();

    if (title.isNotEmpty) {
      final Expense newExpense = Expense(
        id: const Uuid().v4(),
        title: title,
        category: category.isNotEmpty ? category : tr('general_category'),
        amount: paid,
        note: note,
        isPaid: true,
        date: DateTime.now(),
      );

      widget.onExpenseAdded(newExpense);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('expense_name_required'),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          backgroundColor: Colors.red,
        ),
      );
      Logger.log("Neplatné údaje při přidávání výdaje.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle pro táhnutí
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Text(
                  tr('add_expense'),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: '${tr('expense_name')} *',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _categoryController,
                  decoration: InputDecoration(
                    labelText: tr('category'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _paidController,
                  decoration: InputDecoration(
                    labelText: '${tr('amount')} (${tr('currency')}) *',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: tr('note'),
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    '* ${tr('required_fields')}',
                    style: const TextStyle(
                        fontStyle: FontStyle.italic, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _submitExpense,
                  child: Text(tr('add_expense')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EditExpenseForm extends StatefulWidget {
  final Expense expense;
  final Function(Expense) onExpenseUpdated;
  const EditExpenseForm(
      {super.key, required this.expense, required this.onExpenseUpdated});

  @override
  _EditExpenseFormState createState() => _EditExpenseFormState();
}

class _EditExpenseFormState extends State<EditExpenseForm> {
  late TextEditingController _titleController;
  late TextEditingController _categoryController;
  late TextEditingController _paidController;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.expense.title);
    _categoryController = TextEditingController(text: widget.expense.category);
    _paidController =
        TextEditingController(text: widget.expense.amount.toString());
    _noteController = TextEditingController(text: widget.expense.note);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _paidController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _updateExpense() {
    final String title = _titleController.text.trim();
    final String category = _categoryController.text.trim();
    final double paid = double.tryParse(_paidController.text.trim()) ?? 0;
    final String note = _noteController.text.trim();

    if (title.isNotEmpty) {
      final Expense updatedExpense = widget.expense.copyWith(
        title: title,
        category: category.isNotEmpty ? category : tr('general_category'),
        amount: paid,
        note: note,
        isPaid: true,
        updatedAt: DateTime.now(),
      );

      widget.onExpenseUpdated(updatedExpense);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('expense_name_required'),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          backgroundColor: Colors.red,
        ),
      );
      Logger.log("Neplatné údaje při aktualizaci výdaje.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle pro táhnutí
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Text(
                  tr('edit_expense'),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: '${tr('expense_name')} *',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _categoryController,
                  decoration: InputDecoration(
                    labelText: tr('category'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _paidController,
                  decoration: InputDecoration(
                    labelText: '${tr('amount')} (${tr('currency')}) *',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: tr('note'),
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    '* ${tr('required_fields')}',
                    style: const TextStyle(
                        fontStyle: FontStyle.italic, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _updateExpense,
                  child: Text(tr('save')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  double totalBudget = 250000;
  StreamSubscription<WeddingInfo?>? _weddingSubscription;
  late WeddingRepository _weddingRepository;

  String? yourName;
  String? partnerName;

  bool _isLoading = true;
  bool _isUpdatingFromCloud = false;
  WeddingInfo? _weddingInfo;

  @override
  void initState() {
    super.initState();
    Logger.log("Inicializace BudgetScreen");

    _weddingRepository = Provider.of<WeddingRepository>(context, listen: false);

    _loadWeddingInfoFromCloud();
    _subscribeToWeddingInfo();
  }

  Future<void> _loadWeddingInfoFromCloud() async {
    setState(() {
      _isLoading = true;
      _isUpdatingFromCloud = true;
    });

    try {
      Logger.log("Načítání údajů o svatbě z cloudu");
      final weddingInfo = await _weddingRepository.fetchWeddingInfo();

      if (mounted) {
        setState(() {
          _weddingInfo = weddingInfo;
          totalBudget = weddingInfo.budget;
          yourName = weddingInfo.yourName;
          partnerName = weddingInfo.partnerName;
          _isLoading = false;
        });

        Logger.log("Data o svatbě načtena z cloudu: ${weddingInfo.toJson()}");
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.log("Chyba při načítání údajů z cloudu: $e");
      setState(() {
        _isLoading = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingFromCloud = false;
        });
      }
    }
  }

  void _subscribeToWeddingInfo() {
    _weddingSubscription =
        _weddingRepository.weddingInfoStream.listen((weddingInfo) {
      if (weddingInfo != null && mounted && !_isUpdatingFromCloud) {
        if (_weddingInfo != null) {
          final currentJson = _weddingInfo!.toJson().toString();
          final newJson = weddingInfo.toJson().toString();

          if (currentJson == newJson) {
            Logger.log(
                "Ignorujeme redundantní cloud update - data jsou stejná");
            return;
          }
        }

        setState(() {
          _weddingInfo = weddingInfo;
          totalBudget = weddingInfo.budget;
          yourName = weddingInfo.yourName;
          partnerName = weddingInfo.partnerName;
        });
        Logger.log("Rozpočet aktualizován z cloudu: ${weddingInfo.budget}");
      }
    });
  }

  Future<void> _updateBudget(double newBudget) async {
    setState(() {
      _isUpdatingFromCloud = true;
    });

    try {
      Logger.log("Aktualizace rozpočtu v cloudu");
      final currentInfo = await _weddingRepository.fetchWeddingInfo();

      final updatedInfo = currentInfo.copyWith(budget: newBudget);

      await _weddingRepository.updateWeddingInfo(updatedInfo);
      Logger.log("Rozpočet aktualizován v cloudu");

      setState(() {
        _weddingInfo = updatedInfo;
        totalBudget = newBudget;
      });

      Logger.log("Rozpočet aktualizován na $newBudget");
    } catch (e) {
      Logger.log("Chyba při aktualizaci rozpočtu: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingFromCloud = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _weddingSubscription?.cancel();
    super.dispose();
  }

  Widget _buildPremiumButton() {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, child) {
        if (!subscriptionProvider.isPremium) {
          return IconButton(
            icon: const Icon(Icons.star, color: Colors.amber),
            tooltip: tr('upgrade_to_premium'),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const SubscriptionOfferDialog(),
              );
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(tr('budget')),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(tr('loading_from_cloud')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('budget')),
        actions: [
          _buildPremiumButton(),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text(tr('set_budget')),
                    content: BudgetSettingsWidget(
                      currentBudget: totalBudget,
                      onBudgetChanged: (newBudget) {
                        _updateBudget(newBudget);
                      },
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(tr('close')),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadWeddingInfoFromCloud();
              final budgetManager =
                  Provider.of<BudgetManager>(context, listen: false);
              budgetManager.forceRefreshFromCloud();
            },
          ),
        ],
      ),
      body: Consumer<BudgetManager>(
        builder: (context, budgetManager, child) {
          if (budgetManager.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(tr('syncing_expenses')),
                ],
              ),
            );
          }

          final expenses = budgetManager.expenses;

          final double paidAmount = budgetManager.totalPaid;
          final double remainingAmount = totalBudget - paidAmount;
          final double usedPercentage =
              (totalBudget > 0) ? (paidAmount / totalBudget).clamp(0, 1) : 0;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${tr('total_budget')}: ${totalBudget.toStringAsFixed(2)} ${tr('currency')}",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${tr('paid')}: ${paidAmount.toStringAsFixed(2)} ${tr('currency')}",
                              style: const TextStyle(
                                  color: Colors.green, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${tr('remaining')}: ${remainingAmount.toStringAsFixed(2)} ${tr('currency')}",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      CircularPercentIndicator(
                        radius: 40.0,
                        lineWidth: 6.0,
                        percent: usedPercentage,
                        center: Text(
                            "${(usedPercentage * 100).toStringAsFixed(0)}%"),
                        progressColor: Colors.pink,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  if (expenses.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        child: Text(tr('no_expenses_yet')),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final expense = expenses[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(expense.title),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${tr('category')}: ${expense.category}"),
                                Text(
                                  "${tr('amount')}: ${expense.amount.toStringAsFixed(2)} ${tr('currency')}",
                                ),
                                if (expense.note.isNotEmpty)
                                  Text(
                                    "${tr('note')}: ${expense.note}",
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic),
                                  ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () =>
                                      _showEditExpenseDialog(context, expense),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _deleteExpense(context, expense.id),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "budget_fab",
        onPressed: () => _showAddExpenseDialog(context),
        tooltip: tr('add_expense'),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _deleteExpense(BuildContext context, String expenseId) {
    final budgetManager = Provider.of<BudgetManager>(context, listen: false);
    budgetManager.removeExpense(expenseId);
  }

  Future<void> _showAddExpenseDialog(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: false, // ← ZMĚNA: vypnuto, protože používáme SafeArea uvnitř
      builder: (context) => AddExpenseForm(
        onExpenseAdded: (newExpense) async {
          final budgetManager =
              Provider.of<BudgetManager>(context, listen: false);
          final success = await budgetManager.addExpense(newExpense, context);
          if (success && mounted) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Future<void> _showEditExpenseDialog(
      BuildContext context, Expense expense) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: false, // ← ZMĚNA: vypnuto, protože používáme SafeArea uvnitř
      builder: (context) {
        return EditExpenseForm(
          expense: expense,
          onExpenseUpdated: (updatedExpense) {
            final budgetManager =
                Provider.of<BudgetManager>(context, listen: false);
            budgetManager.updateExpense(updatedExpense);
            if (mounted) {
              Navigator.pop(context);
            }
          },
        );
      },
    );
  }
}
