import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/queue_state.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';
import '../queue_provider.dart';
import '../widgets/client_card.dart';
import '../widgets/admin_approval_panel.dart';
import '../widgets/loading_widget.dart';
import '../widgets/offline_banner.dart';
import '../widgets/queue_empty_widget.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  late final QueueProvider _queue;
  final _nameController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _queue = context.read<QueueProvider>();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userId = context.read<AuthProvider>().user?.id;
      if (userId == null) return;
      context.read<QueueProvider>().activateUser(userId);
      context.read<ConnectivityProvider>().initialize();
      context.read<QueueProvider>().initialize();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 300) {
      context.read<QueueProvider>().loadMore();
    }
  }

  void _addClient() {
    final name = _nameController.text;
    _nameController.clear();
    final userId = context.read<AuthProvider>().user?.id;
    context.read<QueueProvider>().addClient(name, ownerId: userId);
  }

  Future<void> _deleteClient(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this client?'),
        content: const Text('This permanently removes the client from the shared queue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<QueueProvider>().adminDeleteClient(id);
    } catch (_) {
      // QueueProvider provides the visible error message.
    }
  }

  Future<void> _callNext() async {
    try {
      final id = await context.read<QueueProvider>().adminCallNextClient();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(id == null
            ? 'The queue is empty.'
            : 'Next client called and removed from the queue.'),
      ));
    } catch (_) {
      // QueueProvider provides the visible error message.
    }
  }

  @override
  void dispose() {
    _queue.deactivateUser();
    _nameController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Waiting Room'),
          centerTitle: true,
          actions: [
            Consumer<AuthProvider>(builder: (context, auth, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Sign out',
                      onPressed: auth.isBusy ? null : auth.signOut,
                      icon: const Icon(Icons.logout),
                    ),
                  ],
                )),
          ],
        ),
        body: Column(children: [
          Consumer<ConnectivityProvider>(
            builder: (_, provider, __) => OfflineBanner(status: provider.status),
          ),
          Consumer<AuthProvider>(builder: (context, auth, _) {
            if (!auth.isAdmin) return const SizedBox.shrink();
            return const AdminApprovalPanel();
          }),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addClient(),
                  textInputAction: TextInputAction.done,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _addClient,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Join'),
              ),
            ]),
          ),
          Consumer<QueueProvider>(
            builder: (_, provider, __) => provider.errorMessage == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(provider.errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
          ),
          Consumer<QueueProvider>(builder: (_, provider, __) {
            if (provider.pendingClients.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: 170,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pending registrations (not in the official queue)'),
                    Expanded(
                      child: ListView.builder(
                        itemCount: provider.pendingClients.length,
                        itemBuilder: (_, index) => ClientCard(
                          client: provider.pendingClients[index],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          Expanded(
            child: Consumer<QueueProvider>(builder: (_, provider, __) {
              if (provider.state == QueueState.loading &&
                  provider.clients.isEmpty) {
                return const LoadingWidget();
              }
              if (provider.clients.isEmpty &&
                  provider.state != QueueState.error) {
                return const QueueEmptyWidget();
              }
              if (provider.state == QueueState.error &&
                  provider.clients.isEmpty) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 8),
                    Text(provider.errorMessage ?? 'Could not load the waiting queue.'),
                    TextButton(
                      onPressed: provider.refresh,
                      child: const Text('Retry'),
                    ),
                  ]),
                );
              }
              return RefreshIndicator(
                onRefresh: provider.refresh,
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: provider.clients.length +
                      (provider.isLoadingMore ? 1 : 0),
                  itemBuilder: (_, index) {
                    if (index == provider.clients.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return Consumer<AuthProvider>(
                      builder: (context, auth, _) => ClientCard(
                        client: provider.clients[index],
                        onDelete: auth.isAdmin
                            ? () => _deleteClient(provider.clients[index].id)
                            : null,
                      ),
                    );
                  },
                ),
              );
            }),
          ),
          Consumer<AuthProvider>(builder: (context, auth, _) {
            if (!auth.isAdmin) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _callNext,
                  child: const Text('Call next client'),
                ),
              ),
            );
          }),
        ]),
      );
}
