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
  const BrideGroomMainMenu({super.key});

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
    // Ujistíme se, ťe onboarding je oznáčen jako dokončený
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
        return tr('schedule_title');
      case 3:
        return tr('guests_title');
      case 4:
        return tr('budget_title');
      default:
        return tr('app_name');
    }
  }

  Widget _buildDrawer() {
    final userRepo = Provider.of<UserRepository>(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(userRepo.cachedUser?.name ?? tr('user')),
            accountEmail: Text(userRepo.cachedUser?.email ?? ""),
            currentAccountPicture: CircleAvatar(
              backgroundImage:
                  (userRepo.cachedUser?.profilePictureUrl != null &&
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
            title: Text(tr('home')),
            onTap: () {
              Navigator.pop(context);
              _onBottomNavTapped(0);
            },
          ),
          ListTile(
            leading: const Icon(Icons.check_box),
            title: Text(tr('checklist')),
            onTap: () {
              Navigator.pop(context);
              _onBottomNavTapped(1);
            },
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(tr('schedule')),
            onTap: () {
              Navigator.pop(context);
              _onBottomNavTapped(2);
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: Text(tr('guests')),
            onTap: () {
              Navigator.pop(context);
              _onBottomNavTapped(3);
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: Text(tr('budget')),
            onTap: () {
              Navigator.pop(context);
              _onBottomNavTapped(4);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.favorite),
            title: Text(tr('wedding')),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/weddingInfo');
            },
          ),
          // Poloťka DodavatelĂ© byla kompletně odstraněna
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text(userRepo.cachedUser?.name ?? tr('settings')),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(tr('logout')),
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
            label: tr('home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.check_box),
            label: tr('checklist'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.schedule),
            label: tr('schedule'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people),
            label: tr('guests'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.account_balance_wallet),
            label: tr('budget'),
          ),
        ],
      ),
    );
  }
}
