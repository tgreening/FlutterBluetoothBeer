import 'package:flutter/material.dart';

import './SelectBondedDevicePage.dart';

void main() => runApp(new ExampleApplication());

class ExampleApplication extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false, home: SelectBondedDevicePage());
  }
}
