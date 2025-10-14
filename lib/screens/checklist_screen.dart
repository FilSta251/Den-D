// lib/screens/checklist_screen.dart - PRODUKČNÍ VERZE S CHECKLIST MANAGER NUTNO DOKONČIT

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../models/subscription.dart';
import '../services/checklist_manager.dart';
import '../services/local_checklist_service.dart';
import '../widgets/subscription_offer_dialog.dart';

class ChecklistPage extends StatefulWidget {
  const ChecklistPage({Key? key}) : super(key: key);

  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = '';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  // Filtry
  String _priorityFilter = 'all'; // all, high, medium, low
  String _statusFilter = 'all'; // all, completed, pending
  bool _showOverdueTasks = false;
  
  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    
    // Načtení dat při prvním zobrazení
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final checklistManager = Provider.of<ChecklistManager>(context, listen: false);
      if (checklistManager.categories.isNotEmpty) {
        setState(() {
          _selectedCategory = checklistManager.categories.first.id;
        });
      }
      
      // Vytvoření tab controlleru podle počtu kategorií
      _tabController = TabController(
        length: checklistManager.categories.length,
        vsync: this,
      );
      
      // Synchronizace s cloudem
      checklistManager.forceRefreshFromCloud();
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Aktualizace tab controlleru při změně počtu kategorií
    final checklistManager = Provider.of<ChecklistManager>(context, listen: false);
    if (_tabController.length != checklistManager.categories.length && checklistManager.categories.isNotEmpty) {
      _tabController.dispose();
      _tabController = TabController(
        length: checklistManager.categories.length,
        vsync: this,
      );
      
      if (_selectedCategory.isEmpty && checklistManager.categories.isNotEmpty) {
        setState(() {
          _selectedCategory = checklistManager.categories.first.id;
        });
      }
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  /// Aplikuje filtry na seznam úkolů
  List<Task> _applyFilters(List<Task> tasks) {
    List<Task> filteredTasks = List.from(tasks);
    
    // Filtr podle priority
    if (_priorityFilter != 'all') {
      final priority = _priorityFilter == 'high' ? 1 : _priorityFilter == 'medium' ? 2 : 3;
      filteredTasks = filteredTasks.where((task) => task.priority == priority).toList();
    }
    
    // Filtr podle stavu
    if (_statusFilter == 'completed') {
      filteredTasks = filteredTasks.where((task) => task.isDone).toList();
    } else if (_statusFilter == 'pending') {
      filteredTasks = filteredTasks.where((task) => !task.isDone).toList();
    }
    
    // Filtr zpožděných úkolů
    if (_showOverdueTasks) {
      final now = DateTime.now();
      filteredTasks = filteredTasks.where((task) => 
        task.dueDate != null && 
        task.dueDate!.isBefore(now) && 
        !task.isDone
      ).toList();
    }
    
    // Vyhledávání
    if (_searchQuery.isNotEmpty) {
      filteredTasks = filteredTasks.where((task) =>
        task.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (task.note?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }
    
    return filteredTasks;
  }
  
  /// Zobrazí dialog pro přidání úkolu
  void _showAddTaskDialog(String categoryId) {
    // Kontrola předplatného
    final subscription = Provider.of<Subscription?>(context, listen: false);
    if (subscription == null || !subscription.isActive) {
      showDialog(
        context: context,
        builder: (context) => const SubscriptionOfferDialog(),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddTaskForm(categoryId: categoryId),
    );
  }
  
  /// Zobrazí dialog pro úpravu úkolu
  void _showEditTaskDialog(Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditTaskForm(task: task),
    );
  }
  
  /// Smaže úkol
  void _deleteTask(String taskId) {
    final checklistManager = Provider.of<ChecklistManager>(context, listen: false);
    checklistManager.removeTask(taskId);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Úkol byl odstraněn'),
        backgroundColor: Colors.orange,
      ),
    );
  }
  
  /// Přepne stav dokončení úkolu
  void _toggleTaskDone(String taskId) {
    final checklistManager = Provider.of<ChecklistManager>(context, listen: false);
    checklistManager.toggleTaskDone(taskId);
  }
  
  /// Panel s filtry
  void _openFilterPanel() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filtr úkolů',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Filtr priority
                  const Text('Priorita', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Vše'),
                        selected: _priorityFilter == 'all',
                        onSelected: (selected) {
                          setState(() {
                            _priorityFilter = 'all';
                          });
                          setStateSheet(() {});
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Vysoká'),
                        selected: _priorityFilter == 'high',
                        selectedColor: Colors.red.shade100,
                        onSelected: (selected) {
                          setState(() {
                            _priorityFilter = 'high';
                          });
                          setStateSheet(() {});
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Střední'),
                        selected: _priorityFilter == 'medium',
                        selectedColor: Colors.orange.shade100,
                        onSelected: (selected) {
                          setState(() {
                            _priorityFilter = 'medium';
                          });
                          setStateSheet(() {});
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Nízká'),
                        selected: _priorityFilter == 'low',
                        selectedColor: Colors.green.shade100,
                        onSelected: (selected) {
                          setState(() {
                            _priorityFilter = 'low';
                          });
                          setStateSheet(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Filtr stavu
                  const Text('Stav', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Vše'),
                        selected: _statusFilter == 'all',
                        onSelected: (selected) {
                          setState(() {
                            _statusFilter = 'all';
                          });
                          setStateSheet(() {});
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Dokončeno'),
                        selected: _statusFilter == 'completed',
                        selectedColor: Colors.green.shade100,
                        onSelected: (selected) {
                          setState(() {
                            _statusFilter = 'completed';
                          });
                          setStateSheet(() {});
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Nedokončeno'),
                        selected: _statusFilter == 'pending',
                        selectedColor: Colors.grey.shade200,
                        onSelected: (selected) {
                          setState(() {
                            _statusFilter = 'pending';
                          });
                          setStateSheet(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Zpožděné úkoly
                  SwitchListTile(
                    title: const Text('Pouze zpožděné úkoly'),
                    value: _showOverdueTasks,
                    onChanged: (value) {
                      setState(() {
                        _showOverdueTasks = value;
                      });
                      setStateSheet(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Tlačítko reset
                  Center(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Resetovat filtry'),
                      onPressed: () {
                        setState(() {
                          _priorityFilter = 'all';
                          _statusFilter = 'all';
                          _showOverdueTasks = false;
                          _searchController.clear();
                        });
                        setStateSheet(() {});
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  /// Widget pro zobrazení statistik
  Widget _buildStatisticsBar(ChecklistManager checklistManager) {
    final stats = checklistManager.getChecklistStatistics();
    final completed = stats['completed'] ?? 0;
    final total = stats['total'] ?? 0;
    final percentage = stats['percentage'] ?? 0;
    final overdue = stats['overdue'] ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Celkový pokrok',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '$completed / $total',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total > 0 ? completed / total : 0,
              minHeight: 20,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                percentage > 80 ? Colors.green : percentage > 50 ? Colors.orange : Colors.red,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$percentage% dokončeno',
                style: TextStyle(
                  color: percentage > 80 ? Colors.green : percentage > 50 ? Colors.orange : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (overdue > 0)
                Text(
                  '$overdue zpožděných',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// Widget pro seznam úkolů v kategorii
  Widget _buildTasksList(String categoryId, ChecklistManager checklistManager) {
    final categoryTasks = checklistManager.getTasksByCategory(categoryId);
    final filteredTasks = _applyFilters(categoryTasks);
    
    if (categoryTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Zatím zde nejsou žádné úkoly',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Přidejte první úkol pomocí tlačítka +',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    if (filteredTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Žádné úkoly neodpovídají filtrům',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    // Seřadíme úkoly - nedokončené nahoře, pak podle priority
    filteredTasks.sort((a, b) {
      if (a.isDone != b.isDone) {
        return a.isDone ? 1 : -1;
      }
      return a.priority.compareTo(b.priority);
    });
    
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        final isOverdue = task.dueDate != null && 
                         task.dueDate!.isBefore(DateTime.now()) && 
                         !task.isDone;
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: task.isDone 
              ? Colors.grey.shade100 
              : isOverdue 
                  ? Colors.red.shade50 
                  : null,
          child: ListTile(
            onTap: () => _showEditTaskDialog(task),
            leading: Checkbox(
              value: task.isDone,
              onChanged: (_) => _toggleTaskDone(task.id),
              activeColor: Colors.green,
            ),
            title: Text(
              task.title,
              style: TextStyle(
                decoration: task.isDone ? TextDecoration.lineThrough : null,
                fontWeight: task.priority == 1 ? FontWeight.bold : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.note != null && task.note!.isNotEmpty)
                  Text(
                    task.note!,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (task.dueDate != null)
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: isOverdue ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd.MM.yyyy').format(task.dueDate!),
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverdue ? Colors.red : Colors.grey,
                          fontWeight: isOverdue ? FontWeight.bold : null,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Indikátor priority
                Container(
                  width: 8,
                  height: 30,
                  decoration: BoxDecoration(
                    color: task.priority == 1 
                        ? Colors.red 
                        : task.priority == 2 
                            ? Colors.orange 
                            : Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteTask(task.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<ChecklistManager>(
      builder: (context, checklistManager, child) {
        // Pokud nejsou kategorie, zobrazíme loading nebo prázdný stav
        if (checklistManager.categories.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: Text(tr('Checklist')),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // Indikátor synchronizace
        final bool showSyncIndicator = checklistManager.syncState == SyncState.syncing;
        
        return Scaffold(
          appBar: AppBar(
            title: Text(tr('Checklist')),
            actions: [
              // Indikátor online/offline stavu
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  checklistManager.isOnline ? Icons.cloud_done : Icons.cloud_off,
                  color: checklistManager.isOnline ? Colors.green : Colors.orange,
                ),
              ),
              // Tlačítko filtru
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _openFilterPanel,
              ),
              // Menu s dalšími akcemi
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'refresh':
                      await checklistManager.forceRefreshFromCloud();
                      break;
                    case 'stats':
                      _showStatisticsDialog(checklistManager);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Obnovit z cloudu'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'stats',
                    child: Row(
                      children: [
                        Icon(Icons.analytics, color: Colors.purple),
                        SizedBox(width: 8),
                        Text('Statistiky'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(
                48 + // TabBar
                (_searchQuery.isNotEmpty || _priorityFilter != 'all' || 
                 _statusFilter != 'all' || _showOverdueTasks ? 40 : 0) // Search bar
              ),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabs: checklistManager.categories.map((category) {
                      final categoryStats = checklistManager.getCategoryStatistics()[category.id];
                      final completed = categoryStats?['completed'] ?? 0;
                      final total = categoryStats?['total'] ?? 0;
                      
                      return Tab(
                        child: Row(
                          children: [
                            Text(category.name),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: completed == total && total > 0 
                                    ? Colors.green 
                                    : Colors.grey.shade400,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$completed/$total',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onTap: (index) {
                      setState(() {
                        _selectedCategory = checklistManager.categories[index].id;
                      });
                    },
                  ),
                  // Search bar pokud jsou aktivní filtry
                  if (_searchQuery.isNotEmpty || _priorityFilter != 'all' || 
                      _statusFilter != 'all' || _showOverdueTasks)
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.orange.shade100,
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16),
                          const SizedBox(width: 8),
                          const Text('Filtry jsou aktivní', style: TextStyle(fontSize: 12)),
                          const Spacer(),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _priorityFilter = 'all';
                                _statusFilter = 'all';
                                _showOverdueTasks = false;
                                _searchController.clear();
                              });
                            },
                            child: const Text(
                              'Zrušit',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  // Statistiky
                  _buildStatisticsBar(checklistManager),
                  
                  // Vyhledávání
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Hledat úkoly...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                  
                  // Seznam úkolů
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: checklistManager.categories.map((category) {
                        return RefreshIndicator(
                          onRefresh: () => checklistManager.forceRefreshFromCloud(),
                          child: _buildTasksList(category.id, checklistManager),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              
              // Indikátor synchronizace
              if (showSyncIndicator)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.blue.withOpacity(0.9),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Synchronizace...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              if (_tabController.index < checklistManager.categories.length) {
                _showAddTaskDialog(checklistManager.categories[_tabController.index].id);
              }
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
  
  /// Dialog se statistikami
  void _showStatisticsDialog(ChecklistManager checklistManager) {
    final stats = checklistManager.getChecklistStatistics();
    final categoryStats = checklistManager.getCategoryStatistics();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Statistiky checklistu'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
	    crossAxisAlignment: CrossAxisAlignment.start,
           mainAxisSize: MainAxisSize.min,
           children: [
             _buildStatRow('Celkem úkolů', stats['total'].toString()),
             _buildStatRow('Dokončeno', stats['completed'].toString(), Colors.green),
             _buildStatRow('Zbývá', stats['pending'].toString(), Colors.orange),
             _buildStatRow('Zpožděno', stats['overdue'].toString(), Colors.red),
             const Divider(),
             _buildStatRow('Vysoká priorita', stats['highPriority'].toString()),
             const Divider(),
             const Text(
               'Podle kategorií:',
               style: TextStyle(fontWeight: FontWeight.bold),
             ),
             const SizedBox(height: 8),
             ...categoryStats.entries.map((entry) {
               final catStats = entry.value;
               return Padding(
                 padding: const EdgeInsets.symmetric(vertical: 4),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Expanded(child: Text(catStats['name'])),
                     Text(
                       '${catStats['completed']}/${catStats['total']} (${catStats['percentage']}%)',
                       style: TextStyle(
                         color: catStats['percentage'] == 100 ? Colors.green : null,
                         fontWeight: catStats['percentage'] == 100 ? FontWeight.bold : null,
                       ),
                     ),
                   ],
                 ),
               );
             }).toList(),
           ],
         ),
       ),
       actions: [
         TextButton(
           onPressed: () => Navigator.pop(context),
           child: const Text('Zavřít'),
         ),
       ],
     ),
   );
 }
 
 Widget _buildStatRow(String label, String value, [Color? color]) {
   return Padding(
     padding: const EdgeInsets.symmetric(vertical: 4),
     child: Row(
       mainAxisAlignment: MainAxisAlignment.spaceBetween,
       children: [
         Text(label),
         Text(
           value,
           style: TextStyle(
             fontWeight: FontWeight.bold,
             color: color,
           ),
         ),
       ],
     ),
   );
 }
}

/// Formulář pro přidání úkolu
class _AddTaskForm extends StatefulWidget {
 final String categoryId;
 
 const _AddTaskForm({
   Key? key,
   required this.categoryId,
 }) : super(key: key);

 @override
 __AddTaskFormState createState() => __AddTaskFormState();
}

class __AddTaskFormState extends State<_AddTaskForm> {
 final _formKey = GlobalKey<FormState>();
 final _titleController = TextEditingController();
 final _noteController =  TextEditingController();
 
 DateTime? _dueDate;
 int _priority = 2;

 @override
 void dispose() {
   _titleController.dispose();
   _noteController.dispose();
   super.dispose();
 }

 void _submitForm() {
   if (_formKey.currentState!.validate()) {
     final checklistManager = Provider.of<ChecklistManager>(context, listen: false);
     
     final newTask = LocalChecklistService.createTask(
       title: _titleController.text.trim(),
       category: widget.categoryId,
       note: _noteController.text.trim(),
       dueDate: _dueDate,
       priority: _priority,
     );
     
     checklistManager.addTask(newTask);
     Navigator.pop(context);
     
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(
         content: Text('Úkol byl přidán'),
         backgroundColor: Colors.green,
       ),
     );
   }
 }

 @override
 Widget build(BuildContext context) {
   return Container(
     decoration: const BoxDecoration(
       color: Colors.white,
       borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
     ),
     padding: EdgeInsets.only(
       bottom: MediaQuery.of(context).viewInsets.bottom,
       left: 16,
       right: 16,
       top: 16,
     ),
     child: Form(
       key: _formKey,
       child: SingleChildScrollView(
         child: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.stretch,
           children: [
             Center(
               child: Container(
                 width: 40,
                 height: 5,
                 decoration: BoxDecoration(
                   color: Colors.grey[300],
                   borderRadius: BorderRadius.circular(10),
                 ),
               ),
             ),
             const SizedBox(height: 16),
             const Text(
               'Přidat úkol',
               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
               textAlign: TextAlign.center,
             ),
             const SizedBox(height: 24),
             
             // Název úkolu
             TextFormField(
               controller: _titleController,
               decoration: const InputDecoration(
                 labelText: 'Název úkolu',
                 border: OutlineInputBorder(),
                 prefixIcon: Icon(Icons.task),
               ),
               textCapitalization: TextCapitalization.sentences,
               validator: (value) {
                 if (value == null || value.trim().isEmpty) {
                   return 'Zadejte název úkolu';
                 }
                 return null;
               },
             ),
             const SizedBox(height: 16),
             
             // Poznámka
             TextFormField(
               controller: _noteController,
               decoration: const InputDecoration(
                 labelText: 'Poznámka (nepovinné)',
                 border: OutlineInputBorder(),
                 prefixIcon: Icon(Icons.note),
               ),
               maxLines: 3,
               textCapitalization: TextCapitalization.sentences,
             ),
             const SizedBox(height: 16),
             
             // Datum
             ListTile(
               shape: RoundedRectangleBorder(
                 borderRadius: BorderRadius.circular(8),
                 side: BorderSide(color: Colors.grey.shade400),
               ),
               leading: const Icon(Icons.calendar_today),
               title: Text(_dueDate == null 
                   ? 'Nastavit termín' 
                   : DateFormat('dd.MM.yyyy').format(_dueDate!)),
               trailing: _dueDate != null
                   ? IconButton(
                       icon: const Icon(Icons.clear),
                       onPressed: () {
                         setState(() {
                           _dueDate = null;
                         });
                       },
                     )
                   : null,
               onTap: () async {
                 final picked = await showDatePicker(
                   context: context,
                   initialDate: _dueDate ?? DateTime.now(),
                   firstDate: DateTime.now().subtract(const Duration(days: 365)),
                   lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                 );
                 if (picked != null) {
                   setState(() {
                     _dueDate = picked;
                   });
                 }
               },
             ),
             const SizedBox(height: 16),
             
             // Priorita
             const Text('Priorita', style: TextStyle(fontSize: 16)),
             const SizedBox(height: 8),
             Row(
               children: [
                 Expanded(
                   child: ChoiceChip(
                     label: const Text('Vysoká'),
                     selected: _priority == 1,
                     selectedColor: Colors.red.shade100,
                     onSelected: (selected) {
                       if (selected) {
                         setState(() {
                           _priority = 1;
                         });
                       }
                     },
                     avatar: const Icon(Icons.flag, size: 18),
                   ),
                 ),
                 const SizedBox(width: 8),
                 Expanded(
                   child: ChoiceChip(
                     label: const Text('Střední'),
                     selected: _priority == 2,
                     selectedColor: Colors.orange.shade100,
                     onSelected: (selected) {
                       if (selected) {
                         setState(() {
                           _priority = 2;
                         });
                       }
                     },
                     avatar: const Icon(Icons.flag, size: 18),
                   ),
                 ),
                 const SizedBox(width: 8),
                 Expanded(
                   child: ChoiceChip(
                     label: const Text('Nízká'),
                     selected: _priority == 3,
                     selectedColor: Colors.green.shade100,
                     onSelected: (selected) {
                       if (selected) {
                         setState(() {
                           _priority = 3;
                         });
                       }
                     },
                     avatar: const Icon(Icons.flag, size: 18),
                   ),
                 ),
               ],
             ),
             const SizedBox(height: 24),
             
             // Tlačítka
             Row(
               children: [
                 Expanded(
                   child: OutlinedButton(
                     onPressed: () => Navigator.pop(context),
                     child: const Text('Zrušit'),
                   ),
                 ),
                 const SizedBox(width: 16),
                 Expanded(
                   child: ElevatedButton(
                     onPressed: _submitForm,
                     child: const Text('Přidat úkol'),
                   ),
                 ),
               ],
             ),
             const SizedBox(height: 16),
           ],
         ),
       ),
     ),
   );
 }
}

/// Formulář pro úpravu úkolu
class _EditTaskForm extends StatefulWidget {
 final Task task;
 
 const _EditTaskForm({
   Key? key,
   required this.task,
 }) : super(key: key);

 @override
 __EditTaskFormState createState() => __EditTaskFormState();
}

class __EditTaskFormState extends State<_EditTaskForm> {
 final _formKey = GlobalKey<FormState>();
 late TextEditingController _titleController;
 late TextEditingController _noteController;
 late String _selectedCategory;
 late DateTime? _dueDate;
 late int _priority;
 late bool _isDone;

 @override
 void initState() {
   super.initState();
   _titleController = TextEditingController(text: widget.task.title);
   _noteController = TextEditingController(text: widget.task.note ?? '');
   _selectedCategory = widget.task.category;
   _dueDate = widget.task.dueDate;
   _priority = widget.task.priority;
   _isDone = widget.task.isDone;
 }

 @override
 void dispose() {
   _titleController.dispose();
   _noteController.dispose();
   super.dispose();
 }

 void _submitForm() {
   if (_formKey.currentState!.validate()) {
     final checklistManager = Provider.of<ChecklistManager>(context, listen: false);
     
     final updatedTask = widget.task.copyWith(
       title: _titleController.text.trim(),
       category: _selectedCategory,
       note: _noteController.text.trim(),
       dueDate: _dueDate,
       priority: _priority,
       isDone: _isDone,
     );
     
     checklistManager.updateTask(updatedTask);
     Navigator.pop(context);
     
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(
         content: Text('Úkol byl aktualizován'),
         backgroundColor: Colors.green,
       ),
     );
   }
 }

 @override
 Widget build(BuildContext context) {
   final checklistManager = Provider.of<ChecklistManager>(context);
   final categories = checklistManager.categories;
   
   return Container(
     decoration: const BoxDecoration(
       color: Colors.white,
       borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
     ),
     padding: EdgeInsets.only(
       bottom: MediaQuery.of(context).viewInsets.bottom,
       left: 16,
       right: 16,
       top: 16,
     ),
     child: Form(
       key: _formKey,
       child: SingleChildScrollView(
         child: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.stretch,
           children: [
             Center(
               child: Container(
                 width: 40,
                 height: 5,
                 decoration: BoxDecoration(
                   color: Colors.grey[300],
                   borderRadius: BorderRadius.circular(10),
                 ),
               ),
             ),
             const SizedBox(height: 16),
             const Text(
               'Upravit úkol',
               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
               textAlign: TextAlign.center,
             ),
             const SizedBox(height: 24),
             
             // Název úkolu
             TextFormField(
               controller: _titleController,
               decoration: const InputDecoration(
                 labelText: 'Název úkolu',
                 border: OutlineInputBorder(),
                 prefixIcon: Icon(Icons.task),
               ),
               textCapitalization: TextCapitalization.sentences,
               validator: (value) {
                 if (value == null || value.trim().isEmpty) {
                   return 'Zadejte název úkolu';
                 }
                 return null;
               },
             ),
             const SizedBox(height: 16),
             
             // Kategorie
             DropdownButtonFormField<String>(
               decoration: const InputDecoration(
                 labelText: 'Kategorie',
                 border: OutlineInputBorder(),
                 prefixIcon: Icon(Icons.category),
               ),
               value: categories.any((c) => c.id == _selectedCategory) 
                   ? _selectedCategory 
                   : categories.first.id,
               items: categories.map((category) => DropdownMenuItem(
                 value: category.id,
                 child: Text(category.name),
               )).toList(),
               onChanged: (value) {
                 setState(() {
                   _selectedCategory = value!;
                 });
               },
             ),
             const SizedBox(height: 16),
             
             // Poznámka
             TextFormField(
               controller: _noteController,
               decoration: const InputDecoration(
                 labelText: 'Poznámka (nepovinné)',
                 border: OutlineInputBorder(),
                 prefixIcon: Icon(Icons.note),
               ),
               maxLines: 3,
               textCapitalization: TextCapitalization.sentences,
             ),
             const SizedBox(height: 16),
             
             // Datum
             ListTile(
               shape: RoundedRectangleBorder(
                 borderRadius: BorderRadius.circular(8),
                 side: BorderSide(color: Colors.grey.shade400),
               ),
               leading: const Icon(Icons.calendar_today),
               title: Text(_dueDate == null 
                   ? 'Nastavit termín' 
                   : DateFormat('dd.MM.yyyy').format(_dueDate!)),
               trailing: _dueDate != null
                   ? IconButton(
                       icon: const Icon(Icons.clear),
                       onPressed: () {
                         setState(() {
                           _dueDate = null;
                         });
                       },
                     )
                   : null,
               onTap: () async {
                 final picked = await showDatePicker(
                   context: context,
                   initialDate: _dueDate ?? DateTime.now(),
                   firstDate: DateTime.now().subtract(const Duration(days: 365)),
                   lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                 );
                 if (picked != null) {
                   setState(() {
                     _dueDate = picked;
                   });
                 }
               },
             ),
             const SizedBox(height: 16),
             
             // Priorita
             const Text('Priorita', style: TextStyle(fontSize: 16)),
             const SizedBox(height: 8),
             Row(
               children: [
                 Expanded(
                   child: ChoiceChip(
                     label: const Text('Vysoká'),
                     selected: _priority == 1,
                     selectedColor: Colors.red.shade100,
                     onSelected: (selected) {
                       if (selected) {
                         setState(() {
                           _priority = 1;
                         });
                       }
                     },
                     avatar: const Icon(Icons.flag, size: 18),
                   ),
                 ),
                 const SizedBox(width: 8),
                 Expanded(
                   child: ChoiceChip(
                     label: const Text('Střední'),
                     selected: _priority == 2,
                     selectedColor: Colors.orange.shade100,
                     onSelected: (selected) {
                       if (selected) {
                         setState(() {
                           _priority = 2;
                         });
                       }
                     },
                     avatar: const Icon(Icons.flag, size: 18),
                   ),
                 ),
                 const SizedBox(width: 8),
                 Expanded(
                   child: ChoiceChip(
                     label: const Text('Nízká'),
                     selected: _priority == 3,
                     selectedColor: Colors.green.shade100,
                     onSelected: (selected) {
                       if (selected) {
                         setState(() {
                           _priority = 3;
                         });
                       }
                     },
                     avatar: const Icon(Icons.flag, size: 18),
                   ),
                 ),
               ],
             ),
             const SizedBox(height: 16),
             
             // Stav úkolu
             SwitchListTile(
               title: const Text('Úkol je dokončen'),
               value: _isDone,
               onChanged: (value) {
                 setState(() {
                   _isDone = value;
                 });
               },
             ),
             const SizedBox(height: 24),
             
             // Tlačítka
             Row(
               children: [
                 Expanded(
                   child: OutlinedButton(
                     onPressed: () => Navigator.pop(context),
                     child: const Text('Zrušit'),
                   ),
                 ),
                 const SizedBox(width: 16),
                 Expanded(
                   child: ElevatedButton(
                     onPressed: _submitForm,
                     child: const Text('Uložit změny'),
                   ),
                 ),
               ],
             ),
             const SizedBox(height: 16),
           ],
         ),
       ),
     ),
   );
 }
}