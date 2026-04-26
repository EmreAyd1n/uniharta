import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zfuwnsxaxjbufmqshrkm.supabase.co',
    anonKey: 'sb_publishable_c5pWbhwK6Y1jXTXZ33xiWA_Ia5lluOp',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Mevcut oturumu kontrol et
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      title: 'UniHarita Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7c6cf0),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: session != null ? const HomePage() : const LoginPage(),
    );
  }
}
