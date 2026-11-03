import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/welcome_screen.dart';
import 'services/api_client.dart';
import 'services/app_state.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(appOverlayStyle);
  runApp(const NdidSimApp());
}

class NdidSimApp extends StatefulWidget {
  const NdidSimApp({super.key, this.api});

  /// ถ้าไม่ระบุ จะเรียกเซิร์ฟเวอร์จำลองที่ [defaultApiBaseUrl]
  final AppApi? api;

  @override
  State<NdidSimApp> createState() => _NdidSimAppState();
}

class _NdidSimAppState extends State<NdidSimApp> {
  late final _state = AppState(
    api: widget.api ?? HttpAppApi(baseUrl: defaultApiBaseUrl),
  );

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: _state,
      child: MaterialApp(
        title: 'NDID Verify LOSE',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        // บนจอกว้าง (เช่นเว็บบนคอมพิวเตอร์) แสดงแอปเป็นคอลัมน์ขนาดมือถือกลางจอ
        builder: (context, child) => ColoredBox(
          color: AppColors.field,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: child,
            ),
          ),
        ),
        home: const WelcomeScreen(),
      ),
    );
  }
}
