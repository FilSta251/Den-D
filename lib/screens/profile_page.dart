import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:easy_localization/easy_localization.dart';

import '../models/user.dart';
import '../repositories/user_repository.dart';
import '../utils/safe_snackbar.dart';

/// ProfilePage slouťí k zobrazení a úpravě uťivatelských dat.
/// Náčítá data z UserRepository, umoťĹuje přepínání mezi reťimem prohlíťení a editáčním reťimem,
/// a poskytuje validaci a asynchronní aktualizaci profilu.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

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

  // Uloťí aktuální data uťivatele získaná z FutureBuilder.
  User? _currentUser;
  // Indikuje, zda jiť byly kontrolĂ©ry naplněny hodnotami uťivatele.
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
    // Získání aktuálního uťivatelskĂ©ho ID z FirebaseAuth.
    final fb.User? fbUser = fb.FirebaseAuth.instance.currentUser;
    if (fbUser != null) {
      _userFuture = _userRepository.fetchUserProfile(userId: fbUser.uid);
    } else {
      // Pokud uťivatel není přihláĹˇen, vrátíme Future s chybou.
      _userFuture = Future.error(tr('error_user_not_logged_in'));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Přepne zobrazení mezi reťimem prohlíťení a editáčním reťimem.
  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      _errorMessage = "";
    });
    // Pokud přecházíme do editáčního reťimu, naplníme kontrolĂ©ry hodnotami uťivatele, ale pouze jednou.
    if (_isEditMode && _currentUser != null && !_controllersInitialized) {
      _nameController.text = _currentUser!.name;
      _emailController.text = _currentUser!.email;
      _controllersInitialized = true;
    } else if (!_isEditMode) {
      _controllersInitialized = false;
    }
  }

  /// Uloťí změny profilu do repozitáře a vrátí se do reťimu prohlíťení.
  Future<void> _saveProfile(User currentUser) async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

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
        SnackBar(
            content: Text(tr('profile_update_success'),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16)),
      );
    } catch (e, stackTrace) {
      debugPrint('Chyba při aktualizaci profilu: $e\n$stackTrace');
      setState(() {
        _errorMessage = e.toString();
      });
      SafeSnackBar.show(
        context,
        tr('profile_update_error', args: [_errorMessage]),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Vytvoří widget pro zobrazení profilu v reťimu prohlíťení.
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
            child: Text(tr('edit_profile')),
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
              decoration: InputDecoration(
                labelText: tr('name'),
                icon: const Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return tr('name_required');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: tr('email'),
                icon: const Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return tr('email_required');
                }
                if (!value.contains('@')) {
                  return tr('invalid_email');
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _saveProfile(user),
              child: Text(tr('save_changes')),
            ),
            TextButton(
              onPressed: _toggleEditMode,
              child: Text(tr('cancel')),
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
        title: Text(tr('profile_and_settings')),
      ),
      body: FutureBuilder<User>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text(tr('error_loading_profile',
                    args: [snapshot.error.toString()])));
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
          return Center(child: Text(tr('user_not_found')));
        },
      ),
    );
  }
}
