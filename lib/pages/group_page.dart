import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/sikawan_theme.dart';
import '../widgets/app_drawer.dart';
import 'group_detail_page.dart';

class GroupPage extends StatefulWidget {
  const GroupPage({super.key});

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final _searchC = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchC.addListener(() {
      setState(() => _search = _searchC.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<String> _generateUniqueCode() async {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final rnd = Random.secure();

    for (int attempt = 0; attempt < 10; attempt++) {
      final code = List.generate(
        8,
        (_) => letters[rnd.nextInt(letters.length)],
      ).join();

      final q = await _db
          .collection('groups')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (q.docs.isEmpty) return code;
    }

    return DateTime.now()
        .millisecondsSinceEpoch
        .toRadixString(36)
        .toUpperCase()
        .padLeft(8, 'A')
        .substring(0, 8);
  }

  // =========================
  //  POPUP: Create Group
  // =========================
  Future<void> _showCreateGroupDialog() async {
    final nameC = TextEditingController();
    final descC = TextEditingController();
    bool creating = false;
    String? err;

    await showDialog(
      context: context,
      barrierDismissible: !creating,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> create() async {
              final uid = _auth.currentUser?.uid;
              if (uid == null) return;

              final name = nameC.text.trim();
              final desc = descC.text.trim();

              if (name.isEmpty) {
                setLocal(() => err = 'Nama grup wajib diisi.');
                return;
              }

              setLocal(() {
                creating = true;
                err = null;
              });

              try {
                final code = await _generateUniqueCode();
                final docRef = _db.collection('groups').doc();

                await docRef.set({
                  'name': name,
                  'description': desc,
                  'code': code,
                  'ownerUid': uid,

                  // ✅ ROLES
                  'admins': [uid],
                  'members': [uid],
                  'memberCount': 1,

                  // photoUrl akan diisi lewat halaman Info Grup
                  'photoUrl': '',
                  'photoFileId': '',

                  'createdAt': FieldValue.serverTimestamp(),
                  'createdAtMs': DateTime.now().millisecondsSinceEpoch,
                });

                if (!mounted) return;
                Navigator.of(context, rootNavigator: true).pop();

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GroupDetailPage(groupId: docRef.id),
                  ),
                );
              } catch (e) {
                setLocal(() {
                  err = 'Gagal membuat grup: $e';
                  creating = false;
                });
              }
            }

            return AlertDialog(
              backgroundColor: SiKawanTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Buat Grup Baru'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameC,
                    decoration: const InputDecoration(
                      labelText: 'Nama Grup',
                      prefixIcon: Icon(Icons.groups_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descC,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi Singkat',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      err!,
                      style: const TextStyle(color: SiKawanTheme.error),
                    ),
                  ]
                ],
              ),
              actions: [
                TextButton(
                  onPressed: creating ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: creating ? null : create,
                  child: creating
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Buat'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================
  //  POPUP: Join Group
  // =========================
  Future<void> _showJoinGroupDialog() async {
    final codeC = TextEditingController();
    bool joining = false;
    String? err;

    await showDialog(
      context: context,
      barrierDismissible: !joining,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> join() async {
              final uid = _auth.currentUser?.uid;
              if (uid == null) return;

              final code = codeC.text.trim().toUpperCase();
              if (code.length != 8) {
                setLocal(() => err = 'Kode grup harus 8 huruf.');
                return;
              }

              setLocal(() {
                joining = true;
                err = null;
              });

              try {
                final q = await _db
                    .collection('groups')
                    .where('code', isEqualTo: code)
                    .limit(1)
                    .get();

                if (q.docs.isEmpty) {
                  setLocal(() {
                    err = 'Grup tidak ditemukan.';
                    joining = false;
                  });
                  return;
                }

                final doc = q.docs.first;
                final groupId = doc.id;

                await _db.runTransaction((tx) async {
                  final snap = await tx.get(doc.reference);
                  if (!snap.exists) return;

                  final data = snap.data() as Map<String, dynamic>;
                  final members = List<String>.from(data['members'] ?? []);

                  if (!members.contains(uid)) {
                    members.add(uid);
                    tx.update(doc.reference, {
                      'members': members,
                      'memberCount': members.length,
                    });
                  }
                });

                if (!mounted) return;
                Navigator.of(context, rootNavigator: true).pop();

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GroupDetailPage(groupId: groupId),
                  ),
                );
              } catch (e) {
                setLocal(() {
                  err = 'Gagal join grup: $e';
                  joining = false;
                });
              }
            }

            return AlertDialog(
              backgroundColor: SiKawanTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Masuk Grup'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeC,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 8,
                    decoration: const InputDecoration(
                      labelText: 'Kode Grup (8 Huruf)',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                      counterText: '',
                    ),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      err!,
                      style: const TextStyle(color: SiKawanTheme.error),
                    ),
                  ]
                ],
              ),
              actions: [
                TextButton(
                  onPressed: joining ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: joining ? null : join,
                  child: joining
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Masuk'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================
  //  Leave Group (NEW RULES)
  // =========================
  Future<void> _confirmLeaveGroup(String groupId, String groupName) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SiKawanTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar dari Grup?'),
        content: Text('Kamu akan keluar dari "$groupName".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SiKawanTheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final ref = _db.collection('groups').doc(groupId);

      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;

        final data = snap.data() as Map<String, dynamic>;
        final members = List<String>.from(data['members'] ?? []);
        final admins = List<String>.from(data['admins'] ?? []);

        if (!members.contains(uid)) return;

        final wasAdmin = admins.contains(uid);

        members.remove(uid);
        admins.remove(uid);

        if (members.isEmpty) {
          tx.delete(ref);
          return;
        }

        if (wasAdmin && admins.isEmpty) {
          final rnd = Random();
          final newAdmin = members[rnd.nextInt(members.length)];
          admins.add(newAdmin);
        }

        tx.update(ref, {
          'members': members,
          'admins': admins,
          'memberCount': members.length,
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berhasil keluar dari grup.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal keluar grup: $e')),
      );
    }
  }

  // =========================
  //  UI
  // =========================
  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    final t = Theme.of(context).textTheme;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Tidak ada user login')),
      );
    }

    return Scaffold(
      // ✅ Drawer versi umum
      drawer: const AppDrawer(current: 'groups'),
      appBar: AppBar(
        title: const Text('Kelola Grup'),
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showCreateGroupDialog,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Buat Grup'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showJoinGroupDialog,
                      icon: const Icon(Icons.vpn_key_outlined),
                      label: const Text('Masuk Grup'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _searchC,
                decoration: InputDecoration(
                  hintText: 'Cari grup...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => _searchC.clear(),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _db
                      .collection('groups')
                      .where('members', arrayContains: uid)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Terjadi error query grup.',
                          style:
                              t.bodyMedium?.copyWith(color: SiKawanTheme.error),
                        ),
                      );
                    }

                    final docs = snap.data?.docs ?? [];

                    docs.sort((a, b) {
                      final ams = (a.data()['createdAtMs'] ?? 0) as int;
                      final bms = (b.data()['createdAtMs'] ?? 0) as int;
                      return bms.compareTo(ams);
                    });

                    final filtered = docs.where((d) {
                      final name = (d.data()['name'] ?? '') as String;
                      return name.toLowerCase().contains(_search);
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          _search.isEmpty
                              ? 'Belum ada grup yang diikuti.'
                              : 'Grup tidak ditemukan.',
                          style: t.bodyMedium?.copyWith(
                            color: SiKawanTheme.textSecondary,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final doc = filtered[i];
                        final data = doc.data();

                        final name = (data['name'] ?? '-') as String;
                        final desc = (data['description'] ?? '') as String;
                        final count = (data['memberCount'] ?? 0).toString();
                        final photoUrl = (data['photoUrl'] ?? '') as String;

                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    GroupDetailPage(groupId: doc.id),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: SiKawanTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: SiKawanTheme.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 6),
                                )
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _GroupAvatar(name: name, photoUrl: photoUrl),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: t.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if (desc.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          desc,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: t.bodySmall?.copyWith(
                                            color: SiKawanTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.people_outline,
                                            size: 16,
                                            color: SiKawanTheme.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$count anggota',
                                            style: t.bodySmall?.copyWith(
                                              color: SiKawanTheme.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Keluar grup',
                                  onPressed: () =>
                                      _confirmLeaveGroup(doc.id, name),
                                  icon: const Icon(
                                    Icons.exit_to_app_rounded,
                                    color: SiKawanTheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupAvatar extends StatelessWidget {
  final String name;
  final String photoUrl;

  const _GroupAvatar({
    required this.name,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'G';

    if (photoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          width: 48,
          color: SiKawanTheme.border,
          child: Image.network(
            photoUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(initial, t),
          ),
        ),
      );
    }

    return _fallback(initial, t);
  }

  Widget _fallback(String initial, TextTheme t) {
    return Container(
      height: 48,
      width: 48,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SiKawanTheme.primary, SiKawanTheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          initial,
          style: t.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
