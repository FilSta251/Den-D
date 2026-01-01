/// lib/screens/wedding_schedule_screen.dart - PRODUKČNÍ VERZE
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

import 'package:den_d/services/local_schedule_service.dart';
import 'package:den_d/services/schedule_manager.dart';
import '../providers/subscription_provider.dart';
import '../widgets/subscription_offer_dialog.dart';
import '../repositories/wedding_repository.dart';
import '../models/wedding_info.dart';
import '../utils/safe_snackbar.dart';

/// Pevně daný den svatby - nastavte zde datum svatby, ke kterému se budou všechny časy vztahovat.
final weddingDay = DateTime(2023, 1, 1);

class WeddingScheduleScreen extends StatefulWidget {
  const WeddingScheduleScreen({super.key});

  @override
  _WeddingScheduleScreenState createState() => _WeddingScheduleScreenState();
}

class _WeddingScheduleScreenState extends State<WeddingScheduleScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint("=== WEDDING SCHEDULE SCREEN: INICIALIZACE ===");
      _forceRefresh();
    });
  }

  @override
  void dispose() {
    debugPrint("=== WEDDING SCHEDULE SCREEN: UKONČENÍ ===");
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("=== WEDDING SCHEDULE SCREEN: NÁVRAT DO APLIKACE ===");
      _forceRefresh();
    }
  }

  void _forceRefresh() {
    debugPrint("=== WEDDING SCHEDULE SCREEN: VYNUCENÁ AKTUALIZACE DAT ===");
    final scheduleManager =
        Provider.of<ScheduleManager>(context, listen: false);
    scheduleManager.forceRefreshFromCloud();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('wedding_schedule_title')),
        actions: [
          _buildPremiumButton(),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.green),
            tooltip: tr('export_pdf'),
            onPressed: () async {
              await _createAndExportPdf(context);
            },
          ),
        ],
      ),
      body: Consumer<ScheduleManager>(
        builder: (context, scheduleManager, child) {
          final items = scheduleManager.scheduleItems;

          final sortedItems = List<ScheduleItem>.from(items)
            ..sort((a, b) {
              if (a.time == null && b.time == null) return 0;
              if (a.time == null) return 1;
              if (b.time == null) return -1;
              return a.time!.compareTo(b.time!);
            });

          if (sortedItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tr('no_schedule_items')),
                  const SizedBox(height: 16),
                  Text(tr('add_schedule_hint')),
                ],
              ),
            );
          }

          return ReorderableListView.builder(
            onReorder: (oldIndex, newIndex) {
              scheduleManager.reorderItems(oldIndex, newIndex);
            },
            itemCount: sortedItems.length,
            itemBuilder: (context, index) {
              final item = sortedItems[index];
              return Dismissible(
                key: Key(item.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  scheduleManager.removeItem(index);
                  SafeSnackBar.show(
                    context,
                    tr('item_deleted'),
                  );
                },
                child: Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(item.title),
                    subtitle: item.time != null
                        ? Text(DateFormat('HH:mm').format(item.time!))
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete),
                          tooltip: tr('delete_item'),
                          onPressed: () {
                            scheduleManager.removeItem(index);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: tr('edit_item'),
                          onPressed: () {
                            _showEditDialog(
                                context, scheduleManager, index, item);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: tr('add_item'),
        onPressed: () {
          _showAddDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context) async {
    final titleController = TextEditingController();
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(tr('add_schedule_item')),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: tr('item_title'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (pickedTime != null) {
                            selectedTime = pickedTime;
                            setStateDialog(() {});
                          }
                        },
                        child: Text(selectedTime != null
                            ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                            : tr('set_time')),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr('cancel')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isNotEmpty &&
                        selectedTime != null) {
                      final scheduleManager =
                          Provider.of<ScheduleManager>(context, listen: false);
                      final dateTime = DateTime(
                        weddingDay.year,
                        weddingDay.month,
                        weddingDay.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      );
                      final newItem = ScheduleItem(
                        id: const Uuid().v4(),
                        title: titleController.text,
                        time: dateTime,
                      );
                      final success =
                          await scheduleManager.addItem(newItem, context);
                      if (success) {
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: Text(tr('add')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, ScheduleManager scheduleManager,
      int index, ScheduleItem currentItem) {
    final titleController = TextEditingController(text: currentItem.title);
    TimeOfDay? selectedTime = currentItem.time != null
        ? TimeOfDay.fromDateTime(currentItem.time!)
        : null;
    String displayedTime = currentItem.time != null
        ? DateFormat('HH:mm').format(currentItem.time!)
        : "";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(tr('edit_schedule_item')),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: tr('item_title'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          final now = TimeOfDay.now();
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: selectedTime ?? now,
                          );
                          if (pickedTime != null) {
                            selectedTime = pickedTime;
                            final dateTime = DateTime(
                              weddingDay.year,
                              weddingDay.month,
                              weddingDay.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                            setStateDialog(() {
                              displayedTime =
                                  DateFormat('HH:mm').format(dateTime);
                            });
                          }
                        },
                        child: Text(tr('set_time')),
                      ),
                      if (displayedTime.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(displayedTime),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(tr('cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedTime == null) return;
                    final dateTime = DateTime(
                      weddingDay.year,
                      weddingDay.month,
                      weddingDay.day,
                      selectedTime!.hour,
                      selectedTime!.minute,
                    );
                    final updatedItem = ScheduleItem(
                      id: currentItem.id,
                      title: titleController.text,
                      time: dateTime,
                    );
                    scheduleManager.updateItem(index, updatedItem);
                    Navigator.pop(context);
                  },
                  child: Text(tr('save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Funkce pro vytvoření a export PDF harmonogramu s hlavičkou svatebních údajů
  Future<void> _createAndExportPdf(BuildContext context) async {
    try {
      SafeSnackBar.show(
        context,
        tr('generating_pdf'),
      );

      final scheduleManager =
          Provider.of<ScheduleManager>(context, listen: false);
      final items = scheduleManager.scheduleItems;

      // Načteme svatební údaje z repository
      final weddingRepository =
          Provider.of<WeddingRepository>(context, listen: false);
      WeddingInfo? weddingInfo;

      try {
        weddingInfo = await weddingRepository.fetchWeddingInfo();
      } catch (e) {
        debugPrint("Chyba při načítání svatebních údajů: $e");
        // Pokud se nepodaří načíst, pokračujeme bez nich
      }

      // Seřadíme položky vzestupně podle času
      final sortedItems = List<ScheduleItem>.from(items)
        ..sort((a, b) {
          if (a.time == null && b.time == null) return 0;
          if (a.time == null) return 1;
          if (b.time == null) return -1;
          return a.time!.compareTo(b.time!);
        });

      // Vytvoření PDF dokumentu
      final pdf = pw.Document();

      // Font s podporou české diakritiky
      final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final fontBoldData =
          await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      final ttf = pw.Font.ttf(fontData);
      final ttfBold = pw.Font.ttf(fontBoldData);

      // Přidání stránky do PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
          build: (pw.Context pdfContext) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Hlavička s informacemi o svatbě
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(10)),
                    border: pw.Border.all(color: PdfColors.grey300, width: 2),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Nadpis
                      pw.Text(
                        tr('wedding_schedule'),
                        style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 32,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 12),

                      // Jména snoubenců (pokud jsou k dispozici)
                      if (weddingInfo != null) ...[
                        pw.Text(
                          '${weddingInfo.yourName} & ${weddingInfo.partnerName}',
                          style: pw.TextStyle(
                            font: ttfBold,
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                      ],

                      // Datum svatby
                      pw.Text(
                        '${tr('date')}: ${weddingInfo != null ? DateFormat('dd.MM.yyyy').format(weddingInfo.weddingDate) : DateFormat('dd.MM.yyyy').format(weddingDay)}',
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 18,
                        ),
                      ),

                      // Místo svatby (pokud je k dispozici)
                      if (weddingInfo != null &&
                          weddingInfo.weddingVenue.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '${tr('wedding_venue')}: ${weddingInfo.weddingVenue}',
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),

                // Nadpis harmonogramu
                pw.Text(
                  tr('schedule') ?? 'Harmonogram',
                  style: pw.TextStyle(
                    font: ttfBold,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 16),

                // Tabulka s harmonogramem
                pw.Table(
                  border:
                      pw.TableBorder.all(color: PdfColors.grey300, width: 1),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(100),
                    1: const pw.FlexColumnWidth(),
                  },
                  children: [
                    // Hlavička tabulky
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Text(
                            tr('time'),
                            style: pw.TextStyle(
                              font: ttfBold,
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Text(
                            tr('activity'),
                            style: pw.TextStyle(
                              font: ttfBold,
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Řádky s položkami harmonogramu
                    ...sortedItems.map((item) {
                      final timeString = item.time != null
                          ? DateFormat('HH:mm').format(item.time!)
                          : tr('time_not_set');

                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text(
                              timeString,
                              style: pw.TextStyle(
                                font: ttfBold,
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text(
                              item.title,
                              style: pw.TextStyle(
                                font: ttf,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),

                pw.SizedBox(height: 30),

                // Poznámky ze svatebních údajů (pokud existují)
                if (weddingInfo != null && weddingInfo.notes.isNotEmpty) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.all(15),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          tr('notes'),
                          style: pw.TextStyle(
                            font: ttfBold,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          weddingInfo.notes,
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Patička s datem vytvoření
                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text(
                    '${tr('created')}: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Uložení PDF do souboru
      final output = await getApplicationDocumentsDirectory();
      final formattedDate =
          DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${output.path}/harmonogram_svatby_$formattedDate.pdf');
      await file.writeAsBytes(await pdf.save());

      // Otevření souboru
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('pdf_created'),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: tr('open'),
            onPressed: () {
              OpenFile.open(file.path);
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint("Chyba při vytváření PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('pdf_error')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
