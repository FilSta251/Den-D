// lib/screens/budget_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../repositories/wedding_repository.dart';
import '../models/wedding_info.dart';
import '../services/budget_manager.dart';
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
    Key? key,
    required this.currentBudget,
    required this.onBudgetChanged,
  }) : super(key: key);

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
            'Aktuální rozpočet: ${currentBudget.toStringAsFixed(2)} Kč',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Nový rozpočet (Kč)',
              border: OutlineInputBorder(),
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
            child: const Text('Uložit nastavení'),
          ),
        ],
      ),
    );
  }
}

class AddExpenseForm extends StatefulWidget {
  final Function(Expense) onExpenseAdded;
  const AddExpenseForm({Key? key, required this.onExpenseAdded}) : super(key: key);

  @override
  _AddExpenseFormState createState() => _AddExpenseFormState();
}

class _AddExpenseFormState extends State<AddExpenseForm> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _paidController = TextEditingController();
  final TextEditingController _pendingController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _paidController.dispose();
    _pendingController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submitExpense() {
    final String title = _titleController.text.trim();
    final String category = _categoryController.text.trim();
    final double paid = double.tryParse(_paidController.text.trim()) ?? 0;
    final double pending = double.tryParse(_pendingController.text.trim()) ?? 0;
    final String note = _noteController.text.trim();
    
    // Kontrola povinných údajů - pouze název a zaplaceno
    if (title.isNotEmpty) {
      final Expense newExpense = Expense(
        id: const Uuid().v4(), // Používáme UUID pro jedinečné identifikátory
        title: title,
        category: category.isNotEmpty ? category : "Obecné", // Výchozí kategorie, pokud není zadána
        amount: paid + pending, // Celková částka je součet zaplaceno + nezaplaceno
        note: note,
        isPaid: pending == 0, // Je zaplaceno, pokud pending je 0
        date: DateTime.now(),
      );
      widget.onExpenseAdded(newExpense);
      Navigator.pop(context);
    } else {
      // Zobrazení chybové hlášky, pokud nejsou vyplněná povinná pole
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vyplňte prosím název výdaje"),
          backgroundColor: Colors.red,
        ),
      );
      Logger.log("Neplatné údaje při přidávání výdaje.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Přidat výdaj',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Název výdaje *', // Označení povinného pole hvězdičkou
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Kategorie',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _paidController,
              decoration: const InputDecoration(
                labelText: 'Zaplaceno (Kč) *', // Označení povinného pole hvězdičkou
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pendingController,
              decoration: const InputDecoration(
                labelText: 'Nevyřízeno (Kč)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Poznámka',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            // Přidání poznámky o povinných polích
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                '* Povinné údaje',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _submitExpense,
              child: const Text('Přidat výdaj'),
            ),
          ],
        ),
      ),
    );
  }
}

class EditExpenseForm extends StatefulWidget {
  final Expense expense;
  final Function(Expense) onExpenseUpdated;
  const EditExpenseForm({Key? key, required this.expense, required this.onExpenseUpdated})
      : super(key: key);

  @override
  _EditExpenseFormState createState() => _EditExpenseFormState();
}

