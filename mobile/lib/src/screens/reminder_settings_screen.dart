import 'package:flutter/material.dart';

import '../services/reminder_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';

class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  bool _loading = true;
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  final _message = TextEditingController(text: ReminderService.defaultMessage);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await ReminderService.instance.loadSettings();
    if (!mounted) return;
    setState(() {
      _enabled = settings.enabled;
      _time = TimeOfDay(hour: settings.hour, minute: settings.minute);
      _message.text = settings.message;
      _loading = false;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    await ReminderService.instance.saveSettings(ReminderSettings(
      enabled: _enabled,
      hour: _time.hour,
      minute: _time.minute,
      message: _message.text,
    ));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Reminder updated.')));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Reminder')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    GlassPanel(
                      padding: EdgeInsets.zero,
                      child: PanelSwitchListTile(
                        value: _enabled,
                        activeThumbColor: AppTheme.primary,
                        title: const Text('Daily Reminder',
                            style: TextStyle(fontWeight: FontWeight.w900)),
                        onChanged: (value) => setState(() => _enabled = value),
                      ),
                    ),
                    const SizedBox(height: 14),
                    GlassPanel(
                      padding: EdgeInsets.zero,
                      child: PanelListTile(
                        leading: const Icon(Icons.schedule),
                        title: const Text('Reminder Time'),
                        trailing: Text(_time.format(context),
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                        onTap: _pickTime,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GlassPanel(
                      child: TextField(
                        controller: _message,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Motivational Message',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
