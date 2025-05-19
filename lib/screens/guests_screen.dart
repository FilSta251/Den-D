import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Rozšířený model hosta – přidán atribut pro stav účasti.
class Guest {
  final String id;
  final String name;
  final String group;
  final String? contact;
  final String gender; // 'Muž', 'Žena', 'Jiné'
  final String table;  // např. "Nepřiřazen" nebo jméno stolu
  final String attendance; // "Potvrzená", "Neutvrzená", "Neodpovězeno"

  const Guest({
    required this.id,
    required this.name,
    required this.group,
    this.contact,
    required this.gender,
    this.table = 'Nepřiřazen',
    this.attendance = 'Neodpovězeno',
  });

  factory Guest.fromJson(Map<String, dynamic> json) {
    return Guest(
      id: json['id'] as String,
      name: json['name'] as String,
      group: json['group'] as String,
      contact: json['contact'] as String?,
      gender: json['gender'] as String? ?? 'Muž',
      table: json['table'] as String? ?? 'Nepřiřazen',
      attendance: json['attendance'] as String? ?? 'Neodpovězeno',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'group': group,
      'contact': contact,
      'gender': gender,
      'table': table,
      'attendance': attendance,
    };
  }

  Guest copyWith({
    String? id,
    String? name,
    String? group,
    String? contact,
    String? gender,
    String? table,
    String? attendance,
  }) {
    return Guest(
      id: id ?? this.id,
      name: name ?? this.name,
      group: group ?? this.group,
      contact: contact ?? this.contact,
      gender: gender ?? this.gender,
      table: table ?? this.table,
      attendance: attendance ?? this.attendance,
    );
  }
}

/// Předdefinované skupiny pro výběr při zadávání hosta.
final List<Map<String, dynamic>> predefinedGroups = [
  {'name': 'Nepřiřazená skupina'},
  {'name': 'Novomanželé'},
  {'name': 'Rodina nevěsty'},
  {'name': 'Rodina ženicha'},
  {'name': 'Přátelé nevěsty'},
  {'name': 'Přátelé ženicha'},
  {'name': 'Vzájemní přátelé'},
  {'name': 'Spolupracovníci nevěsty'},
  {'name': 'Spolupracovníci ženicha'},
  {'name': 'Jiné'},
];

class GuestsScreen extends StatefulWidget {
  const GuestsScreen({Key? key}) : super(key: key);

  @override
  _GuestsScreenState createState() => _GuestsScreenState();
}

class _GuestsScreenState extends State<GuestsScreen> with SingleTickerProviderStateMixin {
  List<Guest> _allGuests = [
    const Guest(id: '1', name: 'Jan Novák', group: 'Rodina', contact: 'jan@example.com', gender: 'Muž', table: 'Nepřiřazen', attendance: 'Potvrzená'),
    const Guest(id: '2', name: 'Petra Svobodová', group: 'Přátelé', contact: 'petra@example.com', gender: 'Žena', table: 'Nepřiřazen', attendance: 'Neodpovězeno'),
    const Guest(id: '3', name: 'Karel Dvořák', group: 'Kolegové', contact: 'karel@example.com', gender: 'Muž', table: 'Nepřiřazen', attendance: 'Neutvrzená'),
    const Guest(id: '4', name: 'Eva Horáková', group: 'Rodina', contact: 'eva@example.com', gender: 'Žena', table: 'Nepřiřazen', attendance: 'Potvrzená'),
  ];
  List<Guest> _filteredGuests = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Filtry
  String _selectedGenderFilter = 'Všichni';
  final List<String> _genders = ['Všichni', 'Muž', 'Žena', 'Jiné'];
  
  String _selectedGroupFilter = 'Všichni';
  final List<String> _groups = ['Všichni', 'Rodina', 'Přátelé', 'Kolegové'];
  
  String _selectedAttendanceFilter = 'Všichni';
  final List<String> _attendanceOptions = ['Všichni', 'Potvrzená', 'Neutvrzená', 'Neodpovězeno'];

