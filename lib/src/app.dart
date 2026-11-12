import 'package:flutter/material.dart';

import 'earn_api.dart';
import 'home_screen.dart';
import 'sign_in_screen.dart';

class EarnApp extends StatefulWidget {
  const EarnApp({super.key, required this.api});

  final EarnApi api;

  @override
  State<EarnApp> createState() => _EarnAppState();
}

class _EarnAppState extends State<EarnApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Earn coins',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF004ABB), useMaterial3: true),
      home: widget.api.signedIn
          ? HomeScreen(api: widget.api, onSignedOut: () => setState(() {}))
          : SignInScreen(api: widget.api, onSignedIn: () => setState(() {})),
    );
  }
}
