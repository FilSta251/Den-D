import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../repositories/wedding_repository.dart';
import '../models/wedding_info.dart';
import '../services/local_wedding_info_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime? weddingDate;
  String? yourName;
  String? partnerName;
  String? weddingVenue;
  double? budget;
  
  Timer? _timer;
  Duration _timeLeft = Duration.zero;
  bool _isLoading = true;
  
  // Flag pro zabránění nekonečné smyčky aktualizací
  bool _isUpdatingFromCloud = false;
  
  // Referenční hodnota z cloudu
  WeddingInfo? _cloudWeddingInfo;

  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  List<Map<String, dynamic>> _todayEvents = [];

  // Přihlášení k streamu cloudových dat
  StreamSubscription<WeddingInfo?>? _weddingSubscription;
  late WeddingRepository _weddingRepository;
  late LocalWeddingInfoService _localWeddingInfoService;

  @override
  void initState() {
    super.initState();
    debugPrint('[HomeScreen] initState');
    
    _weddingRepository = Provider.of<WeddingRepository>(context, listen: false);
    _localWeddingInfoService = LocalWeddingInfoService();
    _localWeddingInfoService.setWeddingRepository(_weddingRepository);
    
    // Nejprve načteme data přímo z cloudu
    _loadWeddingInfoFromCloud();
    
    // Pak se přihlásíme k odběru změn
    _subscribeToWeddingInfo();
    
    _loadEvents();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _calculateTimeLeft();
      }
    });
  }

  Future<void> _loadWeddingInfoFromCloud() async {
    setState(() {
      _isLoading = true;
      _isUpdatingFromCloud = true;
    });

    try {
      debugPrint('[HomeScreen] Loading wedding info from cloud');
      final weddingInfo = await _weddingRepository.fetchWeddingInfo();
      
      if (weddingInfo != null && mounted) {
        setState(() {
          _cloudWeddingInfo = weddingInfo;
          weddingDate = weddingInfo.weddingDate;
          yourName = weddingInfo.yourName;
          partnerName = weddingInfo.partnerName;
          weddingVenue = weddingInfo.weddingVenue;
          budget = weddingInfo.budget;
          _isLoading = false;
        });
        
        // Aktualizujeme také lokální kopii
        await _localWeddingInfoService.saveWeddingInfo(weddingInfo);
        
        debugPrint('[HomeScreen] Cloud wedding info loaded: ${weddingInfo.toJson()}');
      }
    } catch (e) {
      debugPrint('[HomeScreen] Error loading from cloud: $e');
      // Pokud načtení z cloudu selže, zkusíme lokální kopii
      _loadWeddingInfoFromLocal();
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingFromCloud = false;
        });
      }
    }
  }

  Future<void> _loadWeddingInfoFromLocal() async {
    try {
      debugPrint('[HomeScreen] Loading wedding info from local storage');
      final weddingInfo = await _localWeddingInfoService.loadWeddingInfo();
      if (weddingInfo != null && mounted) {
        setState(() {
          _cloudWeddingInfo = weddingInfo;
          weddingDate = weddingInfo.weddingDate;
          yourName = weddingInfo.yourName;
          partnerName = weddingInfo.partnerName;
          weddingVenue = weddingInfo.weddingVenue;
          budget = weddingInfo.budget;
          _isLoading = false;
        });
        debugPrint('[HomeScreen] Local wedding info loaded: ${weddingInfo.toJson()}');
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[HomeScreen] Error loading from local storage: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _subscribeToWeddingInfo() {
    _weddingSubscription = _weddingRepository.weddingInfoStream.listen((weddingInfo) {
      if (weddingInfo != null && mounted && !_isUpdatingFromCloud) {
        // Zabráníme nekonečné smyčce aktualizací
        if (_cloudWeddingInfo != null) {
          // Porovnáme, jestli jsou data opravdu jiná
          final currentJson = _cloudWeddingInfo!.toJson().toString();
          final newJson = weddingInfo.toJson().toString();
          
          if (currentJson == newJson) {
            debugPrint('[HomeScreen] Ignoring redundant cloud update - data are the same');
            return;
          }
        }
        
        setState(() {
          _cloudWeddingInfo = weddingInfo;
          weddingDate = weddingInfo.weddingDate;
          yourName = weddingInfo.yourName;
          partnerName = weddingInfo.partnerName;
          weddingVenue = weddingInfo.weddingVenue;
          budget = weddingInfo.budget;
        });
        debugPrint('[HomeScreen] Updated from cloud: ${weddingInfo.toJson()}');
      }
    });
  }

  void _calculateTimeLeft() {
    if (weddingDate != null) {
      final now = DateTime.now();
      setState(() {
        _timeLeft = weddingDate!.difference(now);
        if (_timeLeft.isNegative) {
          _timeLeft = Duration.zero;
        }
      });
    }
  }

  Future<void> _loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('events');
    if (jsonString != null) {
      Map<String, dynamic> decodedMap = jsonDecode(jsonString);
      setState(() {
        _events = decodedMap.map((key, value) {
          return MapEntry(
            DateTime.parse(key),
            List<Map<String, dynamic>>.from(jsonDecode(value).map((event) {
              return {
                "title": event["title"],
                "time": DateTime.parse(event["time"]),
              };
            })),
          );
        });
        _updateTodayEvents();
      });
    }
  }

  void _updateTodayEvents() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    setState(() {
      _todayEvents = _events[todayDate] ?? [];
    });
  }

  void _navigateToCalendar() {
    Navigator.pushNamed(context, '/calendar').then((_) {
      _loadEvents();
      _updateTodayEvents();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _weddingSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final duration = weddingDate != null ? weddingDate!.difference(now) : Duration.zero;
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    // Použij výchozí hodnotu místo překladu, který chybí
    final String coupleNames = (yourName != null && partnerName != null && 
                              yourName != "--" && partnerName != "--") 
                              ? "$yourName & $partnerName" 
                              : "Svatební dvojice"; // výchozí text místo tr('wedding_couple')

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(tr('home_title')),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Načítání dat z cloudu...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('home_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWeddingInfoFromCloud,
            tooltip: 'Obnovit data',
          ),
        ],
      ),
      body: weddingDate == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(tr('home_no_wedding_date')),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/weddingInfo');
                    },
                    child: Text(tr('set_wedding_date')),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadWeddingInfoFromCloud,
                    child: const Text('Obnovit data'),
                  ),
                ],
              ),
            )
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Color(0xFFFFF0F5)], // Bílá s jemným růžovým nádechem
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Wedding Couple Names
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      coupleNames,
                      style: const TextStyle(
                        fontSize: 24, 
                        fontWeight: FontWeight.bold,
                        color: Colors.pink
                      ),
                    ),
                  ),
                  
                  // Countdown Circle
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFCDD2), Color(0xFFFFEBEE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.favorite, size: 48, color: Colors.pink),
                          const SizedBox(height: 8),
                          Text(
                            "$days d",
                            style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.pink),
                          ),
                          Text(
                            "$hours h : $minutes m : $seconds s",
                            style: const TextStyle(fontSize: 20, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Wedding Venue
                  if (weddingVenue != null && weddingVenue != "--")
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        "Místo konání: $weddingVenue",
                        style: const TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Colors.black87
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                  const SizedBox(height: 12),
                  
                  // Dnešní události
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('today_events'),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _todayEvents.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white70,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      tr('no_events_today'),
                                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _todayEvents.length,
                                  itemBuilder: (context, index) {
                                    final event = _todayEvents[index];
                                    return Card(
                                      margin: const EdgeInsets.symmetric(vertical: 6),
                                      elevation: 3,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: ListTile(
                                        title: Text(
                                          event["title"],
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        trailing: Text(
                                          DateFormat.Hm().format(event["time"]),
                                          style: const TextStyle(fontSize: 18, color: Colors.grey),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE91E63),
        onPressed: _navigateToCalendar,
        child: const Icon(Icons.calendar_today),
      ),
    );
  }
}