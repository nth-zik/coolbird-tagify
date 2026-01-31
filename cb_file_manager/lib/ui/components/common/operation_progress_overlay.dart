import 'dart:async';

import 'package:cb_file_manager/config/languages/app_localizations.dart';
import 'package:cb_file_manager/core/service_locator.dart';
import 'package:cb_file_manager/ui/controllers/operation_progress_controller.dart';
import 'package:flutter/material.dart';

class OperationProgressOverlay extends StatefulWidget {
  const OperationProgressOverlay({Key? key}) : super(key: key);

  @override
  State<OperationProgressOverlay> createState() =>
      _OperationProgressOverlayState();
}

class _OperationProgressOverlayState extends State<OperationProgressOverlay> {
  final OperationProgressController _controller =
      locator<OperationProgressController>();

  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final active = _controller.active;
    _autoDismissTimer?.cancel();

    if (active != null && active.isFinished) {
      // Auto-dismiss success after a short delay, keep errors until user dismisses.
      if (active.status == OperationProgressStatus.success) {
        _autoDismissTimer = Timer(const Duration(seconds: 2), () {
          if (!mounted) return;
          final latest = _controller.active;
          if (latest != null &&
              latest.id == active.id &&
              latest.status == OperationProgressStatus.success) {
            _controller.dismiss();
          }
        });
      }
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final active = _controller.active;
    if (active == null) return const SizedBox.shrink();

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: _OperationProgressStatusBar(
          entry: active,
          onDismiss: _controller.dismiss,
        ),
      ),
    );
  }
}

class _OperationProgressStatusBar extends StatelessWidget {
  final OperationProgressEntry entry;
  final VoidCallback onDismiss;

  const _OperationProgressStatusBar({
    required this.entry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? theme.colorScheme.surface.withValues(alpha: 0.92)
        : theme.colorScheme.surface.withValues(alpha: 0.95);

    final Color accent;
    switch (entry.status) {
      case OperationProgressStatus.running:
        accent = theme.colorScheme.primary;
        break;
      case OperationProgressStatus.success:
        accent = Colors.green;
        break;
      case OperationProgressStatus.error:
        accent = theme.colorScheme.error;
        break;
    }

    final label = entry.isRunning
        ? (entry.isIndeterminate ? l10n.processing : '${entry.completed}/${entry.total}')
        : (entry.status == OperationProgressStatus.success
            ? l10n.done
            : l10n.errorTitle);

    final IconData icon;
    switch (entry.status) {
      case OperationProgressStatus.running:
        icon = Icons.sync;
        break;
      case OperationProgressStatus.success:
        icon = Icons.check_circle_outline;
        break;
      case OperationProgressStatus.error:
        icon = Icons.error_outline;
        break;
    }

    return Material(
      elevation: 10,
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: entry.isIndeterminate ? null : entry.progressFraction,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 10),
            if (!entry.isRunning)
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
