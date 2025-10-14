// lib/screens/guests_screen.dart - PRODUKČNÍ VERZE S GUESTS MANAGER

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/guest.dart';
import '../models/table_arrangement.dart';
import '../services/guests_manager.dart';
import '../services/local_guests_service.dart';

/// Předdefinované skupiny pro výběr při zadávání hosta
final List<String> predefinedGroups = [
  'Nepřiřazená skupina',
  'Novomanželé',
  'Rodina nevěsty',
  'Rodina ženicha',
  'Přátelé nevěsty',
  'Přátelé ženicha',
  'Vzájemní přátelé',
  'Spolupracovníci nevěsty',
  'Spolupracovníci ženicha',
  'Jiné',
];

class GuestsScreen extends StatefulWidget {
  const GuestsScreen({Key? key}) : super(key: key);

  @override
  _GuestsScreenState createState() => _GuestsScreenState();
}

class _GuestsScreenState extends State<GuestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Filtry
  String _selectedGenderFilter = 'Všichni';
  final List<String> _genders = ['Všichni', 'Muž', 'Žena', 'Jiné'];
  
  String _selectedGroupFilter = 'Všichni';
  late List<String> _groups;
  
  String _selectedAttendanceFilter = 'Všichni';
  final List<String> _attendanceOptions = ['Všichni', 'Potvrzená', 'Neutvrzená', 'Neodpovězeno'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    
    // Inicializace skupin
    _groups = ['Všichni', ...predefinedGroups];
    
    // Načtení dat při prvním zobrazení
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final guestsManager = Provider.of<GuestsManager>(context, listen: false);
      guestsManager.forceRefreshFromCloud();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Aplikuje filtry na seznam hostů
  List<Guest> _applyFilters(List<Guest> guests) {
    List<Guest> filteredGuests = List.from(guests);
    
    // Filtrace podle pohlaví
    if (_selectedGenderFilter != 'Všichni') {
      filteredGuests = filteredGuests.where((guest) => guest.gender == _selectedGenderFilter).toList();
    }
    
    // Filtrace podle skupiny
    if (_selectedGroupFilter != 'Všichni') {
      filteredGuests = filteredGuests.where((guest) => guest.group == _selectedGroupFilter).toList();
    }
    
    // Filtrace podle stavu účasti
    if (_selectedAttendanceFilter != 'Všichni') {
      filteredGuests = filteredGuests.where((guest) => guest.attendance == _selectedAttendanceFilter).toList();
    }
    
    // Vyhledávání podle jména
    if (_searchQuery.isNotEmpty) {
      filteredGuests = filteredGuests.where((guest) => 
        guest.name.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    return filteredGuests;
  }

  /// Zobrazí dialog pro přidání hosta
  Future<void> _addGuest() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddGuestForm(),
    );
  }

  /// Zobrazí dialog pro úpravu hosta
  Future<void> _editGuest(Guest guest) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditGuestForm(guest: guest),
    );
  }

  /// Smaže hosta s potvrzením
  Future<void> _deleteGuest(String guestId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Smazat hosta'),
        content: const Text('Opravdu chcete smazat tohoto hosta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ne'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Ano, smazat'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final guestsManager = Provider.of<GuestsManager>(context, listen: false);
      guestsManager.removeGuest(guestId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Host byl odstraněn'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// Widget pro zobrazení přehledu podle pohlaví
  Widget _buildGenderOverview(GuestsManager guestsManager) {
    final stats = guestsManager.getGuestStatistics();
    
    return Container(
      height: 60,
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
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedGenderFilter = 'Muž';
                });
              },
              child: Container(
                color: _selectedGenderFilter == 'Muž' 
                    ? Colors.blue.withOpacity(0.8) 
                    : Colors.blue,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.male, color: Colors.white, size: 24),
                    Text(
                      stats['male'].toString(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedGenderFilter = 'Žena';
                });
              },
              child: Container(
                color: _selectedGenderFilter == 'Žena' 
                    ? Colors.pink.withOpacity(0.8) 
                    : Colors.pink,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.female, color: Colors.white, size: 24),
                    Text(
                      stats['female'].toString(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedGenderFilter = 'Jiné';
                });
              },
              child: Container(
                color: _selectedGenderFilter == 'Jiné' 
                    ? Colors.grey.withOpacity(0.8) 
                    : Colors.grey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.transgender, color: Colors.white, size: 24),
                    Text(
                      stats['other'].toString(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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

  /// Panel s filtry
  void _openFilterPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
                    
                    // Filtr skupiny
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Skupina',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedGroupFilter,
                      items: _groups.map((group) => DropdownMenuItem<String>(
                        value: group,
                        child: Text(group),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedGroupFilter = value!;
                        });
                        setStateSheet(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Filtr pohlaví
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Pohlaví',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedGenderFilter,
                      items: _genders.map((gender) => DropdownMenuItem<String>(
                        value: gender,
                        child: Text(gender),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedGenderFilter = value!;
                        });
                        setStateSheet(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Filtr účasti
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Stav účasti',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedAttendanceFilter,
                      items: _attendanceOptions.map((option) => DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedAttendanceFilter = value!;
                        });
                        setStateSheet(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Vyhledávací pole
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Hledat hosty...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Tlačítko reset
                    Center(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Resetovat filtry'),
                        onPressed: () {
                          setState(() {
                            _selectedGroupFilter = 'Všichni';
                            _selectedGenderFilter = 'Všichni';
                            _selectedAttendanceFilter = 'Všichni';
                            _searchController.clear();
                          });
                          setStateSheet(() {});
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Widget se seznamem hostů
  Widget _buildGuestsList(GuestsManager guestsManager) {
    final filteredGuests = _applyFilters(guestsManager.guests);
    
    if (guestsManager.guests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Zatím zde nejsou žádní hosté',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Přidejte prvního hosta pomocí tlačítka +',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    if (filteredGuests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Žádní hosté neodpovídají filtrům',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: filteredGuests.length,
      itemBuilder: (context, index) {
        final guest = filteredGuests[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            onTap: () => _editGuest(guest),
            leading: CircleAvatar(
              backgroundColor: guest.gender == 'Muž' 
                  ? Colors.blue 
                  : guest.gender == 'Žena' 
                      ? Colors.pink 
                      : Colors.grey,
              child: Icon(
                guest.gender == 'Muž' 
                    ? Icons.male 
                    : guest.gender == 'Žena' 
                        ? Icons.female 
                        : Icons.transgender,
                color: Colors.white,
              ),
            ),
            title: Text(
              guest.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${guest.group} • Stůl: ${guest.table}'),
                Row(
                  children: [
                    Icon(
                      guest.attendance == 'Potvrzená' 
                          ? Icons.check_circle 
                          : guest.attendance == 'Neutvrzená' 
                              ? Icons.cancel 
                              : Icons.help_outline,
                      size: 16,
                      color: guest.attendance == 'Potvrzená' 
                          ? Colors.green 
                          : guest.attendance == 'Neutvrzená' 
                              ? Colors.red 
                              : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      guest.attendance,
                      style: TextStyle(
                        color: guest.attendance == 'Potvrzená' 
                            ? Colors.green 
                            : guest.attendance == 'Neutvrzená' 
                                ? Colors.red 
                                : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteGuest(guest.id),
            ),
          ),
        );
      },
    );
  }

  /// Widget se seznamem stolů
  Widget _buildTablesList(GuestsManager guestsManager) {
    final tables = guestsManager.tables;
    final utilization = guestsManager.getTableUtilization();
    
    if (tables.isEmpty || (tables.length == 1 && tables.first.id == 'unassigned')) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_restaurant, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Zatím zde nejsou žádné stoly',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Přidejte první stůl pomocí tlačítka +',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final table = tables[index];
        final tableInfo = utilization[table.name] ?? {};
        final currentGuests = tableInfo['current'] ?? 0;
        final maxCapacity = tableInfo['max'] ?? 0;
        final isFull = tableInfo['isFull'] ?? false;
        
        // Přeskočíme výchozí stůl "Nepřiřazen" v seznamu
        if (table.id == 'unassigned') {
          return const SizedBox.shrink();
        }
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isFull ? Colors.red : Colors.green,
              child: Icon(
                Icons.table_restaurant,
                color: Colors.white,
              ),
            ),
            title: Text(
              table.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Obsazeno: $currentGuests / $maxCapacity míst',
              style: TextStyle(
                color: isFull ? Colors.red : null,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (maxCapacity > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isFull ? Colors.red : Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${tableInfo['percentage']}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: table.id != 'unassigned' 
                      ? () => _deleteTable(table.id, guestsManager) 
                      : null,
                ),
              ],
            ),
            onTap: () => _showTableDetails(table, guestsManager),
          ),
        );
      },
    );
  }

  /// Smaže stůl
  Future<void> _deleteTable(String tableId, GuestsManager guestsManager) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Smazat stůl'),
        content: const Text(
          'Opravdu chcete smazat tento stůl?\n'
          'Všichni hosté budou přesunuti na "Nepřiřazen".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ne'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Ano, smazat'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await guestsManager.removeTable(tableId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stůl byl odstraněn'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// Zobrazí detail stolu
  void _showTableDetails(TableArrangement table, GuestsManager guestsManager) {
    final guestsAtTable = guestsManager.getGuestsByTable(table.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.table_restaurant),
            const SizedBox(width: 8),
            Expanded(child: Text('Stůl: ${table.name}')),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kapacita: ${guestsAtTable.length} / ${table.maxCapacity > 0 ? table.maxCapacity : "∞"}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (guestsAtTable.isEmpty)
                const Text('Zatím žádní hosté u tohoto stolu')
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: guestsAtTable.length,
                    itemBuilder: (context, index) {
                      final guest = guestsAtTable[index];
                      return ListTile(
                        leading: Icon(
                          guest.gender == 'Muž' 
                              ? Icons.male 
                              : guest.gender == 'Žena' 
                                  ? Icons.female 
                                  : Icons.transgender,
                          color: guest.gender == 'Muž' 
                              ? Colors.blue 
                              : guest.gender == 'Žena' 
                                  ? Colors.pink 
                                  : Colors.grey,
                        ),
                        title: Text(guest.name),
                        subtitle: Text(guest.group),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () {
                            guestsManager.updateGuest(
                              guest.copyWith(table: 'Nepřiřazen')
                            );
                            Navigator.pop(context);
                            _showTableDetails(table, guestsManager);
                          },
                        ),
                      );
                    },
                  ),
                ),
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

  /// Dialog pro přidání stolu
  void _showAddTableDialog() {
    final nameController = TextEditingController();
    final capacityController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Přidat nový stůl'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Název stolu',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: capacityController,
              decoration: const InputDecoration(
                labelText: 'Maximální počet míst',
                border: OutlineInputBorder(),
                helperText: 'Zadejte 0 pro neomezený počet',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final capacity = int.tryParse(capacityController.text.trim()) ?? 0;
              
              if (name.isNotEmpty) {
                final guestsManager = Provider.of<GuestsManager>(context, listen: false);
                
                try {
                  final newTable = LocalGuestsService.createTable(
                    name: name,
                    maxCapacity: capacity,
                  );
                  
                  await guestsManager.addTable(newTable);
                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Stůl byl přidán'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Chyba: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Přidat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GuestsManager>(
      builder: (context, guestsManager, child) {
        // Indikátor synchronizace
        final bool showSyncIndicator = guestsManager.syncState == SyncState.syncing;
        
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Hosté'),
              actions: [
                // Indikátor online/offline stavu
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    guestsManager.isOnline ? Icons.cloud_done : Icons.cloud_off,
                    color: guestsManager.isOnline ? Colors.green : Colors.orange,
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
                        await guestsManager.forceRefreshFromCloud();
                        break;
                      case 'export':
                        // TODO: Implementovat export
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
                      value: 'export',
                      child: Row(
                        children: [
                          Icon(Icons.download, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Exportovat'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(108),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildGenderOverview(guestsManager),
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
            body: Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab Hosté
                    RefreshIndicator(
                      onRefresh: () => guestsManager.forceRefreshFromCloud(),
                      child: _buildGuestsList(guestsManager),
                    ),
                    // Tab Stoly
                    RefreshIndicator(
                      onRefresh: () => guestsManager.forceRefreshFromCloud(),
                      child: _buildTablesList(guestsManager),
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
                              strokeWidth:
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
               if (_tabController.index == 0) {
                 _addGuest();
               } else {
                 _showAddTableDialog();
               }
             },
             child: const Icon(Icons.add),
           ),
         ),
       );
     },
   );
 }
}

/// Formulář pro přidání hosta
class _AddGuestForm extends StatefulWidget {
 const _AddGuestForm({Key? key}) : super(key: key);

 @override
 __AddGuestFormState createState() => __AddGuestFormState();
}

class __AddGuestFormState extends State<_AddGuestForm> {
 final _formKey = GlobalKey<FormState>();
 final _nameController = TextEditingController();
 final _contactController = TextEditingController();
 
 String _selectedGroup = predefinedGroups.first;
 String _selectedGender = 'Muž';
 String _selectedTable = 'Nepřiřazen';
 String _attendanceStatus = 'Neodpovězeno';

 @override
 void dispose() {
   _nameController.dispose();
   _contactController.dispose();
   super.dispose();
 }

 void _submitForm() {
   if (_formKey.currentState!.validate()) {
     final guestsManager = Provider.of<GuestsManager>(context, listen: false);
     
     final newGuest = LocalGuestsService.createGuest(
       name: _nameController.text.trim(),
       group: _selectedGroup,
       contact: _contactController.text.trim(),
       gender: _selectedGender,
       table: _selectedTable,
       attendance: _attendanceStatus,
     );
     
     guestsManager.addGuest(newGuest);
     Navigator.pop(context);
     
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(
         content: Text('Host byl přidán'),
         backgroundColor: Colors.green,
       ),
     );
   }
 }

 @override
 Widget build(BuildContext context) {
   final guestsManager = Provider.of<GuestsManager>(context);
   final tables = guestsManager.tables;
   
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
               'Přidat hosta',
               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
               textAlign: TextAlign.center,
             ),
             const SizedBox(height: 24),
             
             // Jméno
             TextFormField(
               controller: _nameController,
               decoration: const InputDecoration(
                 labelText: 'Jméno a příjmení',
                 border: OutlineInputBorder(),
                 prefixIcon: Icon(Icons.person),
               ),
               textCapitalization: TextCapitalization.words,
               validator: (value) {
                 if (value == null || value.trim().isEmpty) {
                   return 'Zadejte jméno hosta';
                 }
                 return null;
               },
             ),
             const SizedBox(height: 16),
             
             // Skupina
             DropdownButtonFormField<String>(
               decoration: const InputDecoration(
                 labelText: 'Skupina',
                 border: OutlineInputBorder(),
                 prefixIcon: Icon(Icons.group),
               ),
               value: _selectedGroup,
               items: predefinedGroups.map((group) => DropdownMenuItem(
                 value: group,
                 child: Text(group),
               )).toList(),
               onChanged: (value) {
                 setState(() {
                   _selectedGroup = value!;
                 });
               },
             ),
             const SizedBox(height: 16),
             
             // Kontakt
             TextFormField(
               controller: _contactController,
               decoration: const InputDecoration(
                 labelText: 'Kontakt (nepovinné)',
                 border: OutlineInputBorder(),
                 prefixIcon: Icon(Icons.phone),
                 helperText: 'Telefon nebo e-mail',
               ),
               keyboardType: TextInputType.emailAddress,
             ),
             const SizedBox(height: 16),
             
             // Pohlaví
             const Text('Pohlaví', style: TextStyle(fontSize: 16)),
             const SizedBox(height: 8),
             Row(
               children: [
                 Expanded(
                   child: ChoiceChip(
                     label: const Text('Muž'),
                     selected: _selectedGender == 'Muž',
                     onSelected: (selected) {
                       if (selected) {
                         setState(() {
                           _selectedGender = 'Muž';
                         });
                       }
                     },
                     avatar: const Icon(Icons.male, size: 18),
                   ),
                 ),
                 const SizedBox(width: 8),
                 Expanded(
                   child: ChoiceChip(
                     label: const Text('Žena'),
                     selected: _selectedGender == 'Žena',
                     onSelected: (selected) {
                       if (selected) {
                         setState(() {
                           _selectedGender = 'Žena';
                         });
                       }
                     },
                     avatar: const Icon(Icons.female, size: 18),
                   ),
                 ),
                 const SizedBox(width: 8),
                 Expanded(
                   child: ChoiceChip(
                     label: const Text('Jiné'),
                     selected: _selectedGender == 'Jiné',
                     onSelected: (selected) {
                       if (selected) {
                         setState(() {
                           _selectedGender = 'Jiné';
                         });
                       }
                     },
                     avatar: const Icon(Icons.transgender, size: 18),
                   ),
                 ),
               ],
             ),
             const SizedBox(height: 16),
             
             // Stůl
             DropdownButtonFormField<String>(
               decoration: const InputDecoration(
                 labelText: 'Stůl',
                 border: OutlineInputBorder(),
                 prefixIcon: Icon(Icons.table_restaurant),
               ),
               value: _selectedTable,
               items: tables.map((table) => DropdownMenuItem(
                 value: table.name,
                 child: Text(
                   table.name,
                   style: TextStyle(
                     color: table.maxCapacity > 0 && 
                            guestsManager.getGuestsByTable(table.name).length >= table.maxCapacity
                         ? Colors.red
                         : null,
                   ),
                 ),
               )).toList(),
               onChanged: (value) {
                 setState(() {
                   _selectedTable = value!;
                 });
               },
             ),
             const SizedBox(height: 16),
             
             // Stav účasti
             DropdownButtonFormField<String>(
               decoration: const InputDecoration(
                 labelText: 'Stav účasti',
                 border: OutlineInputBorder(),
                 prefixIcon: Icon(Icons.event_available),
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
                     child: const Text('Přidat hosta'),
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

/// Formulář pro úpravu hosta
class _EditGuestForm extends StatefulWidget {
 final Guest guest;
 
 const _EditGuestForm({
   Key? key,
   required this.guest,
 }) : super(key: key);

 @override
 __EditGuestFormState createState() => __EditGuestFormState();
}

class __EditGuestFormState extends State<_EditGuestForm> {
 final _formKey = GlobalKey<FormState>();
 late TextEditingController _nameController;
 late TextEditingController _contactController;
 late String _selectedGroup;
 late String _selectedGender;
 late String _selectedTable;
 late String _attendanceStatus;

 @override
 void initState() {
   super.initState();
   _nameController = TextEditingController(text: widget.guest.name);
   _contactController = TextEditingController(text: widget.guest.contact ?? '');
   _selectedGroup = widget.guest.group;
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

 void _submitForm() {
   if (_formKey.currentState!.validate()) {
     final guestsManager = Provider.of<GuestsManager>(context, listen: false);
     
     final updatedGuest = widget.guest.copyWith(
       name: _nameController.text.trim(),
       group: _selectedGroup,
       contact: _contactController.text.trim(),
       gender: _selectedGender,
       table: _selectedTable,
       attendance: _attendanceStatus,
     );
     
     guestsManager.updateGuest(updatedGuest);
     Navigator.pop(context);
     
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(
         content: Text('Host byl aktualizován'),
         backgroundColor: Colors.green,
       ),
     );
   }
 }

 @override
 Widget build(BuildContext context) {
   final guestsManager = Provider.of<GuestsManager>(context);
   final tables = guestsManager.tables;
   
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
               'Upravit hosta',
               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
               textAlign: TextAlign.center,
             ),
             const SizedBox(height: 24),
             
             // Jméno
             TextFormField(
               controller: _nameController,
               decoration: const InputDecoration(
                 labelText: 'Jméno a příjmení',
                 border: OutlineInputBorder(),
                 prefixIcon: Icon(Icons.person),
               ),
               textCapitalization: TextCapitalization.words,
               validator: (value) {
                 if (value == null || value.trim().isEmpty) {
                   return 'Zadejte jméno hosta';
                 }
                 return null;
               },
             ),
             const SizedBox(height: 16),
             
             // Skupina
             DropdownButtonFormField<String>(
               decoration: const InputDecoration(
                 labelText: 'Skupina',
                 border: OutlineInputBorder(),
                 prefixIcon: Icon(Icons.group),
               ),
               value: predefinedGroups.contains(_selectedGroup) 
                   ? _selectedGroup 
                   : predefinedGroups.first,
               items: predefinedGroups.map((group) => DropdownMenuItem(
                 value: group,
                 child: Text(group),
               )).toList(),
               onChanged: (value) {
                 setState(() {
                   _selectedGroup = value!;
                 });
               },
             ),
             const SizedBox(height: 16),
             
             // Kontakt
             TextFormField(
               controller: _contactController,
               decoration: const InputDecoration(
                 labelText: 'Kontakt (nepovinné)',
                 border: OutlineInputBorder(),
                 prefixIcon: Icon(Icons.phone),
                 helperText: 'Telefon nebo e-mail',
               ),
               keyboardType: TextInputType.emailAddress,
             ),
             const SizedBox(height: 16),
             
             // Pohlaví
             const Text('Pohlaví', style: TextStyle(fontSize: 16)),
             const SizedBox(height: 8),
             Row(
               children: [
                 Expanded(
                   child: ChoiceChip(
                     label: const Text('Muž'),
                     selected: _selectedGender == 'Muž',
                     onSelected: (selected) {
                       if (selected) {
                         setState(() {
                           _selectedGender = 'Muž';
                         });
                       }
                     },
                     avatar: const Icon(Icons.male, size: 18),
                   ),
                 ),
                 const SizedBox(width: 8),
                 Expanded(
                   child: ChoiceChip(
                     label: const Text('Žena'),
                     selected: _selectedGender == 'Žena',
                     onSelected: (selected) {
                       if (selected) {
                         setState(() {
                           _selectedGender = 'Žena';
                         });
                       }
                     },
                     avatar: const Icon(Icons.female, size: 18),
                   ),
                 ),
                 const SizedBox(width: 8),
                 Expanded(
                   child: ChoiceChip(
                     label: const Text('Jiné'),
                     selected: _selectedGender == 'Jiné',
                     onSelected: (selected) {
                       if (selected) {
                         setState(() {
                           _selectedGender = 'Jiné';
                         });
                       }
                     },
                     avatar: const Icon(Icons.transgender, size: 18),
                   ),
                 ),
               ],
             ),
             const SizedBox(height: 16),
             
             // Stůl
             DropdownButtonFormField<String>(
               decoration: const InputDecoration(
                 labelText: 'Stůl',
                 border: OutlineInputBorder(),
                 prefixIcon: Icon(Icons.table_restaurant),
               ),
               value: tables.any((t) => t.name == _selectedTable) 
                   ? _selectedTable 
                   : 'Nepřiřazen',
               items: tables.map((table) => DropdownMenuItem(
                 value: table.name,
                 child: Text(
                   table.name,
                   style: TextStyle(
                     color: table.maxCapacity > 0 && 
                            guestsManager.getGuestsByTable(table.name).length >= table.maxCapacity &&
                            table.name != widget.guest.table
                         ? Colors.red
                         : null,
                   ),
                 ),
               )).toList(),
               onChanged: (value) {
                 setState(() {
                   _selectedTable = value!;
                 });
               },
             ),
             const SizedBox(height: 16),
             
             // Stav účasti
             DropdownButtonFormField<String>(
               decoration: const InputDecoration(
                 labelText: 'Stav účasti',
                 border: OutlineInputBorder(),
                 prefixIcon: Icon(Icons.event_available),
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