import 'package:flutter/material.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final UserPreferences _preferences = UserPreferences();
  late ThemePreference _themePreference;
  late bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    await _preferences.init();
    setState(() {
      _themePreference = _preferences.getThemePreference();
      _isLoading = false;
    });
  }

  Future<void> _updateThemePreference(ThemePreference preference) async {
    await _preferences.setThemePreference(preference);
    setState(() {
      _themePreference = preference;
    });

    // No need for the snackbar message since the theme change will be immediately visible
    // Instead, we can add a subtle visual feedback
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Theme updated'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 160,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Settings',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 16),
                _buildThemeSection(),
                const Divider(),
                // Other settings sections can be added here
              ],
            ),
    );
  }

  Widget _buildThemeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Appearance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Choose how the app looks',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
        _buildThemeOption(
          title: 'System default',
          subtitle: 'Follow system theme settings',
          value: ThemePreference.system,
          icon: Icons.brightness_auto,
        ),
        _buildThemeOption(
          title: 'Light',
          subtitle: 'Light theme for all screens',
          value: ThemePreference.light,
          icon: Icons.light_mode,
        ),
        _buildThemeOption(
          title: 'Dark',
          subtitle: 'Dark theme for all screens',
          value: ThemePreference.dark,
          icon: Icons.dark_mode,
        ),
      ],
    );
  }

  Widget _buildThemeOption({
    required String title,
    required String subtitle,
    required ThemePreference value,
    required IconData icon,
  }) {
    final isSelected = _themePreference == value;

    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      leading: Icon(icon),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
          : null,
      onTap: () => _updateThemePreference(value),
      selected: isSelected,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}
