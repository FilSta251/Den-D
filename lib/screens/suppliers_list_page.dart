/// lib/screens/suppliers_list_page.dart
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// Import modelu dodavatele a detailní obrazovky dodavatele.
import '../models/supplier.dart';
import 'supplier_profile_page.dart';

class SuppliersListPage extends StatefulWidget {
  const SuppliersListPage({super.key});

  @override
  _SuppliersListPageState createState() => _SuppliersListPageState();
}

class _SuppliersListPageState extends State<SuppliersListPage> {
  // Filtráční proměnnĂ© "“ pokud není filtr nastaven, zůstávají null nebo ve výchozím rozpětí.
  String? _selectedProfession;
  String? _selectedRegion;
  String? _selectedDistrict;
  RangeValues _priceRange = const RangeValues(0, 100000);
  DateTime? _selectedWeddingDate;

  // Seznam moťností pro filtry.
  final List<String> _professions = [
    'Foto',
    'Video',
    'MUA',
    'Hudba/DJ',
    'Florista',
    'Catering',
    'Dekorace',
    'Koordinátor',
    'Hotel',
    'Cukrář',
    'JinĂ©'
  ];

  final List<String> _regions = [
    'Hlavní město Praha',
    'Středočeský kraj',
    'Jihočeský kraj',
    'PlzeĹský kraj',
    'Karlovarský kraj',
    'Ăšstecký kraj',
    'Liberecký kraj',
    'KrálovĂ©hradecký kraj',
    'Pardubický kraj',
    'Kraj Vysočina',
    'Jihomoravský kraj',
    'Olomoucký kraj',
    'Zlínský kraj',
    'Moravskoslezský kraj'
  ];

  final Map<String, List<String>> _districtsByRegion = {
    'Hlavní město Praha': ['Praha (hl. m.)'],
    'Středočeský kraj': [
      'BeneĹˇov',
      'Beroun',
      'Kladno',
      'Kolín',
      'Kutná Hora',
      'Mělník',
      'Mladá Boleslav',
      'Nymburk',
      'Praha-východ',
      'Praha-západ',
      'Příbram',
      'Rakovník'
    ],
    'Jihočeský kraj': [
      'ďŚeskĂ© Budějovice',
      'ďŚeský Krumlov',
      'Jindřichův Hradec',
      'Písek',
      'Prachatice',
      'Strakonice',
      'Tábor'
    ],
    'PlzeĹský kraj': [
      'Domaťlice',
      'Klatovy',
      'PlzeĹ-město',
      'PlzeĹ-jih',
      'PlzeĹ-sever',
      'Rokycany',
      'Tachov'
    ],
    'Karlovarský kraj': ['Cheb', 'Karlovy Vary', 'Sokolov'],
    'Ăšstecký kraj': [
      'Děčín',
      'Chomutov',
      'Litoměřice',
      'Louny',
      'Most',
      'Teplice',
      'Ăšstí nad Labem'
    ],
    'Liberecký kraj': [
      'ďŚeská Lípa',
      'Jablonec nad Nisou',
      'Liberec',
      'Semily'
    ],
    'KrálovĂ©hradecký kraj': [
      'Hradec KrálovĂ©',
      'Jičín',
      'Náchod',
      'Rychnov nad Kněťnou',
      'Trutnov'
    ],
    'Pardubický kraj': ['Chrudim', 'Pardubice', 'Svitavy', 'Ăšstí nad Orlicí'],
    'Kraj Vysočina': [
      'Havlíčkův Brod',
      'Jihlava',
      'Pelhřimov',
      'Třebíč',
      'Ĺ˝ďŹár nad Sázavou'
    ],
    'Jihomoravský kraj': [
      'Blansko',
      'Brno-město',
      'Brno-venkov',
      'Břeclav',
      'Hodonín',
      'VyĹˇkov',
      'Znojmo'
    ],
    'Olomoucký kraj': ['Jeseník', 'Olomouc', 'Prostějov', 'Přerov', 'Ĺ umperk'],
    'Zlínský kraj': ['Kroměříť', 'UherskĂ© HradiĹˇtě', 'Vsetín', 'Zlín'],
    'Moravskoslezský kraj': [
      'Bruntál',
      'Frýdek-Místek',
      'Karviná',
      'Nový Jičín',
      'Opava',
      'Ostrava-město'
    ],
  };

