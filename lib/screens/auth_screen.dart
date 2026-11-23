import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _createAccount = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    if (_createAccount) {
      await auth.signUp(_username.text, _password.text);
    } else {
      await auth.signIn(_username.text, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Waiting Room Account')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Consumer<AuthProvider>(builder: (context, auth, _) {
                return Form(
                  key: _formKey,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Text(
                        _createAccount ? 'Request an account' : 'Sign in',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(_createAccount
                          ? 'Regular accounts need administrator approval. Pre-authorized admin usernames are approved automatically.'
                          : 'Sign in with your approved waiting-room account.'),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _username,
                        textCapitalization: TextCapitalization.none,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null ||
                                !RegExp(r'^[a-zA-Z0-9_.-]{3,24}$')
                                    .hasMatch(value.trim())
                            ? 'Use 3–24 letters, numbers, dot, dash, or underscore.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter your password.'
                            : null,
                      ),
                      if (auth.error != null) ...[
                        const SizedBox(height: 12),
                        Text(auth.error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ],
                      if (auth.emailConfirmationRequired) ...[
                        const SizedBox(height: 12),
                        const Text('Username accounts require email confirmation to be disabled in Supabase Auth settings. Ask the administrator to turn it off, then try again.'),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: auth.isBusy ? null : _submit,
                        child: auth.isBusy
                            ? const CircularProgressIndicator()
                            : Text(_createAccount
                                ? 'Request account'
                                : 'Sign in'),
                      ),
                      TextButton(
                        onPressed: auth.isBusy
                            ? null
                            : () => setState(
                                  () => _createAccount = !_createAccount,
                                ),
                        child: Text(_createAccount
                            ? 'Already have an account? Sign in'
                            : 'Need an account? Request one'),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      );
}
