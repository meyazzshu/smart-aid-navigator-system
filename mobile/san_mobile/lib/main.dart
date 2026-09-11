import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'auth/auth_controller.dart';
import 'core/app_theme.dart';
import 'core/config.dart';
import 'core/fcm_service.dart';
import 'core/local_notifications.dart' as local_notifications;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final mapsImplementation = GoogleMapsFlutterPlatform.instance;

  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    mapsImplementation.useAndroidViewSurface = true;
    await mapsImplementation.initializeWithRenderer(
      AndroidMapRenderer.latest,
    );
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  await local_notifications.LocalNotifications.init();

  runApp(const ProviderScope(child: SanApp()));

  unawaited(FcmService.init());
}

class SanApp extends ConsumerStatefulWidget {
  const SanApp({super.key});

  @override
  ConsumerState<SanApp> createState() => _SanAppState();
}

class _SanAppState extends ConsumerState<SanApp> {
  @override
  void initState() {
    super.initState();
    // Restore JWT session on startup
    Future.microtask(() => ref.read(authControllerProvider.notifier).restoreSession());
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Smart Aid Navigator',
      routerConfig: router,
      theme: AppTheme.lightTheme(),
    );
  }
}