  // Ukázková data dodavatelů; v produkci budou data náčítána z backendu.
  final List<Supplier> _allSuppliers = [
    Supplier(
      id: '1',
      name: 'FotoMagic',
      profession: 'Foto',
      region: 'Hlavní město Praha',
      district: 'Praha (hl. m.)',
      price: 20000,
      website: 'https://fotomagic.cz',
      contact: '+420123456789',
      profileImageUrl: 'https://via.placeholder.com/150',
      bio: 'Profesionální fotograf se specializací na svatební focení.',
      portfolioImages: [
        'https://via.placeholder.com/150',
        'https://via.placeholder.com/150'
      ],
    ),
    Supplier(
      id: '2',
      name: 'SladkĂ© Dobroty',
      profession: 'Cukrář',
      region: 'Jihomoravský kraj',
      district: 'Brno-město',
      price: 15000,
      website: 'https://sladkedobroty.cz',
      contact: '+420987654321',
      profileImageUrl: 'https://via.placeholder.com/150',
      bio: 'Cukrář, který připravuje originální svatební dorty a zákusky.',
      portfolioImages: ['https://via.placeholder.com/150'],
    ),
    Supplier(
      id: '3',
      name: 'Květinový Sen',
      profession: 'Florista',
      region: 'Středočeský kraj',
      district: 'Kladno',
      price: 10000,
      website: 'https://kvetinovysen.cz',
      contact: '+420555123456',
      profileImageUrl: 'https://via.placeholder.com/150',
      bio: 'Květinář s váĹˇní pro svatební dekorace a aranťmá.',
      portfolioImages: [],
    ),
  ];

  List<Supplier> _filteredSuppliers = [];

  @override
  void initState() {
    super.initState();
    _loadSavedFilters();
    _filteredSuppliers = List.from(_allSuppliers);
  }

