import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../dashboard/dashboard_screen.dart';
import '../orders/orders_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const OrdersScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              HapticUtils.lightImpact();
              setState(() => _currentIndex = index);
            },
            backgroundColor: isDark 
                ? const Color(0xFF1A1A1A) 
                : Colors.white,
            indicatorColor: AppTheme.primaryBlue.withOpacity(0.15),
            surfaceTintColor: Colors.transparent,
            height: 72,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: Icon(
                  Icons.dashboard_outlined,
                  color: _currentIndex == 0 
                      ? AppTheme.primaryBlue 
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                selectedIcon: const Icon(
                  Icons.dashboard_rounded,
                  color: AppTheme.primaryBlue,
                ),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.receipt_long_outlined,
                  color: _currentIndex == 1 
                      ? AppTheme.primaryBlue 
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                selectedIcon: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppTheme.primaryBlue,
                ),
                label: 'Orders',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.person_outline_rounded,
                  color: _currentIndex == 2 
                      ? AppTheme.primaryBlue 
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                selectedIcon: const Icon(
                  Icons.person_rounded,
                  color: AppTheme.primaryBlue,
                ),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
