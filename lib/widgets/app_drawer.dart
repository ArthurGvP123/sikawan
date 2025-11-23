import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../pages/group_detail_page.dart';
import '../pages/group_page.dart';
import '../pages/profile_page.dart';
import '../pages/root_page.dart';
import '../theme/sikawan_theme.dart';

class AppDrawer extends StatelessWidget {
  final String current; // "home" | "groups" | "profile" (profile key masih boleh dipakai walau menunya dihapus)

  const AppDrawer({
    super.key,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    Widget item({
      required String label,
      required IconData icon,
      required String keyName,
      required VoidCallback onTap,
      Widget? trailing,
    }) {
      final selected = keyName == current;

      return ListTile(
        leading: Icon(
          icon,
          color: selected ? SiKawanTheme.primary : SiKawanTheme.textSecondary,
        ),
        title: Text(
          label,
          style: t.bodyMedium?.copyWith(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected
                ? SiKawanTheme.textPrimary
                : SiKawanTheme.textSecondary,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      );
    }

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================
            // HEADER PROFIL (AKUN)
            // ==========================
            if (uid != null)
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data() ?? {};
                  final name = (data['name'] ?? 'Pengguna') as String;
                  final inst = (data['institution'] ?? '-') as String;
                  final photoUrl =
                      (data['photoUrl'] ??
                              FirebaseAuth.instance.currentUser?.photoURL)
                          as String?;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: SiKawanTheme.border,
                          backgroundImage:
                              (photoUrl != null && photoUrl.isNotEmpty)
                                  ? NetworkImage(photoUrl)
                                  : null,
                          child: (photoUrl == null || photoUrl.isEmpty)
                              ? Text(
                                  _initials(name),
                                  style: t.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: SiKawanTheme.textPrimary,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                inst,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodySmall?.copyWith(
                                  color: SiKawanTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Profil',
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RootPage()),
                              (_) => false,
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ProfilePage()),
                            );
                          },
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  );
                },
              ),

            const Divider(height: 1),

            // ==========================
            // MENU UTAMA (UMUM)
            // ✅ PROFIL DIHAPUS DARI MENU
            // ==========================
            item(
              label: 'Home',
              icon: Icons.home_rounded,
              keyName: 'home',
              onTap: () {
                Navigator.pop(context);
                if (current == 'home') return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const RootPage()),
                  (_) => false,
                );
              },
            ),

            const SizedBox(height: 6),

            // ==========================
            // HEADER GRUP + TOMBOL KELola KECIL
            // ==========================
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  Text(
                    'Grup Anda',
                    style: t.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: SiKawanTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const RootPage()),
                        (_) => false,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GroupPage()),
                      );
                    },
                    child: const Text('Kelola'),
                  ),
                ],
              ),
            ),

            // ==========================
            // LIST SHORTCUT GRUP (MAX 5)
            // ==========================
            Expanded(
              child: uid == null
                  ? const SizedBox()
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('groups')
                          .where('members', arrayContains: uid)
                          .snapshots(),
                      builder: (context, gSnap) {
                        final docs = gSnap.data?.docs ?? [];

                        docs.sort((a, b) {
                          final ams = (a.data()['createdAtMs'] ?? 0) as int;
                          final bms = (b.data()['createdAtMs'] ?? 0) as int;
                          return bms.compareTo(ams);
                        });

                        final top5 = docs.take(5).toList();

                        if (top5.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                'Belum ada grup.',
                                style: t.bodySmall?.copyWith(
                                  color: SiKawanTheme.textSecondary,
                                ),
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                          itemCount: top5.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, i) {
                            final doc = top5[i];
                            final d = doc.data();
                            final name = (d['name'] ?? '-') as String;
                            final photoUrl = (d['photoUrl'] ?? '') as String;

                            return _DrawerGroupShortcutTile(
                              name: name,
                              photoUrl: photoUrl,
                              selected: false,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        GroupDetailPage(groupId: doc.id),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),

            const SizedBox(height: 8),
          ],
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

// =========================
//  TILE GRUP di SIDEBAR
// =========================
class _DrawerGroupShortcutTile extends StatelessWidget {
  final String name;
  final String photoUrl;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerGroupShortcutTile({
    required this.name,
    required this.photoUrl,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'G';

    return Material(
      color: selected
          ? SiKawanTheme.primary.withValues(alpha: 0.10)
          : SiKawanTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SiKawanTheme.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 34,
                  width: 34,
                  color: SiKawanTheme.border,
                  child: photoUrl.isNotEmpty
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _fallbackAvatar(initial, t),
                        )
                      : _fallbackAvatar(initial, t),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? SiKawanTheme.textPrimary
                        : SiKawanTheme.textSecondary,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: SiKawanTheme.primary,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackAvatar(String initial, TextTheme t) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [SiKawanTheme.primary, SiKawanTheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: t.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