  // Dynamický seznam stolů – zajistíme, že "Nepřiřazen" se objeví jen jednou
  List<Map<String, dynamic>> tables = [
    {'name': 'Nepřiřazen', 'maxCapacity': 0},
    {'name': 'Stůl A', 'maxCapacity': 8},
    {'name': 'Stůl B', 'maxCapacity': 10},
  ];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _filteredGuests = List.from(_allGuests);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _applyFilters();
      });
    });
    _tabController = TabController(length: 2, vsync: this);
    _loadGuests();
    _loadTables();
  }

  Future<void> _loadGuests() async {
    final prefs = await SharedPreferences.getInstance();
    final String? guestsJson = prefs.getString('guests');
    if (guestsJson != null) {
      List<dynamic> decoded = jsonDecode(guestsJson);
      setState(() {
        _allGuests = decoded.map((json) => Guest.fromJson(json)).toList();
        _applyFilters();
      });
    }
  }

  Future<void> _saveGuests() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> jsonList = _allGuests.map((g) => g.toJson()).toList();
    await prefs.setString('guests', jsonEncode(jsonList));
  }

  Future<void> _loadTables() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tablesJson = prefs.getString('tables');
    if (tablesJson != null) {
      setState(() {
        tables = List<Map<String, dynamic>>.from(jsonDecode(tablesJson));
        // Zajistíme, že "Nepřiřazen" se objeví jen jednou
        if (tables.where((t) => t['name'] == 'Nepřiřazen').length > 1) {
          tables.removeWhere((t) => t['name'] == 'Nepřiřazen');
          tables.insert(0, {'name': 'Nepřiřazen', 'maxCapacity': 0});
        }
      });
    }
  }

  Future<void> _saveTables() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tables', jsonEncode(tables));
  }

  void _applyFilters() {
    List<Guest> tempGuests = List.from(_allGuests);
    // Filtrace podle pohlaví
    if (_selectedGenderFilter != 'Všichni') {
      tempGuests = tempGuests.where((guest) => guest.gender == _selectedGenderFilter).toList();
    }
    // Filtrace podle skupiny
    if (_selectedGroupFilter != 'Všichni') {
      tempGuests = tempGuests.where((guest) => guest.group.toLowerCase() == _selectedGroupFilter.toLowerCase()).toList();
    }
    // Filtrace podle stavu účasti
    if (_selectedAttendanceFilter != 'Všichni') {
      tempGuests = tempGuests.where((guest) => guest.attendance == _selectedAttendanceFilter).toList();
    }
    // Vyhledávání podle jména
    if (_searchQuery.isNotEmpty) {
      tempGuests = tempGuests.where((guest) => guest.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    setState(() {
      _filteredGuests = tempGuests;
    });
  }

  Future<void> _addGuest() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _AddGuestForm(
          tables: tables,
          predefinedGroups: predefinedGroups,
          onGuestAdded: (guest) {
            setState(() {
              _allGuests.add(guest);
              _applyFilters();
            });
            _saveGuests();
          },
        );
      },
    );
  }

  Future<void> _editGuest(Guest guest) async {
    final Guest? editedGuest = await showModalBottomSheet<Guest>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _EditGuestForm(
          guest: guest,
          tables: tables,
          predefinedGroups: predefinedGroups,
        );
      },
    );
    if (editedGuest != null) {
      setState(() {
        final index = _allGuests.indexWhere((g) => g.id == guest.id);
        if (index != -1) {
          _allGuests[index] = editedGuest;
          _applyFilters();
        }
      });
      _saveGuests();
    }
  }

  Future<void> _deleteGuest(String guestId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Smazat hosta'),
          content: const Text('Opravdu chcete smazat tohoto hosta?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ne'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ano'),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      setState(() {
        _allGuests.removeWhere((guest) => guest.id == guestId);
        _applyFilters();
      });
      _saveGuests();
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final Guest guest = _filteredGuests.removeAt(oldIndex);
      _filteredGuests.insert(newIndex, guest);
      _allGuests = List.from(_filteredGuests);
    });
    _saveGuests();
  }

  /// Nový widget – zobrazení obdélníků s počty hostů podle pohlaví.
  /// Obdélníky jsou roztažené na celou šíři AppBaru a dělí se na třetiny:
  /// modrá pro "Muž", červená pro "Žena", šedá pro "Jiné".
  Widget _buildGenderRectangles() {
    int maleCount = _allGuests.where((guest) => guest.gender == 'Muž').length;
    int femaleCount = _allGuests.where((guest) => guest.gender == 'Žena').length;
    int otherCount = _allGuests.where((guest) => guest.gender == 'Jiné').length;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            color: Colors.blue,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'M',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    maleCount.toString(),
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 50,
            color: Colors.red,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Ž',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    femaleCount.toString(),
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 50,
            color: Colors.grey,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'J',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    otherCount.toString(),
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Filtrovací panel – s titulem "Filtr hostů" a možnostmi filtrování.
  void _openFilterPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateSheet) {
          return Padding(
            padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filtr hostů',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Skupina',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedGroupFilter,
                    items: _groups
                        .map((group) => DropdownMenuItem<String>(
                              value: group,
                              child: Text(group),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedGroupFilter = value!;
                        _applyFilters();
                      });
                      setStateSheet(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Pohlaví',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedGenderFilter,
                    items: _genders
                        .map((gender) => DropdownMenuItem<String>(
                              value: gender,
                              child: Text(gender),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedGenderFilter = value!;
                        _applyFilters();
                      });
                      setStateSheet(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Stav účasti',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedAttendanceFilter,
                    items: _attendanceOptions
                        .map((option) => DropdownMenuItem<String>(
                              value: option,
                              child: Text(option),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedAttendanceFilter = value!;
                        _applyFilters();
                      });
                      setStateSheet(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Hledat hosty...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedGroupFilter = 'Všichni';
                          _selectedGenderFilter = 'Všichni';
                          _selectedAttendanceFilter = 'Všichni';
                          _searchController.clear();
                          _applyFilters();
                        });
                        setStateSheet(() {});
                      },
                      child: const Text('Resetovat filtry'),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  /// Widget se seznamem hostů.
  Widget _buildParticipantsList() {
    if (_allGuests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.group_off, size: 90, color: Colors.grey),
            SizedBox(height: 8),
            Text('Nejsou zde žádní hosté', style: TextStyle(fontSize: 20, color: Colors.grey)),
          ],
        ),
      );
    }
    return ReorderableListView(
      onReorder: _onReorder,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: List.generate(_filteredGuests.length, (index) {
        final guest = _filteredGuests[index];
        return ListTile(
          key: ValueKey(guest.id),
          onTap: () => _editGuest(guest),
          leading: Icon(Icons.person, color: Colors.pink.shade300, size: 30),
          title: Text(guest.name, style: const TextStyle(fontSize: 18)),
          subtitle: Text('${guest.group} | ${guest.gender} | Stůl: ${guest.table} | Účast: ${guest.attendance}', style: const TextStyle(fontSize: 16)),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () => _deleteGuest(guest.id),
          ),
        );
      }),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hosté'),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _openFilterPanel,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(100.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGenderRectangles(),
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  tabs: const [
                    Tab(text: 'Hosté', icon: Icon(Icons.people)),
                    Tab(text: 'Stoly', icon: Icon(Icons.table_chart)),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Záložka "Hosté"
            Column(
              children: [
                Expanded(child: _buildParticipantsList()),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    onPressed: _addGuest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink.shade300,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.person_add, color: Colors.white),
                    label: const Text('PŘIDAT HOSTA', style: TextStyle(color: Colors.white, fontSize: 18)),
                  ),
                ),
              ],
            ),
            // Záložka "Stoly"
            Column(
              children: [
                Expanded(child: _buildTablesList()),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    onPressed: _showAddTableDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink.shade300,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('PŘIDAT STŮL', style: TextStyle(color: Colors.white, fontSize: 18)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Vrací widget se seznamem stolů.
  Widget _buildTablesList() {
    if (tables.isEmpty || (tables.length == 1 && tables.first['name'] == 'Nepřiřazen')) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.table_chart, size: 90, color: Colors.grey),
            SizedBox(height: 8),
            Text('Žádné stoly', style: TextStyle(fontSize: 20, color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final table = tables[index];
        final count = _allGuests.where((g) => g.table == table['name']).length;
        final int maxCapacity = table['maxCapacity'] ?? 0;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: Icon(Icons.table_chart, color: Colors.pink.shade300, size: 30),
            title: Text(table['name'], style: const TextStyle(fontSize: 18)),
            subtitle: Text('Hosté: $count / ${maxCapacity > 0 ? maxCapacity : '∞'}', style: const TextStyle(fontSize: 16)),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () {
                setState(() {
                  for (var guest in _allGuests) {
                    if (guest.table == table['name']) {
                      final updatedGuest = guest.copyWith(table: 'Nepřiřazen');
                      final index = _allGuests.indexWhere((g) => g.id == guest.id);
                      if (index != -1) _allGuests[index] = updatedGuest;
                    }
                  }
                  tables.removeAt(index);
                });
                _saveGuests();
                _saveTables();
              },
            ),
            onTap: () {
              _showTableDetailsDialog(table);
            },
          ),
        );
      },
    );
  }

  void _showAddTableDialog() {
    final TextEditingController tableNameController = TextEditingController();
    final TextEditingController capacityController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tableNameController,
                  decoration: const InputDecoration(labelText: 'Název stolu'),
                ),
                TextField(
                  controller: capacityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Maximální počet míst'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (tableNameController.text.trim().isNotEmpty) {
                      int maxCapacity = int.tryParse(capacityController.text.trim()) ?? 0;
                      setState(() {
                        if (!tables.any((t) => t['name'] == tableNameController.text.trim())) {
                          tables.add({
                            'name': tableNameController.text.trim(),
                            'maxCapacity': maxCapacity,
                          });
                        }
                      });
                      _saveTables();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Přidat stůl'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTableDetailsDialog(Map table) {
    final assignedGuests = _allGuests.where((g) => g.table == table['name']).toList();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Stůl: ${table['name']}'),
          content: assignedGuests.isEmpty
              ? const Text('Žádní hosté přiřazeni.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: assignedGuests.map<Widget>((guest) {
                    return ListTile(
                      title: Text(guest.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            final updatedGuest = guest.copyWith(table: 'Nepřiřazen');
                            final index = _allGuests.indexWhere((g) => g.id == guest.id);
                            if (index != -1) _allGuests[index] = updatedGuest;
                          });
                          _saveGuests();
                          Navigator.pop(context);
                        },
                      ),
                    );
                  }).toList(),
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
  }
}

