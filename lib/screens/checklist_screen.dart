import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../models/subscription.dart'; // Pro ověření předplatného
import '../widgets/subscription_offer_dialog.dart'; // Nový dialog pro nabídku předplatného

//////////////////////////////////////////////////////////////////////////////
// Model úkolu
//////////////////////////////////////////////////////////////////////////////

class Task {
  final String title;
  final bool isDone;
  
  Task({required this.title, this.isDone = false});
  
  Task copyWith({String? title, bool? isDone}) {
    return Task(
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
    );
  }
  
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      title: json['title'] as String,
      isDone: json['isDone'] as bool? ?? false,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'isDone': isDone,
    };
  }
}

//////////////////////////////////////////////////////////////////////////////
// Pomocné třídy
//////////////////////////////////////////////////////////////////////////////

class Logger {
  static void log(String message) {
    debugPrint("[LOG] $message");
  }
}

//////////////////////////////////////////////////////////////////////////////
// ChecklistPage – hlavní obrazovka pro správu úkolů
//////////////////////////////////////////////////////////////////////////////

class ChecklistPage extends StatefulWidget {
  const ChecklistPage({Key? key}) : super(key: key);

  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  // Úkoly rozdělené podle časových rámců, aktualizované pro potřeby průměrného svatebního páru.
  Map<String, List<Task>> _tasksByTime = {
    "12–6 měsíců před svatbou": [
      Task(title: "Rezervovat svatební místo"),
      Task(title: "Vybrat fotografa a kameramana"),
      Task(title: "Stanovit předběžný rozpočet a seznam hostů"),
      Task(title: "Vybrat téma a barevnou paletu"),
      Task(title: "Rezervovat kapelu nebo DJ"),
      Task(title: "Zvážit svatebního koordinátora"),
    ],
    "6–3 měsíců před svatbou": [
      Task(title: "Rozeslat svatební pozvánky"),
      Task(title: "Zamluvit catering"),
      Task(title: "Vybrat svatební šaty a oblek"),
      Task(title: "Objednat svatební dort"),
      Task(title: "Rezervovat květiny a dekorace"),
      Task(title: "Naplánovat harmonogram svatebního dne"),
    ],
    "3–1 měsíc před svatbou": [
      Task(title: "Potvrdit účast hostů"),
      Task(title: "Vybrat svatební prstýnky"),
      Task(title: "Domluvit zasedací pořádek hostů"),
      Task(title: "Zajistit dopravu hostů"),
      Task(title: "Vyzkoušet svatební šaty a oblek"),
      Task(title: "Zařídit drobné přípravné úkony"),
    ],
    "Týden před svatbou": [
      Task(title: "Potvrdit dodavatele"),
      Task(title: "Připravit časový harmonogram dne"),
      Task(title: "Zabalit věci na svatební noc"),
      Task(title: "Nacvičit obřad a projev"),
      Task(title: "Připravit nouzovou sadu"),
    ],
    "Svatební den": [
      Task(title: "Zkontrolovat přípravy a harmonogram"),
      Task(title: "Přivítat hosty"),
      Task(title: "Poděkovat dodavatelům"),
      Task(title: "Užít si svůj den!"),
    ],
  };

  final TextEditingController _taskController = TextEditingController();
  // Výchozí vybraný časový rámec je nastaven na první klíč (všechny sekce jsou nyní přístupné)
  String _selectedTimeFrame = "12–6 měsíců před svatbou";

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  // Načte úkoly ze shared_preferences
  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksJson = prefs.getString('checklist_tasks');
    if (tasksJson != null) {
      try {
        Map<String, dynamic> decoded = jsonDecode(tasksJson);
        Map<String, List<Task>> loadedTasks = {};
        decoded.forEach((timeFrame, tasksList) {
          List<dynamic> list = tasksList as List<dynamic>;
          loadedTasks[timeFrame] = list.map((e) => Task.fromJson(e)).toList();
        });
        setState(() {
          _tasksByTime = loadedTasks;
        });
      } catch (e) {
        Logger.log("Chyba při načítání úkolů: $e");
      }
    }
  }

  // Uloží úkoly do shared_preferences
  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> data = {};
    _tasksByTime.forEach((timeFrame, tasksList) {
      data[timeFrame] = tasksList.map((task) => task.toJson()).toList();
    });
    await prefs.setString('checklist_tasks', jsonEncode(data));
  }

  // Přidá nový úkol do aktuálně vybraného časového rámce
  void _addTask() {
    if (_taskController.text.trim().isNotEmpty) {
      // Kontrola předplatného: pouze předplatitelé mohou přidávat vlastní úkoly.
      final subscription = Provider.of<Subscription?>(context, listen: false);
      if (subscription == null || !subscription.isActive) {
        showDialog(
          context: context,
          builder: (context) => const SubscriptionOfferDialog(),
        );
        return;
      }
      setState(() {
        _tasksByTime[_selectedTimeFrame]?.add(Task(title: _taskController.text.trim()));
        _taskController.clear();
      });
      _saveTasks();
    }
  }

  // Přepne stav úkolu (hotovo/nehotovo)
  void _toggleTask(String timeFrame, int index) {
    setState(() {
      Task task = _tasksByTime[timeFrame]![index];
      _tasksByTime[timeFrame]![index] = task.copyWith(isDone: !task.isDone);
    });
    _saveTasks();
  }

  // Smaže úkol z daného časového rámce
  void _deleteTask(String timeFrame, int index) {
    setState(() {
      _tasksByTime[timeFrame]!.removeAt(index);
    });
    _saveTasks();
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Zobrazíme všechny časové rámce bez filtrování podle data
    List<String> allTimeFrames = _tasksByTime.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Checklist')),
      ),
      body: Column(
        children: [
          // Dropdown pro výběr časového rámce (všechny sekce)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButton<String>(
              value: _selectedTimeFrame,
              isExpanded: true,
              items: allTimeFrames.map((String timeFrame) {
                return DropdownMenuItem<String>(
                  value: timeFrame,
                  child: Text(timeFrame),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedTimeFrame = newValue!;
                });
              },
            ),
          ),
          // Řádek pro přidání nového úkolu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: InputDecoration(
                      labelText: tr('Nový úkol'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  color: Colors.pink,
                  onPressed: _addTask,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Seznam úkolů pro aktuálně vybraný časový rámec
          Expanded(
            child: ListView.builder(
              itemCount: _tasksByTime[_selectedTimeFrame]?.length ?? 0,
              itemBuilder: (context, index) {
                final Task task = _tasksByTime[_selectedTimeFrame]![index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  elevation: 2,
                  child: ListTile(
                    leading: Checkbox(
                      value: task.isDone,
                      onChanged: (_) => _toggleTask(_selectedTimeFrame, index),
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        decoration: task.isDone ? TextDecoration.lineThrough : TextDecoration.none,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      color: Colors.red,
                      onPressed: () => _deleteTask(_selectedTimeFrame, index),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
