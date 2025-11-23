import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/sikawan_theme.dart';
import '../widgets/app_drawer.dart';
import 'group_detail_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // ======== create/join popup reuse ========
  Future<String> _generateUniqueCode() async {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final rnd = Random.secure();

    for (int attempt = 0; attempt < 10; attempt++) {
      final code =
          List.generate(8, (_) => letters[rnd.nextInt(letters.length)]).join();

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

              final nav = Navigator.of(context);

              try {
                final code = await _generateUniqueCode();
                final docRef = _db.collection('groups').doc();

                await docRef.set({
                  'name': name,
                  'description': desc,
                  'code': code,
                  'ownerUid': uid,
                  'admins': [uid],
                  'members': [uid],
                  'memberCount': 1,
                  'photoUrl': '',
                  'photoFileId': '',
                  'createdAt': FieldValue.serverTimestamp(),
                  'createdAtMs': DateTime.now().millisecondsSinceEpoch,
                });

                if (!mounted) return;
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);

                nav.push(
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
                    Text(err!,
                        style: const TextStyle(color: SiKawanTheme.error)),
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

              final nav = Navigator.of(context);

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
                  final data = snap.data() as Map<String, dynamic>;

                  final members = List<String>.from(data['members'] ?? []);
                  if (!members.contains(uid)) members.add(uid);

                  tx.update(doc.reference, {
                    'members': members,
                    'memberCount': members.length,
                  });
                });

                if (!mounted) return;
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);

                nav.push(
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
                    Text(err!,
                        style: const TextStyle(color: SiKawanTheme.error)),
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

  void _showAddGroupSheet() {
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
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text('Buat Grup'),
                  onTap: () {
                    Navigator.pop(context);
                    _showCreateGroupDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.vpn_key_outlined),
                  title: const Text('Masuk Grup'),
                  onTap: () {
                    Navigator.pop(context);
                    _showJoinGroupDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ======================
  // Leave Group (NEW RULES)
  // ======================
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

  // ======================
  // UPCOMING ACTIVITIES
  // ======================
  Future<List<_UpcomingItem>> _fetchUpcoming(List<String> groupIds) async {
    final now = DateTime.now();
    final futures = groupIds.map((gid) async {
      final snap = await _db
          .collection('groups')
          .doc(gid)
          .collection('meetings')
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .orderBy('dateTime', descending: false)
          .limit(5)
          .get();

      return snap.docs.map((d) {
        final m = d.data();
        final ts = (m['dateTime'] as Timestamp).toDate();
        return _UpcomingItem(
          groupId: gid,
          meetingId: d.id,
          title: (m['title'] ?? 'Kegiatan') as String,
          desc: (m['description'] ?? '') as String,
          dateTime: ts,
          raw: m,
        );
      }).toList();
    });

    final lists = await Future.wait(futures);
    final all = lists.expand((e) => e).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return all.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final safeUser = _auth.currentUser;

    if (safeUser == null) {
      return const Scaffold(
        body: Center(child: Text('Tidak ada user login')),
      );
    }

    final uid = safeUser.uid;

    return Scaffold(
      drawer: const AppDrawer(current: 'home'),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Home'),
        centerTitle: true,
      ),

      floatingActionButton: Container(
        height: 58,
        width: 58,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [SiKawanTheme.primary, SiKawanTheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          heroTag: 'homeAddGroupFab',
          onPressed: _showAddGroupSheet,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),

      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _db.collection('users').doc(uid).snapshots(),
          builder: (context, userSnap) {
            final udata = userSnap.data?.data() ?? {};
            final fullName =
                (udata['name'] ?? safeUser.displayName ?? 'Pengguna') as String;
            final firstName = fullName.trim().split(RegExp(r'\s+')).first;
            final institution = (udata['institution'] ?? '-') as String;
            final photoUrl =
                (udata['photoUrl'] ?? safeUser.photoURL) as String?;

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db
                  .collection('groups')
                  .where('members', arrayContains: uid)
                  .snapshots(),
              builder: (context, groupSnap) {
                final groupDocs = groupSnap.data?.docs ?? [];
                final groupIds = groupDocs.map((d) => d.id).toList();

                groupDocs.sort((a, b) {
                  final ams = (a.data()['createdAtMs'] ?? 0) as int;
                  final bms = (b.data()['createdAtMs'] ?? 0) as int;
                  return bms.compareTo(ams);
                });

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ProfilePage(),
                              ),
                            );
                          },
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: SiKawanTheme.border,
                            backgroundImage:
                                (photoUrl != null && photoUrl.isNotEmpty)
                                    ? NetworkImage(photoUrl)
                                    : null,
                            child: (photoUrl == null || photoUrl.isEmpty)
                                ? Text(
                                    firstName.isNotEmpty
                                        ? firstName[0].toUpperCase()
                                        : 'U',
                                    style: t.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Halo, $firstName',
                                style: t.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                institution,
                                style: t.bodyMedium?.copyWith(
                                  color: SiKawanTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Text(
                      'Kegiatan Mendatang',
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (groupIds.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: SiKawanTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: SiKawanTheme.border),
                        ),
                        child: Text(
                          'Belum ada grup yang diikuti.',
                          style: t.bodyMedium?.copyWith(
                            color: SiKawanTheme.textSecondary,
                          ),
                        ),
                      )
                    else
                      FutureBuilder<List<_UpcomingItem>>(
                        future: _fetchUpcoming(groupIds),
                        builder: (context, upSnap) {
                          final items = upSnap.data ?? [];

                          if (upSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox(
                              height: 132,
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          if (items.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: SiKawanTheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: SiKawanTheme.border),
                              ),
                              child: Text(
                                'Belum ada kegiatan mendatang.',
                                style: t.bodyMedium?.copyWith(
                                  color: SiKawanTheme.textSecondary,
                                ),
                              ),
                            );
                          }

                          return SizedBox(
                            height: 132,
                            child: PageView.builder(
                              controller:
                                  PageController(viewportFraction: 0.88),
                              itemCount: items.length,
                              itemBuilder: (context, i) {
                                final a = items[i];
                                return _UpcomingCard(
                                  item: a,
                                  uid: uid,
                                  onTap: () {
                                    // ✅ TAP UPCOMING → BUKA HALAMAN GRUP
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            GroupDetailPage(groupId: a.groupId),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 18),

                    Text(
                      'Grup Anda',
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (groupDocs.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Text(
                            'Belum ada grup yang diikuti.',
                            style: t.bodyMedium?.copyWith(
                              color: SiKawanTheme.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      ...groupDocs.map((doc) {
                        final data = doc.data();
                        final name = (data['name'] ?? '-') as String;
                        final desc = (data['description'] ?? '') as String;
                        final count = (data['memberCount'] ?? 0).toString();
                        final gPhoto = (data['photoUrl'] ?? '') as String;

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
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: SiKawanTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: SiKawanTheme.border),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 6),
                                )
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _GroupAvatar(
                                  name: name,
                                  photoUrl: gPhoto,
                                ),
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
                                            color:
                                                SiKawanTheme.textSecondary,
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

// ======================
// GROUP AVATAR
// ======================
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

// ======================
// UPCOMING MODEL + CARD
// ======================
class _UpcomingItem {
  final String groupId;
  final String meetingId;
  final String title;
  final String desc;
  final DateTime dateTime;
  final Map<String, dynamic> raw;

  _UpcomingItem({
    required this.groupId,
    required this.meetingId,
    required this.title,
    required this.desc,
    required this.dateTime,
    required this.raw,
  });
}

class _UpcomingCard extends StatelessWidget {
  final _UpcomingItem item;
  final String uid;
  final VoidCallback onTap;

  const _UpcomingCard({
    required this.item,
    required this.uid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = item.dateTime;

    String status = 'Belum absen';
    final att = item.raw['attendance'] as Map<String, dynamic>?;
    if (att != null && att[uid] == true) status = 'Hadir';

    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SiKawanTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SiKawanTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${d.day}/${d.month}/${d.year} • $hh:$mm WIB',
              style: t.bodySmall?.copyWith(
                color: SiKawanTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (item.desc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.desc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall?.copyWith(
                  color: SiKawanTheme.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: SiKawanTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Absensi: $status',
                style: t.bodySmall?.copyWith(
                  color: SiKawanTheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
