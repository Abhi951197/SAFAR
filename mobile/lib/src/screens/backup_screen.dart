import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/personal_backup_service.dart';
import '../models/backup_record.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({required this.service, super.key});
  final PersonalBackupService service;
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _password = TextEditingController();
  bool _remember = true;
  List<DriveBackup>? _drive;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _action(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _exportCopy(BackupRecord record) async {
    final saved = await widget.service.saveCopy(record);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved
      ? 'Copy written to your selected location. If you chose Drive, check upload/sync in the Drive app.'
      : 'No destination selected. Your backup is still saved inside Safar.')));
  }

  Future<void> _restore({DriveBackup? drive}) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Restore your diary?'),
                content: const Text(
                    'Sign in to the account that created this backup and enter its backup password. Missing entries and media will be restored. Your current entries will be kept. An internet connection is needed.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Continue'))
                ]));
    if (confirmed != true) return;
    await _action(() async {
      final count = drive == null
          ? await widget.service.restoreFromPhone(_password.text)
          : await widget.service.restoreFromDrive(drive, _password.text);
      if (mounted && count != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Restored $count missing entries. ${widget.service.warning ?? 'Available media is ready on this phone.'}')));
      }
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final s = widget.service;
        return Scaffold(
            appBar: AppBar(title: const Text('Backups & restore')),
            body: ListView(padding: const EdgeInsets.all(20), children: [
              const Icon(Icons.shield_outlined, size: 48),
              const SizedBox(height: 12),
              Text('Keep your memories with you',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                  'Your diary, entry links and available media are saved in one encrypted .safar file. Attachments without their original decryption key are preserved as locked files, not recovered media. Keep your backup password safe.'),
              const SizedBox(height: 20),
              if (!s.supported)
                const Text(
                    'Phone and Google Drive backups are available in the Android app.')
              else ...[
                TextField(
                    controller: _password,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: const InputDecoration(
                        labelText: 'Backup password',
                        helperText:
                            'At least 10 characters. Use the original password to restore.')),
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _remember,
                    onChanged: s.busy
                        ? null
                        : (v) => setState(() => _remember = v ?? true),
                    title: const Text('Remember securely on this phone')),
                FilledButton.icon(
                    onPressed: s.busy
                        ? null
                        : () => _action(() async {
                              await s.backup(_password.text,
                                  remember: _remember);
                            }),
                    icon: const Icon(Icons.backup_outlined),
                    label: const Text('Back up now')),
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: s.autoEnabled,
                    onChanged: s.busy
                        ? null
                        : (v) => _action(() => s.setAutoEnabled(v)),
                    title: const Text('Back up after diary changes'),
                    subtitle: const Text(
                        'Runs while Safar is open. Keeps recent backups; locked or incomplete backups never remove an older complete backup.')),
                const Divider(height: 32),
                Text('Google Drive',
                    style: Theme.of(context).textTheme.titleLarge),
                const Text(
                    'Uses the Google account you use for Safar. Backups appear in My Drive → Safar Backups. Drive permission expires; reconnect when asked. Phone backups continue independently.'),
                const SizedBox(height: 8),
                FilledButton.icon(
                    onPressed: s.busy
                        ? null
                        : () => _action(() async {
                              final record = await s.backup(_password.text,
                                  remember: _remember);
                              await _exportCopy(record);
                            }),
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Save backup to Drive / Files')),
                const Text(
                    'In the Android file picker, open the side menu, choose Drive and select the Google account you use for Safar. If Drive is not listed, install or enable Google Drive, or save to Documents and upload the file with Drive. This does not use Safar’s Google OAuth connection.'),
                const SizedBox(height: 12),
                ExpansionTile(
                    title: const Text(
                        'Direct Drive connection (requires app setup)'),
                    children: [
                      const Text(
                          'Access blocked / testing? The app owner must add your email under Google Cloud → Google Auth Platform → Audience → Test users. This setting is not in Supabase.'),
                      OutlinedButton.icon(
                          onPressed:
                              s.busy ? null : () => _action(s.connectDrive),
                          icon: const Icon(Icons.cloud_outlined),
                          label: Text(s.driveReady
                              ? 'Reconnect Google Drive'
                              : 'Connect Google Drive')),
                      if (s.driveEnabled)
                        TextButton(
                            onPressed: s.busy
                                ? null
                                : () => _action(s.disconnectDrive),
                            child: const Text('Disconnect Drive')),
                      if (s.lastDriveBackup != null)
                        Text(
                            'Last verified Drive upload: ${DateFormat.yMMMd().add_jm().format(s.lastDriveBackup!.toLocal())}'),
                      OutlinedButton(
                          onPressed: s.busy
                              ? null
                              : () => _action(() async {
                                    final items = await s.listDriveBackups();
                                    if (mounted) setState(() => _drive = items);
                                  }),
                          child: const Text('Find Drive backups')),
                      if (_drive != null && _drive!.isEmpty)
                        const Text('No backups found for this Safar account.'),
                      for (final item in _drive ?? <DriveBackup>[])
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.name),
                            subtitle: Text(
                                '${(item.bytes / 1048576).toStringAsFixed(1)} MB'),
                            trailing: TextButton(
                                onPressed:
                                    s.busy ? null : () => _restore(drive: item),
                                child: const Text('Restore'))),
                    ]),
                const Divider(height: 32),
                Text('On this phone',
                    style: Theme.of(context).textTheme.titleLarge),
                const Text(
                    'These copies are inside Safar. Use “Save a copy” to keep one in Documents, an SD card or a folder you choose. That copy survives uninstalling Safar.'),
                if (s.localBackups.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No completed phone backup yet.')),
                for (final item in s.localBackups)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lock_outline),
                      title: Text(DateFormat.yMMMd()
                          .add_jm()
                          .format(item.createdAt.toLocal())),
                      subtitle: Text(
                          '${item.entries} entries · ${item.media} media (${item.lockedMedia} locked, ${item.missingMedia} unavailable) · ${(item.bytes / 1048576).toStringAsFixed(1)} MB'),
                      trailing: IconButton(
                          tooltip: 'Save a copy',
                          icon: const Icon(Icons.save_alt),
                          onPressed: s.busy
                              ? null
                              : () => _action(() async {
                                    await _exportCopy(item);
                                  }))),
                OutlinedButton.icon(
                    onPressed: s.busy ? null : () => _restore(),
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore from a file')),
              ],
              if (s.busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
                if (s.waitingForDrive)
                  TextButton(
                      onPressed: s.cancelDriveConnection,
                      child: const Text(
                          'Google blocked access? Cancel connection')),
                Text(s.phase)
              ],
              if (s.warning != null)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(s.warning!)),
              if (s.error != null)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(s.error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
            ]));
      });
}
