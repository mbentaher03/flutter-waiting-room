import 'package:flutter/material.dart';

class WaitingRoomCard extends StatelessWidget {
  final String name;

  const WaitingRoomCard({
    super.key,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
return Card(
  child: Column(
    children: [
      const Text('Hello,'),
      Text(name),
    ],
  ),
);
  }
}