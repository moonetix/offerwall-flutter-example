import 'package:flutter/material.dart';

import 'earn_api.dart';
import 'earn_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api, required this.onSignedOut});

  final EarnApi api;
  final VoidCallback onSignedOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Account? _account;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshBalance();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Offers can credit minutes or days later, so also reload when the app comes back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshBalance();
  }

  /// The balance always comes from your server, which credits it from postbacks.
  Future<void> _refreshBalance() async {
    try {
      final Account account = await widget.api.me();
      if (!mounted) return;
      setState(() {
        _account = account;
        _error = null;
      });
    } on ApiException catch (e) {
      if (e.signedOut) return widget.onSignedOut();
      if (mounted) setState(() => _error = 'Balance not available right now.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Balance not available right now.');
    }
  }

  Future<void> _signOut() async {
    try {
      await widget.api.signOut();
    } catch (_) {
      // Signed out locally either way.
    }
    widget.onSignedOut();
  }

  @override
  Widget build(BuildContext context) {
    final Account? account = _account;
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rewards'),
        actions: <Widget>[
          IconButton(tooltip: 'Sign out', onPressed: _signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshBalance,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Text('Your balance', style: text.labelLarge),
            Text(
              account == null ? (_error ?? '...') : '${account.balance} ${account.currency}',
              key: const Key('balance'),
              style: text.headlineMedium,
            ),
            const SizedBox(height: 24),
            EarnButton(api: widget.api, onClosed: _refreshBalance),
            const SizedBox(height: 8),
            Text(
              'Offers come from third-party advertisers. Some rewards arrive after a review. '
              'VPNs and proxies are not supported.',
              style: text.bodySmall,
            ),
            if (account != null && account.history.isNotEmpty) ...<Widget>[
              const SizedBox(height: 24),
              Text('Recent rewards', style: text.titleMedium),
              for (final Reward r in account.history)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.offer),
                  subtitle: Text(r.at),
                  trailing: Text(r.status == 'reversed' ? 'Reversed ${r.reward}' : '+${r.reward}'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
