import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/diary_entry.dart';
import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/diary_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/state_views.dart';
import 'filtered_entries_screen.dart';
import 'reminder_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen(
      {required this.api,
      required this.repository,
      required this.onOpenCalendar,
      super.key});

  final ApiClient api;
  final DiaryRepository repository;
  final VoidCallback onOpenCalendar;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  late final AnimationController _flipController;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520));
    Future<void>.delayed(const Duration(milliseconds: 900), () async {
      if (!mounted) return;
      await _flipController.forward();
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (mounted) await _flipController.reverse();
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _editProfile(UserProfile user) async {
    final controller = TextEditingController(text: user.name ?? '');
    XFile? avatarFile;
    String? avatarUrl = user.avatarUrl;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit profile'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picked = await _picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                          maxWidth: 900);
                      if (picked != null) {
                        setDialogState(() => avatarFile = picked);
                      }
                    },
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                      foregroundImage: avatarFile == null && avatarUrl != null
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarFile == null
                          ? const Icon(Icons.add_a_photo_outlined,
                              color: AppTheme.primary)
                          : const Icon(Icons.check, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                      controller: controller,
                      decoration: const InputDecoration(labelText: 'Name')),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Save')),
              ],
            );
          },
        );
      },
    );
    if (result != true) return;

    try {
      if (avatarFile != null) {
        final uploaded = await widget.api.uploadImage(avatarFile!);
        avatarUrl = uploaded['image_url'];
      }
      final name = controller.text.trim();
      await AuthService()
          .updateProfileMetadata(name: name, avatarUrl: avatarUrl);
      await widget.repository.updateProfile(name: name, avatarUrl: avatarUrl);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Your saved entries stay in Safar.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout')),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repository.clearMemory();
      await AuthService().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      showImageBackground: true,
      child: AnimatedBuilder(
        animation: widget.repository,
        builder: (context, _) {
          final user = widget.repository.currentUser;
          final entries = widget.repository.entries;
          if (user == null &&
              widget.repository.entries.isEmpty &&
              widget.repository.isRefreshing) {
            return const Center(child: CircularProgressIndicator());
          }
          if (user == null) {
            return ErrorState(
                message: 'Unable to load profile. Please try again.',
                onRetry: widget.repository.refreshAll);
          }
          final authEmail = Supabase.instance.client.auth.currentUser?.email;
          final name = user.name?.trim().isNotEmpty == true
              ? user.name!.trim()
              : 'Safar User';
          final stats = _streakStats(entries);
          return RefreshIndicator(
            onRefresh: () => widget.repository.refreshAll(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
              children: [
                _FlipProfileCard(
                  controller: _flipController,
                  name: name,
                  email: user.email.isNotEmpty ? user.email : authEmail ?? '',
                  avatarUrl: user.avatarUrl,
                  currentStreak: stats.currentStreak,
                  onEdit: () => _editProfile(user),
                ),
                const SizedBox(height: 16),
                _MilestoneRow(currentStreak: stats.currentStreak),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _Stat(
                            label: 'Entries', value: '${stats.totalEntries}')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _Stat(
                            label: 'Longest', value: '${stats.longestStreak}')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _Stat(
                            label: 'This Month', value: '${stats.thisMonth}')),
                  ],
                ),
                const SizedBox(height: 16),
                GlassPanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      PanelListTile(
                          leading: const Icon(Icons.article_outlined),
                          title: const Text('Full Diaries'),
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => FilteredEntriesScreen(
                                      api: widget.api,
                                      repository: widget.repository,
                                      entryType: 'full'))),
                          trailing: Text(
                              '${entries.where((entry) => entry.entryType == 'full').length}')),
                      const Divider(height: 1),
                      PanelListTile(
                          leading: const Icon(Icons.flash_on_outlined),
                          title: const Text('Quick Diaries'),
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => FilteredEntriesScreen(
                                      api: widget.api,
                                      repository: widget.repository,
                                      entryType: 'quick'))),
                          trailing: Text(
                              '${entries.where((entry) => entry.entryType == 'quick').length}')),
                      const Divider(height: 1),
                      PanelListTile(
                          leading: const Icon(Icons.calendar_month),
                          title: const Text('Calendar'),
                          onTap: widget.onOpenCalendar),
                      const Divider(height: 1),
                      PanelListTile(
                          leading: const Icon(Icons.notifications_none),
                          title: const Text('Reminders'),
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ReminderSettingsScreen()))),
                      const Divider(height: 1),
                      PanelListTile(
                          leading: const Icon(Icons.logout),
                          title: const Text('Logout'),
                          onTap: _signOut),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  _StreakStats _streakStats(List<DiaryEntry> entries) {
    final dates = <DateTime>{};
    for (final entry in entries) {
      final date = entry.entryDate;
      dates.add(DateTime(date.year, date.month, date.day));
    }
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    var cursor = todayOnly;
    if (!dates.contains(cursor) &&
        dates.contains(cursor.subtract(const Duration(days: 1)))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var current = 0;
    while (dates.contains(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    final sorted = dates.toList()..sort();
    var longest = 0;
    var running = 0;
    DateTime? previous;
    for (final date in sorted) {
      if (previous == null || date.difference(previous).inDays != 1) {
        running = 1;
      } else {
        running++;
      }
      longest = math.max(longest, running);
      previous = date;
    }
    final monthStart = DateTime(today.year, today.month);
    final monthEnd = DateTime(today.year, today.month + 1);
    final thisMonth = dates
        .where((date) => !date.isBefore(monthStart) && date.isBefore(monthEnd))
        .length;
    return _StreakStats(
        totalEntries: entries.length,
        currentStreak: current,
        longestStreak: longest,
        thisMonth: thisMonth);
  }
}

class _StreakStats {
  const _StreakStats(
      {required this.totalEntries,
      required this.currentStreak,
      required this.longestStreak,
      required this.thisMonth});

  final int totalEntries;
  final int currentStreak;
  final int longestStreak;
  final int thisMonth;
}

class _FlipProfileCard extends StatelessWidget {
  const _FlipProfileCard({
    required this.controller,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.currentStreak,
    required this.onEdit,
  });

  final AnimationController controller;
  final String name;
  final String email;
  final String? avatarUrl;
  final int currentStreak;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          controller.value < 0.5 ? controller.forward() : controller.reverse(),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final angle = controller.value * math.pi;
          final showBack = controller.value >= 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: showBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _StreakBackCard(currentStreak: currentStreak),
                  )
                : _ProfileFrontCard(
                    name: name,
                    email: email,
                    avatarUrl: avatarUrl,
                    onEdit: onEdit),
          );
        },
      ),
    );
  }
}

