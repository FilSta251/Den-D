/// lib/screens/checklist_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../services/checklist_manager.dart';
import '../services/local_checklist_service.dart';

/// Helper funkce pro překlad starých category ID
String _getCategoryTranslation(String categoryId) {
  const categoryIdMap = {
    '12-6-months': 'category_12_6_months',
    '6-3-months': 'category_6_3_months',
    '3-1-months': 'category_3_1_months',
    'week-before': 'category_week_before',
    'wedding-day': 'category_wedding_day',
  };

  if (categoryIdMap.containsKey(categoryId)) {
    return tr(categoryIdMap[categoryId]!);
  }

  return categoryId.startsWith('category_') ? tr(categoryId) : categoryId;
}

/// Helper funkce pro získání přeloženého textu
String _getTranslatedText(String text) {
  // Mapa českých textů na překladové klíče
  const czechToKeyMap = {
    'Rezervovat svatební místo': 'task_reserve_venue',
    'Vybrat fotografa a kameramana': 'task_choose_photographer',
    'Stanovit předběžný rozpočet': 'task_set_budget',
    'Vytvořit předběžný seznam hostů': 'task_create_guest_list',
    'Vybrat téma a barevnou paletu': 'task_choose_theme',
    'Rezervovat kapelu nebo DJ': 'task_reserve_band',
    'Zvážit svatebního koordinátora': 'task_consider_coordinator',
    'Rozeslat svatební pozvánky': 'task_send_invitations',
    'Zamluvit catering': 'task_book_catering',
    'Vybrat svatební šaty a oblek': 'task_choose_dress_suit',
    'Objednat svatební dort': 'task_order_cake',
    'Rezervovat květiny a dekorace': 'task_reserve_flowers',
    'Naplánovat harmonogram svatebního dne': 'task_plan_schedule',
    'Zajistit ubytování pro hosty': 'task_arrange_accommodation',
    'Potvrdit účast hostů': 'task_confirm_guests',
    'Vybrat svatební prstýnky': 'task_choose_rings',
    'Domluvit zasedací pořádek hostů': 'task_arrange_seating',
    'Zajistit dopravu hostů': 'task_arrange_transport',
    'Vyzkoušet svatební šaty a oblek': 'task_try_dress_suit',
    'Připravit svatební program': 'task_prepare_program',
    'Dokončit výzdobu': 'task_finish_decoration',
    'Potvrdit všechny dodavatele': 'task_confirm_vendors',
    'Připravit časový harmonogram dne': 'task_prepare_timeline',
    'Zabalit věci na svatební cestu': 'task_pack_honeymoon',
    'Nacvičit obřad a proslovy': 'task_rehearse_ceremony',
    'Připravit nouzovou sadu': 'task_prepare_emergency_kit',
    'Zkontrolovat počasí': 'task_check_weather',
    'Dokončit platby dodavatelům': 'task_finish_payments',
    'Zkontrolovat všechny přípravy': 'task_check_preparations',
    'Přivítat hosty': 'task_welcome_guests',
    'Poděkovat dodavatelům': 'task_thank_vendors',
    'Užít si svůj velký den!': 'task_enjoy_day',
  };

  if (czechToKeyMap.containsKey(text)) {
    return tr(czechToKeyMap[text]!);
  }

  if (text.startsWith('task_') || text.startsWith('category_')) {
    return tr(text);
  }

  return text;
}

class ChecklistPage extends StatefulWidget {
  const ChecklistPage({super.key});

  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isTabControllerInitialized = false;

  String _selectedCategory = '';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ChecklistManager>().forceRefreshFromCloud();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final categories =
        Provider.of<ChecklistManager>(context, listen: false).categories;

