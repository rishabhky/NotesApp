import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:get/get_navigation/src/routes/get_route.dart';
import 'package:notes/screens/home.dart';
import 'package:notes/screens/notice.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      theme: ThemeData(
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.white12, // Cursor color
          selectionColor: Colors.white24, // Text highlight/selection color
          selectionHandleColor: Colors.white54, // Handle (drag) color
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        quill.FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // or any other you want
      ],
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      getPages: [
        GetPage(name: '/', page: () => const HomePage()),
        GetPage(name: '/edit', page: () => const EditScreen()),
      ],
      initialRoute: '/',
    );
  }
}
