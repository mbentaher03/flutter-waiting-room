import 'package:flutter/material.dart';

import '../models/client.dart';
import '../models/sync_status.dart';

class ClientCard extends StatelessWidget {
  final Client client;
  final VoidCallback? onDelete;

  const ClientCard({super.key, required this.client, this.onDelete});

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
        trailing: onDelete != null
            ? IconButton(
                tooltip: 'Remove client from queue',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              )
            : Icon(
                pending
                    ? Icons.cloud_upload_outlined
                    : Icons.check_circle_outline,
                color: pending ? Colors.orange : Colors.green,
              ),
      ),
    );
  }
}
