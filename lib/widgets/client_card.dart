import 'package:flutter/material.dart';

import '../models/client.dart';
import '../models/sync_status.dart';

class ClientCard extends StatelessWidget {
  final Client client;

  const ClientCard({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final pending = client.syncStatus != SyncStatus.synced;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: client.queueNumber == null
              ? const Icon(Icons.person_outline)
              : Text('${client.queueNumber}'),
        ),
        title: Text(client.name),
        subtitle: Text(pending
            ? 'Saved on this device · waiting to sync'
            : client.hasLocation
                ? 'Location context captured'
                : 'Location not captured'),
        trailing: Icon(
          pending ? Icons.cloud_upload_outlined : Icons.check_circle_outline,
          color: pending ? Colors.orange : Colors.green,
        ),
      ),
    );
  }
}
