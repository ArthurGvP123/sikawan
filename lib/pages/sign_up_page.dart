import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/sikawan_theme.dart';
import '../widgets/fade_slide.dart';
// import 'home_page.dart';
import 'root_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _nameC = TextEditingController();
  final _institutionC = TextEditingController();
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  late final AnimationController _ctrl;
  late final Animation<double> aIntro;
  late final Animation<double> aCard;
  late final Animation<double> aName;
  late final Animation<double> aInst;
  late final Animation<double> aEmail;
  late final Animation<double> aPass;
  late final Animation<double> aBtn;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    aIntro = CurvedAnimation(parent: _ctrl, curve: const Interval(0.00, 0.30));
    aCard = CurvedAnimation(parent: _ctrl, curve: const Interval(0.15, 0.55));
    aName = CurvedAnimation(parent: _ctrl, curve: const Interval(0.30, 0.62));
    aInst = CurvedAnimation(parent: _ctrl, curve: const Interval(0.40, 0.72));
    aEmail =
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.50, 0.82));
    aPass =
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.60, 0.90));
    aBtn = CurvedAnimation(parent: _ctrl, curve: const Interval(0.70, 1.00));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _nameC.dispose();
    _institutionC.dispose();
    _emailC.dispose();
    _passwordC.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailC.text.trim(),
        password: _passwordC.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set({
        'name': _nameC.text.trim(),
        'institution': _institutionC.text.trim(),
        'email': _emailC.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RootPage()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      String m = 'Terjadi kesalahan saat mendaftar.';
      if (e.code == 'email-already-in-use') m = 'Email sudah terdaftar.';
      if (e.code == 'weak-password') m = 'Kata sandi terlalu lemah.';
      setState(() => _errorMessage = m);
    } catch (_) {
      setState(() => _errorMessage = 'Terjadi kesalahan tak terduga.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Akun SiKawan')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeSlide(
                    animation: aIntro,
                    beginOffset: const Offset(0, 0.08),
                    child: Text(
                      'Lengkapi data Anda untuk bergabung dengan KKG di SiKawan.',
                      style: t.bodyMedium
                          ?.copyWith(color: SiKawanTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 16),

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
                        padding: const EdgeInsets.all(20),
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
                                    child: const Icon(
                                      Icons.person_add_alt_1_outlined,
                                      size: 18,
                                      color: SiKawanTheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('Data akun', style: t.titleMedium),
                                ],
                              ),
                              const SizedBox(height: 16),

                              FadeSlide(
                                animation: aName,
                                child: TextFormField(
                                  controller: _nameC,
                                  decoration: const InputDecoration(
                                    labelText: 'Nama lengkap',
                                    hintText: 'Misal: Bapak/Ibu Guru...',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Nama tidak boleh kosong.'
                                          : null,
                                ),
                              ),
                              const SizedBox(height: 12),

                              FadeSlide(
                                animation: aInst,
                                child: TextFormField(
                                  controller: _institutionC,
                                  decoration: const InputDecoration(
                                    labelText: 'Asal institusi',
                                    hintText:
                                        'Misal: SDN 1 Semarang / KKG Kecamatan ...',
                                    prefixIcon:
                                        Icon(Icons.apartment_outlined),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Asal institusi tidak boleh kosong.'
                                          : null,
                                ),
                              ),
                              const SizedBox(height: 12),

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
                                animation: aBtn,
                                beginOffset: const Offset(0, 0.06),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _signUp,
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
                                      : const Text('Daftar'),
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
