import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/drive_upload_service.dart';
import '../theme/sikawan_theme.dart';
import '../widgets/group_drawer.dart';

class GroupInfoPage extends StatefulWidget {
  final String groupId;
  const GroupInfoPage({super.key, required this.groupId});

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _picker = ImagePicker();

  bool _uploadingPhoto = false;

  Future<Map<String, String>> _fetchNames(List<String> uids) async {
    final Map<String, String> out = {};
    for (final uid in uids) {
      final snap = await _db.collection('users').doc(uid).get();
      final name = (snap.data()?['name'] ?? uid.substring(0, 6)) as String;
      out[uid] = name;
    }
    return out;
  }

  // =========================
  // EDIT GROUP NAME/DESC
  // =========================
  Future<void> _showEditGroupDialog({
    required String groupId,
    required String currentName,
    required String currentDesc,
  }) async {
    final nameC = TextEditingController(text: currentName);
    final descC = TextEditingController(text: currentDesc);
    bool saving = false;
    String? err;

    await showDialog(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> save() async {
              final messenger = ScaffoldMessenger.of(context); // ✅ simpan sebelum await
              final newName = nameC.text.trim();
              final newDesc = descC.text.trim();
              if (newName.isEmpty) {
                setLocal(() => err = 'Nama grup wajib diisi.');
                return;
              }

              setLocal(() {
                saving = true;
                err = null;
              });

              try {
                await _db.collection('groups').doc(groupId).set({
                  'name': newName,
                  'description': newDesc,
                }, SetOptions(merge: true));

                if (!mounted || !dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Info grup diperbarui.')),
                );
              } catch (e) {
                setLocal(() {
                  err = 'Gagal memperbarui grup: $e';
                  saving = false;
                });
              }
            }

            return AlertDialog(
              backgroundColor: SiKawanTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Edit Info Grup'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: nameC,
                      decoration: const InputDecoration(
                        labelText: 'Nama grup',
                        prefixIcon: Icon(Icons.groups_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descC,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Deskripsi singkat',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    if (err != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        err!,
                        style: const TextStyle(color: SiKawanTheme.error),
                      ),
                    ]
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
                          child: CircularProgressIndicator(strokeWidth: 2),
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

  // =========================
  // EDIT GROUP PHOTO (Drive)
  // =========================
  Future<void> _showEditPhotoSheet({
    required String groupId,
    required bool isAdmin,
  }) async {
    if (!isAdmin) return;

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
                      await _uploadGroupPhoto(groupId, img);
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
                      await _uploadGroupPhoto(groupId, img);
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

  Future<void> _uploadGroupPhoto(String groupId, XFile xfile) async {
    setState(() => _uploadingPhoto = true);
    final messenger = ScaffoldMessenger.of(context); // ✅ simpan sebelum await

    try {
      final Uint8List bytes = await xfile.readAsBytes();
      final String filename = xfile.name.isNotEmpty
          ? xfile.name
          : 'group_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final res = await DriveUploadService.uploadBytes(
        bytes: bytes,
        filename: filename,
        mimeType: _mimeFromName(filename),
        category: 'group_profile',
      );

      final directUrl = res['directUrl'] as String?;
      final fileId = res['fileId'] as String?;

      if (directUrl == null || fileId == null) {
        throw Exception('Invalid upload response');
      }

      await _db.collection('groups').doc(groupId).set({
        'photoUrl': directUrl,
        'photoFileId': fileId,
      }, SetOptions(merge: true));

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Foto grup diperbarui.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal memperbarui foto grup: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return 'application/octet-stream';
  }

  // =========================
  // MEMBER ACTIONS (ADMIN)
  // =========================
  Future<void> _showMemberActions({
    required Map<String, dynamic> groupData,
    required String targetUid,
    required String targetName,
  }) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    final admins = List<String>.from(groupData['admins'] ?? []);
    final isMeAdmin = admins.contains(myUid);
    final isTargetAdmin = admins.contains(targetUid);

    if (!isMeAdmin) return;

    final isSelf = targetUid == myUid;

    Future<void> promoteToAdmin() async {
      await _db.collection('groups').doc(widget.groupId).update({
        'admins': FieldValue.arrayUnion([targetUid]),
      });
    }

    Future<void> demoteToMember() async {
      if (isSelf) return;

      final messenger = ScaffoldMessenger.of(context); // ✅ simpan sebelum await

      final currentAdmins = List<String>.from(
        (await _db.collection('groups').doc(widget.groupId).get())
                .data()?['admins'] ??
            [],
      );

      if (currentAdmins.length <= 1 && currentAdmins.contains(targetUid)) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Tidak bisa menurunkan admin terakhir.')),
        );
        return;
      }

      await _db.collection('groups').doc(widget.groupId).update({
        'admins': FieldValue.arrayRemove([targetUid]),
      });
    }

    Future<void> removeMember() async {
      if (isSelf) return;
      await _db.collection('groups').doc(widget.groupId).update({
        'members': FieldValue.arrayRemove([targetUid]),
        'admins': FieldValue.arrayRemove([targetUid]),
        'memberCount': FieldValue.increment(-1),
      });
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: SiKawanTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 50,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: SiKawanTheme.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(targetName),
                  subtitle: Text(isTargetAdmin ? 'Admin' : 'Anggota'),
                ),
                const Divider(height: 1),
                if (!isTargetAdmin)
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: const Text('Jadikan Admin'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await promoteToAdmin();
                    },
                  ),
                if (isTargetAdmin && !isSelf)
                  ListTile(
                    leading: const Icon(Icons.person_remove_alt_1_outlined),
                    title: const Text('Jadikan Anggota'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await demoteToMember();
                    },
                  ),
                if (!isSelf)
                  ListTile(
                    leading: const Icon(Icons.remove_circle_outline,
                        color: SiKawanTheme.error),
                    title: const Text('Keluarkan Anggota'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await removeMember();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _auth.currentUser?.uid;

    return Scaffold(
      drawer: GroupDrawer(groupId: widget.groupId, current: 'info'),
      appBar: AppBar(
        title: const Text('Info Grup'),
        centerTitle: true,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _db.collection('groups').doc(widget.groupId).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snap.data!.data() ?? {};
            final name = (data['name'] ?? '-') as String;
            final desc = (data['description'] ?? '') as String;
            final code = (data['code'] ?? widget.groupId) as String;
            final photoUrl = (data['photoUrl'] ?? '') as String;

            final members = List<String>.from(data['members'] ?? []);
            final admins = List<String>.from(data['admins'] ?? []);
            final isMeAdmin = myUid != null && admins.contains(myUid);

            return FutureBuilder<Map<String, String>>(
              future: _fetchNames(members),
              builder: (context, nameSnap) {
                final namesMap = nameSnap.data ?? {};

                List<String> adminList = admins.toList()
                  ..sort((a, b) =>
                      (namesMap[a] ?? a).toLowerCase().compareTo(
                            (namesMap[b] ?? b).toLowerCase(),
                          ));

                List<String> memberOnly = members
                    .where((m) => !admins.contains(m))
                    .toList()
                  ..sort((a, b) =>
                      (namesMap[a] ?? a).toLowerCase().compareTo(
                            (namesMap[b] ?? b).toLowerCase(),
                          ));

                final t = Theme.of(context).textTheme;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
                  children: [
                    // =================
                    // GROUP HEADER
                    // =================
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 34,
                              backgroundColor: SiKawanTheme.border,
                              backgroundImage: photoUrl.isNotEmpty
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: photoUrl.isEmpty
                                  ? Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : 'G',
                                      style: t.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: SiKawanTheme.textPrimary,
                                      ),
                                    )
                                  : null,
                            ),
                            if (isMeAdmin)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: _uploadingPhoto
                                      ? null
                                      : () => _showEditPhotoSheet(
                                            groupId: widget.groupId,
                                            isAdmin: isMeAdmin,
                                          ),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: SiKawanTheme.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.12),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        )
                                      ],
                                    ),
                                    child: _uploadingPhoto
                                        ? const SizedBox(
                                            height: 14,
                                            width: 14,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Icon(Icons.edit_outlined,
                                            size: 14),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: t.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (desc.isNotEmpty)
                                Text(
                                  desc,
                                  style: t.bodySmall?.copyWith(
                                    color: SiKawanTheme.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isMeAdmin)
                          IconButton(
                            tooltip: 'Edit info grup',
                            icon: const Icon(Icons.edit_rounded),
                            onPressed: () => _showEditGroupDialog(
                              groupId: widget.groupId,
                              currentName: name,
                              currentDesc: desc,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // =================
                    // CARD KODE GRUP
                    // =================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: SiKawanTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: SiKawanTheme.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: SiKawanTheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.key_rounded,
                              color: SiKawanTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kode/ID Grup',
                                  style: t.bodySmall?.copyWith(
                                    color: SiKawanTheme.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  code,
                                  style: t.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Salin kode',
                            icon: const Icon(Icons.copy_rounded),
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context); // ✅ simpan sebelum await
                              await Clipboard.setData(
                                ClipboardData(text: code),
                              );
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Kode grup disalin.')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    Text(
                      'Admin',
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),

                    ...adminList.map((uid) {
                      final uname = namesMap[uid] ?? uid.substring(0, 6);
                      return _MemberTile(
                        name: uname,
                        isAdmin: true,
                        isMe: uid == myUid,
                        onTap: isMeAdmin
                            ? () => _showMemberActions(
                                  groupData: data,
                                  targetUid: uid,
                                  targetName: uname,
                                )
                            : null,
                      );
                    }),

                    const SizedBox(height: 14),
                    Text(
                      'Anggota',
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),

                    ...memberOnly.map((uid) {
                      final uname = namesMap[uid] ?? uid.substring(0, 6);
                      return _MemberTile(
                        name: uname,
                        isAdmin: false,
                        isMe: uid == myUid,
                        onTap: isMeAdmin
                            ? () => _showMemberActions(
                                  groupData: data,
                                  targetUid: uid,
                                  targetName: uname,
                                )
                            : null,
                      );
                    }),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final String name;
  final bool isAdmin;
  final bool isMe;
  final VoidCallback? onTap;

  const _MemberTile({
    required this.name,
    required this.isAdmin,
    required this.isMe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: SiKawanTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SiKawanTheme.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: SiKawanTheme.border,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: t.bodySmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isMe ? '$name (Saya)' : name,
                style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (isAdmin)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: SiKawanTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Admin',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: SiKawanTheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
