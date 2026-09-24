import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/dashboard/presentation/dashboard_controller.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../theme/app_theme.dart';

class StudyBuddyApp extends StatelessWidget {
  const StudyBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyBuddy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('de', 'AT'),
      supportedLocales: const [Locale('de', 'AT')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _LifecycleSync(child: DashboardScreen()),
    );
  }
}

class _LifecycleSync extends ConsumerStatefulWidget {
  const _LifecycleSync({required this.child});

  final Widget child;

  @override
  ConsumerState<_LifecycleSync> createState() => _LifecycleSyncState();
}

class _LifecycleSyncState extends ConsumerState<_LifecycleSync>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        ref
            .read(studyBuddyControllerProvider.notifier)
            .syncNow()
            .catchError((Object _) {}),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
