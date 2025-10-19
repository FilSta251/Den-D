/// lib/screens/guests_screen.dart - PRODUKČNÍ VERZE S GUESTS MANAGER
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/guest.dart';
import '../models/table_arrangement.dart';
import '../services/guests_manager.dart';
import '../services/local_guests_service.dart';
import '../providers/subscription_provider.dart';
import '../widgets/subscription_offer_dialog.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/services.dart';

/// Předdefinované skupiny pro výběr při zadávání hosta
List<String> get predefinedGroups => [
      tr('group_unassigned'),
      tr('group_newlyweds'),
      tr('group_bride_family'),
      tr('group_groom_family'),
      tr('group_bride_friends'),
      tr('group_groom_friends'),
      tr('group_mutual_friends'),
      tr('group_bride_coworkers'),
      tr('group_groom_coworkers'),
      tr('group_other'),
    ];

class GuestsScreen extends StatefulWidget {
  const GuestsScreen({super.key});

  @override
  _GuestsScreenState createState() => _GuestsScreenState();
}

class _GuestsScreenState extends State<GuestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Filtry
  String _selectedGenderFilter = '';
  List<String> _genders = [];

  String _selectedGroupFilter = '';
  List<String> _groups = [];

  String _selectedAttendanceFilter = '';
  List<String> _attendanceOptions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });

    // Inicializace filtrů
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _selectedGenderFilter = tr('filter_all');
        _selectedGroupFilter = tr('filter_all');
        _selectedAttendanceFilter = tr('filter_all');

        _genders = [
          tr('filter_all'),
          tr('guest.gender_male'),
          tr('guest.gender_female'),
          tr('guest.gender_other')
        ];
        _groups = [tr('filter_all'), ...predefinedGroups];
        _attendanceOptions = [
          tr('filter_all'),
          tr('guest.attendance_confirmed'),
          tr('guest.attendance_declined'),
          tr('guest.attendance_pending')
        ];
      });
    });

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

    // ✅ Filtrace podle pohlaví - OPRAVENO - porovnává konstanty
    if (_selectedGenderFilter != tr('filter_all')) {
      String? genderValue;
      if (_selectedGenderFilter == tr('guest.gender_male')) {
        genderValue = GuestConstants.genderMale;
      } else if (_selectedGenderFilter == tr('guest.gender_female')) {
        genderValue = GuestConstants.genderFemale;
      } else if (_selectedGenderFilter == tr('guest.gender_other')) {
        genderValue = GuestConstants.genderOther;
      }

      if (genderValue != null) {
        filteredGuests = filteredGuests
            .where((guest) => guest.gender == genderValue)
            .toList();
      }
    }

    // Filtrace podle skupiny
    if (_selectedGroupFilter != tr('filter_all')) {
      filteredGuests = filteredGuests
          .where((guest) => guest.group == _selectedGroupFilter)
          .toList();
    }

    // ✅ Filtrace podle stavu účasti - OPRAVENO - porovnává konstanty
    if (_selectedAttendanceFilter != tr('filter_all')) {
      String? attendanceValue;
      if (_selectedAttendanceFilter == tr('guest.attendance_confirmed')) {
        attendanceValue = GuestConstants.attendanceConfirmed;
      } else if (_selectedAttendanceFilter == tr('guest.attendance_declined')) {
        attendanceValue = GuestConstants.attendanceDeclined;
      } else if (_selectedAttendanceFilter == tr('guest.attendance_pending')) {
        attendanceValue = GuestConstants.attendancePending;
      }

      if (attendanceValue != null) {
        filteredGuests = filteredGuests
            .where((guest) => guest.attendance == attendanceValue)
            .toList();
      }
    }

    // Vyhledávání podle jména
    if (_searchQuery.isNotEmpty) {
      filteredGuests = filteredGuests
          .where((guest) =>
              guest.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    return filteredGuests;
  }

  /// Zobrazí dialog pro přidání hosta
  Future<void> _addGuest() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddGuestForm(),
    );
  }

  /// Zobrazí dialog pro úpravu hosta
  Future<void> _editGuest(Guest guest) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditGuestForm(guest: guest),
    );
  }

  /// Smaže hosta s potvrzením
  Future<void> _deleteGuest(String guestId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('delete_guest_title')),
        content: Text(tr('delete_guest_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(tr('delete_confirm')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final guestsManager = Provider.of<GuestsManager>(context, listen: false);
      guestsManager.removeGuest(guestId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('guest_deleted')),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// Widget pro zobrazení přehledu podle pohlaví
  Widget _buildGenderOverview(GuestsManager guestsManager) {
    // ✅ Spočítáme statistiky podle KONSTANT
    final maleCount = guestsManager.guests
        .where((g) => g.gender == GuestConstants.genderMale)
        .length;
    final femaleCount = guestsManager.guests
        .where((g) => g.gender == GuestConstants.genderFemale)
        .length;
    final otherCount = guestsManager.guests
        .where((g) => g.gender == GuestConstants.genderOther)
        .length;

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
                  _selectedGenderFilter = tr('guest.gender_male');
                });
              },
              child: Container(
                color: _selectedGenderFilter == tr('guest.gender_male')
                    ? Colors.blue.withOpacity(0.8)
                    : Colors.blue,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.male, color: Colors.white, size: 24),
                    Text(
                      maleCount.toString(),
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
                  _selectedGenderFilter = tr('guest.gender_female');
                });
              },
              child: Container(
                color: _selectedGenderFilter == tr('guest.gender_female')
                    ? Colors.pink.withOpacity(0.8)
                    : Colors.pink,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.female, color: Colors.white, size: 24),
                    Text(
                      femaleCount.toString(),
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
                  _selectedGenderFilter = tr('guest.gender_other');
                });
              },
              child: Container(
                color: _selectedGenderFilter == tr('guest.gender_other')
                    ? Colors.grey.withOpacity(0.8)
                    : Colors.grey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.transgender,
                        color: Colors.white, size: 24),
                    Text(
                      otherCount.toString(),
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
      useSafeArea: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tr('filter_guests'),
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
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
                        decoration: InputDecoration(
                          labelText: tr('group'),
                          border: const OutlineInputBorder(),
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
                          });
                          setStateSheet(() {});
                        },
                      ),
                      const SizedBox(height: 16),

                      // Filtr pohlaví
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: tr('gender'),
                          border: const OutlineInputBorder(),
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
                          });
                          setStateSheet(() {});
                        },
                      ),
                      const SizedBox(height: 16),

                      // Filtr účasti
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: tr('attendance_status'),
                          border: const OutlineInputBorder(),
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
                          });
                          setStateSheet(() {});
                        },
                      ),
                      const SizedBox(height: 16),

                      // Vyhledávací pole
                      TextField(
                        controller: _searchController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: tr('search_guests'),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Tlačítko reset
                      Center(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: Text(tr('reset_filters')),
                          onPressed: () {
                            setState(() {
                              _selectedGroupFilter = tr('filter_all');
                              _selectedGenderFilter = tr('filter_all');
                              _selectedAttendanceFilter = tr('filter_all');
                              _searchController.clear();
                            });
                            setStateSheet(() {});
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
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
              tr('no_guests_yet'),
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              tr('add_first_guest_hint'),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
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
            Text(
              tr('no_guests_match_filters'),
              style: const TextStyle(fontSize: 18, color: Colors.grey),
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

        // ✅ Použij pomocné metody z Guest modelu
        Color genderColor = guest.gender == GuestConstants.genderMale
            ? Colors.blue
            : guest.gender == GuestConstants.genderFemale
                ? Colors.pink
                : Colors.grey;

        IconData genderIcon = guest.gender == GuestConstants.genderMale
            ? Icons.male
            : guest.gender == GuestConstants.genderFemale
                ? Icons.female
                : Icons.transgender;

        IconData attendanceIcon =
            guest.attendance == GuestConstants.attendanceConfirmed
                ? Icons.check_circle
                : guest.attendance == GuestConstants.attendanceDeclined
                    ? Icons.cancel
                    : Icons.help_outline;

        Color attendanceColor =
            guest.attendance == GuestConstants.attendanceConfirmed
                ? Colors.green
                : guest.attendance == GuestConstants.attendanceDeclined
                    ? Colors.red
                    : Colors.orange;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            onTap: () => _editGuest(guest),
            leading: CircleAvatar(
              backgroundColor: genderColor,
              child: Icon(genderIcon, color: Colors.white),
            ),
            title: Text(
              guest.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${guest.group} • ${tr('table')}: ${guest.tableDisplay}'),
                Row(
                  children: [
                    Icon(attendanceIcon, size: 16, color: attendanceColor),
                    const SizedBox(width: 4),
                    Text(
                      guest.attendanceDisplay,
                      style: TextStyle(
                        color: attendanceColor,
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

    if (tables.isEmpty ||
        (tables.length == 1 && tables.first.id == 'unassigned')) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_restaurant, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              tr('no_tables_yet'),
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              tr('add_first_table_hint'),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
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

        // Přeskočíme výchozí stůl v seznamu
        if (table.id == 'unassigned') {
          return const SizedBox.shrink();
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isFull ? Colors.red : Colors.green,
              child: const Icon(
                Icons.table_restaurant,
                color: Colors.white,
              ),
            ),
            title: Text(
              table.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${tr('occupied')}: $currentGuests / $maxCapacity ${tr('seats')}',
              style: TextStyle(
                color: isFull ? Colors.red : null,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (maxCapacity > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
        title: Text(tr('delete_table_title')),
        content: Text(tr('delete_table_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(tr('delete_confirm')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await guestsManager.removeTable(tableId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('table_deleted')),
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
            Expanded(child: Text('${tr('table')}: ${table.name}')),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${tr('capacity')}: ${guestsAtTable.length} / ${table.maxCapacity > 0 ? table.maxCapacity : tr('unlimited')}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (guestsAtTable.isEmpty)
                Text(tr('no_guests_at_table'))
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: guestsAtTable.length,
                    itemBuilder: (context, index) {
                      final guest = guestsAtTable[index];

                      IconData genderIcon =
                          guest.gender == GuestConstants.genderMale
                              ? Icons.male
                              : guest.gender == GuestConstants.genderFemale
                                  ? Icons.female
                                  : Icons.transgender;

                      Color genderColor =
                          guest.gender == GuestConstants.genderMale
                              ? Colors.blue
                              : guest.gender == GuestConstants.genderFemale
                                  ? Colors.pink
                                  : Colors.grey;

                      return ListTile(
                        leading: Icon(genderIcon, color: genderColor),
                        title: Text(guest.name),
                        subtitle: Text(guest.group),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle,
                              color: Colors.red),
                          onPressed: () {
                            guestsManager.updateGuest(guest.copyWith(
                                table: GuestConstants.unassignedTable));
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
            child: Text(tr('close')),
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
        title: Text(tr('add_table_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: tr('table_name'),
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: capacityController,
              decoration: InputDecoration(
                labelText: tr('table_max_seats'),
                border: const OutlineInputBorder(),
                helperText: tr('table_unlimited_hint'),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final capacity =
                  int.tryParse(capacityController.text.trim()) ?? 0;

              if (name.isNotEmpty) {
                final guestsManager =
                    Provider.of<GuestsManager>(context, listen: false);

                try {
                  final newTable = LocalGuestsService.createTable(
                    name: name,
                    maxCapacity: capacity,
                  );

                  await guestsManager.addTable(newTable);
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(tr('table_added')),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${tr('error')}: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(tr('add')),
          ),
        ],
      ),
    );
  }

  /// Export hostů do PDF
  Future<void> _exportGuestsToPDF(GuestsManager guestsManager) async {
    try {
      final pdf = pw.Document();

      // Získání dat
      final guests = guestsManager.guests;
      final tables = guestsManager.tables;

      // ✅ Spočítáme statistiky podle KONSTANT
      int maleCount =
          guests.where((g) => g.gender == GuestConstants.genderMale).length;
      int femaleCount =
          guests.where((g) => g.gender == GuestConstants.genderFemale).length;
      int otherCount =
          guests.where((g) => g.gender == GuestConstants.genderOther).length;
      int totalCount = guests.length;

      // Načtení fontu s diakritikou
      final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final fontBoldData =
          await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      final ttf = pw.Font.ttf(fontData);
      final ttfBold = pw.Font.ttf(fontBoldData);

      // Stránka 1: Přehled
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
          build: (pw.Context pdfContext) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Nadpis
                pw.Text(
                  tr('guests'),
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                    font: ttfBold,
                  ),
                ),
                pw.SizedBox(height: 20),

                // Statistiky
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 2),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        tr('overview'),
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          font: ttfBold,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatBox('${tr('total')}: $totalCount', ttfBold),
                          _buildStatBox(
                              '${tr('guest.gender_male')}: $maleCount',
                              ttfBold),
                          _buildStatBox(
                              '${tr('guest.gender_female')}: $femaleCount',
                              ttfBold),
                          _buildStatBox(
                              '${tr('guest.gender_other')}: $otherCount',
                              ttfBold),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Seznam hostů
                pw.Text(
                  tr('guest_list'),
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    font: ttfBold,
                  ),
                ),
                pw.SizedBox(height: 12),

                // Tabulka s hosty
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    // Hlavička
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _buildTableHeader(tr('guest_name'), ttfBold),
                        _buildTableHeader(tr('group'), ttfBold),
                        _buildTableHeader(tr('gender'), ttfBold),
                        _buildTableHeader(tr('table'), ttfBold),
                        _buildTableHeader(tr('attendance_status'), ttfBold),
                      ],
                    ),
                    // Řádky s hosty - ✅ POUŽIJ .genderDisplay a .attendanceDisplay
                    ...guests
                        .map((guest) => pw.TableRow(
                              children: [
                                _buildTableCell(guest.name, ttf),
                                _buildTableCell(guest.group, ttf),
                                _buildTableCell(guest.genderDisplay, ttf),
                                _buildTableCell(guest.tableDisplay, ttf),
                                _buildTableCell(guest.attendanceDisplay, ttf),
                              ],
                            ))
                        .toList(),
                  ],
                ),
              ],
            );
          },
        ),
      );

      // Stránka 2: Rozložení stolů
      if (tables.length > 1) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
            build: (pw.Context pdfContext) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    tr('tables'),
                    style: pw.TextStyle(
                      fontSize: 32,
                      fontWeight: pw.FontWeight.bold,
                      font: ttfBold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  ...tables.where((t) => t.id != 'unassigned').map((table) {
                    final tableGuests =
                        guestsManager.getGuestsByTable(table.name);
                    return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 16),
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.blue, width: 2),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                table.name,
                                style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                  font: ttfBold,
                                ),
                              ),
                              pw.Text(
                                '${tableGuests.length} / ${table.maxCapacity > 0 ? table.maxCapacity.toString() : tr('unlimited')}',
                                style: pw.TextStyle(fontSize: 14, font: ttf),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 8),
                          if (tableGuests.isNotEmpty)
                            pw.Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: tableGuests
                                  .map((g) => pw.Text('• ${g.name}',
                                      style: pw.TextStyle(
                                          fontSize: 12, font: ttf)))
                                  .toList(),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              );
            },
          ),
        );
      }

      // Uložení PDF
      final bytes = await pdf.save();

      // Uložení PDF na zařízení
      final directory = await getApplicationDocumentsDirectory();
      final filePath =
          '${directory.path}/guests_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Otevření PDF
      await OpenFile.open(filePath);

      // Zobrazení hlášky o úspěchu
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('export_success')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Zobrazení chybové hlášky
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Pomocné funkce pro PDF - S FONTEM
  pw.Widget _buildStatBox(String text, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
            fontSize: 14, fontWeight: pw.FontWeight.bold, font: font),
      ),
    );
  }

  pw.Widget _buildTableHeader(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold, fontSize: 12, font: font),
      ),
    );
  }

  pw.Widget _buildTableCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 10, font: font)),
    );
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
    return Consumer<GuestsManager>(
      builder: (context, guestsManager, child) {
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(tr('guests')),
              actions: [
                _buildPremiumButton(),
                // Indikátor online/offline stavu
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    guestsManager.isOnline ? Icons.cloud_done : Icons.cloud_off,
                    color:
                        guestsManager.isOnline ? Colors.green : Colors.orange,
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
                        await _exportGuestsToPDF(guestsManager);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          const Icon(Icons.refresh, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(tr('refresh_from_cloud')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'export',
                      child: Row(
                        children: [
                          const Icon(Icons.download, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(tr('export')),
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
                      tabs: [
                        Tab(text: tr('guests'), icon: const Icon(Icons.people)),
                        Tab(
                            text: tr('tables'),
                            icon: const Icon(Icons.table_chart)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            body: TabBarView(
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
  const _AddGuestForm({super.key});

  @override
  __AddGuestFormState createState() => __AddGuestFormState();
}

class __AddGuestFormState extends State<_AddGuestForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();

  late String _selectedGroup;
  // ✅ UKLÁDÁME KONSTANTY místo českých textů
  String _selectedGender = GuestConstants.genderMale;
  String _selectedTable = GuestConstants.unassignedTable;
  String _attendanceStatus = GuestConstants.attendancePending;

  @override
  void initState() {
    super.initState();
    _selectedGroup = predefinedGroups.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final guestsManager = Provider.of<GuestsManager>(context, listen: false);

      final newGuest = LocalGuestsService.createGuest(
        name: _nameController.text.trim(),
        group: _selectedGroup,
        contact: _contactController.text.trim(),
        gender: _selectedGender, // již je konstanta
        table: _selectedTable, // již je konstanta
        attendance: _attendanceStatus, // již je konstanta
      );

      final success = await guestsManager.addGuest(newGuest, context);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('guest_added')),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  List<TableArrangement> _sortTablesWithUnassignedLast(
      List<TableArrangement> tables) {
    final unassignedTables = tables.where((t) => t.id == 'unassigned').toList();
    final regularTables = tables.where((t) => t.id != 'unassigned').toList();
    return [...regularTables, ...unassignedTables];
  }

  @override
  Widget build(BuildContext context) {
    final guestsManager = Provider.of<GuestsManager>(context);
    final sortedTables = _sortTablesWithUnassignedLast(guestsManager.tables);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
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
                    tr('add_guest'),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Jméno
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: tr('guest_name'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return tr('guest_name_required');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Skupina
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: tr('group'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.group),
                    ),
                    value: _selectedGroup,
                    items: predefinedGroups
                        .map((group) => DropdownMenuItem(
                              value: group,
                              child: Text(group),
                            ))
                        .toList(),
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
                    decoration: InputDecoration(
                      labelText: tr('contact_optional'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.phone),
                      helperText: tr('contact_helper'),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),

                  // Pohlaví - ✅ UKLÁDÁ KONSTANTY, ZOBRAZUJE PŘEKLADY
                  Text(tr('gender'), style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text(tr('guest.gender_male')),
                          selected:
                              _selectedGender == GuestConstants.genderMale,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedGender = GuestConstants.genderMale;
                              });
                            }
                          },
                          avatar: const Icon(Icons.male, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Text(tr('guest.gender_female')),
                          selected:
                              _selectedGender == GuestConstants.genderFemale,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedGender = GuestConstants.genderFemale;
                              });
                            }
                          },
                          avatar: const Icon(Icons.female, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Text(tr('guest.gender_other')),
                          selected:
                              _selectedGender == GuestConstants.genderOther,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedGender = GuestConstants.genderOther;
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
                    decoration: InputDecoration(
                      labelText: tr('table'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.table_restaurant),
                    ),
                    value: _selectedTable,
                    items: sortedTables
                        .map((table) => DropdownMenuItem(
                              value: table.id == 'unassigned'
                                  ? GuestConstants.unassignedTable
                                  : table.name,
                              child: Text(
                                table.id == 'unassigned'
                                    ? tr('guest.unassigned_table')
                                    : table.name,
                                style: TextStyle(
                                  color: table.maxCapacity > 0 &&
                                          guestsManager
                                                  .getGuestsByTable(table.name)
                                                  .length >=
                                              table.maxCapacity
                                      ? Colors.red
                                      : null,
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTable = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Stav účasti - ✅ UKLÁDÁ KONSTANTY, ZOBRAZUJE PŘEKLADY
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: tr('attendance_status'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.event_available),
                    ),
                    value: _attendanceStatus,
                    items: [
                      DropdownMenuItem(
                          value: GuestConstants.attendanceConfirmed,
                          child: Text(tr('guest.attendance_confirmed'))),
                      DropdownMenuItem(
                          value: GuestConstants.attendanceDeclined,
                          child: Text(tr('guest.attendance_declined'))),
                      DropdownMenuItem(
                          value: GuestConstants.attendancePending,
                          child: Text(tr('guest.attendance_pending'))),
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
                          child: Text(tr('cancel')),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _submitForm,
                          child: Text(tr('add_guest')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
    super.key,
    required this.guest,
  });

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
    _contactController =
        TextEditingController(text: widget.guest.contact ?? '');
    _selectedGroup = widget.guest.group;
    _selectedGender = widget.guest.gender; // již je konstanta z migrace
    _selectedTable = widget.guest.table; // již je konstanta z migrace
    _attendanceStatus = widget.guest.attendance; // již je konstanta z migrace
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
        SnackBar(
          content: Text(tr('guest_updated')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  List<TableArrangement> _sortTablesWithUnassignedLast(
      List<TableArrangement> tables) {
    final unassignedTables = tables.where((t) => t.id == 'unassigned').toList();
    final regularTables = tables.where((t) => t.id != 'unassigned').toList();
    return [...regularTables, ...unassignedTables];
  }

  @override
  Widget build(BuildContext context) {
    final guestsManager = Provider.of<GuestsManager>(context);
    final sortedTables = _sortTablesWithUnassignedLast(guestsManager.tables);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
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
                    tr('edit_guest'),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Jméno
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: tr('guest_name'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return tr('guest_name_required');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Skupina
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: tr('group'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.group),
                    ),
                    value: predefinedGroups.contains(_selectedGroup)
                        ? _selectedGroup
                        : predefinedGroups.first,
                    items: predefinedGroups
                        .map((group) => DropdownMenuItem(
                              value: group,
                              child: Text(group),
                            ))
                        .toList(),
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
                    decoration: InputDecoration(
                      labelText: tr('contact_optional'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.phone),
                      helperText: tr('contact_helper'),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),

                  // Pohlaví - ✅ UKLÁDÁ KONSTANTY, ZOBRAZUJE PŘEKLADY
                  Text(tr('gender'), style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text(tr('guest.gender_male')),
                          selected:
                              _selectedGender == GuestConstants.genderMale,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedGender = GuestConstants.genderMale;
                              });
                            }
                          },
                          avatar: const Icon(Icons.male, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Text(tr('guest.gender_female')),
                          selected:
                              _selectedGender == GuestConstants.genderFemale,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedGender = GuestConstants.genderFemale;
                              });
                            }
                          },
                          avatar: const Icon(Icons.female, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Text(tr('guest.gender_other')),
                          selected:
                              _selectedGender == GuestConstants.genderOther,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedGender = GuestConstants.genderOther;
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
                    decoration: InputDecoration(
                      labelText: tr('table'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.table_restaurant),
                    ),
                    value: _selectedTable,
                    items: sortedTables
                        .map((table) => DropdownMenuItem(
                              value: table.id == 'unassigned'
                                  ? GuestConstants.unassignedTable
                                  : table.name,
                              child: Text(
                                table.id == 'unassigned'
                                    ? tr('guest.unassigned_table')
                                    : table.name,
                                style: TextStyle(
                                  color: table.maxCapacity > 0 &&
                                          guestsManager
                                                  .getGuestsByTable(table.name)
                                                  .length >=
                                              table.maxCapacity &&
                                          table.name != widget.guest.table
                                      ? Colors.red
                                      : null,
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTable = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Stav účasti - ✅ UKLÁDÁ KONSTANTY, ZOBRAZUJE PŘEKLADY
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: tr('attendance_status'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.event_available),
                    ),
                    value: _attendanceStatus,
                    items: [
                      DropdownMenuItem(
                          value: GuestConstants.attendanceConfirmed,
                          child: Text(tr('guest.attendance_confirmed'))),
                      DropdownMenuItem(
                          value: GuestConstants.attendanceDeclined,
                          child: Text(tr('guest.attendance_declined'))),
                      DropdownMenuItem(
                          value: GuestConstants.attendancePending,
                          child: Text(tr('guest.attendance_pending'))),
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
      ),
    );
  }
}