class _ProfileFrontCard extends StatelessWidget {
  const _ProfileFrontCard(
      {required this.name,
      required this.email,
      required this.avatarUrl,
      required this.onEdit});

  final String name;
  final String email;
  final String? avatarUrl;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
            foregroundImage:
                avatarUrl == null ? null : NetworkImage(avatarUrl!),
            child: const Icon(Icons.person, size: 44, color: AppTheme.primary),
          ),
          const SizedBox(height: 12),
          Text(name,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          Text(email,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Profile')),
        ],
      ),
    );
  }
}

class _StreakBackCard extends StatelessWidget {
  const _StreakBackCard({required this.currentStreak});

  final int currentStreak;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
            colors: [AppTheme.primaryDark, AppTheme.primary]),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A111827), blurRadius: 28, offset: Offset(0, 16))
        ],
      ),
      child: Column(
        children: [
          const Text('Keep it up!',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18)),
          const SizedBox(height: 18),
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70, width: 2)),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_fire_department,
                    color: Color(0xFFFFC857)),
                Text('$currentStreak',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w900)),
                const Text('Days', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('Current Streak', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.currentStreak});

  final int currentStreak;

  @override
  Widget build(BuildContext context) {
    const milestones = [1, 7, 30, 100, 365];
    return GlassPanel(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: milestones.map((days) {
          final active = currentStreak >= days;
          return Column(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: active
                    ? AppTheme.primary.withValues(alpha: 0.16)
                    : const Color(0xFFF3F4F6),
                foregroundColor:
                    active ? AppTheme.primary : AppTheme.textSecondary,
                child: Icon(
                    active
                        ? Icons.local_fire_department
                        : Icons.emoji_events_outlined,
                    size: 19),
              ),
              const SizedBox(height: 6),
              Text('$days Day${days == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
