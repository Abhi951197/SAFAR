import 'package:flutter/material.dart';

import '../models/diary_entry.dart';
import '../services/diary_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/entry_card.dart';
import '../widgets/state_views.dart';
import 'entry_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.repository, super.key});

  final DiaryRepository repository;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      child: AnimatedBuilder(
        animation: repository,
        builder: (context, _) {
          final entries = repository.entries;
          final name = _displayName();
          final isInitialLoading = !repository.isHydrated && repository.isRefreshing && entries.isEmpty;

          return RefreshIndicator(
            onRefresh: () => repository.refreshAll(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 96),
              children: [
                Row(
                  children: [
                    const SafarLogo(height: 48, compact: true),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hi, $name', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(repository.isRefreshing ? 'Syncing your journey...' : 'Good to see you again', style: const TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const SafarHeroImage(height: 190),
                const SizedBox(height: 18),
                TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    hintText: 'Search entries...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.lock_clock, color: AppTheme.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const SectionTitle('Today'),
                const SizedBox(height: 10),
                if (isInitialLoading)
                  const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()))
                else if (repository.errorMessage != null && entries.isEmpty)
                  ErrorState(message: 'Unable to connect. Please try again.', onRetry: repository.refreshAll)
                else if (entries.isEmpty)
                  const SizedBox(height: 320, child: EmptyState(message: 'No entries yet. Start writing your first memory today.'))
                else
                  ...entries.map((entry) => EntryCard(
                        entry: entry,
                        onTap: () => _openDetail(context, entry),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  String _displayName() {
    final user = repository.currentUser;
    final name = user?.name?.trim();
    if (name != null && name.isNotEmpty) return name.split(RegExp(r'\s+')).first;
    final email = user?.email;
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'there';
  }

  Future<void> _openDetail(BuildContext context, DiaryEntry entry) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EntryDetailScreen(api: repository.api, repository: repository, entry: entry),
    ));
  }
}
