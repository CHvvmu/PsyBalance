import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/services/auth_bootstrap.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();

  final String persistSessionKey =
      'sb-${Uri.parse(AppConfig.supabaseUrl).host.split('.').first}-auth-token';

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: SharedPreferencesLocalStorage(
        persistSessionKey: persistSessionKey,
      ),
    ),
  );

  await AuthBootstrap.ensureReady();

  runApp(const PsyBalanceApp());
}