/// Persistentní formulář pro přidání hosta
class _AddGuestForm extends StatefulWidget {
  final List<Map<String, dynamic>> tables;
  final List<Map<String, dynamic>> predefinedGroups;
  final Function(Guest) onGuestAdded;

  const _AddGuestForm({
    Key? key,
    required this.tables,
    required this.predefinedGroups,
    required this.onGuestAdded,
  }) : super(key: key);

  @override
  __AddGuestFormState createState() => __AddGuestFormState();
}

class __AddGuestFormState extends State<_AddGuestForm> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedGroup = 'Nepřiřazená skupina';
  final TextEditingController _contactController = TextEditingController();
  String _selectedGender = 'Muž';
  String _selectedTable = 'Nepřiřazen';
  String _attendanceStatus = 'Neodpovězeno';

  @override
  void initState() {
    super.initState();
    if (widget.tables.isNotEmpty) {
      _selectedTable = widget.tables.firstWhere((t) => t['name'] == 'Nepřiřazen', orElse: () => widget.tables.first)['name'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Přidat hosta',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Jméno'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Skupina',
                border: OutlineInputBorder(),
              ),
              value: _selectedGroup,
              items: widget.predefinedGroups
                  .map((group) => DropdownMenuItem<String>(
                        value: group['name'] as String,
                        child: Text(group['name'] as String),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedGroup = value!;
                });
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contactController,
              decoration: const InputDecoration(labelText: 'Kontakt'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: [
                ChoiceChip(
                  label: const Text('Muž'),
                  selected: _selectedGender == 'Muž',
                  selectedColor: Colors.pink.shade700,
                  labelStyle: TextStyle(color: _selectedGender == 'Muž' ? Colors.white : Colors.black),
                  onSelected: (selected) {
                    setState(() {
                      _selectedGender = 'Muž';
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Žena'),
                  selected: _selectedGender == 'Žena',
                  selectedColor: Colors.pink.shade700,
                  labelStyle: TextStyle(color: _selectedGender == 'Žena' ? Colors.white : Colors.black),
                  onSelected: (selected) {
                    setState(() {
                      _selectedGender = 'Žena';
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Jiné'),
                  selected: _selectedGender == 'Jiné',
                  selectedColor: Colors.pink.shade700,
                  labelStyle: TextStyle(color: _selectedGender == 'Jiné' ? Colors.white : Colors.black),
                  onSelected: (selected) {
                    setState(() {
                      _selectedGender = 'Jiné';
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Stůl',
                border: OutlineInputBorder(),
              ),
              value: _selectedTable,
              items: [
                if (!widget.tables.any((t) => t['name'] == 'Nepřiřazen'))
                  const DropdownMenuItem(value: 'Nepřiřazen', child: Text('Nepřiřazen')),
                ...widget.tables.map((table) => DropdownMenuItem(
                      value: table['name'],
                      child: Text(table['name']),
                    )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedTable = value!;
                });
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Stav účasti',
                border: OutlineInputBorder(),
              ),
              value: _attendanceStatus,
              items: const [
                DropdownMenuItem(value: 'Potvrzená', child: Text('Potvrzená')),
                DropdownMenuItem(value: 'Neutvrzená', child: Text('Neutvrzená')),
                DropdownMenuItem(value: 'Neodpovězeno', child: Text('Neodpovězeno')),
              ],
              onChanged: (value) {
                setState(() {
                  _attendanceStatus = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_nameController.text.trim().isNotEmpty && _selectedGroup.isNotEmpty) {
                  final guest = Guest(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: _nameController.text.trim(),
                    group: _selectedGroup,
                    contact: _contactController.text.trim(),
                    gender: _selectedGender,
                    table: _selectedTable,
                    attendance: _attendanceStatus,
                  );
                  widget.onGuestAdded(guest);
                  _nameController.clear();
                  _contactController.clear();
                  setState(() {
                    _selectedGender = 'Muž';
                    _selectedGroup = widget.predefinedGroups.first['name'] as String;
                    _selectedTable = widget.tables.isNotEmpty ? widget.tables.first['name'] as String : 'Nepřiřazen';
                    _attendanceStatus = 'Neodpovězeno';
                  });
                }
              },
              child: const Text('PŘIDAT HOSTA'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Persistentní formulář pro úpravu hosta
class _EditGuestForm extends StatefulWidget {
  final Guest guest;
  final List<Map<String, dynamic>> tables;
  final List<Map<String, dynamic>> predefinedGroups;

  const _EditGuestForm({
    Key? key,
    required this.guest,
    required this.tables,
    required this.predefinedGroups,
  }) : super(key: key);

  @override
  __EditGuestFormState createState() => __EditGuestFormState();
}

class __EditGuestFormState extends State<_EditGuestForm> {
  late TextEditingController _nameController;
  late String _selectedGroup;
  late TextEditingController _contactController;
  late String _selectedGender;
  late String _selectedTable;
  late String _attendanceStatus;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.guest.name);
    _selectedGroup = widget.guest.group;
    _contactController = TextEditingController(text: widget.guest.contact);
    _selectedGender = widget.guest.gender;
    _selectedTable = widget.guest.table;
    _attendanceStatus = widget.guest.attendance;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Upravit hosta',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Jméno'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Skupina',
                border: OutlineInputBorder(),
              ),
              value: _selectedGroup,
              items: widget.predefinedGroups
                  .map((group) => DropdownMenuItem<String>(
                        value: group['name'] as String,
                        child: Text(group['name'] as String),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedGroup = value!;
                });
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contactController,
              decoration: const InputDecoration(labelText: 'Kontakt'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: [
                ChoiceChip(
                  label: const Text('Muž'),
                  selected: _selectedGender == 'Muž',
                  selectedColor: Colors.pink.shade700,
                  labelStyle: TextStyle(color: _selectedGender == 'Muž' ? Colors.white : Colors.black),
                  onSelected: (selected) {
                    setState(() {
                      _selectedGender = 'Muž';
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Žena'),
                  selected: _selectedGender == 'Žena',
                  selectedColor: Colors.pink.shade700,
                  labelStyle: TextStyle(color: _selectedGender == 'Žena' ? Colors.white : Colors.black),
                  onSelected: (selected) {
                    setState(() {
                      _selectedGender = 'Žena';
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Jiné'),
                  selected: _selectedGender == 'Jiné',
                  selectedColor: Colors.pink.shade700,
                  labelStyle: TextStyle(color: _selectedGender == 'Jiné' ? Colors.white : Colors.black),
                  onSelected: (selected) {
                    setState(() {
                      _selectedGender = 'Jiné';
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Stůl',
                border: OutlineInputBorder(),
              ),
              value: _selectedTable,
              items: [
                if (!widget.tables.any((t) => t['name'] == 'Nepřiřazen'))
                  const DropdownMenuItem(value: 'Nepřiřazen', child: Text('Nepřiřazen')),
                ...widget.tables.map((table) => DropdownMenuItem(
                      value: table['name'],
                      child: Text(table['name']),
                    )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedTable = value!;
                });
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Stav účasti',
                border: OutlineInputBorder(),
              ),
              value: _attendanceStatus,
              items: const [
                DropdownMenuItem(value: 'Potvrzená', child: Text('Potvrzená')),
                DropdownMenuItem(value: 'Neutvrzená', child: Text('Neutvrzená')),
                DropdownMenuItem(value: 'Neodpovězeno', child: Text('Neodpovězeno')),
              ],
              onChanged: (value) {
                setState(() {
                  _attendanceStatus = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final updatedGuest = widget.guest.copyWith(
                  name: _nameController.text.trim(),
                  group: _selectedGroup,
                  contact: _contactController.text.trim(),
                  gender: _selectedGender,
                  table: _selectedTable,
                  attendance: _attendanceStatus,
                );
                Navigator.pop(context, updatedGuest);
              },
              child: const Text('Uložit'),
            ),
          ],
        ),
      ),
    );
  }
}
