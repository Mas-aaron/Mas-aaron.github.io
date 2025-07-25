import 'package:flutter/material.dart';

class KDSScreen extends StatelessWidget {
  const KDSScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Kitchen Display System', style: Theme.of(context).textTheme.headlineMedium),
    );
  }
}
