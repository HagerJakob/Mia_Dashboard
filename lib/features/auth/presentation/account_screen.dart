import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/build_info.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../calendar/presentation/calendar_controller.dart';
import '../../dashboard/presentation/dashboard_controller.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _message;
  String? _diagnostics;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final client = SupabaseService.client;
    if (client == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      await ref.read(studyBuddyControllerProvider.notifier).syncNow();
      await ref.read(calendarControllerProvider.notifier).refresh();
      if (mounted) setState(() => _message = 'Angemeldet und synchronisiert.');
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Anmeldung oder Sync fehlgeschlagen: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sync() async {
    setState(() {
      _busy = true;
      _message = null;
      _diagnostics = null;
    });
    try {
      await ref.read(studyBuddyControllerProvider.notifier).syncNow();
      await ref.read(calendarControllerProvider.notifier).refresh();
      if (mounted) setState(() => _message = 'Synchronisierung abgeschlossen.');
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Synchronisierung fehlgeschlagen: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await SupabaseService.client?.auth.signOut();
      if (mounted) {
        setState(
          () => _message = 'Abgemeldet. Das Gerät bleibt sicher an das bisherige StudyBuddy-Konto gebunden, damit keine lokalen Daten versehentlich einem anderen Konto zugeordnet werden.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _message = 'Abmelden fehlgeschlagen: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _busy = true;
      _message = null;
      _diagnostics = null;
    });
    try {
      final client = SupabaseService.client;
      final user = client?.auth.currentUser;
      final localSubjects = ref.read(studyBuddyControllerProvider).subjects;
      var remoteActive = 0;
      var remoteDeleted = 0;
      final newestSubjects = <String>[];

      if (client != null && user != null) {
        final rows = await client
            .from('study_items')
            .select('payload, deleted_at, updated_at')
            .eq('owner_id', user.id)
            .eq('kind', 'subject')
            .order('updated_at', ascending: false)
            .limit(8);
        for (final row in rows) {
          final payload = row['payload'];
          final name = payload is Map ? payload['name'] : null;
          final deleted = row['deleted_at'] != null;
          if (deleted) {
            remoteDeleted++;
          } else {
            remoteActive++;
          }
          newestSubjects.add(
            '${deleted ? 'gelöscht' : 'aktiv'}: ${name ?? '(ohne Name)'}',
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _diagnostics = [
          'Build: ${BuildInfo.label}',
          'Build-Zeit: ${BuildInfo.builtAt}',
          'Supabase konfiguriert: ${client == null ? 'nein' : 'ja'}',
          'Angemeldet: ${user?.email ?? 'nein'}',
          'User-ID: ${user?.id ?? '-'}',
          'Lokale aktive Fächer: ${localSubjects.length}',
          'Remote aktive Fächer unter den letzten 8: $remoteActive',
          'Remote gelöschte Fächer unter den letzten 8: $remoteDeleted',
          if (newestSubjects.isNotEmpty) '',
          ...newestSubjects,
        ].join('\n');
      });
    } catch (error) {
      if (mounted) {
        setState(() => _diagnostics = 'Diagnose fehlgeschlagen: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = SupabaseService.client;
    final email = client?.auth.currentUser?.email;
    return Scaffold(
      appBar: AppBar(title: const Text('Konto & Synchronisierung')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.favorite_rounded, size: 44),
              const SizedBox(height: 20),
              if (client == null)
                const Text(
                  'Supabase ist noch nicht eingerichtet. Die App speichert lokal auf Windows und Android.',
                ),
              if (client != null && !kIsWeb && email == null) ...[
                const Text('Mit deinem StudyBuddy-Konto anmelden'),
                const SizedBox(height: 16),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'E-Mail'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Passwort'),
                  onSubmitted: (_) => _signIn(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _signIn,
                  child: const Text('Anmelden'),
                ),
              ],
              if (email != null && !kIsWeb) ...[
                Text('Angemeldet als $email'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _sync,
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Jetzt synchronisieren'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _runDiagnostics,
                  icon: const Icon(Icons.bug_report_outlined),
                  label: const Text('Sync-Diagnose anzeigen'),
                ),
                TextButton(
                  onPressed: _busy ? null : _signOut,
                  child: const Text('Abmelden'),
                ),
              ],
              if (kIsWeb)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text(
                    'Die Web-Vorschau ist nur zum Anschauen. Anmeldung und dauerhafte Speicherung gibt es auf Windows und Android.',
                  ),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(_message!),
                ),
              if (_diagnostics != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: SelectableText(_diagnostics!),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
