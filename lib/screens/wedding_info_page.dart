import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/wedding_info.dart';
import '../services/local_wedding_info_service.dart';
import '../repositories/wedding_repository.dart';

/// WeddingInfoPage zobrazuje informace o svatbě a umožňuje je upravovat.
/// Data jsou ukládána lokálně pomocí SharedPreferences a synchronizována s cloudem.
class WeddingInfoPage extends StatefulWidget {
  const WeddingInfoPage({Key? key}) : super(key: key);

  @override
  _WeddingInfoPageState createState() => _WeddingInfoPageState();
}

class _WeddingInfoPageState extends State<WeddingInfoPage> {
  bool _isEditMode = false;
  bool _isSaving = false;
  bool _isLoading = true;
  String _errorMessage = '';
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _dateController;
  late final TextEditingController _yourNameController;
  late final TextEditingController _partnerNameController;
  late final TextEditingController _venueController;
  late final TextEditingController _budgetController;
  late final TextEditingController _notesController;

  late LocalWeddingInfoService _localService;
  late WeddingRepository _weddingRepository;
  
  // Referenční hodnota z cloudu
  WeddingInfo? _cloudWeddingInfo;
  
  // Flag pro zabránění nekonečné smyčky aktualizací
  bool _isUpdatingFromCloud = false;
  
  // Subscription na stream dat z cloudu
  StreamSubscription<WeddingInfo?>? _weddingSubscription;

  @override
  void initState() {
    super.initState();
    debugPrint('[WeddingInfoPage] initState');
    
    _dateController = TextEditingController();
    _yourNameController = TextEditingController();
    _partnerNameController = TextEditingController();
    _venueController = TextEditingController();
    _budgetController = TextEditingController();
    _notesController = TextEditingController();
    
    _localService = LocalWeddingInfoService();
    _weddingRepository = Provider.of<WeddingRepository>(context, listen: false);
    
    // Nastavíme referenci na repository pro lokální service
    _localService.setWeddingRepository(_weddingRepository);
    
    // Přihlásíme se k odběru změn z cloudu
    _subscribeToCloudUpdates();
    
    // Načteme data primárně z cloudu
    _loadWeddingInfoFromCloud();
  }

  void _subscribeToCloudUpdates() {
    _weddingSubscription = _weddingRepository.weddingInfoStream.listen((weddingInfo) {
      if (weddingInfo != null && mounted && !_isEditMode && !_isUpdatingFromCloud) {
        debugPrint('[WeddingInfoPage] Received cloud update while not in edit mode');
        
        // Zabráníme nekonečné smyčce aktualizací
        if (_cloudWeddingInfo != null) {
          // Porovnáme, jestli jsou data opravdu jiná
          final currentJson = _cloudWeddingInfo!.toJson().toString();
          final newJson = weddingInfo.toJson().toString();
          
          if (currentJson == newJson) {
            debugPrint('[WeddingInfoPage] Ignoring redundant cloud update - data are the same');
            return;
          }
        }
        
        // Aktualizujeme zobrazení s aktuálními daty z cloudu
        setState(() {
          _cloudWeddingInfo = weddingInfo;
          if (!_isEditMode) {
            _initializeControllers(weddingInfo);
          }
        });
      }
    });
  }

