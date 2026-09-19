import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_flutter_sdk_navi/kakao_flutter_sdk_navi.dart';


import 'core/app_theme.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'services/app_repository.dart';
import 'services/location_service.dart';
import 'services/storage_service.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env 로드
  await dotenv.load(
    fileName: '.env',
    isOptional: true,
  );

  // ------------------------------------------------------------
  // Kakao Flutter SDK 초기화
  // ------------------------------------------------------------
  final kakaoNativeAppKey =
      dotenv.env['KAKAO_NATIVE_APP_KEY'];

  if (
      kakaoNativeAppKey != null &&
      kakaoNativeAppKey.trim().isNotEmpty) {
    KakaoSdk.init(
      nativeAppKey: kakaoNativeAppKey.trim(),
    );
  } else {
    debugPrint(
      '[Kakao] KAKAO_NATIVE_APP_KEY가 설정되지 않았습니다.',
    );
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.paper,
      systemNavigationBarIconBrightness:
          Brightness.dark,
    ),
  );

  final controller = AppController(
    repository: AppRepository(
      ApiClient(),
    ),
    locationService: LocationService(),
    storageService: StorageService(),
  );

  runApp(
    GyeongjuHanjeokApp(
      controller: controller,
    ),
  );
}

class GyeongjuHanjeokApp
    extends StatefulWidget {
  const GyeongjuHanjeokApp({
    required this.controller,
    super.key,
  });

  final AppController controller;

  @override
  State<GyeongjuHanjeokApp> createState() =>
      _GyeongjuHanjeokAppState();
}

class _GyeongjuHanjeokAppState
    extends State<GyeongjuHanjeokApp> {
  @override
  void initState() {
    super.initState();

    widget.controller.initialize();
  }

  @override
  void dispose() {
    widget.controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: widget.controller,
      child: MaterialApp(
        title: '경주한적',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: _AppBootstrap(
          controller: widget.controller,
        ),
      ),
    );
  }
}

class _AppBootstrap
    extends StatelessWidget {
  const _AppBootstrap({
    required this.controller,
  });

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (
        context,
        _,
      ) {
        if (controller.isInitializing) {
          return const AppLoadingScreen();
        }

        if (!controller.isAuthenticated) {
          return const LoginScreen();
        }

        if (
            controller.places.isEmpty &&
            controller.globalError != null) {
          return AppFatalErrorScreen(
            message: controller.globalError!,
            onRetry: controller.initialize,
          );
        }

        return const AppShell();
      },
    );
  }
}