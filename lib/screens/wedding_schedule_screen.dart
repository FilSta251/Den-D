// lib/screens/wedding_schedule_screen.dart - PRODUKČNÍ VERZE

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

import 'package:svatebni_planovac/services/local_schedule_service.dart'; // Potřebujeme pro model ScheduleItem
import 'package:svatebni_planovac/services/schedule_manager.dart';

/// Pevně daný den svatby – nastavte zde datum svatby, ke kterému se budou všechny časy vztahovat.
final weddingDay = DateTime(2023, 1, 1);

class WeddingScheduleScreen extends StatefulWidget {
  const WeddingScheduleScreen({Key? key}) : super(key: key);

  @override
  _WeddingScheduleScreenState createState() => _WeddingScheduleScreenState();
}

class _WeddingScheduleScreenState extends State<WeddingScheduleScreen> with WidgetsBindingObserver {
  // Reference na vytvořený PDF soubor
  File? _pdfFile;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Při inicializaci obrazovky zajistíme načtení dat z cloudu
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
    // Při návratu do aplikace znovu synchronizujeme data
    if (state == AppLifecycleState.resumed) {
      debugPrint("=== WEDDING SCHEDULE SCREEN: NÁVRAT DO APLIKACE ===");
      _forceRefresh();
    }
  }

  void _forceRefresh() {
    debugPrint("=== WEDDING SCHEDULE SCREEN: VYNUCENÁ AKTUALIZACE DAT ===");
    final scheduleManager = Provider.of<ScheduleManager>(context, listen: false);
    scheduleManager.forceRefreshFromCloud();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('wedding_schedule_title')),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'export_pdf') {
                await _createAndExportPdf(context);
              } else if (value == 'share_text') {
                await _shareScheduleAsText(context);
              } else if (value == 'share_pdf') {
                if (_pdfFile == null) {
                  await _createAndExportPdf(context, showSnackbar: false);
                }
                if (_pdfFile != null) {
                  await _sharePdf(context);
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'export_pdf',
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(tr('export_pdf')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share_text',
                child: Row(
                  children: [
                    const Icon(Icons.text_fields, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text("Sdílet jako text"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share_pdf',
                child: Row(
                  children: [
                    const Icon(Icons.share, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text("Sdílet jako PDF"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<ScheduleManager>(
        builder: (context, scheduleManager, child) {
          // Zobrazíme indikátor načítání, pokud probíhá synchronizace
          if (scheduleManager.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          final items = scheduleManager.scheduleItems;
          
          // Seřadíme položky vzestupně podle času.
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
                  const Text("Přidejte položky harmonogramu pomocí tlačítka +"),
                ],
              ),
            );
          }
          
          return Column(
            children: [
              // Banner pro informaci o cloudové synchronizaci
              if (scheduleManager.isSyncing)
                Container(
                  width: double.infinity,
                  color: Colors.blue.shade100,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Probíhá synchronizace...",
                          style: TextStyle(color: Colors.blue.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Hlavní seznam položek
              Expanded(
                child: ReorderableListView.builder(
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(tr('item_deleted'))),
                        );
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(item.title),
                          subtitle: item.time != null
                              ? Text(DateFormat('HH:mm').format(item.time!))
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Tlačítko pro smazání položky
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
                                  _showEditDialog(context, scheduleManager, index, item);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
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

  void _showAddDialog(BuildContext context) {
    final titleController = TextEditingController();
    // Pouze tlačítko pro výběr času – textové pole pro čas není
    TimeOfDay? selectedTime;
    String displayedTime = "";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(tr('add_schedule_item')),
              content: SingleChildScrollView(
                child: Column(
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
                          initialTime: now,
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
                            displayedTime = DateFormat('HH:mm').format(dateTime);
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
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(tr('cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text;
                    if (title.trim().isEmpty || selectedTime == null) return;
                    final dateTime = DateTime(
                      weddingDay.year,
                      weddingDay.month,
                      weddingDay.day,
                      selectedTime!.hour,
                      selectedTime!.minute,
                    );
                    final newItem = ScheduleItem(
                      id: const Uuid().v4(),
                      title: title,
                      time: dateTime,
                    );
                    Provider.of<ScheduleManager>(context, listen: false).addItem(newItem);
                    Navigator.pop(context);
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

  void _showEditDialog(BuildContext context, ScheduleManager scheduleManager, int index, ScheduleItem currentItem) {
    final titleController = TextEditingController(text: currentItem.title);
    TimeOfDay? selectedTime = currentItem.time != null
        ? TimeOfDay.fromDateTime(currentItem.time!)
        : null;
    String displayedTime = currentItem.time != null ? DateFormat('HH:mm').format(currentItem.time!) : "";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(tr('edit_schedule_item')),
              content: SingleChildScrollView(
                child: Column(
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
                            displayedTime = DateFormat('HH:mm').format(dateTime);
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

  // Funkce pro vytvoření a export PDF harmonogramu
  Future<void> _createAndExportPdf(BuildContext context, {bool showSnackbar = true}) async {
    try {
      // Ukaž indikátor načítání
      if (showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Generuji PDF harmonogram...")),
        );
      }
      
      final scheduleManager = Provider.of<ScheduleManager>(context, listen: false);
      final items = scheduleManager.scheduleItems;
      
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
      final font = await _loadFont();
      
      // Přidání stránky do PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Nadpis
                pw.Center(
                  child: pw.Text(
                    'Harmonogram svatby',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                
                // Datum svatby
                pw.Center(
                  child: pw.Text(
                    'Datum: ${DateFormat('dd.MM.yyyy').format(weddingDay)}',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 16,
                    ),
                  ),
                ),
                pw.SizedBox(height: 30),
                
                // Seznam položek harmonogramu
                ...sortedItems.map((item) {
                  final timeString = item.time != null 
                    ? DateFormat('HH:mm').format(item.time!) 
                    : 'Čas neurčen';
                  
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 60,
                          child: pw.Text(
                            timeString,
                            style: pw.TextStyle(
                              font: font,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 20),
                        pw.Expanded(
                          child: pw.Text(
                            item.title,
                            style: pw.TextStyle(font: font),
                          ),
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
      
      // Uložení PDF do souboru
      final output = await getApplicationDocumentsDirectory();
      final formattedDate = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${output.path}/harmonogram_svatby_$formattedDate.pdf');
      await file.writeAsBytes(await pdf.save());
      
      // Uložení reference na vytvořený soubor
      _pdfFile = file;
      
      // Otevření souboru
      if (showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF harmonogram byl vytvořen'),
            action: SnackBarAction(
              label: 'Otevřít',
              onPressed: () {
                OpenFile.open(file.path);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při vytváření PDF: $e')),
        );
      }
    }
  }
  
  // Načtení fontu s podporou diakritiky pro PDF
  Future<pw.Font> _loadFont() async {
    try {
      // Zkusíme načíst vlastní font s českou diakritikou, pokud je k dispozici
      final fontData = await rootBundle.load("assets/fonts/DejaVuSans.ttf");
      return pw.Font.ttf(fontData);
    } catch (e) {
      // Fallback na výchozí font, pokud vlastní font není k dispozici
      return pw.Font.helvetica();
    }
  }
  
  // Sdílení PDF souboru - AKTUALIZOVÁNO
  Future<void> _sharePdf(BuildContext context) async {
    try {
      if (_pdfFile != null && await _pdfFile!.exists()) {
        debugPrint("=== SDÍLENÍ PDF SOUBORU: ${_pdfFile!.path} ===");
        // Sdílení PDF souboru
        await Share.shareXFiles(
          [XFile(_pdfFile!.path)], 
          text: 'Harmonogram svatby',
          subject: 'Harmonogram svatby'
        );
      } else {
        // Pokud soubor neexistuje, vytvoříme nový
        debugPrint("=== PDF SOUBOR NEEXISTUJE, VYTVÁŘÍM NOVÝ ===");
        await _createAndExportPdf(context);
        if (_pdfFile != null && await _pdfFile!.exists()) {
          // Pokusíme se znovu sdílet
          await Share.shareXFiles(
            [XFile(_pdfFile!.path)], 
            text: 'Harmonogram svatby',
            subject: 'Harmonogram svatby'
          );
        } else {
          throw Exception('Nepodařilo se vytvořit PDF soubor.');
        }
      }
    } catch (e) {
      debugPrint("=== CHYBA PŘI SDÍLENÍ PDF: $e ===");
      // Pokud selže sdílení PDF, nabízíme sdílení textu jako záložní řešení
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Problém se sdílením PDF: $e'),
          action: SnackBarAction(
            label: 'Sdílet jako text',
            onPressed: () {
              _shareScheduleAsText(context);
            },
          ),
        ),
      );
    }
  }
  
  // Funkce pro sdílení harmonogramu jako text
  Future<void> _shareScheduleAsText(BuildContext context) async {
    try {
      final scheduleManager = Provider.of<ScheduleManager>(context, listen: false);
      final items = scheduleManager.scheduleItems;
      
      // Seřadíme položky vzestupně podle času
      final sortedItems = List<ScheduleItem>.from(items)
        ..sort((a, b) {
          if (a.time == null && b.time == null) return 0;
          if (a.time == null) return 1;
          if (b.time == null) return -1;
          return a.time!.compareTo(b.time!);
        });
      
      // Vytvoření textové reprezentace harmonogramu
      final StringBuffer textBuffer = StringBuffer();
      textBuffer.writeln('HARMONOGRAM SVATBY');
      textBuffer.writeln('Datum: ${DateFormat('dd.MM.yyyy').format(weddingDay)}');
      textBuffer.writeln('------------------------------');
      
      for (final item in sortedItems) {
        final timeString = item.time != null 
          ? DateFormat('HH:mm').format(item.time!) 
          : 'Čas neurčen';
        
        textBuffer.writeln('$timeString: ${item.title}');
      }
      
      debugPrint("=== SDÍLENÍ TEXTU ===");
      // Sdílení textu
      await Share.share(
        textBuffer.toString(),
        subject: 'Harmonogram svatby'
      );
    } catch (e) {
      debugPrint("=== CHYBA PŘI SDÍLENÍ TEXTU: $e ===");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chyba při sdílení textu: $e')),
      );
    }
  }
}