  // Načítání dat přímo z cloudu
  Future<void> _loadWeddingInfoFromCloud() async {
    setState(() {
      _isLoading = true;
      _isUpdatingFromCloud = true;
    });
    
    debugPrint('[WeddingInfoPage] Loading wedding info directly from cloud');
    
    try {
      // Načteme data z cloudu
      final weddingInfo = await _weddingRepository.fetchWeddingInfo();
      
      if (weddingInfo != null && mounted) {
        debugPrint('[WeddingInfoPage] Cloud data loaded: ${weddingInfo.toJson()}');
        
        // Aktualizujeme referenční hodnotu
        _cloudWeddingInfo = weddingInfo;
        
        // Aktualizujeme lokální kopii, ale bez zpětné propagace na cloud
        await _localService.saveWeddingInfo(weddingInfo);
        
        if (!_isEditMode) {
          _initializeControllers(weddingInfo);
        }
      }
    } catch (e) {
      debugPrint('[WeddingInfoPage] Error loading from cloud: $e, falling back to local data');
      // Pokud se nezdaří načíst z cloudu, zkusíme lokální kopii
      _loadWeddingInfoFromLocal();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUpdatingFromCloud = false;
        });
      }
    }
  }

  // Záložní metoda pro načtení dat lokálně
  Future<void> _loadWeddingInfoFromLocal() async {
    debugPrint('[WeddingInfoPage] Loading wedding info from local storage');
    
    try {
      final localInfo = await _localService.loadWeddingInfo();
      if (localInfo != null && mounted) {
        _cloudWeddingInfo = localInfo;
        
        if (!_isEditMode) {
          _initializeControllers(localInfo);
        }
      }
    } catch (e) {
      debugPrint('[WeddingInfoPage] Error loading from local storage: $e');
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _yourNameController.dispose();
    _partnerNameController.dispose();
    _venueController.dispose();
    _budgetController.dispose();
    _notesController.dispose();
    _weddingSubscription?.cancel();
    debugPrint('[WeddingInfoPage] dispose');
    super.dispose();
  }

  /// Naplní textové controllery hodnotami z instance [WeddingInfo].
  void _initializeControllers(WeddingInfo info) {
    _dateController.text = DateFormat('yyyy-MM-dd').format(info.weddingDate);
    _yourNameController.text = info.yourName;
    _partnerNameController.text = info.partnerName;
    _venueController.text = info.weddingVenue;
    _budgetController.text = info.budget.toStringAsFixed(2);
    _notesController.text = info.notes;
    debugPrint('[WeddingInfoPage] Controllers initialized with wedding info data: ${info.toJson()}');
  }

  /// Uloží upravené informace lokálně a na cloud a aktualizuje zobrazení.
  Future<void> _saveWeddingInfo(WeddingInfo originalInfo) async {
    if (!_formKey.currentState!.validate()) {
      debugPrint('[WeddingInfoPage] Form validation failed.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = '';
    });

    try {
      final parsedDate = DateFormat('yyyy-MM-dd').parse(_dateController.text.trim());
      final parsedBudget = double.tryParse(_budgetController.text.trim()) ?? 0.0;

      final updatedInfo = originalInfo.copyWith(
        weddingDate: parsedDate,
        yourName: _yourNameController.text.trim(),
        partnerName: _partnerNameController.text.trim(),
        weddingVenue: _venueController.text.trim(),
        budget: parsedBudget,
        notes: _notesController.text.trim(),
      );

      debugPrint('[WeddingInfoPage] Saving updated wedding info: ${updatedInfo.toJson()}');
      
      // Zabránit zpětné propagaci na cloud během ukládání
      _isUpdatingFromCloud = true;
      
      // Prioritně ukládáme na cloud
      try {
        await _weddingRepository.updateWeddingInfo(updatedInfo);
        debugPrint('[WeddingInfoPage] Wedding info updated in cloud');
        
        // Aktualizujeme referenční hodnotu
        _cloudWeddingInfo = updatedInfo;
        
        // Poté aktualizujeme lokální kopii
        await _localService.saveWeddingInfo(updatedInfo);
        debugPrint('[WeddingInfoPage] Wedding info updated locally');
      } catch (e) {
        debugPrint('[WeddingInfoPage] Error updating in cloud: $e, trying local save');
        // Pokud selže aktualizace na cloudu, uložíme alespoň lokálně
        await _localService.saveWeddingInfo(updatedInfo);
      }

      setState(() {
        _isEditMode = false;
        _isUpdatingFromCloud = false; // Znovu povolíme aktualizace z cloudu
      });
      
      debugPrint('[WeddingInfoPage] Wedding info updated successfully.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informace o svatbě byly úspěšně aktualizovány.')),
      );
      
    } catch (e, stack) {
      setState(() {
        _errorMessage = e.toString();
        _isUpdatingFromCloud = false;
      });
      debugPrint('[WeddingInfoPage] Error updating wedding info: $e');
      debugPrintStack(label: 'StackTrace', stackTrace: stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chyba při ukládání: $_errorMessage')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _pickWeddingDate() async {
    try {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: now.add(const Duration(days: 1)),
        firstDate: now,
        lastDate: DateTime(now.year + 5),
      );
      if (picked != null) {
        setState(() {
          _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
        });
        debugPrint('[WeddingInfoPage] Date picked: ${_dateController.text}');
      }
    } catch (e) {
      debugPrint('[WeddingInfoPage] Error picking date: $e');
    }
  }

  Widget _buildCountdown(WeddingInfo info) {
    final diff = info.weddingDate.difference(DateTime.now());
    if (diff.isNegative) {
      return const Text(
        'Svatba již proběhla',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      );
    }
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;
    return Text(
      'Do svatby zbývá: $days dní, $hours hodin, $minutes minut, $seconds sekund',
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildViewMode(WeddingInfo info) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCountdown(info),
          const SizedBox(height: 16),
          Text('Datum svatby: ${DateFormat('yyyy-MM-dd').format(info.weddingDate)}', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text('Vaše jméno: ${info.yourName}', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text('Jméno partnera: ${info.partnerName}', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text('Místo svatby: ${info.weddingVenue}', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text('Rozpočet: ${info.budget.toStringAsFixed(2)} Kč', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text('Poznámky: ${info.notes}', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          Center(
            // Odstraněno tlačítko pro obnovení z cloudu, ponecháno pouze tlačítko pro úpravy
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _isEditMode = true;
                  _initializeControllers(info);
                });
                debugPrint('[WeddingInfoPage] Switched to edit mode.');
              },
              child: const Text('Upravit informace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditMode(WeddingInfo info) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: 'Datum svatby (YYYY-MM-dd)',
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: _pickWeddingDate,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Datum je povinné';
                }
                try {
                  DateFormat('yyyy-MM-dd').parse(value.trim());
                } catch (_) {
                  return 'Neplatný formát data (YYYY-MM-dd)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _yourNameController,
              decoration: const InputDecoration(labelText: 'Vaše jméno'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vaše jméno je povinné';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _partnerNameController,
              decoration: const InputDecoration(labelText: 'Jméno partnera'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Jméno partnera je povinné';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _venueController,
              decoration: const InputDecoration(labelText: 'Místo svatby'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Místo svatby je povinné';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _budgetController,
              decoration: const InputDecoration(labelText: 'Rozpočet (Kč)'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Rozpočet je povinný';
                }
                if (double.tryParse(value.trim()) == null) {
                  return 'Neplatná částka';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Poznámky'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            _isSaving
                ? const CircularProgressIndicator()
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => _saveWeddingInfo(info),
                        child: const Text('Uložit změny'),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _isEditMode = false;
                          });
                          debugPrint('[WeddingInfoPage] Edit mode canceled.');
                        },
                        child: const Text('Zrušit'),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[WeddingInfoPage] build() called.');
    
    // Pokud nemáme žádná data, ale načítáme, zobrazíme indikátor načítání
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Informace o svatbě'),
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
    
    // Pokud máme data z cloudu, zobrazíme je
    if (_cloudWeddingInfo != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Informace o svatbě'),
        ),
        body: _isEditMode 
              ? _buildEditMode(_cloudWeddingInfo!) 
              : _buildViewMode(_cloudWeddingInfo!),
      );
    }
    
    // Pokud nemáme data ani z cloudu ani lokálně, zobrazíme chybu
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informace o svatbě'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Nepodařilo se načíst data o svatbě.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadWeddingInfoFromCloud,
              child: const Text('Zkusit znovu'),
            ),
          ],
        ),
      ),
    );
  }
}