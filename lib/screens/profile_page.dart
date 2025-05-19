import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../models/user.dart';
import '../repositories/user_repository.dart';

/// ProfilePage slouží k zobrazení a úpravě uživatelských dat.
/// Načítá data z UserRepository, umožňuje přepínání mezi režimem prohlížení a editačním režimem,
/// a poskytuje validaci a asynchronní aktualizaci profilu.
class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final UserRepository _userRepository;
  late Future<User> _userFuture;
  bool _isEditMode = false;
  bool _isLoading = false;
  String _errorMessage = "";

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;

  // Uloží aktuální data uživatele získaná z FutureBuilder.
  User? _currentUser;
  // Indikuje, zda již byly kontroléry naplněny hodnotami uživatele.
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Získání instance UserRepository z Provideru.
    _userRepository = Provider.of<UserRepository>(context, listen: false);
    // Získání aktuálního uživatelského ID z FirebaseAuth.
    final fb.User? fbUser = fb.FirebaseAuth.instance.currentUser;
    if (fbUser != null) {
      _userFuture = _userRepository.fetchUserProfile(userId: fbUser.uid);
    } else {
      // Pokud uživatel není přihlášen, vrátíme Future s chybou.
      _userFuture = Future.error('Uživatel není přihlášen.');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Přepne zobrazení mezi režimem prohlížení a editačním režimem.
  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      _errorMessage = "";
    });
    // Pokud přecházíme do editačního režimu, naplníme kontroléry hodnotami uživatele, ale pouze jednou.
    if (_isEditMode && _currentUser != null && !_controllersInitialized) {
      _nameController.text = _currentUser!.name;
      _emailController.text = _currentUser!.email;
      _controllersInitialized = true;
    } else if (!_isEditMode) {
      _controllersInitialized = false;
    }
  }

  /// Uloží změny profilu do repozitáře a vrátí se do režimu prohlížení.
  Future<void> _saveProfile(User currentUser) async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });
    try {
      final updatedUser = currentUser.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
      );
      await _userRepository.updateUserProfile(updatedUser);
      setState(() {
        _isEditMode = false;
        _errorMessage = "";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil byl úspěšně aktualizován.')),
      );
    } catch (e, stackTrace) {
      debugPrint('Chyba při aktualizaci profilu: $e\n$stackTrace');
      setState(() {
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chyba při aktualizaci profilu: $_errorMessage')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Vytvoří widget pro zobrazení profilu v režimu prohlížení.
  Widget _buildProfileView(User user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: user.profilePictureUrl.isNotEmpty
                ? NetworkImage(user.profilePictureUrl)
                : null,
            child: user.profilePictureUrl.isEmpty
                ? const Icon(Icons.person, size: 50)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            user.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            user.email,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _toggleEditMode,
            child: const Text('Upravit profil'),
          ),
        ],
      ),
    );
  }

  /// Vytvoří formulář pro úpravu profilu.
  Widget _buildEditForm(User user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: user.profilePictureUrl.isNotEmpty
                  ? NetworkImage(user.profilePictureUrl)
                  : null,
              child: user.profilePictureUrl.isEmpty
                  ? const Icon(Icons.person, size: 50)
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Jméno',
                icon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Jméno nesmí být prázdné';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                icon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email nesmí být prázdný';
                }
                if (!value.contains('@')) {
                  return 'Neplatný email';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _saveProfile(user),
              child: const Text('Uložit změny'),
            ),
            TextButton(
              onPressed: _toggleEditMode,
              child: const Text('Zrušit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil a nastavení'),
      ),
      body: FutureBuilder<User>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Chyba: ${snapshot.error}'));
          }
          if (snapshot.hasData) {
            final user = snapshot.data!;
            _currentUser = user;
            return Stack(
              children: [
                _isEditMode ? _buildEditForm(user) : _buildProfileView(user),
                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            );
          }
          return const Center(child: Text('Uživatel nebyl nalezen.'));
        },
      ),
    );
  }
}
