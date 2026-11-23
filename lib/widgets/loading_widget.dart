import 'package:flutter/material.dart';

class LoadingWidget extends StatelessWidget {
  final String message;
  const LoadingWidget({super.key, this.message = 'Loading queue…'});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(message),
        ]),
      );
}
