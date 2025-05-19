import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../repositories/user_repository.dart';
import '../services/onboarding_manager.dart';
import '../widgets/permission_error_banner.dart'; 
import 'home_screen.dart';
import 'checklist_screen.dart';
// Import pro SuppliersListPage byl odstraněn
import 'guests_screen.dart';
import 'budget_screen.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'subscription_page.dart';
import 'wedding_schedule_screen.dart';

class BrideGroomMainMenu extends StatefulWidget {
  const BrideGroomMainMenu({Key? key}) : super(key: key);

  @override
  _BrideGroomMainMenuState createState() => _BrideGroomMainMenuState();
}

class _BrideGroomMainMenuState extends State<BrideGroomMainMenu> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  // Seznam stránek bez SuppliersListPage
  final List<Widget> _pages = const [
    HomeScreen(),
    ChecklistPage(),
    WeddingScheduleScreen(), 
    GuestsScreen(),
    BudgetScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    // Ujistíme se, že onboarding je označen jako dokončený
    _ensureOnboardingCompleted();
  }

  Future<void> _ensureOnboardingCompleted() async {
    await OnboardingManager.markOnboardingCompleted();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onBottomNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return tr('home_title');
      case 1:
        return tr('checklist_title');
      case 2:
        // Pokud překlad neexistuje, použijeme pevný text
        try {
          return tr('schedule_title');
        } catch (_) {
          return 'Harmonogram';
        }
      case 3:
        return tr('guests_title');
      case 4:
        return tr('budget_title');
      default:
        try {
          return tr('app_title');
        } catch (_) {
          return 'Svatební plánovač';
        }
    }
  }

  Widget _buildDrawer() {
    final userRepo = Provider.of<UserRepository>(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(userRepo.cachedUser?.name ?? "Uživatel"),
            accountEmail: Text(userRepo.cachedUser?.email ?? ""),
            currentAccountPicture: CircleAvatar(
              backgroundImage: (userRepo.cachedUser?.profilePictureUrl != null &&
                      userRepo.cachedUser!.profilePictureUrl.isNotEmpty)
                  ? NetworkImage(userRepo.cachedUser!.profilePictureUrl)
                  : null,
              child: (userRepo.cachedUser?.profilePictureUrl == null ||
                      userRepo.cachedUser!.profilePictureUrl.isEmpty)
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.pink, Colors.pinkAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Banner pro zobrazení chyb s oprávněními
          const PermissionErrorBanner(),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text("Domů"),
            onTap: () {
              Navigator.pop(context);
              _onBottomNavTapped(0);
            },
          ),
          ListTile(
            leading: const Icon(Icons.check_box),
            title: const Text("Checklist"),
            onTap: () {
              Navigator.pop(context);
              _onBottomNavTapped(1);
            },
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text("Harmonogram"),
            onTap: () {
              Navigator.pop(context);
              _onBottomNavTapped(2);
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text("Hosté"),
            onTap: () {
              Navigator.pop(context);
              _onBottomNavTapped(3);
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: const Text("Rozpočet"),
            onTap: () {
              Navigator.pop(context);
              _onBottomNavTapped(4);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.favorite),
            title: const Text("Svatba"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/weddingInfo');
            },
          ),
          // Položka Dodavatelé byla kompletně odstraněna
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text(userRepo.cachedUser?.name ?? "Nastavení"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Odhlásit se"),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/auth');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        centerTitle: true,
        backgroundColor: Colors.pink,
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          // Banner s informacemi o oprávněních
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: PermissionErrorBanner(),
          ),
          // Hlavní obsah stránky
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              children: _pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.pink,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: _getTranslation('home', 'Domů'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.check_box),
            label: _getTranslation('checklist', 'Checklist'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.schedule),
            label: _getTranslation('schedule', 'Harmonogram'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people),
            label: _getTranslation('guests', 'Hosté'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.account_balance_wallet),
            label: _getTranslation('budget', 'Rozpočet'),
          ),
        ],
      ),
    );
  }
  
  // Pomocná metoda pro získání překladu s fallback hodnotou
  String _getTranslation(String key, String fallback) {
    try {
      return tr(key);
    } catch (_) {
      return fallback;
    }
  }
}