import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme_config.dart';
import '../../../providers/theme_provider.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn Giao Diện'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Theme preview section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xem trước giao diện',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      ThemeConfig.themeNames[themeProvider.currentTheme] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Theme list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: AppThemeType.values.length,
              itemBuilder: (context, index) {
                final themeType = AppThemeType.values[index];
                final themeName = ThemeConfig.themeNames[themeType] ?? '';
                final isSelected = themeProvider.currentTheme == themeType;

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  elevation: isSelected ? 4 : 1,
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getThemePreviewColor(themeType),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 20)
                          : null,
                    ),
                    title: Text(
                      themeName,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(_getThemeDescription(themeType)),
                    trailing: isSelected
                        ? Icon(
                            Icons.radio_button_checked,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : const Icon(Icons.radio_button_unchecked),
                    onTap: () {
                      context.read<ThemeProvider>().setTheme(themeType);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã chọn giao diện: $themeName'),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getThemePreviewColor(AppThemeType themeType) {
    switch (themeType) {
      case AppThemeType.light:
        return const Color(0xFF2196F3);
      case AppThemeType.dark:
        return const Color(0xFF1F1F1F);
      case AppThemeType.amoled:
        return Colors.black;
      case AppThemeType.blue:
        return const Color(0xFF0D47A1);
      case AppThemeType.green:
        return const Color(0xFF2E7D32);
      case AppThemeType.purple:
        return const Color(0xFF6A1B9A);
      case AppThemeType.orange:
        return const Color(0xFFE65100);
    }
  }

  String _getThemeDescription(AppThemeType themeType) {
    switch (themeType) {
      case AppThemeType.light:
        return 'Giao diện sáng cổ điển';
      case AppThemeType.dark:
        return 'Giao diện tối dịu mắt';
      case AppThemeType.amoled:
        return 'Màn hình đen thuần tiết kiệm pin';
      case AppThemeType.blue:
        return 'Màu xanh dương đại dương';
      case AppThemeType.green:
        return 'Màu xanh lá cây rừng';
      case AppThemeType.purple:
        return 'Màu tím hoàng gia';
      case AppThemeType.orange:
        return 'Màu cam hoàng hôn';
    }
  }
}
