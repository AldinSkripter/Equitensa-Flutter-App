import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';

enum ConflictChoice { reloadAndRetry, keepEditing }

/// Revision conflict (409 FINANCE_VERSION_CONFLICT): never overwrite silently and never
/// discard the user's input. The caller keeps its form state either way.
Future<ConflictChoice> showConflictDialog(BuildContext context) async {
  final s = S.of(context);
  final r = await showDialog<ConflictChoice>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: Brand.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: const Icon(
        Icons.sync_problem_rounded,
        color: Brand.warning,
        size: 36,
      ),
      title: Text(s.t('conflict_title'), textAlign: TextAlign.center),
      content: Text(s.t('conflict_body'), textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ConflictChoice.reloadAndRetry),
          child: Text(s.t('conflict_reload')),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, ConflictChoice.keepEditing),
          child: Text(s.t('conflict_keep')),
        ),
      ],
    ),
  );
  return r ?? ConflictChoice.keepEditing;
}
