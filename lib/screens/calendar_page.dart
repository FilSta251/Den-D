/// lib/screens/calendar_page.dart
library;

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../models/calendar_event.dart';
import '../repositories/wedding_repository.dart';
import '../models/wedding_info.dart';
import '../services/calendar_manager.dart';
import '../services/notification_service.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage>
    with TickerProviderStateMixin {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  WeddingInfo? _weddingInfo;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  late TabController _viewTabController;
  final List<String> _viewOptions = ['month_view', 'week_view', 'day_view'];
  int _currentViewIndex = 0;

  // Filtr podle barvy
  Color? _selectedColorFilter;

  // Dostupné barvy
  final List<Color> _availableColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.brown,
    Colors.amber,
    Colors.indigo,
    Colors.cyan,
    Colors.lime,
  ];

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    _loadWeddingInfo();

    _viewTabController = TabController(
      length: _viewOptions.length,
      vsync: this,
      initialIndex: _currentViewIndex,
    );
    _viewTabController.addListener(_handleViewChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final calendarManager =
            Provider.of<CalendarManager>(context, listen: false);
        calendarManager.forceRefreshFromCloud();
      }
    });
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
        switch (_currentViewIndex) {
          case 0:
            _calendarFormat = CalendarFormat.month;
            break;
          case 1:
            _calendarFormat = CalendarFormat.week;
            break;
          case 2:
            _calendarFormat = CalendarFormat.week;
            break;
        }
      });
    }
  }

  Future<void> _loadWeddingInfo() async {
    if (!mounted) return;

    try {
      final weddingRepo =
          Provider.of<WeddingRepository>(context, listen: false);
      final wedding = await weddingRepo.fetchWeddingInfo();

      if (!mounted) return;

      setState(() {
        _weddingInfo = wedding;
      });

      if (!mounted) return;

      final today = DateTime.now();
      final todayKey = DateTime(today.year, today.month, today.day);

      setState(() {
        _selectedDay = todayKey;
        _focusedDay = todayKey;
      });
    } catch (e) {
      debugPrint('[CalendarPage] Error loading wedding info: $e');
    }
  }

  List<CalendarEvent> _getEventsForDay(
      DateTime day, CalendarManager calendarManager) {
    final events = calendarManager.getEventsForDay(day);

    // Filtrování podle barvy
    if (_selectedColorFilter != null) {
      return events
          .where((e) => Color(e.color) == _selectedColorFilter)
          .toList();
    }

    return events;
  }

  Future<void> _addOrEditEvent(
      {CalendarEvent? event, DateTime? selectedDate}) async {
    if (!mounted) return;

    final calendarManager =
        Provider.of<CalendarManager>(context, listen: false);
    final notificationService =
        Provider.of<NotificationService>(context, listen: false);

    final TextEditingController titleController = TextEditingController(
      text: event?.title ?? "",
    );
    final TextEditingController descriptionController = TextEditingController(
      text: event?.description ?? "",
    );
    final TextEditingController locationController = TextEditingController(
      text: event?.location ?? "",
    );

    final eventDate = selectedDate ?? _selectedDay ?? _focusedDay;

    TimeOfDay selectedStartTime = event != null
        ? TimeOfDay.fromDateTime(event.startTime)
        : TimeOfDay.now();

    TimeOfDay selectedEndTime = event != null && event.endTime != null
        ? TimeOfDay.fromDateTime(event.endTime!)
        : TimeOfDay(
            hour: TimeOfDay.now().hour + 1, minute: TimeOfDay.now().minute);

    bool isAllDay = event?.allDay ?? false;
    Color selectedColor = event != null ? Color(event.color) : Colors.blue;

    // Nastavení notifikací
    bool notificationEnabled = event?.notificationEnabled ?? false;
    int notificationMinutesBefore = event?.notificationMinutesBefore ?? 30;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 40,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(builderContext).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header s titulkem
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event, color: Colors.pink.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              event == null
                                  ? tr('add_event')
                                  : tr('edit_event'),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.pink.shade700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                    ),

                    // Scrollovatelný obsah
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Název události
                            TextField(
                              controller: titleController,
                              autofocus: false,
                              decoration: InputDecoration(
                                labelText: tr('event_title'),
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.title),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Celý den switch
                            SwitchListTile(
                              title: Text(tr('all_day_event')),
                              value: isAllDay,
                              activeColor: Colors.pink,
                              onChanged: (newValue) {
                                setDialogState(() => isAllDay = newValue);
                              },
                            ),

                            // Časy (pokud není celý den)
                            if (!isAllDay) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final picked = await showTimePicker(
                                          context: builderContext,
                                          initialTime: selectedStartTime,
                                          builder: (context, child) =>
                                              MediaQuery(
                                            data: MediaQuery.of(context)
                                                .copyWith(
                                                    alwaysUse24HourFormat:
                                                        true),
                                            child: child!,
                                          ),
                                        );
                                        if (picked != null) {
                                          setDialogState(() {
                                            selectedStartTime = picked;
                                            if (_timeToMinutes(
                                                    selectedEndTime) <=
                                                _timeToMinutes(
                                                    selectedStartTime)) {
                                              selectedEndTime = TimeOfDay(
                                                hour: (selectedStartTime.hour +
                                                        1) %
                                                    24,
                                                minute:
                                                    selectedStartTime.minute,
                                              );
                                            }
                                          });
                                        }
                                      },
                                      child: InputDecorator(
                                        decoration: InputDecoration(
                                          labelText: tr('start_time'),
                                          border: const OutlineInputBorder(),
                                          prefixIcon:
                                              const Icon(Icons.access_time),
                                        ),
                                        child: Text(
                                          '${selectedStartTime.hour.toString().padLeft(2, '0')}:${selectedStartTime.minute.toString().padLeft(2, '0')}',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final picked = await showTimePicker(
                                          context: builderContext,
                                          initialTime: selectedEndTime,
                                          builder: (context, child) =>
                                              MediaQuery(
                                            data: MediaQuery.of(context)
                                                .copyWith(
                                                    alwaysUse24HourFormat:
                                                        true),
                                            child: child!,
                                          ),
                                        );
                                        if (picked != null) {
                                          setDialogState(
                                              () => selectedEndTime = picked);
                                        }
                                      },
                                      child: InputDecorator(
                                        decoration: InputDecoration(
                                          labelText: tr('end_time'),
                                          border: const OutlineInputBorder(),
                                          prefixIcon: const Icon(
                                              Icons.access_time_filled),
                                        ),
                                        child: Text(
                                          '${selectedEndTime.hour.toString().padLeft(2, '0')}:${selectedEndTime.minute.toString().padLeft(2, '0')}',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Popis
                            TextField(
                              controller: descriptionController,
                              decoration: InputDecoration(
                                labelText: tr('event_description'),
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.description),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),

                            // Lokace
                            TextField(
                              controller: locationController,
                              decoration: InputDecoration(
                                labelText: tr('event_location'),
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.location_on),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Výběr barvy
                            Text(
                              "${tr('event_color')}:",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: _availableColors.map((color) {
                                final isSelected = selectedColor == color;
                                return GestureDetector(
                                  onTap: () => setDialogState(
                                      () => selectedColor = color),
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(
                                              color: Colors.black,
                                              width: 3,
                                            )
                                          : null,
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: color.withValues(
                                                    alpha: 0.5),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 28,
                                          )
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 12),

                            // Notifikace
                            SwitchListTile(
                              title: Row(
                                children: [
                                  const Icon(Icons.notifications_active,
                                      size: 20),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      tr('event_notification'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: notificationEnabled
                                  ? Text(
                                      tr('event_notification_time', namedArgs: {
                                        'minutes':
                                            notificationMinutesBefore.toString()
                                      }),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              value: notificationEnabled,
                              activeColor: Colors.pink,
                              onChanged: (newValue) {
                                setDialogState(
                                    () => notificationEnabled = newValue);
                              },
                            ),

                            // Nastavení času notifikace
                            if (notificationEnabled) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tr('event_notification_before'),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _buildTimeChip(
                                          builderContext,
                                          label: '5 ${tr('minutes')}',
                                          minutes: 5,
                                          selectedMinutes:
                                              notificationMinutesBefore,
                                          onTap: () => setDialogState(() =>
                                              notificationMinutesBefore = 5),
                                        ),
                                        _buildTimeChip(
                                          builderContext,
                                          label: '10 ${tr('minutes')}',
                                          minutes: 10,
                                          selectedMinutes:
                                              notificationMinutesBefore,
                                          onTap: () => setDialogState(() =>
                                              notificationMinutesBefore = 10),
                                        ),
                                        _buildTimeChip(
                                          builderContext,
                                          label: '15 ${tr('minutes')}',
                                          minutes: 15,
                                          selectedMinutes:
                                              notificationMinutesBefore,
                                          onTap: () => setDialogState(() =>
                                              notificationMinutesBefore = 15),
                                        ),
                                        _buildTimeChip(
                                          builderContext,
                                          label: '30 ${tr('minutes')}',
                                          minutes: 30,
                                          selectedMinutes:
                                              notificationMinutesBefore,
                                          onTap: () => setDialogState(() =>
                                              notificationMinutesBefore = 30),
                                        ),
                                        _buildTimeChip(
                                          builderContext,
                                          label: '1 ${tr('hour')}',
                                          minutes: 60,
                                          selectedMinutes:
                                              notificationMinutesBefore,
                                          onTap: () => setDialogState(() =>
                                              notificationMinutesBefore = 60),
                                        ),
                                        _buildTimeChip(
                                          builderContext,
                                          label: '2 ${tr('hours')}',
                                          minutes: 120,
                                          selectedMinutes:
                                              notificationMinutesBefore,
                                          onTap: () => setDialogState(() =>
                                              notificationMinutesBefore = 120),
                                        ),
                                        _buildTimeChip(
                                          builderContext,
                                          label: '1 ${tr('day')}',
                                          minutes: 1440,
                                          selectedMinutes:
                                              notificationMinutesBefore,
                                          onTap: () => setDialogState(() =>
                                              notificationMinutesBefore = 1440),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Tlačítka
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text(tr('cancel')),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pink.shade300,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            icon: const Icon(Icons.check),
                            label: Text(event == null ? tr('add') : tr('save')),
                            onPressed: () {
                              if (titleController.text.trim().isNotEmpty) {
                                final eventStartTime = DateTime(
                                  eventDate.year,
                                  eventDate.month,
                                  eventDate.day,
                                  isAllDay ? 0 : selectedStartTime.hour,
                                  isAllDay ? 0 : selectedStartTime.minute,
                                );

                                final eventEndTime = isAllDay
                                    ? null
                                    : DateTime(
                                        eventDate.year,
                                        eventDate.month,
                                        eventDate.day,
                                        selectedEndTime.hour,
                                        selectedEndTime.minute,
                                      );

                                Navigator.pop(dialogContext, {
                                  "title": titleController.text.trim(),
                                  "startTime": eventStartTime,
                                  "endTime": eventEndTime,
                                  "description":
                                      descriptionController.text.trim(),
                                  "location": locationController.text.trim(),
                                  "allDay": isAllDay,
                                  "color": selectedColor.value,
                                  "notificationEnabled": notificationEnabled,
                                  "notificationMinutesBefore":
                                      notificationMinutesBefore,
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
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (result != null) {
      if (event != null) {
        final updatedEvent = event.copyWith(
          title: result["title"],
          startTime: result["startTime"],
          endTime: result["endTime"],
          description: result["description"],
          location: result["location"],
          allDay: result["allDay"],
          color: result["color"],
          notificationEnabled: result["notificationEnabled"],
          notificationMinutesBefore: result["notificationMinutesBefore"],
        );
        calendarManager.updateEvent(updatedEvent);

        // Naplánování notifikace
        if (updatedEvent.notificationEnabled) {
          await _scheduleNotification(notificationService, updatedEvent);
        } else {
          await notificationService
              .cancelNotification(updatedEvent.id.hashCode);
        }
      } else {
        final newEvent = CalendarEvent(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: result["title"],
          startTime: result["startTime"],
          endTime: result["endTime"],
          description: result["description"],
          location: result["location"],
          allDay: result["allDay"],
          color: result["color"],
          notificationEnabled: result["notificationEnabled"],
          notificationMinutesBefore: result["notificationMinutesBefore"],
        );
        calendarManager.addEvent(newEvent);

        // Naplánování notifikace
        if (newEvent.notificationEnabled) {
          await _scheduleNotification(notificationService, newEvent);
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('event_saved'),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildTimeChip(
    BuildContext context, {
    required String label,
    required int minutes,
    required int selectedMinutes,
    required VoidCallback onTap,
  }) {
    final isSelected = minutes == selectedMinutes;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Colors.pink.shade200,
      onSelected: (bool selected) => onTap(),
    );
  }

  Future<void> _scheduleNotification(
      NotificationService notificationService, CalendarEvent event) async {
    if (!event.notificationEnabled) return;

    final notificationTime = event.startTime.subtract(
      Duration(minutes: event.notificationMinutesBefore),
    );

    if (notificationTime.isAfter(DateTime.now())) {
      await notificationService.scheduleNotification(
        title: tr('event_reminder'),
        body:
            '${event.title} ${tr('event_starts_in')} ${event.notificationMinutesBefore} ${tr('minutes')}',
        scheduledTime: notificationTime,
        payload: {'event_id': event.id, 'type': 'calendar_event'},
      );
    }
  }

  int _timeToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  Future<void> _deleteEvent(CalendarEvent event) async {
    if (!mounted) return;

    final bool confirm = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(tr('confirm')),
            content: Text(tr('confirm_delete_event'),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(tr('cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(tr('delete')),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted) return;

    if (confirm) {
      final calendarManager =
          Provider.of<CalendarManager>(context, listen: false);
      final notificationService =
          Provider.of<NotificationService>(context, listen: false);

      // Zrušení notifikace
      await notificationService.cancelNotification(event.id.hashCode);

      calendarManager.removeEvent(event.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('event_deleted'),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _showEventDetails(CalendarEvent event) async {
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _addOrEditEvent(event: event);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _deleteEvent(event);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(event.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.grey.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: event.allDay
                            ? Text(
                                tr('all_day_event'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : Text(
                                '${event.startTime.hour.toString().padLeft(2, '0')}:${event.startTime.minute.toString().padLeft(2, '0')} - ${event.endTime != null ? '${event.endTime!.hour.toString().padLeft(2, '0')}:${event.endTime!.minute.toString().padLeft(2, '0')}' : ""}',
                                style: const TextStyle(fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ],
                  ),
                  if (event.location != null && event.location!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.grey.shade700),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              event.location!,
                              style: const TextStyle(fontSize: 16),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (event.notificationEnabled)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Icon(Icons.notifications_active,
                              color: Colors.grey.shade700),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tr('event_notification_time', namedArgs: {
                                'minutes':
                                    event.notificationMinutesBefore.toString()
                              }),
                              style: const TextStyle(fontSize: 16),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (event.description != null &&
                      event.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
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
                            event.description!,
                            style: const TextStyle(fontSize: 16),
                            maxLines: 10,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
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
                          Navigator.pop(sheetContext);
                          _addOrEditEvent(event: event);
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
                          Navigator.pop(sheetContext);
                          _deleteEvent(event);
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
    return Consumer<CalendarManager>(
      builder: (context, calendarManager, child) {
        final weddingDay = _weddingInfo?.weddingDate != null
            ? DateTime(
                _weddingInfo!.weddingDate.year,
                _weddingInfo!.weddingDate.month,
                _weddingInfo!.weddingDate.day,
              )
            : null;

        final bool showSyncIndicator =
            calendarManager.syncState == SyncState.syncing;

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            // Callback po zavření stránky
          },
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              title: Text(tr('calendar')),
              centerTitle: true,
              actions: [
                // ONLINE/OFFLINE ikona
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    calendarManager.isOnline
                        ? Icons.cloud_done
                        : Icons.cloud_off,
                    color:
                        calendarManager.isOnline ? Colors.green : Colors.orange,
                  ),
                ),
                // JUMP TO TODAY
                IconButton(
                  icon: const Icon(Icons.today),
                  tooltip: tr('jump_to_today'),
                  onPressed: () {
                    setState(() {
                      _focusedDay = DateTime.now();
                      _selectedDay = DateTime.now();
                    });
                  },
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
            body: Stack(
              children: [
                Column(
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      child: _currentViewIndex == 2
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.arrow_back_ios),
                                        onPressed: () {
                                          setState(() {
                                            _selectedDay = _selectedDay!
                                                .subtract(
                                                    const Duration(days: 1));
                                            _focusedDay = _selectedDay!;
                                          });
                                        },
                                      ),
                                      Expanded(
                                        child: Text(
                                          DateFormat.yMMMMd(
                                                  context.locale.toString())
                                              .format(
                                                  _selectedDay ?? _focusedDay),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon:
                                            const Icon(Icons.arrow_forward_ios),
                                        onPressed: () {
                                          setState(() {
                                            _selectedDay = _selectedDay!
                                                .add(const Duration(days: 1));
                                            _focusedDay = _selectedDay!;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          : TableCalendar<CalendarEvent>(
                              focusedDay: _focusedDay,
                              firstDay: DateTime(2000),
                              lastDay: DateTime(2100),
                              locale: context.locale.languageCode,
                              selectedDayPredicate: (day) =>
                                  isSameDay(_selectedDay, day),
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
                              eventLoader: (day) =>
                                  _getEventsForDay(day, calendarManager),
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
                              headerStyle: const HeaderStyle(
                                titleCentered: true,
                                formatButtonVisible: false,
                                titleTextStyle: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              calendarBuilders: CalendarBuilders(
                                defaultBuilder: (context, day, focusedDay) {
                                  if (weddingDay != null &&
                                      isSameDay(day, weddingDay)) {
                                    return Container(
                                      margin: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.pink, width: 2),
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
                                              : Color(events.first.color),
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
                    if (weddingDay != null &&
                        _selectedDay != null &&
                        isSameDay(_selectedDay!, weddingDay))
                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_selectedColorFilter != null)
                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _selectedColorFilter!.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _selectedColorFilter!, width: 2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: _selectedColorFilter,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tr('color_filter_active'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                setState(() => _selectedColorFilter = null);
                              },
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(Icons.event, color: Colors.pink.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr('events_for_day', namedArgs: {
                                'date':
                                    DateFormat.yMMMMd(context.locale.toString())
                                        .format(_selectedDay ?? _focusedDay)
                              }),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(thickness: 1, height: 16),
                    Expanded(
                      child: _getEventsForDay(
                                  _selectedDay ?? _focusedDay, calendarManager)
                              .isEmpty
                          ? SingleChildScrollView(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top: 20,
                                  bottom: MediaQuery.of(context)
                                          .viewPadding
                                          .bottom +
                                      16,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.event_busy,
                                        size: 50, color: Colors.grey.shade400),
                                    const SizedBox(height: 16),
                                    Text(
                                      _selectedColorFilter != null
                                          ? tr('no_events_with_color')
                                          : tr('no_events'),
                                      style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _getEventsForDay(
                                      _selectedDay ?? _focusedDay,
                                      calendarManager)
                                  .length,
                              itemBuilder: (context, index) {
                                final event = _getEventsForDay(
                                    _selectedDay ?? _focusedDay,
                                    calendarManager)[index];

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 12),
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: Color(event.color),
                                      width: 2,
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Color(event.color),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        event.notificationEnabled
                                            ? Icons.notifications_active
                                            : Icons.event_note,
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Text(
                                      event.title,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          event.allDay
                                              ? tr('all_day_event')
                                              : tr('event_time', namedArgs: {
                                                  'time':
                                                      '${event.startTime.hour.toString().padLeft(2, '0')}:${event.startTime.minute.toString().padLeft(2, '0')}'
                                                }),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (event.location != null &&
                                            event.location!.isNotEmpty)
                                          Text(
                                            event.location!,
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                    trailing: SizedBox(
                                      width: 88,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                color: Colors.blue, size: 18),
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(
                                              minWidth: 36,
                                              minHeight: 36,
                                            ),
                                            onPressed: () =>
                                                _addOrEditEvent(event: event),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red, size: 18),
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(
                                              minWidth: 36,
                                              minHeight: 36,
                                            ),
                                            onPressed: () =>
                                                _deleteEvent(event),
                                          ),
                                        ],
                                      ),
                                    ),
                                    onTap: () => _showEventDetails(event),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
                if (showSyncIndicator)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.blue.withValues(alpha: 0.9),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tr('syncing'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              backgroundColor: Colors.pink.shade700,
              onPressed: () =>
                  _addOrEditEvent(selectedDate: _selectedDay ?? _focusedDay),
              tooltip: tr('add_event'),
              child: const Icon(Icons.add),
            ),
          ),
        );
      },
    );
  }
}
