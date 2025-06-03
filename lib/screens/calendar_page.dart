import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../repositories/wedding_repository.dart';
import '../models/wedding_info.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Pro upozornění
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with TickerProviderStateMixin {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  
  // Reference pro zjištění, jestli je potřeba při návratu obnovit data na homepage
  bool _hasChanges = false;
  
  // Reference na svatbu, pokud existuje
  WeddingInfo? _weddingInfo;
  
  // Pro zobrazení různých pohledů kalendáře
  CalendarFormat _calendarFormat = CalendarFormat.month;
  
  // Pro notifikace
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  
  // Pro animaci mezi pohledy
  late TabController _viewTabController;
  final List<String> _viewOptions = ['month_view', 'week_view', 'day_view'];
  int _currentViewIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    _loadEvents();
    _loadWeddingInfo();
    _initializeNotifications();
    
    // Inicializace pro přepínání pohledů
    _viewTabController = TabController(
      length: _viewOptions.length, 
      vsync: this,
      initialIndex: _currentViewIndex,
    );
    _viewTabController.addListener(_handleViewChange);
    
    // Vždy po načtení stránky požádáme o povolení upozornění
    _requestNotificationPermissions();
  }
  
  // Metoda pro vyžádání oprávnění k upozorněním
  Future<void> _requestNotificationPermissions() async {
    // Pro iOS explicitně požádáme o povolení
    final ios = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    
    // Pro Android 13+ (API úroveň 33+) je také potřeba explicitně požádat o povolení
    final android = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      // Opraveno: změněno na requestNotificationsPermission místo requestPermission
      await android.requestNotificationsPermission();
    }
    
    // Informovat uživatele, že upozornění byla povolena
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('notification_permissions_requested')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  
  @override
  void dispose() {
    _viewTabController.removeListener(_handleViewChange);
    _viewTabController.dispose();
    super.dispose();
  }
  
  void _handleViewChange() {
    if (_viewTabController.index != _currentViewIndex) {
      setState(() {
        _currentViewIndex = _viewTabController.index;
        // Aktualizace formátu zobrazení kalendáře
        switch (_currentViewIndex) {
          case 0:
            _calendarFormat = CalendarFormat.month;
            break;
          case 1:
            _calendarFormat = CalendarFormat.week;
            break;
          case 2:
            _calendarFormat = CalendarFormat.week; // Den v TableCalendar není, ale lze přizpůsobit výškou
            break;
        }
      });
    }
  }
  
  Future<void> _initializeNotifications() async {
    // Inicializace časových zón pro plánování upozornění
    tzdata.initializeTimeZones();
    
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Když uživatel klikne na upozornění, otevřeme kalendář na správném dni
        if (details.payload != null) {
          try {
            final Map<String, dynamic> payloadData = jsonDecode(details.payload!);
            if (payloadData.containsKey('day')) {
              final parts = payloadData['day'].split('-');
              if (parts.length == 3) {
                final year = int.parse(parts[0]);
                final month = int.parse(parts[1]);
                final day = int.parse(parts[2]);
                
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {
                    _selectedDay = DateTime(year, month, day);
                    _focusedDay = _selectedDay!;
                  });
                });
              }
            }
          } catch (e) {
            debugPrint('Error parsing notification payload: $e');
          }
        }
      },
    );
    
    // Zkontrolujeme oprávnění na iOS
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }
  
  // Načtení informací o svatbě pro zobrazení v kalendáři
  Future<void> _loadWeddingInfo() async {
    try {
      final weddingRepo = Provider.of<WeddingRepository>(context, listen: false);
      final wedding = await weddingRepo.fetchWeddingInfo();
      if (mounted) {
        setState(() {
          _weddingInfo = wedding;
        });
      }
      
      // Pokud máme datum svatby a nejsme na dnešním dni, automaticky vybereme den v kalendáři
      if (wedding.weddingDate != null && mounted) {
        final weddingDay = DateTime(
          wedding.weddingDate.year,
          wedding.weddingDate.month,
          wedding.weddingDate.day
        );
        final today = DateTime.now();
        final todayKey = DateTime(today.year, today.month, today.day);
        
        // Nastavíme vybraný den na dnešek nebo na den svatby, pokud je to relevantní
        setState(() {
          // Dáváme přednost dnešnímu dni jako výchozímu
          _selectedDay = todayKey;
          _focusedDay = todayKey;
        });
      }
    } catch (e) {
      debugPrint('[CalendarPage] Error loading wedding info: $e');
    }
  }

  Future<void> _loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('events');
    if (jsonString != null) {
      try {
        final Map<String, dynamic> decodedMap = jsonDecode(jsonString);
        setState(() {
          _events = decodedMap.map((key, value) {
            return MapEntry(
              DateTime.parse(key),
              List<Map<String, dynamic>>.from(jsonDecode(value).map((event) {
                // Nyní musíme mít více polí - přidáváme popis, lokaci, reminder, barvu atd.
                return {
                  "id": event["id"] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  "title": event["title"],
                  "time": DateTime.parse(event["time"]),
                  "endTime": event["endTime"] != null ? DateTime.parse(event["endTime"]) : null,
                  "description": event["description"] ?? "",
                  "location": event["location"] ?? "",
                  "allDay": event["allDay"] ?? false,
                  "color": event["color"] ?? Colors.blue.value,
                  "reminder": event["reminder"] != null ? {
                    "type": event["reminder"]["type"],
                    "value": event["reminder"]["value"],
                    "scheduled": event["reminder"]["scheduled"] ?? false,
                  } : null,
                };
              })),
            );
          });
        });
        
        // Po načtení zkontrolujeme, jestli potřebujeme nastavit nějaká upozornění
        _scheduleNotificationsForEvents();
      } catch (e) {
        debugPrint('[CalendarPage] Error parsing events: $e');
      }
    }
  }

  // Naplánování všech upozornění po načtení
  Future<void> _scheduleNotificationsForEvents() async {
    // Nejprve vyčistíme všechna upozornění
    await flutterLocalNotificationsPlugin.cancelAll();
    
    // Plánujeme nová upozornění pro všechny události s reminder
    for (final dayEvents in _events.entries) {
      for (final event in dayEvents.value) {
        if (event["reminder"] != null && !(event["reminder"]["scheduled"] ?? false)) {
          await _scheduleNotification(event);
          
          // Označíme, že upozornění bylo naplánováno
          event["reminder"]["scheduled"] = true;
        }
      }
    }
    
    // Uložíme aktualizovaná data
    await _saveEvents();
  }

  Future<void> _saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, String> stringEvents = _events.map((key, value) {
      return MapEntry(
        key.toIso8601String(),
        jsonEncode(value.map((event) {
          // Uložíme všechna rozšířená pole
          return {
            "id": event["id"],
            "title": event["title"],
            "time": (event["time"] as DateTime).toIso8601String(),
            "endTime": event["endTime"] != null ? (event["endTime"] as DateTime).toIso8601String() : null,
            "description": event["description"],
            "location": event["location"],
            "allDay": event["allDay"],
            "color": event["color"],
            "reminder": event["reminder"],
          };
        }).toList()),
      );
    });
    await prefs.setString('events', jsonEncode(stringEvents));
    
    // Označíme, že došlo ke změnám, aby se aktualizovala homepage
    _hasChanges = true;
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final dayKey = DateTime(day.year, day.month, day.day);
    return _events[dayKey] ?? [];
  }

  // Pro podporu zobrazení denního pohledu
  List<Map<String, dynamic>> _getEventsForToday() {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    return _events[todayKey] ?? [];
  }

  Future<void> _addOrEditEvent({Map<String, dynamic>? event, int? index}) async {
    final TextEditingController titleController = TextEditingController(
      text: event != null ? event["title"] : "",
    );
    final TextEditingController descriptionController = TextEditingController(
      text: event != null ? event["description"] : "",
    );
    final TextEditingController locationController = TextEditingController(
      text: event != null ? event["location"] : "",
    );
    
    TimeOfDay selectedStartTime = event != null
        ? TimeOfDay.fromDateTime(event["time"])
        : TimeOfDay.now();
    
    TimeOfDay selectedEndTime = event != null && event["endTime"] != null
        ? TimeOfDay.fromDateTime(event["endTime"])
        : TimeOfDay(
            hour: TimeOfDay.now().hour + 1,
            minute: TimeOfDay.now().minute
          );
    
    bool isAllDay = event != null ? event["allDay"] ?? false : false;
    
    // Výchozí barva nebo načtená
    Color selectedColor = event != null 
        ? Color(event["color"]) 
        : Colors.blue;
    
    // Upozornění
    Map<String, dynamic>? reminder = event != null 
        ? event["reminder"] 
        : null;
        
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(event == null ? tr('add_event') : tr('edit_event', namedArgs: {'event': event["title"]})),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: tr('event_title'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Celodenní událost přepínač
                    Row(
                      children: [
                        Text(tr('all_day_event')),
                        Switch(
                          value: isAllDay,
                          activeColor: Colors.pink,
                          onChanged: (value) {
                            setState(() {
                              isAllDay = value;
                            });
                          },
                        ),
                      ],
                    ),
                    
                    if (!isAllDay) ...[
                      // Čas začátku
                      Row(
                        children: [
                          Text("${tr('start_time')}: "),
                          TextButton.icon(
                            icon: const Icon(Icons.access_time),
                            onPressed: () async {
                              final pickedTime = await showTimePicker(
                                context: context,
                                initialTime: selectedStartTime,
                                builder: (context, child) {
                                  return MediaQuery(
                                    data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                                    child: child!,
                                  );
                                },
                              );
                              if (pickedTime != null) {
                                setState(() {
                                  selectedStartTime = pickedTime;
                                  // Pokud je konec dříve než začátek, posuneme konec
                                  if (_timeToMinutes(selectedEndTime) < _timeToMinutes(selectedStartTime)) {
                                    selectedEndTime = TimeOfDay(
                                      hour: selectedStartTime.hour + 1,
                                      minute: selectedStartTime.minute,
                                    );
                                  }
                                });
                              }
                            },
                            label: Text(
                              DateFormat.Hm().format(DateTime(
                                2022, 1, 1, 
                                selectedStartTime.hour, 
                                selectedStartTime.minute
                              )),
                              style: const TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // Čas konce
                      Row(
                        children: [
                          Text("${tr('end_time')}: "),
                          TextButton.icon(
                            icon: const Icon(Icons.access_time),
                            onPressed: () async {
                              final pickedTime = await showTimePicker(
                                context: context,
                                initialTime: selectedEndTime,
                                builder: (context, child) {
                                  return MediaQuery(
                                    data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                                    child: child!,
                                  );
                                },
                              );
                              if (pickedTime != null) {
                                setState(() {
                                  selectedEndTime = pickedTime;
                                });
                              }
                            },
                            label: Text(
                              DateFormat.Hm().format(DateTime(
                                2022, 1, 1, 
                                selectedEndTime.hour, 
                                selectedEndTime.minute
                              )),
                              style: const TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    
                    // Popis události
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: tr('event_description'),
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Lokace události
                    TextField(
                      controller: locationController,
                      decoration: InputDecoration(
                        labelText: tr('event_location'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.location_on),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Barva události
                    Text(
                      "${tr('event_color')}:",
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Colors.blue,
                        Colors.red,
                        Colors.green,
                        Colors.orange,
                        Colors.purple,
                        Colors.teal,
                        Colors.pink,
                        Colors.brown,
                      ].map((color) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: selectedColor == color
                                  ? Border.all(color: Colors.black, width: 2)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Nastavení upozornění
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${tr('reminder_when')}:",
                          style: const TextStyle(fontSize: 16),
                        ),
                        if (reminder != null)
                          TextButton.icon(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            label: Text(
                              tr('reminder_remove'),
                              style: const TextStyle(color: Colors.red),
                            ),
                            onPressed: () async {
                              // Potvrzení odstranění upozornění
                              final bool confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(tr('confirm')),
                                  content: Text(tr('reminder_confirm_remove')),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text(tr('cancel')),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => Navigator.pop(context, true),
                                      child: Text(tr('delete')),
                                    ),
                                  ],
                                ),
                              ) ?? false;
                              
                              if (confirm) {
                                setState(() {
                                  reminder = null;
                                });
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (reminder == null)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.notifications_active),
                        label: Text(tr('reminder_add_now')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          // Otevřeme dialog pro výběr času upozornění
                          final selectedReminder = await _showReminderSelectionDialog();
                          if (selectedReminder != null) {
                            setState(() {
                              reminder = selectedReminder;
                            });
                          }
                        },
                      )
                    else
                      // Zobrazit aktuální nastavení připomenutí
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.pink.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.pink.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active, color: Colors.pink),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getReminderText(reminder!),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16),
                              onPressed: () async {
                                final selectedReminder = await _showReminderSelectionDialog(
                                  initialReminder: reminder
                                );
                                if (selectedReminder != null) {
                                  setState(() {
                                    reminder = selectedReminder;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr('cancel')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink.shade300,
                  ),
                  onPressed: () {
                    if (titleController.text.trim().isNotEmpty && _selectedDay != null) {
                      final eventId = event != null ? event["id"] : DateTime.now().millisecondsSinceEpoch.toString();
                      
                      final eventStartTime = DateTime(
                        _selectedDay!.year,
                        _selectedDay!.month,
                        _selectedDay!.day,
                        isAllDay ? 0 : selectedStartTime.hour,
                        isAllDay ? 0 : selectedStartTime.minute,
                      );
                      
                      final eventEndTime = isAllDay ? null : DateTime(
                        _selectedDay!.year,
                        _selectedDay!.month,
                        _selectedDay!.day,
                        selectedEndTime.hour,
                        selectedEndTime.minute,
                      );
                      
                      Navigator.pop(context, {
                        "id": eventId,
                        "title": titleController.text.trim(),
                        "time": eventStartTime,
                        "endTime": eventEndTime,
                        "description": descriptionController.text.trim(),
                        "location": locationController.text.trim(),
                        "allDay": isAllDay,
                        "color": selectedColor.value,
                        "reminder": reminder,
                      });
                    }
                  },
                  child: Text(event == null ? tr('add') : tr('save')),
                ),
              ],
            );
          }
        );
      },
    );
    
    if (result != null && _selectedDay != null) {
      final dayKey = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
      setState(() {
        if (_events.containsKey(dayKey)) {
          if (event != null && index != null) {
            // Edit existing event.
            _events[dayKey]![index] = result;
          } else {
            // Add new event.
            _events[dayKey]!.add(result);
          }
        } else {
          _events[dayKey] = [result];
        }
      });
      
      // Uložíme změny
      await _saveEvents();
      
      // Naplánujeme upozornění, pokud existuje
      if (result["reminder"] != null) {
        await _scheduleNotification(result);
      }
      
      // Oznámíme uživateli
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('event_saved')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Pomocná metoda pro převod TimeOfDay na minuty pro snadné porovnávání
  int _timeToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }
  
  // Dialog pro výběr upozornění
  Future<Map<String, dynamic>?> _showReminderSelectionDialog({Map<String, dynamic>? initialReminder}) async {
    String reminderType = initialReminder != null ? initialReminder["type"] : "minutes";
    int reminderValue = initialReminder != null ? initialReminder["value"] : 30;
    
    final options = <Map<String, dynamic>>[
      {"type": "minutes", "values": [5, 10, 15, 30]},
      {"type": "hours", "values": [1, 2, 3, 6, 12]},
      {"type": "days", "values": [1, 2, 3, 7]},
    ];
    
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(tr('set_reminder')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: options.map((typeOption) {
                  final String type = typeOption["type"];
                  final List<int> values = typeOption["values"];
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      ...values.map((value) {
                        final bool isSelected = reminderType == type && reminderValue == value;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              reminderType = type;
                              reminderValue = value;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                  color: isSelected ? Colors.pink : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  type == "minutes" 
                                      ? tr('reminder_minutes_before', namedArgs: {'minutes': value.toString()})
                                      : type == "hours"
                                          ? tr('reminder_hours_before', namedArgs: {'hours': value.toString()})
                                          : tr('reminder_days_before', namedArgs: {'days': value.toString()}),
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr('cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                ),
                onPressed: () {
                  Navigator.pop(context, {
                    "type": reminderType,
                    "value": reminderValue,
                    "scheduled": false,
                  });
                },
                child: Text(tr('save')),
              ),
            ],
          );
        },
      ),
    );
  }
  
  // Získání textu pro zobrazení upozornění
  String _getReminderText(Map<String, dynamic> reminder) {
    final type = reminder["type"];
    final value = reminder["value"];
    
    switch (type) {
      case "minutes":
        return tr('reminder_minutes_before', namedArgs: {'minutes': value.toString()});
      case "hours":
        return tr('reminder_hours_before', namedArgs: {'hours': value.toString()});
      case "days":
        return tr('reminder_days_before', namedArgs: {'days': value.toString()});
      default:
        return "";
    }
  }
  
  // Plánování upozornění pro událost
  Future<void> _scheduleNotification(Map<String, dynamic> event) async {
    if (event["reminder"] == null) return;
    
    final int uniqueId = int.parse(event["id"].toString().substring(0, 9));
    final DateTime eventTime = event["time"];
    final String title = event["title"];
    
    // Výpočet času upozornění v závislosti na typu a hodnotě
    final reminderType = event["reminder"]["type"];
    final reminderValue = event["reminder"]["value"];
    
    // Výpočet času upozornění
    DateTime notificationTime;
    switch (reminderType) {
      case "minutes":
        notificationTime = eventTime.subtract(Duration(minutes: reminderValue));
        break;
      case "hours":
        notificationTime = eventTime.subtract(Duration(hours: reminderValue));
        break;
      case "days":
        notificationTime = eventTime.subtract(Duration(days: reminderValue));
        break;
      default:
        notificationTime = eventTime.subtract(const Duration(minutes: 30));
    }
    
    // Neplánovat upozornění v minulosti
    if (notificationTime.isBefore(DateTime.now())) {
      debugPrint('[CalendarPage] Skipping notification in the past');
      return;
    }
    
    // Struktura upozornění
    final androidDetails = AndroidNotificationDetails(
      'wedding_calendar_channel',
      'Wedding Calendar Notifications',
      channelDescription: 'Notifications for wedding calendar events',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(event["color"]),
    );
    
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    final platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    // Vytvoření obsahu upozornění
    // Opravili jsme placeholder tak, aby používal namedArgs {event}
    final titleText = tr('reminder_title', namedArgs: {'event': title});
    // Opravili jsme placeholder tak, aby používal namedArgs {time}
    final bodyText = event["location"].isNotEmpty
        ? '${tr('reminder_body', namedArgs: {'time': DateFormat.Hm().format(eventTime)})} - ${event["location"]}'
        : tr('reminder_body', namedArgs: {'time': DateFormat.Hm().format(eventTime)});
        
    final payload = jsonEncode({
      'eventId': event["id"],
      'day': '${eventTime.year}-${eventTime.month}-${eventTime.day}',
    });
    
    // Naplánování upozornění - OPRAVA: odstraněny neplatné parametry
    await flutterLocalNotificationsPlugin.zonedSchedule(
      uniqueId,
      titleText,
      bodyText,
      tz.TZDateTime.from(notificationTime, tz.local),
      platformDetails,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // Odstraněn parametr uiLocalNotificationDateInterpretation, který není potřeba v novější verzi pluginu
    );
    
    // Označíme upozornění jako naplánované
    event["reminder"]["scheduled"] = true;
    
    // Zobrazíme potvrzení
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('reminder_added')),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteEvent(DateTime day, int index) async {
    // Přidáno potvrzení před smazáním
    final bool confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('confirm')),
        content: Text(tr('confirm_delete_event')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    ) ?? false;
    
    if (confirm) {
      final dayKey = DateTime(day.year, day.month, day.day);
      
      // Rušíme naplánované upozornění
      if (_events[dayKey]?[index]["reminder"] != null) {
        final eventId = _events[dayKey]![index]["id"];
        final uniqueId = int.parse(eventId.toString().substring(0, 9));
        await flutterLocalNotificationsPlugin.cancel(uniqueId);
      }
      
      setState(() {
        _events[dayKey]?.removeAt(index);
        if (_events[dayKey]?.isEmpty ?? false) {
          _events.remove(dayKey);
        }
      });
      await _saveEvents();
      
      // Zobrazíme potvrzení o smazání
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('event_deleted')),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  // Zobrazení detailů události
  Future<void> _showEventDetails(Map<String, dynamic> event, int index) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          tr('event_details'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              Navigator.pop(context);
                              _addOrEditEvent(event: event, index: index);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteEvent(_selectedDay ?? _focusedDay, index);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),
                  
                  // Název události
                  Text(
                    event["title"],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(event["color"]),
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  // Čas události
                  Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.grey.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: event["allDay"]
                            ? Text(tr('all_day_event'))
                            : Text(
                                '${DateFormat.Hm().format(event["time"])} - ${event["endTime"] != null ? DateFormat.Hm().format(event["endTime"]) : ""}',
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                    ],
                  ),
                  
                  // Lokace (pokud existuje)
                  if (event["location"] != null && event["location"].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.grey.shade700),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              event["location"],
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Popis (pokud existuje)
                  if (event["description"] != null && event["description"].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('event_description'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            event["description"],
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 15),
                  
                  // Reminder status
                  if (event["reminder"] != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.pink.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_active, color: Colors.pink),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_getReminderText(event["reminder"])),
                          ),
                        ],
                      ),
                    ),
                    
                  const SizedBox(height: 20),
                  
                  // Tlačítka akcí
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: Text(tr('edit')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _addOrEditEvent(event: event, index: index);
                        },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.delete),
                        label: Text(tr('delete')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteEvent(_selectedDay ?? _focusedDay, index);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Zvýraznění dne svatby v kalendáři, pokud existuje
    final weddingDay = _weddingInfo?.weddingDate != null 
      ? DateTime(
          _weddingInfo!.weddingDate.year,
          _weddingInfo!.weddingDate.month,
          _weddingInfo!.weddingDate.day,
        ) 
      : null;
    
    return WillPopScope(
      // Předáme informaci o změnách při návratu na předchozí obrazovku
      onWillPop: () async {
        Navigator.pop(context, _hasChanges);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('calendar')),
          centerTitle: true,
          actions: [
            // Tlačítko pro přechod na dnešek
            IconButton(
              icon: const Icon(Icons.today),
              tooltip: tr('jump_to_today'),
              onPressed: () {
                setState(() {
                  _selectedDay = DateTime.now();
                  _focusedDay = DateTime.now();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: tr('refresh'),
              onPressed: _loadEvents,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: TabBar(
              controller: _viewTabController,
              tabs: [
                Tab(text: tr('month_view')),
                Tab(text: tr('week_view')),
                Tab(text: tr('day_view')),
              ],
              labelColor: Colors.pink,
              indicatorColor: Colors.pink,
            ),
          ),
        ),
        body: Column(
          children: [
            // Kalendář - zobrazení se mění podle vybraného pohledu
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: _currentViewIndex == 2 // denní pohled
                ? Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Pouze zobrazit dnešní datum
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios),
                              onPressed: () {
                                setState(() {
                                  _selectedDay = _selectedDay!.subtract(const Duration(days: 1));
                                  _focusedDay = _selectedDay!;
                                });
                              },
                            ),
                            Text(
                              DateFormat.yMMMMd(context.locale.toString()).format(_selectedDay ?? _focusedDay),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios),
                              onPressed: () {
                                setState(() {
                                  _selectedDay = _selectedDay!.add(const Duration(days: 1));
                                  _focusedDay = _selectedDay!;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : TableCalendar(
                    focusedDay: _focusedDay,
                    firstDay: DateTime(2000),
                    lastDay: DateTime(2100),
                    locale: context.locale.languageCode,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    calendarFormat: _calendarFormat,
                    onFormatChanged: (format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    },
                    eventLoader: _getEventsForDay,
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Colors.pink.shade300,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Colors.pink.shade700,
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: BoxDecoration(
                        color: Colors.pink.shade200,
                        shape: BoxShape.circle,
                      ),
                      markerSize: 8,
                      markersMaxCount: 5,
                    ),
                    headerStyle: HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                      titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    calendarBuilders: CalendarBuilders(
                      // Speciální vykreslení pro den svatby
                      defaultBuilder: (context, day, focusedDay) {
                        if (weddingDay != null && isSameDay(day, weddingDay)) {
                          return Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.pink, width: 2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                day.day.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }
                        return null;
                      },
                      // Přizpůsobení markerů pro události
                      markerBuilder: (context, date, events) {
                        if (events.isNotEmpty) {
                          return Positioned(
                            bottom: 1,
                            child: Container(
                              height: 6,
                              width: 6,
                              decoration: BoxDecoration(
                                color: events.length > 1 
                                  ? Colors.pink 
                                  : Color((events.first as Map<String, dynamic>)["color"]),
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        }
                        return null;
                      },
                    ),
                  ),
            ),
            const SizedBox(height: 8),
            
            // Zobrazíme informaci o svatbě, pokud je aktuálně vybraný den svatby
            if (weddingDay != null && _selectedDay != null && isSameDay(_selectedDay!, weddingDay))
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.pink.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.favorite, color: Colors.pink),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr('wedding_day_info', namedArgs: {
                          'name1': _weddingInfo?.yourName ?? '',
                          'name2': _weddingInfo?.partnerName ?? ''
                        }),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
            const SizedBox(height: 8),
            
            // Záhlaví sekce událostí
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.event, color: Colors.pink.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('events_for_day', namedArgs: {
                        'date': DateFormat.yMMMMd(context.locale.toString()).format(_selectedDay ?? _focusedDay)
                      }),
                      style: const TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(thickness: 1, height: 16),
            
            Expanded(
              child: _getEventsForDay(_selectedDay ?? _focusedDay).isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 50, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            tr('no_events'),
                            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.add),
                            label: Text(tr('add_event')),
                            onPressed: () => _addOrEditEvent(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.pink.shade700,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _getEventsForDay(_selectedDay ?? _focusedDay).length,
                      itemBuilder: (context, index) {
                        final event = _getEventsForDay(_selectedDay ?? _focusedDay)[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Color(event["color"]),
                              child: const Icon(Icons.event_note, color: Colors.white),
                            ),
                            title: Text(
                              event["title"],
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event["allDay"] 
                                    ? tr('all_day_event')
                                    : tr('event_time', namedArgs: {
                                        'time': DateFormat.Hm().format(event["time"])
                                      }),
                                ),
                                if (event["location"] != null && event["location"].toString().isNotEmpty)
                                  Text(
                                    event["location"],
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (event["reminder"] != null)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.notifications,
                                        size: 12, 
                                        color: Colors.pink,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _getReminderText(event["reminder"]),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.pink,
                                        ),
                                      ),
                                    ],
                                  ),  
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _addOrEditEvent(event: event, index: index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteEvent(_selectedDay ?? _focusedDay, index),
                                ),
                              ],
                            ),
                            onTap: () => _showEventDetails(event, index),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.pink.shade700,
          onPressed: () => _addOrEditEvent(),
          child: const Icon(Icons.add),
          tooltip: tr('add_event'),
        ),
      ),
    );
  }
}
