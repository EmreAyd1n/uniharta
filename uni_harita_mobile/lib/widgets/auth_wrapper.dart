import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/login_screen.dart';
import '../screens/map_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Oturum durumunu al (stream'den veya mevcut oturumdan)
        final session = snapshot.data?.session ??
            Supabase.instance.client.auth.currentSession;

        // Geçişlerde akıcı animasyonlar için AnimatedSwitcher kullanıyoruz
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          // session varsa MapScreen, yoksa LoginScreen göster
          child: session != null
              ? const MapScreen(key: ValueKey('map_screen'))
              : const LoginScreen(key: ValueKey('login_screen')),
        );
      },
    );
  }
}
