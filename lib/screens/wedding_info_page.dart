import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/wedding_info.dart';
import '../services/local_wedding_info_service.dart';
import '../repositories/wedding_repository.dart';
import '../utils/safe_snackbar.dart';

/// WeddingInfoPage zobrazuje informace o svatbě a umožňuje je upravovat.
/// Data jsou ukládána lokálně pomocí SharedPreferences a synchronizována s cloudem.
class WeddingInfoPage extends StatefulWidget {
  const WeddingInfoPage({super.key});

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
    _weddingSubscription =
        _weddingRepository.weddingInfoStream.listen((weddingInfo) {
      if (weddingInfo != null &&
          mounted &&
          !_isEditMode &&
          !_isUpdatingFromCloud) {
        debugPrint(
            '[WeddingInfoPage] Received cloud update while not in edit mode');

        // Zabráníme nekonečné smyčce aktualizací
        if (_cloudWeddingInfo != null) {
          // Porovnáme, jestli jsou data opravdu jiná
          final currentJson = _cloudWeddingInfo!.toJson().toString();
          final newJson = weddingInfo.toJson().toString();

          if (currentJson == newJson) {
            debugPrint(
                '[WeddingInfoPage] Ignoring redundant cloud update - data are the same');
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

      if (mounted) {
        debugPrint(
            '[WeddingInfoPage] Cloud data loaded: ${weddingInfo.toJson()}');

        // Aktualizujeme referenční hodnotu
        _cloudWeddingInfo = weddingInfo;

        // Aktualizujeme lokální kopii, ale bez zpětné propagace na cloud
        await _localService.saveWeddingInfo(weddingInfo);

        if (!_isEditMode) {
          _initializeControllers(weddingInfo);
        }
      }
    } catch (e) {
      debugPrint(
          '[WeddingInfoPage] Error loading from cloud: $e, falling back to local data');
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
    debugPrint(
        '[WeddingInfoPage] Controllers initialized with wedding info data: ${info.toJson()}');
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
      final parsedDate =
          DateFormat('yyyy-MM-dd').parse(_dateController.text.trim());
      final parsedBudget =
          double.tryParse(_budgetController.text.trim()) ?? 0.0;

      final updatedInfo = originalInfo.copyWith(
        weddingDate: parsedDate,
        yourName: _yourNameController.text.trim(),
        partnerName: _partnerNameController.text.trim(),
        weddingVenue: _venueController.text.trim(),
        budget: parsedBudget,
        notes: _notesController.text.trim(),
      );

      debugPrint(
          '[WeddingInfoPage] Saving updated wedding info: ${updatedInfo.toJson()}');

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
        debugPrint(
            '[WeddingInfoPage] Error updating in cloud: $e, trying local save');
        // Pokud selže aktualizace na cloudu, uložíme alespoň lokálně
        await _localService.saveWeddingInfo(updatedInfo);
      }

      setState(() {
        _isEditMode = false;
        _isUpdatingFromCloud = false; // Znovu povolíme aktualizace z cloudu
      });

      debugPrint('[WeddingInfoPage] Wedding info updated successfully.');
      SafeSnackBar.show(
        context,
        tr('wedding_info_update_success'),
      );
    } catch (e, stack) {
      setState(() {
        _errorMessage = e.toString();
        _isUpdatingFromCloud = false;
      });
      debugPrint('[WeddingInfoPage] Error updating wedding info: $e');
      debugPrintStack(label: 'StackTrace', stackTrace: stack);
      SafeSnackBar.show(
        context,
        tr('save_error', args: [_errorMessage]),
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
      return Text(
        tr('wedding_already_happened'),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      );
    }
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;
    return Text(
      tr('wedding_countdown', args: [
        days.toString(),
        hours.toString(),
        minutes.toString(),
        seconds.toString()
      ]),
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
          Text(
              '${tr('wedding_date')}: ${DateFormat('yyyy-MM-dd').format(info.weddingDate)}',
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text('${tr('your_name')}: ${info.yourName}',
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text('${tr('partner_name')}: ${info.partnerName}',
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text('${tr('wedding_venue')}: ${info.weddingVenue}',
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text(
              '${tr('budget')}: ${info.budget.toStringAsFixed(2)} ${tr('currency')}',
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text('${tr('notes')}: ${info.notes}',
              style: const TextStyle(fontSize: 16)),
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
              child: Text(tr('edit_information')),
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
              decoration: InputDecoration(
                labelText: tr('wedding_date_format'),
                suffixIcon: const Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: _pickWeddingDate,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return tr('date_required');
                }
                try {
                  DateFormat('yyyy-MM-dd').parse(value.trim());
                } catch (_) {
                  return tr('invalid_date_format');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _yourNameController,
              decoration: InputDecoration(labelText: tr('your_name')),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return tr('your_name_required');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _partnerNameController,
              decoration: InputDecoration(labelText: tr('partner_name')),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return tr('partner_name_required');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _venueController,
              decoration: InputDecoration(labelText: tr('wedding_venue')),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return tr('wedding_venue_required');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _budgetController,
              decoration: InputDecoration(labelText: tr('budget_czk')),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return tr('budget_required');
                }
                if (double.tryParse(value.trim()) == null) {
                  return tr('invalid_amount');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(labelText: tr('notes')),
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
                        child: Text(tr('save_changes')),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _isEditMode = false;
                          });
                          debugPrint('[WeddingInfoPage] Edit mode canceled.');
                        },
                        child: Text(tr('cancel')),
                      ),
                    ],
                  ),
            // Přidáme extra mezeru na konci pro klávesnici
            const SizedBox(height: 100),
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
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(tr('wedding_information')),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(tr('loading_from_cloud')),
            ],
          ),
        ),
      );
    }

    // Pokud máme data z cloudu, zobrazíme je
    if (_cloudWeddingInfo != null) {
      return Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(tr('wedding_information')),
        ),
        body: _isEditMode
            ? _buildEditMode(_cloudWeddingInfo!)
            : _buildViewMode(_cloudWeddingInfo!),
      );
    }

    // Pokud nemáme data ani z cloudu ani lokálně, zobrazíme chybu
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(tr('wedding_information')),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tr('failed_to_load_wedding_data')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadWeddingInfoFromCloud,
              child: Text(tr('try_again')),
            ),
          ],
        ),
      ),
    );
  }
}
