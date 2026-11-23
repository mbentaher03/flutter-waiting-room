import 'package:flutter/material.dart';

import '../models/app_connectivity.dart';

class OfflineBanner extends StatelessWidget {
  final AppConnectivity status;

  const OfflineBanner({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (message, color) = switch (status) {
      AppConnectivity.offline => ('No network connection', Colors.red),
      AppConnectivity.backendUnavailable =>
        ('Waiting-room server unavailable', Colors.deepOrange),
      AppConnectivity.checking => ('Checking connection…', Colors.blueGrey),
      AppConnectivity.online => ('', Colors.transparent),
    };
    if (status == AppConnectivity.online) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      color: color,
      child: Text(message,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }
}