    if (!_isTabControllerInitialized && categories.isNotEmpty) {
      _isTabControllerInitialized = true;
      _tabController = TabController(length: categories.length, vsync: this);
      _selectedCategory = categories.first.id;
    } else if (_isTabControllerInitialized &&
        _tabController.length != categories.length) {
      _tabController.dispose();
      _tabController = TabController(length: categories.length, vsync: this);
      if (_selectedCategory.isEmpty && categories.isNotEmpty) {
        _selectedCategory = categories.first.id;
      }
    }
  }

  @override
  void dispose() {
    if (_isTabControllerInitialized) _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Task> _applyFilters(List<Task> tasks) {
    var filtered = tasks;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              (t.note?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return filtered;
  }

  void _showEditTaskDialog(Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditTaskForm(task: task),
    );
  }

  void _deleteTask(String id) {
    Provider.of<ChecklistManager>(context, listen: false).removeTask(id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(tr('task_deleted'),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          backgroundColor: Colors.orange),
    );
  }

  void _toggleTaskDone(String id) {
    Provider.of<ChecklistManager>(context, listen: false).toggleTaskDone(id);
  }

  Widget _buildTasksList(String categoryId, ChecklistManager m) {
    final all = m.getTasksByCategory(categoryId);
    final list = _applyFilters(all);

    if (all.isEmpty) {
      return _EmptyPlaceholder(
        icon: Icons.task_alt,
        title: tr('no_tasks_yet'),
        subtitle: tr('add_first_task_hint'),
      );
    }
    if (list.isEmpty) {
      return _EmptyPlaceholder(
        icon: Icons.search_off,
        title: tr('no_tasks_match_search'),
      );
    }

    list.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      return a.priority.compareTo(b.priority);
    });

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final t = list[i];
        final overdue = t.dueDate != null &&
            t.dueDate!.isBefore(DateTime.now()) &&
            !t.isDone;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: t.isDone
              ? Colors.grey.shade100
              : overdue
                  ? Colors.red.shade50
                  : null,
          child: ListTile(
            onTap: () => _showEditTaskDialog(t),
            leading: Checkbox(
              value: t.isDone,
              onChanged: (_) => _toggleTaskDone(t.id),
              activeColor: Colors.green,
            ),
            title: Text(
              _getTranslatedText(t.title),
              style: TextStyle(
                decoration: t.isDone ? TextDecoration.lineThrough : null,
                fontWeight: t.priority == 1 ? FontWeight.bold : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (t.note?.isNotEmpty == true)
                  Text(
                    t.note!,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (t.dueDate != null)
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 14, color: overdue ? Colors.red : Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd.MM.yyyy').format(t.dueDate!),
                        style: TextStyle(
                          fontSize: 12,
                          color: overdue ? Colors.red : Colors.grey,
                          fontWeight: overdue ? FontWeight.bold : null,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 30,
                  decoration: BoxDecoration(
                    color: t.priority == 1
                        ? Colors.red
                        : t.priority == 2
                            ? Colors.orange
                            : Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteTask(t.id),
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
      builder: (ctx, m, _) {
        final cats = m.categories;
        if (cats.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(tr('checklist'))),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(tr('checklist')),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.white,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelColor: Colors.white.withOpacity(0.6),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              tabs: cats
                  .map((c) => Tab(text: _getCategoryTranslation(c.id)))
                  .toList(),
              onTap: (i) => setState(() => _selectedCategory = cats[i].id),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: tr('search_tasks'),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: cats.map((c) => _buildTasksList(c.id, m)).toList(),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              final idx = _tabController.index;
              if (idx < cats.length) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _AddTaskForm(categoryId: cats[idx].id),
                );
              }
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _EmptyPlaceholder(
      {required this.icon, required this.title, this.subtitle = ''});

  @override
  Widget build(BuildContext ctx) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(fontSize: 18, color: Colors.grey)),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(subtitle,
                  style: const TextStyle(fontSize: 14, color: Colors.grey)),
            ]
          ],
        ),
      );
}

class _AddTaskForm extends StatefulWidget {
  final String categoryId;
  const _AddTaskForm({required this.categoryId});

  @override
  State<_AddTaskForm> createState() => _AddTaskFormState();
}

