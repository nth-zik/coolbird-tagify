import 'package:flutter/material.dart';

class RouteUtils {
  static void toNewScreen(BuildContext context, Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context)
        .push(PageRouteBuilder(pageBuilder: (BuildContext context, _, __) {
      return screen;
    }, transitionsBuilder: (_, Animation<double> animation, __, Widget child) {
      return FadeTransition(opacity: animation, child: child);
    }));
  }

  static void toNewScreenWithoutPop(BuildContext context, Widget screen) {
    Navigator.of(context)
        .push(PageRouteBuilder(pageBuilder: (BuildContext context, _, __) {
      return screen;
    }, transitionsBuilder: (_, Animation<double> animation, __, Widget child) {
      return FadeTransition(opacity: animation, child: child);
    }));
  }

  static void replaceScreen(BuildContext context, Widget screen) {
    Navigator.of(context).pushReplacement(
        PageRouteBuilder(pageBuilder: (BuildContext context, _, __) {
      return screen;
    }, transitionsBuilder: (_, Animation<double> animation, __, Widget child) {
      return FadeTransition(opacity: animation, child: child);
    }));
  }
}
