import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/drive_upload_service.dart';
import '../theme/sikawan_theme.dart';
import '../widgets/app_drawer.dart';
import 'sign_in_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _picker = ImagePicker();

  bool _uploadingPhoto = false;

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInPage()),
      (_) => false,
    );
  }

  Future<void> _showEditPhotoSheet(String uid) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: SiKawanTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 48,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: SiKawanTheme.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Pilih dari galeri'),
                  onTap: () async {
                    Navigator.pop(context);
                    final img = await _picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                    );
                    if (img != null) {
                      await _uploadProfilePhoto(uid, img);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Ambil foto'),
                  onTap: () async {
                    Navigator.pop(context);
                    final img = await _picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 85,
                    );
                    if (img != null) {
                      await _uploadProfilePhoto(uid, img);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _uploadProfilePhoto(String uid, XFile xfile) async {
    setState(() => _uploadingPhoto = true);

    try {
      final Uint8List bytes = await xfile.readAsBytes();
      final String filename = xfile.name.isNotEmpty
          ? xfile.name
          : 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final res = await DriveUploadService.uploadBytes(
        bytes: bytes,
        filename: filename,
        mimeType: _mimeFromName(filename),
        category: 'user_profile',
      );

      final directUrl = res['directUrl'] as String?;
      final fileId = res['fileId'] as String?;

      if (directUrl == null || fileId == null) {
        throw Exception('Invalid upload response');
      }

      await _db.collection('users').doc(uid).set({
        'photoUrl': directUrl,
        'photoFileId': fileId,
      }, SetOptions(merge: true));

      await _auth.currentUser?.updatePhotoURL(directUrl);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto profil diperbarui.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui foto: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'application/octet-stream';
  }

  Future<void> _showEditPersonalDialog({
    required String uid,
    required String email,
    required String name,
    required String institution,
  }) async {
    final nameC = TextEditingController(text: name);
    final instC = TextEditingController(text: institution);
    final currentPassC = TextEditingController();
    final newPassC = TextEditingController();
    final confirmPassC = TextEditingController();

    bool saving = false;
    String? errorText;

    await showDialog(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> save() async {
              setLocal(() {
                saving = true;
                errorText = null;
              });

              try {
                final newName = nameC.text.trim();
                final newInst = instC.text.trim();
                final newPass = newPassC.text.trim();
                final confirmPass = confirmPassC.text.trim();
                final currentPass = currentPassC.text.trim();

                await _db.collection('users').doc(uid).set({
                  'name': newName,
                  'institution': newInst,
                }, SetOptions(merge: true));

                await _auth.currentUser?.updateDisplayName(newName);

                if (newPass.isNotEmpty || confirmPass.isNotEmpty) {
                  if (newPass.length < 6) {
                    throw 'Password baru minimal 6 karakter.';
                  }
                  if (newPass != confirmPass) {
                    throw 'Konfirmasi password tidak cocok.';
                  }
                  if (currentPass.isEmpty) {
                    throw 'Masukkan password saat ini untuk mengganti password.';
                  }

                  final cred = EmailAuthProvider.credential(
                    email: email,
                    password: currentPass,
                  );

                  await _auth.currentUser?.reauthenticateWithCredential(cred);
                  await _auth.currentUser?.updatePassword(newPass);
                }

                if (!mounted) return;
                Navigator.of(context, rootNavigator: true).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profil berhasil diperbarui.')),
                );
              } on FirebaseAuthException catch (e) {
                String msg = 'Gagal memperbarui profil.';
                if (e.code == 'wrong-password') msg = 'Password saat ini salah.';
                if (e.code == 'requires-recent-login') {
                  msg = 'Silakan login ulang lalu coba ganti password.';
                }
                setLocal(() {
                  errorText = msg;
                  saving = false;
                });
              } catch (e) {
                setLocal(() {
                  errorText = e.toString();
                  saving = false;
                });
              }
            }

            return AlertDialog(
              backgroundColor: SiKawanTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Edit Personal Info'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: nameC,
                      decoration: const InputDecoration(
                        labelText: 'Nama lengkap',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: instC,
                      decoration: const InputDecoration(
                        labelText: 'Asal institusi',
                        prefixIcon: Icon(Icons.apartment_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: TextEditingController(text: email),
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Email (tidak bisa diubah)',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ganti password (opsional)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: currentPassC,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password saat ini',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: newPassC,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password baru',
                        prefixIcon: Icon(Icons.lock_reset_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: confirmPassC,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Konfirmasi password baru',
                        prefixIcon: Icon(Icons.lock_reset_outlined),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: const TextStyle(color: SiKawanTheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : save,
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const SignInPage();

    return Scaffold(
      // ✅ Drawer versi umum
      drawer: const AppDrawer(current: 'profile'),
      appBar: AppBar(
        title: const Text('Profil'),
        centerTitle: true,
        // ✅ tombol menu untuk buka drawer
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _db.collection('users').doc(user.uid).snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data() ?? {};
            final name =
                (data['name'] ?? user.displayName ?? 'Pengguna') as String;
            final institution = (data['institution'] ?? '-') as String;
            final email = user.email ?? '-';
            final photoUrl = (data['photoUrl'] ?? user.photoURL) as String?;

            return LayoutBuilder(
              builder: (context, constraints) {
                final screenW = MediaQuery.of(context).size.width;
                final effectiveW = math.min(screenW, 520.0);
                final scale = (effectiveW / 390.0).clamp(0.85, 1.25);

                final t = Theme.of(context).textTheme;

                final avatarRadius = 58.0 * scale;
                final editPad = 10.0 * scale;
                final editIconSize = (18.0 * scale).clamp(16.0, 22.0);

                final cardHPad = 16.0 * scale;
                final cardVPadTop = 14.0 * scale;
                final cardVPadBottom = 10.0 * scale;
                final gapAfterAvatar = 12.0 * scale;
                final gapAfterCard = 18.0 * scale;

                final infoIconSize = (20.0 * scale).clamp(18.0, 24.0);
                final infoVPad = 8.0 * scale;

                final buttonHeight = (48.0 * scale).clamp(44.0, 58.0);

                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      16 * scale,
                      0,
                      16 * scale,
                      24 * scale,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: avatarRadius,
                                backgroundColor: SiKawanTheme.border,
                                backgroundImage:
                                    (photoUrl != null && photoUrl.isNotEmpty)
                                        ? NetworkImage(photoUrl)
                                        : null,
                                child: (photoUrl == null || photoUrl.isEmpty)
                                    ? Text(
                                        _initials(name),
                                        style: t.headlineLarge?.copyWith(
                                          fontSize:
                                              (t.headlineLarge?.fontSize ?? 32) *
                                                  scale,
                                          color: SiKawanTheme.textPrimary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: 4 * scale,
                                bottom: 4 * scale,
                                child: GestureDetector(
                                  onTap: _uploadingPhoto
                                      ? null
                                      : () => _showEditPhotoSheet(user.uid),
                                  child: Container(
                                    padding: EdgeInsets.all(editPad),
                                    decoration: BoxDecoration(
                                      color: SiKawanTheme.surface,
                                      borderRadius:
                                          BorderRadius.circular(12 * scale),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.12),
                                          blurRadius: 8 * scale,
                                          offset: Offset(0, 4 * scale),
                                        ),
                                      ],
                                    ),
                                    child: _uploadingPhoto
                                        ? SizedBox(
                                            height: 18 * scale,
                                            width: 18 * scale,
                                            child:
                                                const CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Icon(Icons.edit_outlined,
                                            size: editIconSize),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: gapAfterAvatar),

                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.fromLTRB(
                              cardHPad,
                              cardVPadTop,
                              cardHPad,
                              cardVPadBottom,
                            ),
                            decoration: BoxDecoration(
                              color: SiKawanTheme.surface,
                              borderRadius:
                                  BorderRadius.circular(16 * scale),
                              border: Border.all(color: SiKawanTheme.border),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12 * scale,
                                  offset: Offset(0, 6 * scale),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Informasi Personal',
                                      style: t.titleMedium?.copyWith(
                                        fontSize:
                                            (t.titleMedium?.fontSize ?? 16) *
                                                scale,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () =>
                                          _showEditPersonalDialog(
                                        uid: user.uid,
                                        email: email,
                                        name: name,
                                        institution: institution,
                                      ),
                                      child: Text(
                                        'Edit',
                                        style: TextStyle(fontSize: 14 * scale),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4 * scale),
                                _InfoRow(
                                  icon: Icons.person_outline,
                                  label: 'Nama',
                                  value: name,
                                  iconSize: infoIconSize,
                                  verticalPad: infoVPad,
                                ),
                                _InfoRow(
                                  icon: Icons.email_outlined,
                                  label: 'E-mail',
                                  value: email,
                                  iconSize: infoIconSize,
                                  verticalPad: infoVPad,
                                ),
                                _InfoRow(
                                  icon: Icons.apartment_outlined,
                                  label: 'Asal institusi',
                                  value: institution,
                                  iconSize: infoIconSize,
                                  verticalPad: infoVPad,
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: gapAfterCard),

                          SizedBox(
                            width: double.infinity,
                            height: buttonHeight,
                            child: OutlinedButton.icon(
                              onPressed: _signOut,
                              icon: Icon(Icons.logout_rounded,
                                  size: 20 * scale),
                              label: Text(
                                'Keluar',
                                style: TextStyle(
                                  fontSize: 15 * scale,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: SiKawanTheme.error,
                                side: const BorderSide(
                                  color: SiKawanTheme.error,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12 * scale),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final double iconSize;
  final double verticalPad;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconSize = 20,
    this.verticalPad = 8,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: iconSize, color: SiKawanTheme.textSecondary),
          SizedBox(width: 12 * (iconSize / 20)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: t.bodySmall?.copyWith(
                    color: SiKawanTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: t.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: SiKawanTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
