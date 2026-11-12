import 'package:flutter/material.dart';

import 'earn_api.dart';

/// Your own account system. The offerwall user ID is the account ID your
/// server assigns, never a value the app picks.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.api, required this.onSignedIn});

  final EarnApi api;
  final VoidCallback onSignedIn;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _creating = false;
  bool _over16 = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_creating) {
        await widget.api.register(_email.text.trim(), _password.text, over16: _over16);
      } else {
        await widget.api.signIn(_email.text.trim(), _password.text);
      }
      widget.onSignedIn();
    } on ApiException catch (e) {
      setState(() => _message = _describe(e.error));
    } catch (_) {
      setState(() => _message = 'The server is not reachable right now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _describe(String error) => switch (error) {
        'wrong_email_or_password' => 'Wrong email or password.',
        'email_taken' => 'An account with this email already exists.',
        'invalid_email' => 'Enter a valid email address.',
        'password_8_to_200_characters' => 'Use a password of at least 8 characters.',
        'must_be_16_or_older' => 'You must be 16 or older to earn rewards.',
        'too_many_attempts' => 'Too many attempts. Try again in a few minutes.',
        _ => 'Something went wrong. Try again.',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_creating ? 'Create account' : 'Sign in')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          TextField(
            key: const Key('email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const <String>[AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('password'),
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          if (_creating)
            CheckboxListTile(
              key: const Key('over16'),
              contentPadding: EdgeInsets.zero,
              value: _over16,
              onChanged: (bool? value) => setState(() => _over16 = value ?? false),
              title: const Text('I am 16 or older'),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('submit'),
            onPressed: _busy || (_creating && !_over16) ? null : _submit,
            child: Text(_creating ? 'Create account' : 'Sign in'),
          ),
          TextButton(
            onPressed: _busy ? null : () => setState(() => _creating = !_creating),
            child: Text(_creating ? 'I already have an account' : 'Create an account'),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
    );
  }
}
