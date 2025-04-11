import 'package:flutter/material.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';

// Legacy code maintained for backward compatibility
final GlobalKey<ScaffoldState> scaffoldKey = BaseScreen.scaffoldKey;

class CBTemplate extends StatefulWidget {
  final Map<String, dynamic> config;

  const CBTemplate(this.config, {Key? key}) : super(key: key);

  @override
  State<CBTemplate> createState() => _CBTemplateState();
}

class _CBTemplateState extends State<CBTemplate> {
  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: widget.config['appBarTitle']?.toString() ?? '',
      body: widget.config['body'] as Widget,
    );
  }
}

// Legacy function maintained for backward compatibility
void openGlobalDrawer() {
  BaseScreen.openDrawer();
}
