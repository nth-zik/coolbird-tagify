import 'package:flutter/material.dart';

/// Component to display error messages with appropriate styling and actions
class ErrorView extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onGoBack;

  const ErrorView({
    Key? key,
    required this.errorMessage,
    required this.onRetry,
    required this.onGoBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check if error is likely due to permissions
    bool isAdminError = errorMessage.toLowerCase().contains('access denied') ||
        errorMessage.toLowerCase().contains('administrator privileges');

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isAdminError ? Icons.admin_panel_settings : Icons.error_outline,
            size: 48,
            color: isAdminError ? Colors.orange : Colors.red,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              errorMessage,
              style: TextStyle(
                color: isAdminError ? Colors.orange[800] : Colors.red[700],
                fontSize: isAdminError ? 16.0 : 14.0,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          if (isAdminError)
            Column(
              children: [
                const Text(
                  'To access this drive, you need to:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    '1. Close the app\n'
                    '2. Right-click on the app icon\n'
                    '3. Select "Run as administrator"\n'
                    '4. Try accessing the drive again',
                    textAlign: TextAlign.left,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Try Again'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onGoBack,
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}
