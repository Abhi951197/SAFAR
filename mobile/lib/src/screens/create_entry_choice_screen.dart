import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/diary_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';
import 'entry_form_screen.dart';

class CreateEntryChoiceScreen extends StatelessWidget {
  const CreateEntryChoiceScreen({required this.api, required this.repository, super.key});

  final ApiClient api;
  final DiaryRepository repository;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showImageBackground: true,
      padding: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 76, 20, 96),
        children: [
          const Center(child: SafarLogo(height: 96)),
          const SizedBox(height: 18),
          Center(child: Text('What do you want to add?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
          const SizedBox(height: 22),
          _ChoiceCard(
            icon: Icons.edit_note,
            title: 'Full Diary',
            description: 'Write detailed thoughts and experiences.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntryFormScreen(api: api, repository: repository, entryType: 'full'))),
          ),
          _ChoiceCard(
            icon: Icons.bolt,
            title: 'Quick Diary',
            description: 'Answer a few quick questions.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntryFormScreen(api: api, repository: repository, entryType: 'quick'))),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.icon, required this.title, required this.description, required this.onTap});

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: GlassPanel(
          padding: EdgeInsets.zero,
          child: SizedBox(
          height: 156,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 38, color: AppTheme.primary),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
