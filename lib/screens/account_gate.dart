import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'auth_screen.dart';
import 'queue_screen.dart';

class AccountGate extends StatelessWidget {
  const AccountGate({super.key});

  @override
  Widget build(BuildContext context) => Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (auth.user == null) return const AuthScreen();
          if (auth.profile == null) {
            return _AccountMessage(
              title: 'Account setup needed',
              message: auth.error ??
                  'The account profile could not be loaded. Confirm that the account approval migration has been applied in Supabase.',
            );
          }
          if (!auth.isApproved) {
            return _AccountMessage(
              title: auth.isRejected ? 'Request not approved' : 'Approval pending',
              message: auth.isRejected
                  ? 'An administrator did not approve this account. Contact the waiting-room administrator if you think this is a mistake.'
                  : 'Your account request is waiting for administrator approval. You cannot join the official queue until it is approved.',
            );
          }
          return const QueueScreen();
        },
      );
}

class _AccountMessage extends StatelessWidget {
  final String title;
  final String message;

  const _AccountMessage({required this.title, required this.message});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            TextButton(
              onPressed: () => context.read<AuthProvider>().signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    title == 'Approval pending'
                        ? Icons.hourglass_top
                        : Icons.info_outline,
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => context.read<AuthProvider>().refreshProfile(),
                    child: const Text('Check approval again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
