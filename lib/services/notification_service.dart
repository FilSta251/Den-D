// lib/services/notification_service.dart - OPRAVENÁ VERZE 4

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';

/// Enum pro intervaly opakování notifikací
enum RepeatInterval {
  daily,
  weekly,
  monthly,
  yearly,
}

/// NotificationService zajišťuje správu místních notifikací.
///
/// Tato služba umožňuje plánování a zrušení notifikací na konkrétní časy
/// pro upozornění na události, které souvisejí se svatbou.
class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionsGranted = false;
  
  // Inicializace notifikačního pluginu
  Future<bool> initialize() async {
    if (_initialized) return _permissionsGranted;
    
    try {
      // Inicializace časových zón
      tz_data.initializeTimeZones();
      final String timeZoneName = tz.local.name;
      debugPrint('Inicializace TimeZone: $timeZoneName');
      
      // Nastavení inicializace pro Android
      const AndroidInitializationSettings androidInitialize = AndroidInitializationSettings('app_icon');
      
      // Nastavení inicializace pro iOS - BEZ onDidReceiveLocalNotification
      const DarwinInitializationSettings iOSInitialize = DarwinInitializationSettings(
        requestAlertPermission: false, // Požádáme o povolení separátně
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      
      // Nastavení inicializace pro obě platformy
      const InitializationSettings initializationSettings = InitializationSettings(
        android: androidInitialize,
        iOS: iOSInitialize,
      );
      
      // Inicializace pluginu
      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Zde lze reagovat na kliknutí na notifikaci
          debugPrint('Notifikace kliknuta: ${response.payload}');
          _handleNotificationTap(response.payload);
        },
        onDidReceiveBackgroundNotificationResponse: _notificationTapBackground,
      );
      
      // Požádat o oprávnění
      _permissionsGranted = await _requestPermissions();
      
      _initialized = true;
      debugPrint('NotificationService inicializován (oprávnění: ${_permissionsGranted ? 'uděleno' : 'zamítnuto'})');
      return _permissionsGranted;
    } catch (e) {
      debugPrint('Chyba při inicializaci NotificationService: $e');
      return false;
    }
  }
  
  // Statická metoda pro background handling
  @pragma('vm:entry-point')
  static void _notificationTapBackground(NotificationResponse response) {
    debugPrint('Background notifikace kliknuta: ${response.payload}');
  }
  
  // Požádat o oprávnění pro notifikace
  Future<bool> _requestPermissions() async {
    try {
      if (Platform.isIOS) {
        // Oprávnění pro iOS
        final bool? result = await _notificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        return result ?? false;
      } else if (Platform.isAndroid) {
        // Oprávnění pro Android
        // Od Androidu 13 (SDK 33) je nutné explicitně požádat o oprávnění
        if (await Permission.notification.status.isDenied) {
          final status = await Permission.notification.request();
          return status.isGranted;
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Chyba při získávání oprávnění: $e');
      return false;
    }
  }
  
  // Kontrola stavu oprávnění pro notifikace
  Future<bool> checkPermissionStatus() async {
    try {
      if (Platform.isAndroid) {
        return await Permission.notification.isGranted;
      } else if (Platform.isIOS) {
        // Pro nové verze flutter_local_notifications používáme jiný přístup
        final bool? hasPermission = await _notificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: false,
              badge: false,
              sound: false,
            );
        return hasPermission ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Chyba při kontrole stavu oprávnění: $e');
      return false;
    }
  }
  
  // Zpracování kliknutí na notifikaci
  void _handleNotificationTap(String? payload) {
    if (payload != null && payload.isNotEmpty) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        // Zde můžete provést akce na základě dat v payload
        // Například navigaci na konkrétní obrazovku
        debugPrint('Zpracování kliknutí na notifikaci: $data');
      } catch (e) {
        debugPrint('Chyba při zpracování payload notifikace: $e');
      }
    }
  }
  
  // Naplánování notifikace s využitím zonedSchedule
  Future<int> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    Map<String, dynamic>? payload,
    String? channelId,
    String? channelName,
    String? channelDescription,
    bool playSound = true,
    String? soundName,
  }) async {
    // Inicializace pokud ještě nebyla provedena
    if (!_initialized) {
      final permissionGranted = await initialize();
      if (!permissionGranted) {
        debugPrint('Nelze naplánovat notifikaci - chybí oprávnění');
        throw Exception('Oprávnění pro notifikace nebylo uděleno');
      }
    }
    
    // Kontrola, zda čas notifikace je v budoucnosti
    final now = DateTime.now();
    if (scheduledTime.isBefore(now)) {
      debugPrint('Čas notifikace je v minulosti, upravuji na nejbližší budoucí čas');
      scheduledTime = now.add(const Duration(minutes: 1));
    }
    
    // Generování ID notifikace
    final notificationId = Random().nextInt(1000000);
    
    // Převod na TZDateTime pro správné časové pásmo
    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);
    
    // Nastavení detailů notifikace pro Android
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId ?? 'svatebni_planovac_channel',
      channelName ?? 'Svatební plánovač',
      channelDescription: channelDescription ?? 'Notifikace pro svatební plánovač',
      importance: Importance.max,
      priority: Priority.high,
      playSound: playSound,
      enableVibration: true,
      sound: soundName != null ? RawResourceAndroidNotificationSound(soundName) : null,
      styleInformation: const BigTextStyleInformation(''),
      category: AndroidNotificationCategory.reminder,
    );
    
    // Nastavení detailů notifikace pro iOS
    final DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
      sound: soundName,
      categoryIdentifier: 'reminder',
    );
    
    // Nastavení detailů notifikace pro obě platformy
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );
    
    try {
      // Naplánování notifikace pomocí zonedSchedule
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // UILocalNotificationDateInterpretation již neexistuje
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
        payload: payload != null ? jsonEncode(payload) : null,
      );
      
      // Uložení informací o notifikaci pro pozdější správu
      await _saveNotificationInfo(
        notificationId, 
        title, 
        body,
        scheduledTime, 
        payload,
      );
      
      debugPrint('Notifikace naplánována - ID: $notificationId, Čas: ${scheduledTime.toString()}');
      return notificationId;
    } catch (e) {
      debugPrint('Chyba při plánování notifikace: $e');
      throw Exception('Nepodařilo se naplánovat notifikaci: $e');
    }
  }
  
  // Naplánování opakující se notifikace
  Future<int> scheduleRepeatingNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    required RepeatInterval repeatInterval,
    Map<String, dynamic>? payload,
    String? channelId,
    String? channelName,
  }) async {
    // Inicializace pokud ještě nebyla provedena
    if (!_initialized) {
      final permissionGranted = await initialize();
      if (!permissionGranted) {
        debugPrint('Nelze naplánovat notifikaci - chybí oprávnění');
        throw Exception('Oprávnění pro notifikace nebylo uděleno');
      }
    }
    
    // Generování ID notifikace
    final notificationId = Random().nextInt(1000000);
    
    // Převod na TZDateTime pro správné časové pásmo
    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);
    
    // Nastavení detailů notifikace pro Android
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId ?? 'svatebni_planovac_recurring_channel',
      channelName ?? 'Opakující se upozornění',
      channelDescription: 'Opakující se notifikace pro svatební plánovač',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    
    // Nastavení detailů notifikace pro iOS
    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    // Nastavení detailů notifikace pro obě platformy
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );
    
    try {
      // Naplánování opakující se notifikace
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // UILocalNotificationDateInterpretation již neexistuje
        matchDateTimeComponents: _getDateTimeComponentsFromInterval(repeatInterval),
        payload: payload != null ? jsonEncode(payload) : null,
      );
      
      // Uložení informací o notifikaci
      await _saveNotificationInfo(
        notificationId, 
        title, 
        body,
        scheduledTime, 
        payload,
        repeatInterval: repeatInterval,
      );
      
      debugPrint('Opakující se notifikace naplánována - ID: $notificationId, Interval: $repeatInterval');
      return notificationId;
    } catch (e) {
      debugPrint('Chyba při plánování opakující se notifikace: $e');
      throw Exception('Nepodařilo se naplánovat opakující se notifikaci: $e');
    }
  }
  
  // Převod RepeatInterval na DateTimeComponents pro opakující se notifikace
  DateTimeComponents? _getDateTimeComponentsFromInterval(RepeatInterval interval) {
    switch (interval) {
      case RepeatInterval.daily:
        return DateTimeComponents.time;
      case RepeatInterval.weekly:
        return DateTimeComponents.dayOfWeekAndTime;
      case RepeatInterval.monthly:
        return DateTimeComponents.dayOfMonthAndTime;
      case RepeatInterval.yearly:
        // Pro roční opakování používáme dateAndTime, protože yearly není podporováno
        return DateTimeComponents.dateAndTime;
    }
  }
  
  // Zrušení notifikace podle ID
  Future<bool> cancelNotification(int id) async {
    try {
      if (!_initialized) {
        await initialize();
      }
      
      await _notificationsPlugin.cancel(id);
      await _removeNotificationInfo(id);
      
      debugPrint('Notifikace zrušena - ID: $id');
      return true;
    } catch (e) {
      debugPrint('Chyba při rušení notifikace: $e');
      return false;
    }
  }
  
  // Zrušení všech notifikací
  Future<bool> cancelAllNotifications() async {
    try {
      if (!_initialized) {
        await initialize();
      }
      
      await _notificationsPlugin.cancelAll();
      await _clearAllNotificationInfo();
      
      debugPrint('Všechny notifikace zrušeny');
      return true;
    } catch (e) {
      debugPrint('Chyba při rušení všech notifikací: $e');
      return false;
    }
  }
  
  // Uložení informací o notifikaci do SharedPreferences
  Future<void> _saveNotificationInfo(
    int id, 
    String title, 
    String body,
    DateTime scheduledTime, 
    Map<String, dynamic>? payload, {
    RepeatInterval? repeatInterval,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Načtení existujících informací
      final String notificationsJson = prefs.getString('notifications_info') ?? '{}';
      final Map<String, dynamic> notificationsMap = Map<String, dynamic>.from(
        jsonDecode(notificationsJson) as Map
      );
      
      // Přidání nové notifikace
      notificationsMap[id.toString()] = {
        'id': id,
        'title': title,
        'body': body,
        'scheduledTime': scheduledTime.toIso8601String(),
        'created': DateTime.now().toIso8601String(),
        if (payload != null) 'payload': payload,
        if (repeatInterval != null) 'repeatInterval': repeatInterval.index,
      };
      
      // Uložení aktualizovaných informací
      await prefs.setString('notifications_info', jsonEncode(notificationsMap));
    } catch (e) {
      debugPrint('Chyba při ukládání informací o notifikaci: $e');
    }
  }
  
  // Odstranění informací o notifikaci ze SharedPreferences
  Future<void> _removeNotificationInfo(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Načtení existujících informací
      final String notificationsJson = prefs.getString('notifications_info') ?? '{}';
      final Map<String, dynamic> notificationsMap = Map<String, dynamic>.from(
        jsonDecode(notificationsJson) as Map
      );
      
      // Odstranění notifikace
      notificationsMap.remove(id.toString());
      
      // Uložení aktualizovaných informací
      await prefs.setString('notifications_info', jsonEncode(notificationsMap));
    } catch (e) {
      debugPrint('Chyba při odstraňování informací o notifikaci: $e');
    }
  }
  
  // Vymazání všech informací o notifikacích ze SharedPreferences
  Future<void> _clearAllNotificationInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('notifications_info');
    } catch (e) {
      debugPrint('Chyba při odstraňování všech informací o notifikacích: $e');
    }
  }
  
  // Získání seznamu plánovaných notifikací
  Future<List<Map<String, dynamic>>> getScheduledNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Načtení existujících informací
      final String notificationsJson = prefs.getString('notifications_info') ?? '{}';
      final Map<String, dynamic> notificationsMap = Map<String, dynamic>.from(
        jsonDecode(notificationsJson) as Map
      );
      
      // Převod na seznam
      final List<Map<String, dynamic>> notificationsList = [];
      for (final entry in notificationsMap.entries) {
        final data = entry.value as Map<String, dynamic>;
        
        // Přidat do seznamu pouze pokud obsahuje požadované klíče
        if (data.containsKey('id') && data.containsKey('title') && data.containsKey('scheduledTime')) {
          notificationsList.add(Map<String, dynamic>.from(data));
        }
      }
      
      // Seřadit podle plánovaného času
      notificationsList.sort((a, b) {
        final DateTime timeA = DateTime.parse(a['scheduledTime'] as String);
        final DateTime timeB = DateTime.parse(b['scheduledTime'] as String);
        return timeA.compareTo(timeB);
      });
      
      return notificationsList;
    } catch (e) {
      debugPrint('Chyba při získávání seznamu notifikací: $e');
      return [];
    }
  }
  
  // Odeslání okamžité notifikace
  Future<int> showInstantNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
    String? bigPicture,
    bool playSound = true,
  }) async {
    if (!_initialized) {
      final permissionGranted = await initialize();
      if (!permissionGranted) {
        throw Exception('Oprávnění pro notifikace nebylo uděleno');
      }
    }
    
    // Nastavení detailů pro notifikaci s obrázkem, pokud je poskytnut
    AndroidNotificationDetails androidDetails;
    
    if (bigPicture != null) {
      // Notifikace s obrázkem
      androidDetails = AndroidNotificationDetails(
        'svatebni_planovac_image_channel',
        'Svatební plánovač s obrázkem',
        channelDescription: 'Notifikace pro svatební plánovač s obrázkem',
        importance: Importance.max,
        priority: Priority.high,
        playSound: playSound,
        enableVibration: true,
        styleInformation: BigPictureStyleInformation(
          FilePathAndroidBitmap(bigPicture),
          largeIcon: FilePathAndroidBitmap(bigPicture),
          contentTitle: title,
          summaryText: body,
          hideExpandedLargeIcon: false,
        ),
      );
    } else {
      // Standardní notifikace
      androidDetails = AndroidNotificationDetails(
        'svatebni_planovac_channel',
        'Svatební plánovač',
        channelDescription: 'Notifikace pro svatební plánovač',
        importance: Importance.max,
        priority: Priority.high,
        playSound: playSound,
        enableVibration: true,
      );
    }
    
    // Nastavení detailů notifikace pro iOS
    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );
    
    // Nastavení detailů notifikace pro obě platformy
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );
    
    // Generování ID notifikace
    final int notificationId = Random().nextInt(1000000);
    
    try {
      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload != null ? jsonEncode(payload) : null,
      );
      
      // Uložení informací o okamžité notifikaci
      await _saveNotificationInfo(
        notificationId, 
        title, 
        body,
        DateTime.now(), 
        payload,
      );
      
      debugPrint('Okamžitá notifikace zobrazena - ID: $notificationId');
      return notificationId;
    } catch (e) {
      debugPrint('Chyba při zobrazování okamžité notifikace: $e');
      throw Exception('Nepodařilo se zobrazit notifikaci: $e');
    }
  }
  
  // Vytvoření vlastního kanálu pro Android
  Future<void> createNotificationChannel({
    required String channelId,
    required String channelName,
    required String channelDescription,
    required Importance importance,
    bool playSound = true,
    String? soundSource,
  }) async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin = 
          _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        final AndroidNotificationChannel channel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: importance,
          playSound: playSound,
          sound: soundSource != null ? RawResourceAndroidNotificationSound(soundSource) : null,
          enableVibration: true,
        );
        
        await androidPlugin.createNotificationChannel(channel);
        debugPrint('Vytvořen nový notifikační kanál: $channelId');
      }
    }
  }
  
  // Odstranění notifikačního kanálu
  Future<void> deleteNotificationChannel(String channelId) async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin = 
          _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        await androidPlugin.deleteNotificationChannel(channelId);
        debugPrint('Odstraněn notifikační kanál: $channelId');
      }
    }
  }
  
  // Získání aktivních notifikací
  Future<List<ActiveNotification>?> getActiveNotifications() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin = 
          _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        return await androidPlugin.getActiveNotifications();
      }
    }
    
    return null;
  }
  
  // Otevření nastavení notifikací
  Future<void> openNotificationSettings() async {
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidPlugin = 
            _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
        if (androidPlugin != null) {
          await androidPlugin.requestNotificationsPermission();
        }
      } else if (Platform.isIOS) {
        await openAppSettings();
      }
    } catch (e) {
      debugPrint('Chyba při otevírání nastavení notifikací: $e');
    }
  }
}