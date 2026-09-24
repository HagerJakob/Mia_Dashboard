import 'dart:async';

import 'package:flutter/foundation.dart';

class SyncCoordinator {
  SyncCoordinator({
    required this.runner,
    this.debounceDuration = const Duration(milliseconds: 800),
    this.debugLabel = 'Sync',
  });

  final Future<void> Function() runner;
  final Duration debounceDuration;
  final String debugLabel;

  Timer? _debounceTimer;
  Completer<void>? _idleCompleter;
  bool _running = false;
  bool _runAgain = false;
  Object? _lastError;

  bool get isRunning => _running;
  Object? get lastError => _lastError;

  void requestSync({bool debounced = false, String? reason}) {
    _log('requested${reason == null ? '' : ': $reason'}');
    _idleCompleter ??= Completer<void>();
    if (debounced) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounceDuration, _startOrQueue);
      return;
    }
    _debounceTimer?.cancel();
    _startOrQueue();
  }

  Future<void> flush() {
    _idleCompleter ??= Completer<void>();
    _debounceTimer?.cancel();
    _startOrQueue();
    return _idleCompleter!.future;
  }

  void dispose() {
    _debounceTimer?.cancel();
    final completer = _idleCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _startOrQueue() {
    if (_running) {
      _runAgain = true;
      _log('queued follow-up');
      return;
    }
    unawaited(_drain());
  }

  Future<void> _drain() async {
    _running = true;
    do {
      _runAgain = false;
      try {
        _lastError = null;
        _log('started');
        await runner();
        _log('completed');
      } catch (error, stackTrace) {
        _lastError = error;
        _log('failed: $error');
        if (kDebugMode) {
          debugPrint(stackTrace.toString());
        }
      }
    } while (_runAgain);
    _running = false;
    final completer = _idleCompleter;
    _idleCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[$debugLabel] $message');
    }
  }
}
