import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/diary_repository.dart';
import 'calendar_screen.dart';
import 'create_entry_choice_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

class TabsShell extends StatefulWidget {
  const TabsShell({required this.api, super.key});

  final ApiClient api;

  @override
  State<TabsShell> createState() => _TabsShellState();
}

class _TabsShellState extends State<TabsShell> {
  int _index = 0;
  late final DiaryRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = DiaryRepository(widget.api)..initialize();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(repository: _repository),
      CreateEntryChoiceScreen(api: widget.api, repository: _repository),
      CalendarScreen(repository: _repository),
      ProfileScreen(api: widget.api, repository: _repository, onOpenCalendar: () => setState(() => _index = 2)),
    ];
    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        height: 68,
        elevation: 0,
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Add'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
