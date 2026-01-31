import 'dart:math';

import 'package:flutter/foundation.dart';

enum OperationProgressStatus { running, success, error }

@immutable
class OperationProgressEntry {
  final String id;
  final String title;
  final String? detail;
  final int total;
  final int completed;
  final OperationProgressStatus status;
  final bool isMinimized;
  final bool isIndeterminate;
  final DateTime startedAt;
  final DateTime? finishedAt;

  const OperationProgressEntry({
    required this.id,
    required this.title,
    required this.total,
    required this.completed,
    required this.status,
    required this.isMinimized,
    required this.isIndeterminate,
    required this.startedAt,
    this.finishedAt,
    this.detail,
  });

  double get progressFraction {
    if (isIndeterminate) return 0;
    if (total <= 0) return 0;
    return (completed / total).clamp(0.0, 1.0);
  }

  bool get isRunning => status == OperationProgressStatus.running;
  bool get isFinished => status != OperationProgressStatus.running;

  OperationProgressEntry copyWith({
    String? title,
    String? detail,
    int? total,
    int? completed,
    OperationProgressStatus? status,
    bool? isMinimized,
    bool? isIndeterminate,
    DateTime? finishedAt,
    bool clearDetail = false,
  }) {
    return OperationProgressEntry(
      id: id,
      title: title ?? this.title,
      detail: clearDetail ? null : (detail ?? this.detail),
      total: total ?? this.total,
      completed: completed ?? this.completed,
      status: status ?? this.status,
      isMinimized: isMinimized ?? this.isMinimized,
      isIndeterminate: isIndeterminate ?? this.isIndeterminate,
      startedAt: startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }
}

/// A lightweight, reusable controller to show a modal progress UI and a minimized
/// status bar entry for long-running operations (delete, copy, move, etc.).
///
/// This intentionally supports a single active operation for now.
class OperationProgressController extends ChangeNotifier {
  OperationProgressEntry? _active;

  OperationProgressEntry? get active => _active;

  String begin({
    required String title,
    required int total,
    String? detail,
    bool isIndeterminate = false,
    bool showModal = false,
  }) {
    final id = _newId();
    _active = OperationProgressEntry(
      id: id,
      title: title,
      detail: detail,
      total: max(0, total),
      completed: 0,
      status: OperationProgressStatus.running,
      isMinimized: !showModal,
      isIndeterminate: isIndeterminate,
      startedAt: DateTime.now(),
    );
    notifyListeners();
    return id;
  }

  void update(
    String id, {
    int? completed,
    String? detail,
    int? total,
    bool? isIndeterminate,
  }) {
    final current = _active;
    if (current == null) return;
    if (current.id != id) return;
    if (!current.isRunning) return;

    final nextCompleted =
        completed == null ? current.completed : max(0, completed);
    final nextTotal = total == null ? current.total : max(0, total);
    _active = current.copyWith(
      completed: min(nextCompleted, nextTotal == 0 ? nextCompleted : nextTotal),
      total: nextTotal,
      detail: detail,
      isIndeterminate: isIndeterminate,
    );
    notifyListeners();
  }

  void succeed(String id, {String? detail}) {
    final current = _active;
    if (current == null) return;
    if (current.id != id) return;

    _active = current.copyWith(
      completed: current.total == 0 ? current.completed : current.total,
      status: OperationProgressStatus.success,
      detail: detail,
      finishedAt: DateTime.now(),
    );
    notifyListeners();
  }

  void fail(String id, {String? detail}) {
    final current = _active;
    if (current == null) return;
    if (current.id != id) return;

    _active = current.copyWith(
      status: OperationProgressStatus.error,
      detail: detail,
      finishedAt: DateTime.now(),
    );
    notifyListeners();
  }

  void minimize() {
    final current = _active;
    if (current == null) return;
    if (current.isMinimized) return;
    _active = current.copyWith(isMinimized: true);
    notifyListeners();
  }

  void show() {
    final current = _active;
    if (current == null) return;
    if (!current.isMinimized) return;
    _active = current.copyWith(isMinimized: false);
    notifyListeners();
  }

  void dismiss() {
    if (_active == null) return;
    _active = null;
    notifyListeners();
  }

  String _newId() {
    return '${DateTime.now().microsecondsSinceEpoch}-${_rand32()}';
  }

  int _rand32() {
    final v = DateTime.now().microsecondsSinceEpoch;
    return (v ^ (v >> 16)) & 0xFFFFFFFF;
  }
}
