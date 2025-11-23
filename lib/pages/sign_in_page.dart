import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/sikawan_theme.dart';
import '../widgets/fade_slide.dart';
import 'sign_up_page.dart';
// import 'home_page.dart';
import 'root_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  late final AnimationController _ctrl;

  late final Animation<double> aHeader;
  late final Animation<double> aSubtitle;
  late final Animation<double> aCard;
  late final Animation<double> aEmail;
  late final Animation<double> aPass;
  late final Animation<double> aButton;
  late final Animation<double> aFooter;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    aHeader = CurvedAnimation(parent: _ctrl, curve: const Interval(0.00, 0.35));
    aSubtitle =
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.10, 0.45));
    aCard = CurvedAnimation(parent: _ctrl, curve: const Interval(0.20, 0.60));
    aEmail = CurvedAnimation(parent: _ctrl, curve: const Interval(0.35, 0.70));
    aPass = CurvedAnimation(parent: _ctrl, curve: const Interval(0.45, 0.80));
    aButton =
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.55, 0.95));
    aFooter =
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.65, 1.00));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _emailC.dispose();
    _passwordC.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailC.text.trim(),
        password: _passwordC.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RootPage()),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Terjadi kesalahan saat masuk.';
      if (e.code == 'user-not-found') {
        message = 'Akun tidak ditemukan.';
      } else if (e.code == 'wrong-password') {
        message = 'Kata sandi salah.';
      }
      setState(() => _errorMessage = message);
    } catch (_) {
      setState(() => _errorMessage = 'Terjadi kesalahan tak terduga.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToSignUp() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignUpPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeSlide(
                    animation: aHeader,
                    beginOffset: const Offset(0, 0.12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selamat datang di',
                          style: t.bodyMedium?.copyWith(
                            color: SiKawanTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('SiKawan', style: t.headlineLarge),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: SiKawanTheme.primarySoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.school_outlined,
                                      size: 16, color: SiKawanTheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'LMS KKG!',
                                    style: t.bodySmall?.copyWith(
                                      color: SiKawanTheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  FadeSlide(
                    animation: aSubtitle,
                    beginOffset: const Offset(0, 0.08),
                    child: Text(
                      'Sistem Kegiatan dan Wawasan untuk Kelompok Kerja Guru.',
                      style: t.bodyMedium,
                    ),
                  ),

                  const SizedBox(height: 24),

                  FadeSlide(
                    animation: aCard,
                    beginOffset: const Offset(0, 0.10),
                    child: Card(
                      color: SiKawanTheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: SiKawanTheme.border),
                      ),
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    height: 32,
                                    width: 32,
                                    decoration: BoxDecoration(
                                      color: SiKawanTheme.primarySoft,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.login_rounded,
                                        size: 18,
                                        color: SiKawanTheme.primary),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('Masuk ke akun Anda',
                                      style: t.titleMedium),
                                ],
                              ),
                              const SizedBox(height: 16),

                              FadeSlide(
                                animation: aEmail,
                                child: TextFormField(
                                  controller: _emailC,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    hintText: 'nama@sekolah.sch.id',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Email tidak boleh kosong.';
                                    }
                                    if (!v.contains('@')) {
                                      return 'Format email tidak valid.';
                                    }
                                    return null;
                                  },
                                ),
                              ),

                              const SizedBox(height: 12),

                              FadeSlide(
                                animation: aPass,
                                child: TextFormField(
                                  controller: _passwordC,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Kata sandi',
                                    prefixIcon: Icon(Icons.lock_outline),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Kata sandi tidak boleh kosong.';
                                    }
                                    if (v.trim().length < 6) {
                                      return 'Kata sandi minimal 6 karakter.';
                                    }
                                    return null;
                                  },
                                ),
                              ),

                              const SizedBox(height: 8),

                              if (_errorMessage != null) ...[
                                Text(
                                  _errorMessage!,
                                  style: t.bodySmall
                                      ?.copyWith(color: SiKawanTheme.error),
                                ),
                                const SizedBox(height: 8),
                              ],

                              const SizedBox(height: 8),

                              FadeSlide(
                                animation: aButton,
                                beginOffset: const Offset(0, 0.06),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _signIn,
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation(
                                                    Colors.white),
                                          ),
                                        )
                                      : const Text('Masuk'),
                                ),
                              ),

                              const SizedBox(height: 12),

                              FadeSlide(
                                animation: aFooter,
                                beginOffset: const Offset(0, 0.04),
                                child: Center(
                                  child: TextButton(
                                    onPressed:
                                        _isLoading ? null : _goToSignUp,
                                    child: const Text(
                                      'Belum punya akun? Daftar',
                                      style: TextStyle(
                                        color: SiKawanTheme.primary,
                                      ),
                                    ),
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
        ),
      ),
    );
  }
}