class _AddTaskFormState extends State<_AddTaskForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime? _dueDate;
  int _priority = 2;

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final mgr = Provider.of<ChecklistManager>(context, listen: false);
      final newTask = LocalChecklistService.createTask(
        title: _titleController.text.trim(),
        category: widget.categoryId,
        note: _noteController.text.trim(),
        dueDate: _dueDate,
        priority: _priority,
      );

      final success = await mgr.addTask(newTask, context);

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('task_added'),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr('add_task'),
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: tr('task_name'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.task),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? tr('task_name_required')
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        labelText: tr('note_optional'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.note),
                      ),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade400)),
                      leading: const Icon(Icons.calendar_today),
                      title: Text(_dueDate == null
                          ? tr('set_due_date')
                          : DateFormat('dd.MM.yyyy').format(_dueDate!)),
                      trailing: _dueDate != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _dueDate = null))
                          : null,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dueDate ?? DateTime.now(),
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 365)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (picked != null) setState(() => _dueDate = picked);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(tr('priority'), style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Text(tr('priority_high')),
                            selected: _priority == 1,
                            selectedColor: Colors.red.shade100,
                            onSelected: (sel) {
                              if (sel) setState(() => _priority = 1);
                            },
                            avatar: const Icon(Icons.flag, size: 18),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: Text(tr('priority_medium')),
                            selected: _priority == 2,
                            selectedColor: Colors.orange.shade100,
                            onSelected: (sel) {
                              if (sel) setState(() => _priority = 2);
                            },
                            avatar: const Icon(Icons.flag, size: 18),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: Text(tr('priority_low')),
                            selected: _priority == 3,
                            selectedColor: Colors.green.shade100,
                            onSelected: (sel) {
                              if (sel) setState(() => _priority = 3);
                            },
                            avatar: const Icon(Icons.flag, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(tr('cancel')),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _submitForm,
                            child: Text(tr('add_task')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ✅ OPRAVENÝ EDITAČNÍ FORMULÁŘ
class _EditTaskForm extends StatefulWidget {
  final Task task;
  const _EditTaskForm({required this.task});

  @override
  State<_EditTaskForm> createState() => _EditTaskFormState();
}

class _EditTaskFormState extends State<_EditTaskForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController, _noteController;
  late String _selectedCategory;
  DateTime? _dueDate;
  late int _priority;
  late bool _isDone;
  late String _originalTitle;
  late String _translatedTitle;

  @override
  void initState() {
    super.initState();

    _originalTitle = widget.task.title;
    _translatedTitle = _getTranslatedText(widget.task.title);

    _titleController = TextEditingController(text: _translatedTitle);
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
      final mgr = Provider.of<ChecklistManager>(context, listen: false);

      final newTitle = _titleController.text.trim();
      final titleToSave =
          (newTitle == _translatedTitle) ? _originalTitle : newTitle;

      final updated = widget.task.copyWith(
        title: titleToSave,
        category: _selectedCategory,
        note: _noteController.text.trim(),
        dueDate: _dueDate,
        priority: _priority,
        isDone: _isDone,
      );

      mgr.updateTask(updated);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('task_updated'),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = Provider.of<ChecklistManager>(context).categories;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr('edit_task'),
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: tr('task_name'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.task),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? tr('task_name_required')
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: tr('category'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.category),
                      ),
                      value: cats.any((c) => c.id == _selectedCategory)
                          ? _selectedCategory
                          : cats.first.id,
                      items: cats
                          .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(_getCategoryTranslation(c.id))))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        labelText: tr('note_optional'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.note),
                      ),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade400)),
                      leading: const Icon(Icons.calendar_today),
                      title: Text(_dueDate == null
                          ? tr('set_due_date')
                          : DateFormat('dd.MM.yyyy').format(_dueDate!)),
                      trailing: _dueDate != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _dueDate = null))
                          : null,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dueDate ?? DateTime.now(),
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 365)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (picked != null) setState(() => _dueDate = picked);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(tr('priority'), style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Text(tr('priority_high')),
                            selected: _priority == 1,
                            selectedColor: Colors.red.shade100,
                            onSelected: (sel) {
                              if (sel) setState(() => _priority = 1);
                            },
                            avatar: const Icon(Icons.flag, size: 18),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: Text(tr('priority_medium')),
                            selected: _priority == 2,
                            selectedColor: Colors.orange.shade100,
                            onSelected: (sel) {
                              if (sel) setState(() => _priority = 2);
                            },
                            avatar: const Icon(Icons.flag, size: 18),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: Text(tr('priority_low')),
                            selected: _priority == 3,
                            selectedColor: Colors.green.shade100,
                            onSelected: (sel) {
                              if (sel) setState(() => _priority = 3);
                            },
                            avatar: const Icon(Icons.flag, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: Text(tr('task_completed')),
                      value: _isDone,
                      onChanged: (v) => setState(() => _isDone = v),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(tr('cancel')),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _submitForm,
                            child: Text(tr('save_changes')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
