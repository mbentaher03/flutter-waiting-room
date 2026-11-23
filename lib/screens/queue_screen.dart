import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/queue_state.dart';
import '../providers/connectivity_provider.dart';
import '../queue_provider.dart';
import '../widgets/client_card.dart';
import '../widgets/loading_widget.dart';
import '../widgets/offline_banner.dart';
import '../widgets/queue_empty_widget.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final _nameController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
    context.read<QueueProvider>().addClient(name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Waiting Room'), centerTitle: true),
        body: Column(children: [
          Consumer<ConnectivityProvider>(
            builder: (_, provider, __) => OfflineBanner(status: provider.status),
          ),
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
                    return ClientCard(client: provider.clients[index]);
                  },
                ),
              );
            }),
          ),
        ]),
      );
}
