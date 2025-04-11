import 'package:flutter/material.dart';
import 'package:cb_file_manager/ui/template.dart';
import 'package:cb_file_manager/ui/home/local_home.dart';
import 'utils/route.dart';

class MyHomePage extends StatefulWidget {
  final String title;

  const MyHomePage({Key? key, required this.title}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    // Creating a map with the required configuration properties
    final Map<String, dynamic> templateConfig = {
      'appBarTitle': widget.title,
      'body': Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'CoolBird File Manager',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            const Icon(
              Icons.file_copy_outlined,
              size: 100,
              color: Colors.green,
            ),
            const SizedBox(height: 40),
            const Text(
              'Your complete file management solution',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              'Organize your files with powerful tagging capabilities',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Browse Files'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              onPressed: () {
                RouteUtils.toNewScreenWithoutPop(context, const LocalHome());
              },
            ),
          ],
        ),
      )
    };
    
    // Pass the map to CBTemplate as a positional parameter
    return CBTemplate(templateConfig);
  }
}
