import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moonetix_offerwall/moonetix_offerwall.dart';

import 'earn_api.dart';

/// Opens the Moonetix offerwall with a fresh single-use token from your server.
/// Rewards never come through here: your server credits them from postbacks.
class EarnButton extends StatefulWidget {
  const EarnButton({super.key, required this.api, required this.onClosed});

  final EarnApi api;

  /// Called when the user closes the offerwall. Reload the balance there.
  final VoidCallback onClosed;

  @override
  State<EarnButton> createState() => _EarnButtonState();
}

class _EarnButtonState extends State<EarnButton> {
  late final StreamSubscription<MoonetixEvent> _events;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Listen before open: the stream does not keep events for later.
    _events = Moonetix.events.listen((MoonetixEvent event) {
      switch (event) {
        case MoonetixOpened():
          break;
        case MoonetixClosed():
          widget.onClosed();
        case MoonetixErrorEvent(:final MoonetixError error):
          debugPrint('Moonetix: ${error.code.name}: ${error.message}');
          _show(_describe(error.code));
      }
    });
  }

  @override
  void dispose() {
    _events.cancel();
    super.dispose();
  }

  Future<void> _openOfferwall() async {
    setState(() => _busy = true);
    try {
      // A new token on every tap. Tokens work once and for 10 minutes.
      final String token = await widget.api.fetchMoonetixToken();
      await Moonetix.open(token, options: const MoonetixOptions(title: 'Earn coins'));
    } catch (_) {
      _show('The offerwall is not available right now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _describe(MoonetixErrorCode code) => switch (code) {
        MoonetixErrorCode.network => 'No connection. Try again when you are back online.',
        MoonetixErrorCode.unsupported => 'Offers open on Android and iOS only.',
        _ => 'The offerwall is not available right now. Try again.',
      };

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const Key('earn'),
      onPressed: _busy ? null : _openOfferwall,
      icon: const Icon(Icons.card_giftcard),
      label: const Text('Earn coins'),
    );
  }
}
