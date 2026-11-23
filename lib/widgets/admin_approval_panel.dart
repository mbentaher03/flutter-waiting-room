import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class AdminApprovalPanel extends StatefulWidget {
  const AdminApprovalPanel({super.key});

  @override
  State<AdminApprovalPanel> createState() => _AdminApprovalPanelState();
}

class _AdminApprovalPanelState extends State<AdminApprovalPanel> {
  late Future<List<Map<String, dynamic>>> _requests;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  void _loadRequests() {
    _requests = context.read<AuthProvider>().loadPendingApprovals();
  }

  Future<void> _decide(String id, bool approve) async {
    try {
      await context.read<AuthProvider>().decideApproval(id, approve: approve);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve ? 'User approved.' : 'User rejected.'),
      ));
      setState(_loadRequests);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update the request: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Account requests',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh requests',
                    onPressed: () => setState(_loadRequests),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _requests,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Could not load account requests.'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final requests = snapshot.data!;
                  if (requests.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No pending requests.'),
                    );
                  }
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 190),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        final id = request['id'] as String;
                        final username =
                            request['username']?.toString() ?? 'Unknown user';
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(username),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => _decide(id, true),
                                child: const Text('Approve'),
                              ),
                              TextButton(
                                onPressed: () => _decide(id, false),
                                child: const Text('Reject'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
}
