import 'package:flutter/material.dart';

/// Utility class for common dialogs used throughout the application
class DialogUtils {
  /// Shows a confirmation dialog asking if the user wants to continue iteration
  ///
  /// Returns true if the user wants to continue, false otherwise
  static Future<bool> showContinueIterationDialog(
    BuildContext context, {
    String title = 'Continue?',
    String message = 'Continue to iterate?',
    String continueText = 'Continue',
    String cancelText = 'Stop',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(cancelText),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(continueText),
            ),
          ],
        );
      },
    );

    // Return false if dialog was dismissed without selection
    return result ?? false;
  }

  /// Shows a general confirmation dialog with customizable options
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'OK',
    String cancelText = 'Cancel',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(cancelText),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}