class _EditExpenseFormState extends State<EditExpenseForm> {
  late TextEditingController _titleController;
  late TextEditingController _categoryController;
  late TextEditingController _paidController;
  late TextEditingController _pendingController;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.expense.title);
    _categoryController = TextEditingController(text: widget.expense.category);
    _paidController = TextEditingController(text: widget.expense.paid.toString());
    _pendingController = TextEditingController(text: widget.expense.pending.toString());
    _noteController = TextEditingController(text: widget.expense.note);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _paidController.dispose();
    _pendingController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _updateExpense() {
    final String title = _titleController.text.trim();
    final String category = _categoryController.text.trim();
    final double paid = double.tryParse(_paidController.text.trim()) ?? 0;
    final double pending = double.tryParse(_pendingController.text.trim()) ?? 0;
    final String note = _noteController.text.trim();
    
    // Kontrola povinných údajů - pouze název a zaplaceno
    if (title.isNotEmpty) {
      final Expense updatedExpense = widget.expense.copyWith(
        title: title,
        category: category.isNotEmpty ? category : "Obecné", // Výchozí kategorie, pokud není zadána
        amount: paid + pending, // Celková částka je součet zaplaceno + nezaplaceno
        note: note,
        isPaid: pending == 0, // Je zaplaceno, pokud pending je 0
        updatedAt: DateTime.now(),
      );
      widget.onExpenseUpdated(updatedExpense);
      Navigator.pop(context);
    } else {
      // Zobrazení chybové hlášky, pokud nejsou vyplněná povinná pole
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vyplňte prosím název výdaje"),
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
      padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Upravit výdaj',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Název výdaje *', // Označení povinného pole hvězdičkou
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Kategorie',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _paidController,
              decoration: const InputDecoration(
                labelText: 'Zaplaceno (Kč) *', // Označení povinného pole hvězdičkou
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pendingController,
              decoration: const InputDecoration(
                labelText: 'Nevyřízeno (Kč)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Poznámka',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            // Přidání poznámky o povinných polích
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                '* Povinné údaje',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _updateExpense,
              child: const Text('Uložit'),
            ),
          ],
        ),
      ),
    );
  }
}

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({Key? key}) : super(key: key);

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
    
    // Nejprve načteme data přímo z cloudu
    _loadWeddingInfoFromCloud();
    
    // Pak se přihlásíme k odběru změn 
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
      
      if (weddingInfo != null && mounted) {
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
    _weddingSubscription = _weddingRepository.weddingInfoStream.listen((weddingInfo) {
      if (weddingInfo != null && mounted && !_isUpdatingFromCloud) {
        // Zabráníme nekonečné smyčce aktualizací
        if (_weddingInfo != null) {
          // Porovnáme, jestli jsou data opravdu jiná
          final currentJson = _weddingInfo!.toJson().toString();
          final newJson = weddingInfo.toJson().toString();
          
          if (currentJson == newJson) {
            Logger.log("Ignorujeme redundantní cloud update - data jsou stejná");
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
      // Nejprve načteme aktuální data z cloudu
      Logger.log("Aktualizace rozpočtu v cloudu");
      final currentInfo = await _weddingRepository.fetchWeddingInfo();
      if (currentInfo != null) {
        final updatedInfo = currentInfo.copyWith(budget: newBudget);
        
        // Uložíme aktualizaci na cloud
        await _weddingRepository.updateWeddingInfo(updatedInfo);
        Logger.log("Rozpočet aktualizován v cloudu");
        
        setState(() {
          _weddingInfo = updatedInfo;
          totalBudget = newBudget;
        });
        
        Logger.log("Rozpočet aktualizován na $newBudget");
      }
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Rozpočet'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Načítání dat z cloudu...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rozpočet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Nastavit rozpočet'),
                    content: BudgetSettingsWidget(
                      currentBudget: totalBudget,
                      onBudgetChanged: (newBudget) {
                        _updateBudget(newBudget);
                      },
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Zavřít'),
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
              // Aktualizace dat z cloudu
              _loadWeddingInfoFromCloud();
              // Aktualizace položek rozpočtu
              final budgetManager = Provider.of<BudgetManager>(context, listen: false);
              budgetManager.forceRefreshFromCloud();
            },
          ),
        ],
      ),
      body: Consumer<BudgetManager>(
        builder: (context, budgetManager, child) {
          // Indikátor načítání pro synchronizaci s cloudem
          if (budgetManager.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Synchronizace výdajů...'),
                ],
              ),
            );
          }
          
          final expenses = budgetManager.expenses;
          
          // Výpočet hodnot pro rozpočet
          final double paidAmount = budgetManager.totalPaid;
          final double pendingAmount = budgetManager.totalPending;
          final double remainingAmount = totalBudget - paidAmount - pendingAmount;
          final double usedPercentage = (totalBudget > 0) 
              ? (paidAmount / totalBudget).clamp(0, 1)
              : 0;
          
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Celkový rozpočet: ${totalBudget.toStringAsFixed(2)} Kč",
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
                              "Zaplaceno: ${paidAmount.toStringAsFixed(2)} Kč",
                              style: const TextStyle(color: Colors.green, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Nevyřízeno: ${pendingAmount.toStringAsFixed(2)} Kč",
                              style: const TextStyle(color: Colors.orange, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Zůstatek: ${remainingAmount.toStringAsFixed(2)} Kč",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      CircularPercentIndicator(
                        radius: 40.0,
                        lineWidth: 6.0,
                        percent: usedPercentage,
                        center: Text("${(usedPercentage * 100).toStringAsFixed(0)}%"),
                        progressColor: Colors.pink,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  // Zobrazení seznamu výdajů
                  if (expenses.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32.0),
                        child: Text("Zatím nemáte žádné výdaje. Přidejte první pomocí tlačítka +"),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final expense = expenses[index];
                        // Používáme getter paid a pending z modelu Expense
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(expense.title),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Kategorie: ${expense.category}"),
                                Text(
                                  "Zaplaceno: ${expense.paid.toStringAsFixed(2)} Kč | Nevyřízeno: ${expense.pending.toStringAsFixed(2)} Kč",
                                ),
                                if (expense.note.isNotEmpty)
                                  Text(
                                    "Poznámka: ${expense.note}",
                                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                  ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _showEditExpenseDialog(context, expense),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteExpense(context, expense.id),
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
        heroTag: "budget_fab", // Přidáme unikátní heroTag
        onPressed: () => _showAddExpenseDialog(context),
        tooltip: 'Přidat výdaj',
        child: const Icon(Icons.add),
      ),
    );
  }
  
  // Pomocné metody pro práci s výdaji
  
  void _deleteExpense(BuildContext context, String expenseId) {
    final budgetManager = Provider.of<BudgetManager>(context, listen: false);
    budgetManager.removeExpense(expenseId);
  }
  
  Future<void> _showAddExpenseDialog(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return AddExpenseForm(
          onExpenseAdded: (newExpense) {
            final budgetManager = Provider.of<BudgetManager>(context, listen: false);
            budgetManager.addExpense(newExpense);
          },
        );
      },
    );
  }

  Future<void> _showEditExpenseDialog(BuildContext context, Expense expense) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return EditExpenseForm(
          expense: expense,
          onExpenseUpdated: (updatedExpense) {
            final budgetManager = Provider.of<BudgetManager>(context, listen: false);
            budgetManager.updateExpense(updatedExpense);
          },
        );
      },
    );
  }
}