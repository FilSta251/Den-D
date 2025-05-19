// lib/screens/tasks_screen.dart

import 'package:flutter/material.dart';
import '../models/task.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({Key? key}) : super(key: key);

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  // Seznam úkolů (simulace; v reálné aplikaci načítat z repozitáře)
  final List<Task> _tasks = [];
  final TextEditingController _taskController = TextEditingController();

  // Filtr – true: zobrazit všechny, false: pouze nedokončené
  bool _showAllTasks = true;

  @override
  void initState() {
    super.initState();
    // Iniciální simulovaná data
    _tasks.addAll([
      Task(
        id: '1',
        title: 'Připravit květinovou výzdobu',
        isCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Task(
        id: '2',
        title: 'Objednat dort',
        isCompleted: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Task(
        id: '3',
        title: 'Potvrdit účast hostů',
        isCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ]);
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  /// Přidá nový úkol, pokud není vstup prázdný.
  void _addTask() {
    final String text = _taskController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      final newTask = Task(
        id: UniqueKey().toString(),
        title: text,
        isCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _tasks.add(newTask);
      _taskController.clear();
    });
  }

  /// Přepne stav dokončení úkolu na indexu [index].
  void _toggleTaskCompletion(int index) {
    setState(() {
      _tasks[index] = _tasks[index].copyWith(
        isCompleted: !_tasks[index].isCompleted,
        updatedAt: DateTime.now(),
      );
    });
  }

  /// Smaže úkol z _tasks na zadaném indexu.
  void _deleteTask(int index) {
    setState(() {
      _tasks.removeAt(index);
    });
  }

  /// Umožňuje přetahování úkolů a změnu jejich pořadí.
  void _reorderTask(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final Task task = _tasks.removeAt(oldIndex);
      _tasks.insert(newIndex, task);
    });
  }

  /// Umožňuje editaci úkolu prostřednictvím dialogu.
  void _editTask(Task task, int index) {
    final TextEditingController editController = TextEditingController(text: task.title);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Upravit úkol'),
          content: TextField(
            controller: editController,
            decoration: const InputDecoration(labelText: 'Název úkolu'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zrušit'),
            ),
            ElevatedButton(
              onPressed: () {
                final String newTitle = editController.text.trim();
                if (newTitle.isNotEmpty) {
                  setState(() {
                    _tasks[index] = task.copyWith(
                      title: newTitle,
                      updatedAt: DateTime.now(),
                    );
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Uložit'),
            ),
          ],
        );
      },
    );
  }

  /// Vrací filtrovaný seznam úkolů podle stavu dokončení.
  List<Task> get _filteredTasks {
    if (_showAllTasks) return _tasks;
    return _tasks.where((task) => !task.isCompleted).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tasksToShow = _filteredTasks;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Úkoly'),
        actions: [
          IconButton(
            icon: Icon(_showAllTasks ? Icons.filter_alt_off : Icons.filter_alt),
            onPressed: () {
              setState(() {
                _showAllTasks = !_showAllTasks;
              });
            },
            tooltip: _showAllTasks ? 'Zobrazit pouze nedokončené' : 'Zobrazit všechny',
          ),
        ],
      ),
      body: Column(
        children: [
          // Řádek pro zadávání nového úkolu
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: const InputDecoration(
                      labelText: 'Nový úkol',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTask,
                  child: const Text('Přidat'),
                ),
              ],
            ),
          ),
          const Divider(),
          // Seznam úkolů s podporou drag & drop
          Expanded(
            child: ReorderableListView(
              onReorder: _reorderTask,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (int index = 0; index < tasksToShow.length; index++)
                  ListTile(
                    key: ValueKey(tasksToShow[index].id),
                    leading: Checkbox(
                      value: tasksToShow[index].isCompleted,
                      onChanged: (_) {
                        final originalIndex = _tasks.indexWhere((t) => t.id == tasksToShow[index].id);
                        if (originalIndex != -1) {
                          _toggleTaskCompletion(originalIndex);
                        }
                      },
                    ),
                    title: Text(
                      tasksToShow[index].title,
                      style: TextStyle(
                        decoration: tasksToShow[index].isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            final originalIndex = _tasks.indexWhere((t) => t.id == tasksToShow[index].id);
                            if (originalIndex != -1) {
                              _editTask(tasksToShow[index], originalIndex);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            final originalIndex = _tasks.indexWhere((t) => t.id == tasksToShow[index].id);
                            if (originalIndex != -1) {
                              _deleteTask(originalIndex);
                            }
                          },
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
  }
}
