import 'package:flutter/material.dart';
import 'package:moonetix_offerwall/moonetix_offerwall.dart';

import 'src/app.dart';
import 'src/config.dart';
import 'src/earn_api.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The App ID is public. The API key never ships in the app: it stays on your server.
  Moonetix.init(AppConfig.moonetixAppId);
  runApp(EarnApp(api: EarnApi(baseUrl: AppConfig.apiBaseUrl)));
}
