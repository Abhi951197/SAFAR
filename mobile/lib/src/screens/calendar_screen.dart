import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/diary_entry.dart';
import '../services/diary_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/entry_card.dart';
import '../widgets/state_views.dart';
import 'entry_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({required this.repository, super.key});

  final DiaryRepository repository;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _dayFormat = DateFormat('yyyy-MM-dd');
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    widget.repository.unawaitedRefreshMonth(_focusedDay);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      child: AnimatedBuilder(
        animation: widget.repository,
        builder: (context, _) {
          final dayIndex = widget.repository.dayIndexForMonth(_focusedDay);
          final selected =
              dayIndex[_dayFormat.format(_selectedDay)] ?? const <DiaryEntry>[];
          final hasMonthCache = widget.repository.entriesByMonth
              .containsKey(widget.repository.monthKey(_focusedDay));

          return RefreshIndicator(
            onRefresh: () => widget.repository.refreshMonth(_focusedDay),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 96),
              children: [
                Text('Calendar',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Card(
                  child: TableCalendar<DiaryEntry>(
                    rowHeight: 42,
                    headerStyle: const HeaderStyle(
                        formatButtonVisible: false, titleCentered: true),
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.18),
                          shape: BoxShape.circle),
                      selectedDecoration: const BoxDecoration(
                          color: AppTheme.primary, shape: BoxShape.circle),
                      markersMaxCount: 0,
                    ),
                    calendarBuilders: CalendarBuilders<DiaryEntry>(
                      defaultBuilder: (context, day, focusedDay) => _HeatmapDay(
                          day: day,
                          count: _entriesForDay(dayIndex, day).length),
                      todayBuilder: (context, day, focusedDay) => _HeatmapDay(
                          day: day,
                          count: _entriesForDay(dayIndex, day).length,
                          isToday: true),
                      selectedBuilder: (context, day, focusedDay) =>
                          _HeatmapDay(
                              day: day,
                              count: _entriesForDay(dayIndex, day).length,
                              isSelected: true),
                      outsideBuilder: (context, day, focusedDay) => _HeatmapDay(
                          day: day,
                          count: _entriesForDay(dayIndex, day).length,
                          isOutside: true),
                      markerBuilder: (context, day, events) =>
                          const SizedBox.shrink(),
                    ),
                    firstDay: DateTime.utc(2000),
                    lastDay: DateTime.utc(2100),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => _sameDay(day, _selectedDay),
                    eventLoader: (day) =>
                        dayIndex[_dayFormat.format(day)] ??
                        const <DiaryEntry>[],
                    onDaySelected: (selectedDay, focusedDay) => setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    }),
                    onPageChanged: (focusedDay) {
                      setState(() => _focusedDay = focusedDay);
                      widget.repository.unawaitedRefreshMonth(focusedDay);
                    },
                  ),
                ),
                const SizedBox(height: 14),
                if (!hasMonthCache && widget.repository.entries.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else if (widget.repository.errorMessage != null &&
                    !hasMonthCache)
                  ErrorState(
                      message: 'Unable to connect. Please try again.',
                      onRetry: () =>
                          widget.repository.refreshMonth(_focusedDay))
                else if (selected.isEmpty)
                  const SizedBox(
                      height: 180,
                      child:
                          EmptyState(message: 'Nothing recorded on this day.'))
                else
                  ...selected.map((entry) => EntryCard(
                        entry: entry,
                        onTap: () =>
                            Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => EntryDetailScreen(
                              api: widget.repository.api,
                              repository: widget.repository,
                              entry: entry),
                        )),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  List<DiaryEntry> _entriesForDay(
      Map<String, List<DiaryEntry>> dayIndex, DateTime day) {
    return dayIndex[_dayFormat.format(day)] ?? const <DiaryEntry>[];
  }
}

class _HeatmapDay extends StatelessWidget {
  const _HeatmapDay({
    required this.day,
    required this.count,
    this.isToday = false,
    this.isSelected = false,
    this.isOutside = false,
  });

  final DateTime day;
  final int count;
  final bool isToday;
  final bool isSelected;
  final bool isOutside;

  @override
  Widget build(BuildContext context) {
    final intensity = count == 0 ? 0.0 : (0.16 + (count.clamp(1, 4) * 0.14));
    final background = isSelected
        ? AppTheme.primary
        : count > 0
            ? const Color(0xFF22C55E).withValues(alpha: intensity)
            : isToday
                ? AppTheme.primary.withValues(alpha: 0.12)
                : Colors.transparent;
    final foreground = isSelected
        ? Colors.white
        : isOutside
            ? AppTheme.textSecondary.withValues(alpha: 0.45)
            : AppTheme.textPrimary;
    return Center(
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: isToday && !isSelected
              ? Border.all(color: AppTheme.primary.withValues(alpha: 0.35))
              : null,
        ),
        child: Text(
          '${day.day}',
          style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight:
                  count > 0 || isSelected ? FontWeight.w900 : FontWeight.w500),
        ),
      ),
    );
  }
}