  Future<void> _loadSavedFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString('wedding_date');
    if (savedDate != null) {
      try {
        setState(() {
          _selectedWeddingDate = DateFormat('dd.MM.yyyy').parse(savedDate);
        });
      } catch (e) {
        debugPrint("Error parsing saved wedding date: $e");
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredSuppliers = _allSuppliers.where((supplier) {
        final matchesProfession = _selectedProfession == null ||
            supplier.profession.toLowerCase() ==
                _selectedProfession!.toLowerCase();
        final matchesRegion = _selectedRegion == null ||
            supplier.region.toLowerCase() == _selectedRegion!.toLowerCase();
        final matchesDistrict = _selectedDistrict == null ||
            supplier.district.toLowerCase() == _selectedDistrict!.toLowerCase();
        final matchesPrice = supplier.price >= _priceRange.start &&
            supplier.price <= _priceRange.end;
        return matchesProfession &&
            matchesRegion &&
            matchesDistrict &&
            matchesPrice;
      }).toList();
    });
  }

  void _clearFilter(String field) {
    setState(() {
      if (field == 'profession') {
        _selectedProfession = null;
      } else if (field == 'region') {
        _selectedRegion = null;
        _selectedDistrict = null;
      } else if (field == 'district') {
        _selectedDistrict = null;
      } else if (field == 'price') {
        _priceRange = const RangeValues(0, 100000);
      } else if (field == 'wedding_date') {
        _selectedWeddingDate = null;
      }
      _applyFilters();
    });
  }

  Future<void> _selectWeddingDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedWeddingDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _selectedWeddingDate = picked;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'wedding_date', DateFormat('dd.MM.yyyy').format(picked));
      _applyFilters();
    }
  }

  void _openSupplierProfile(Supplier supplier) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierProfilePage(supplier: supplier),
      ),
    );
  }

  void _openFilterPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header s tláčítkem pro zavření
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tr('filter_suppliers'),
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
                      // Filtr: Profese
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: tr('profession'),
                                border: const OutlineInputBorder(),
                              ),
                              value: _selectedProfession,
                              items: [
                                DropdownMenuItem<String>(
                                  value: null,
                                  child:
                                      Text("auto.suppliers_list_page.v_e".tr()),
                                ),
                                ..._professions
                                    .map((prof) => DropdownMenuItem<String>(
                                          value: prof,
                                          child: Text(prof),
                                        ))
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedProfession = value;
                                  _applyFilters();
                                });
                                setModalState(() {});
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _clearFilter('profession');
                              setModalState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Filtr: Kraj
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: tr('region'),
                                border: const OutlineInputBorder(),
                              ),
                              value: _selectedRegion,
                              items: [
                                DropdownMenuItem<String>(
                                  value: null,
                                  child: Text(
                                      "auto.suppliers_list_page.v_e_63bwfi"
                                          .tr()),
                                ),
                                ..._regions
                                    .map((region) => DropdownMenuItem<String>(
                                          value: region,
                                          child: Text(region),
                                        ))
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedRegion = value;
                                  _selectedDistrict = null;
                                  _applyFilters();
                                });
                                setModalState(() {});
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _clearFilter('region');
                              setModalState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Filtr: Okres
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: tr('district'),
                                border: const OutlineInputBorder(),
                              ),
                              value: _selectedDistrict,
                              items: (_selectedRegion != null &&
                                      _districtsByRegion
                                          .containsKey(_selectedRegion))
                                  ? [
                                      DropdownMenuItem<String>(
                                        value: null,
                                        child: Text(
                                            "auto.suppliers_list_page.v_e_1rb6i9"
                                                .tr()),
                                      ),
                                      ..._districtsByRegion[_selectedRegion]!
                                          .map((district) =>
                                              DropdownMenuItem<String>(
                                                value: district,
                                                child: Text(district),
                                              ))
                                    ]
                                  : [],
                              onChanged: (value) {
                                setState(() {
                                  _selectedDistrict = value;
                                  _applyFilters();
                                });
                                setModalState(() {});
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _clearFilter('district');
                              setModalState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Filtr: CenovĂ© rozpětí
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tr('price_range'),
                                    style: const TextStyle(fontSize: 16)),
                                RangeSlider(
                                  values: _priceRange,
                                  min: 0,
                                  max: 100000,
                                  divisions: 100,
                                  labels: RangeLabels(
                                    _priceRange.start.round().toString(),
                                    _priceRange.end.round().toString(),
                                  ),
                                  onChanged: (values) {
                                    setState(() {
                                      _priceRange = values;
                                      _applyFilters();
                                    });
                                    setModalState(() {});
                                  },
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _clearFilter('price');
                              setModalState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Filtr: Datum svatby
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedWeddingDate != null
                                  ? DateFormat('dd.MM.yyyy')
                                      .format(_selectedWeddingDate!)
                                  : tr('home_no_wedding_date'),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await _selectWeddingDate();
                              setModalState(() {});
                            },
                            child: Text(tr('set_wedding_date')),
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _clearFilter('wedding_date');
                              setModalState(() {});
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('suppliers')),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilterPanel,
          ),
        ],
      ),
      body: _filteredSuppliers.isEmpty
          ? Center(
              child: Text(
                tr('no_suppliers_found'),
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredSuppliers.length,
              itemBuilder: (context, index) {
                final supplier = _filteredSuppliers[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    onTap: () => _openSupplierProfile(supplier),
                    title: Text(
                      supplier.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${tr('profession')}: ${supplier.profession}"),
                        Text(
                            "${tr('region')}: ${supplier.region} - ${supplier.district}"),
                        Text(
                            "${tr('price')}: ${supplier.price.toStringAsFixed(0)} Kč"),
                        Text("${tr('website')}: ${supplier.website}"),
                        Text("${tr('contact')}: ${supplier.contact}"),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
