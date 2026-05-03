import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _userType = 'ogrenci';
  bool _loading = false;
  bool _obscure = true;
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  final _types = [
    {'value': 'ogrenci', 'label': '🎓 Öğrenci'},
    {'value': 'organizator', 'label': '🎯 Organizatör'},
  ];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        data: {
          'full_name': _nameCtrl.text.trim(),
          'user_type': _userType,
        },
      );
      if (!mounted) return;
      if (res.session != null) {
        // Navigation is now handled by AuthWrapper
      } else {
        _snack('Kayıt başarılı! E-postanızı doğruladıktan sonra giriş yapabilirsiniz.', false);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (r) => false,
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      _snack(e.message, true);
    } catch (_) {
      if (!mounted) return;
      _snack('Beklenmeyen bir hata oluştu.', true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, bool err) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(err ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: err ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0f0c29), Color(0xFF302b63), Color(0xFF24243e)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Column(
                    children: [
                      // Logo
                      Container(
                        width: 78, height: 78,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF7c6cf0), Color(0xFFa78bfa)]),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [BoxShadow(color: const Color(0xFF7c6cf0).withAlpha(90), blurRadius: 24, offset: const Offset(0, 8))],
                        ),
                        child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 36),
                      ),
                      const SizedBox(height: 18),
                      RichText(text: const TextSpan(children: [
                        TextSpan(text: 'Uni', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Color(0xFF7c6cf0))),
                        TextSpan(text: 'Harita', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
                      ])),
                      const SizedBox(height: 6),
                      Text('Yeni hesap oluşturun', style: TextStyle(fontSize: 14, color: Colors.white.withAlpha(128))),
                      const SizedBox(height: 30),

                      // Card
                      Container(
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(14),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: Colors.white.withAlpha(25)),
                          boxShadow: [BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 36, offset: const Offset(0, 10))],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            // Ad Soyad
                            _label('Ad Soyad'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _nameCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                              decoration: _dec('Adınız Soyadınız', Icons.person_outline),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ad soyad gerekli' : null,
                            ),
                            const SizedBox(height: 18),

                            // E-posta
                            _label('E-posta'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                              decoration: _dec('ornek@universite.edu.tr', Icons.email_outlined),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'E-posta gerekli';
                                if (!v.contains('@')) return 'Geçerli bir e-posta girin';
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            // Şifre
                            _label('Şifre'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passCtrl,
                              obscureText: _obscure,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                              decoration: _dec('En az 6 karakter', Icons.lock_outline).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white.withAlpha(110), size: 20),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Şifre gerekli';
                                if (v.length < 6) return 'Şifre en az 6 karakter olmalı';
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            // Kullanıcı Tipi
                            _label('Kullanıcı Tipi'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _userType,
                              dropdownColor: const Color(0xFF1e1b4b),
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                              icon: Icon(Icons.keyboard_arrow_down, color: Colors.white.withAlpha(110)),
                              decoration: _dec('', Icons.badge_outlined).copyWith(hintText: null),
                              items: _types.map((t) => DropdownMenuItem<String>(
                                value: t['value'], child: Text(t['label']!),
                              )).toList(),
                              onChanged: (v) { if (v != null) setState(() => _userType = v); },
                            ),
                            const SizedBox(height: 26),

                            // Kayıt butonu
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7c6cf0),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: const Color(0xFF7c6cf0).withAlpha(110),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                                child: _loading
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                    : const Text('Kayıt Ol'),
                              ),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 26),

                      // Footer
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('Zaten hesabınız var mı? ', style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 14)),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Text('Giriş Yap', style: TextStyle(color: Color(0xFFa78bfa), fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                      ]),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withAlpha(180), letterSpacing: 0.3));

  InputDecoration _dec(String hint, IconData ico) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.white.withAlpha(55)),
    prefixIcon: Icon(ico, color: Colors.white.withAlpha(90), size: 20),
    filled: true,
    fillColor: Colors.white.withAlpha(12),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withAlpha(25))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withAlpha(25))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7c6cf0), width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEF4444))),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
  );
}
