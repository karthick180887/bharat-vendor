import 'package:flutter/material.dart';
import '../../design_system.dart';
import '../../services/firebase_messaging_service.dart';
import 'dashboard/dashboard_screen.dart';
// import 'bookings/bookings_screen.dart';
// import 'create_booking/create_booking_screen.dart';
// import 'drivers/drivers_list_screen.dart';
import 'profile/profile_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Ensure FCM token is registered on app start if logged in
    FirebaseMessagingService().registerToken();
  }

  final List<Widget> _screens = const [
    DashboardScreen(),
    // BookingsScreen(),
    // CreateBookingScreen(), // Or a placeholder that opens a modal
    // DriversListScreen(),
    ProfileScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabTapped,
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primaryLight,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: AppColors.primary),
              label: 'Home',
            ),
            /*
            NavigationDestination(
              icon: Icon(CupertinoIcons.doc_text),
              selectedIcon: Icon(CupertinoIcons.doc_text_fill, color: AppColors.primary),
              label: 'Bookings',
            ),
            */
            /*
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline, size: 32),
              selectedIcon: Icon(Icons.add_circle, size: 32, color: AppColors.primary),
              label: 'Create',
            ),
            */
            /*
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people, color: AppColors.primary),
              label: 'Drivers',
            ),
            */
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppColors.primary),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
