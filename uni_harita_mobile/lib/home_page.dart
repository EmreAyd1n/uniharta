import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _fullName = '';
  String _email = '';
  String _userType = 'ogrenci';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
      return;
    }

    _email = user.email ?? '';

    // Profil bilgilerini getir
    try {
      final data = await supabase
          .from('profiles')
          .select('full_name, user_type')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _fullName = data['full_name'] ?? '';
          _userType = data['user_type'] ?? 'ogrenci';
          _loading = false;
        });
      }
    } catch (_) {
      // Fallback: metadata'dan al
      if (mounted) {
        setState(() {
          _fullName = user.userMetadata?['full_name'] ?? '';
          _userType = user.userMetadata?['user_type'] ?? 'ogrenci';
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOrganizator = _userType == 'organizator';
    final userTypeLabel = isOrganizator ? '🎯 Organizatör' : '🎓 Öğrenci';
    final badgeColor = isOrganizator
        ? const Color(0xFFF59E0B).withAlpha(38)
        : const Color(0xFF3B82F6).withAlpha(38);
    final badgeBorder = isOrganizator
        ? const Color(0xFFF59E0B).withAlpha(76)
        : const Color(0xFF3B82F6).withAlpha(76);
    final badgeTextColor = isOrganizator
        ? const Color(0xFFFCD34D)
        : const Color(0xFF93C5FD);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0f0c29),
              Color(0xFF302b63),
              Color(0xFF24243e),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(10),
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withAlpha(20)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Uni',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7c6cf0),
                            ),
                          ),
                          TextSpan(
                            text: 'Harita',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Çıkış'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFCA5A5),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.red.withAlpha(76)),
                        ),
                        backgroundColor: Colors.red.withAlpha(38),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Center(
                  child: _loading
                      ? const CircularProgressIndicator(color: Color(0xFF7c6cf0))
                      : Padding(
                          padding: const EdgeInsets.all(28),
                          child: Container(
                            padding: const EdgeInsets.all(36),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(18),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withAlpha(30)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(100),
                                  blurRadius: 32,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('👋', style: TextStyle(fontSize: 56)),
                                const SizedBox(height: 12),
                                const Text(
                                  'Hoş Geldiniz!',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                if (_fullName.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _fullName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withAlpha(204),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  _email,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withAlpha(153),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: badgeColor,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: badgeBorder),
                                  ),
                                  child: Text(
                                    userTypeLabel,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: badgeTextColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
