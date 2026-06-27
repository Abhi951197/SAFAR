import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/diary_entry.dart';
import '../services/diary_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/entry_card.dart';
import '../widgets/state_views.dart';
import 'entry_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.repository, super.key});

  final DiaryRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      child: AnimatedBuilder(
        animation: widget.repository,
        builder: (context, _) {
          final entries = _filterEntries(widget.repository.entries);
          final name = _displayName();
          final isInitialLoading = !widget.repository.isHydrated &&
              widget.repository.isRefreshing &&
              widget.repository.entries.isEmpty;

          return RefreshIndicator(
            onRefresh: () => widget.repository.refreshAll(),
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
                          Text('Hi, $name',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(
                              widget.repository.isRefreshing
                                  ? 'Syncing your journey...'
                                  : 'Good to see you again',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const SafarHeroImage(height: 190),
                const SizedBox(height: 18),
                TextField(
                  controller: _search,
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search entries...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Clear search',
                            onPressed: () => setState(() {
                              _search.clear();
                              _query = '';
                            }),
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                const SectionTitle('Today'),
                const SizedBox(height: 10),
                if (isInitialLoading)
                  const SizedBox(
                      height: 260,
                      child: Center(child: CircularProgressIndicator()))
                else if (widget.repository.errorMessage != null &&
                    widget.repository.entries.isEmpty)
                  ErrorState(
                      message: 'Unable to connect. Please try again.',
                      onRetry: widget.repository.refreshAll)
                else if (entries.isEmpty && _query.isNotEmpty)
                  const SizedBox(
                      height: 220,
                      child: EmptyState(message: 'No matching entries.'))
                else if (entries.isEmpty)
                  const SizedBox(
                      height: 320,
                      child: EmptyState(
                          message:
                              'No entries yet. Start writing your first memory today.'))
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
    final user = widget.repository.currentUser;
    final name = user?.name?.trim();
    if (name != null && name.isNotEmpty) {
      return name.split(RegExp(r'\s+')).first;
    }
    final email = user?.email;
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'there';
  }

  Future<void> _openDetail(BuildContext context, DiaryEntry entry) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EntryDetailScreen(
          api: widget.repository.api,
          repository: widget.repository,
          entry: entry),
    ));
  }

  List<DiaryEntry> _filterEntries(List<DiaryEntry> entries) {
    if (_query.isEmpty) return entries;
    return entries.where((entry) {
      final haystack = [
        entry.title,
        entry.content,
        entry.mood,
        entry.bestMoment,
        entry.challenge,
        DateFormat('yyyy-MM-dd').format(entry.entryDate),
        DateFormat('MMM d, yyyy').format(entry.entryDate),
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(_query);
    }).toList();
  }
}
