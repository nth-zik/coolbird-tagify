import 'package:flutter/material.dart';
import 'drawer.dart';

class CBTemplate extends StatefulWidget {
  final Map<String, dynamic> config;

  const CBTemplate(this.config, {Key? key}) : super(key: key);

  @override
  State<CBTemplate> createState() => _CBTemplateState();
}

class _CBTemplateState extends State<CBTemplate> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.config['appBarTitle']?.toString() ?? ''),
      ),
      body: widget.config['body'] as Widget,
      drawer: CBDrawer(context),
    );
  }
}
