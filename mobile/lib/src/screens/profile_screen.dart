import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/diary_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/state_views.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.api, required this.repository, required this.onOpenCalendar, super.key});

  final ApiClient api;
  final DiaryRepository repository;
  final VoidCallback onOpenCalendar;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();

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
                      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 900);
                      if (picked != null) setDialogState(() => avatarFile = picked);
                    },
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                      foregroundImage: avatarFile == null && avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarFile == null ? const Icon(Icons.add_a_photo_outlined, color: AppTheme.primary) : const Icon(Icons.check, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: controller, decoration: const InputDecoration(labelText: 'Name')),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
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
      await AuthService().updateProfileMetadata(name: name, avatarUrl: avatarUrl);
      await widget.repository.updateProfile(name: name, avatarUrl: avatarUrl);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Your saved entries stay in Safar.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Logout')),
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
          if (user == null && widget.repository.entries.isEmpty && widget.repository.isRefreshing) {
            return const Center(child: CircularProgressIndicator());
          }
          if (user == null) {
            return ErrorState(message: 'Unable to load profile. Please try again.', onRetry: widget.repository.refreshAll);
          }
          final authEmail = Supabase.instance.client.auth.currentUser?.email;
          final name = user.name?.trim().isNotEmpty == true ? user.name!.trim() : 'Safar User';
          return RefreshIndicator(
            onRefresh: () => widget.repository.refreshAll(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
              children: [
                GlassPanel(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: const Color(0xFFC7F26D),
                        foregroundImage: user.avatarUrl == null ? null : NetworkImage(user.avatarUrl!),
                        child: const Icon(Icons.person, size: 44, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 12),
                      Text(name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      Text(user.email.isNotEmpty ? user.email : authEmail ?? '', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(onPressed: () => _editProfile(user), icon: const Icon(Icons.edit_outlined), label: const Text('Edit Profile')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _Stat(label: 'Entries', value: '${entries.length}')),
                    const SizedBox(width: 12),
                    Expanded(child: _Stat(label: 'Quick', value: '${entries.where((entry) => entry.entryType == 'quick').length}')),
                  ],
                ),
                const SizedBox(height: 16),
                GlassPanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(leading: const Icon(Icons.article_outlined), title: const Text('Full Diaries'), trailing: Text('${entries.where((entry) => entry.entryType == 'full').length}')),
                      const Divider(height: 1),
                      ListTile(leading: const Icon(Icons.flash_on_outlined), title: const Text('Quick Diaries'), trailing: Text('${entries.where((entry) => entry.entryType == 'quick').length}')),
                      const Divider(height: 1),
                      ListTile(leading: const Icon(Icons.calendar_month), title: const Text('Calendar'), onTap: widget.onOpenCalendar),
                      const Divider(height: 1),
                      ListTile(leading: const Icon(Icons.logout), title: const Text('Logout'), onTap: _signOut),
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
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
