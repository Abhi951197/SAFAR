import 'package:flutter/material.dart';

import '../models/diary_entry.dart';
import '../services/api_client.dart';
import '../services/diary_repository.dart';
import '../widgets/app_chrome.dart';
import '../widgets/entry_card.dart';
import '../widgets/state_views.dart';
import 'entry_detail_screen.dart';

class FilteredEntriesScreen extends StatelessWidget {
  const FilteredEntriesScreen({
    required this.api,
    required this.repository,
    required this.entryType,
    super.key,
  });

  final ApiClient api;
  final DiaryRepository repository;
  final String entryType;

  @override
  Widget build(BuildContext context) {
    final title = entryType == 'full' ? 'Full Diaries' : 'Quick Diaries';
    return AppScaffold(
      padding: EdgeInsets.zero,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(title)),
        body: AnimatedBuilder(
          animation: repository,
          builder: (context, _) {
            final entries = repository.entries
                .where((entry) => entry.entryType == entryType)
                .toList();
            if (repository.isRefreshing && entries.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (entries.isEmpty) {
              return EmptyState(message: 'No $title saved yet.');
            }
            return RefreshIndicator(
              onRefresh: repository.refreshAll,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return EntryCard(
                    entry: entry,
                    onTap: () => _openDetail(context, entry),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, DiaryEntry entry) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EntryDetailScreen(
        api: api,
        repository: repository,
        entry: entry,
      ),
    ));
  }
}
