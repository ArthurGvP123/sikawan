import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../pages/group_detail_page.dart';
import '../pages/group_finance_page.dart';
import '../pages/group_info_page.dart';
import '../pages/group_page.dart';
import '../pages/profile_page.dart';
import '../pages/root_page.dart';
import '../theme/sikawan_theme.dart';

class GroupDrawer extends StatelessWidget {
  final String groupId;
  final String current; // "info" | "kegiatan" | "keuangan"

  const GroupDrawer({
    super.key,
    required this.groupId,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('groups')
              .doc(groupId)
              .snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data() ?? {};
            final groupName = (data['name'] ?? 'Grup') as String;

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
                  color: selected
                      ? SiKawanTheme.primary
                      : SiKawanTheme.textSecondary,
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

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ====== Header nama grup sedang dibuka
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    groupName,
                    style: t.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Divider(height: 1),

                // ====== Menu utama grup
                item(
                  label: 'Info Grup',
                  icon: Icons.info_outline_rounded,
                  keyName: 'info',
                  onTap: () {
                    Navigator.pop(context);
                    if (current == 'info') return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupInfoPage(groupId: groupId),
                      ),
                    );
                  },
                ),
                item(
                  label: 'Kegiatan',
                  icon: Icons.event_note_outlined,
                  keyName: 'kegiatan',
                  onTap: () {
                    Navigator.pop(context);
                    if (current == 'kegiatan') return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupDetailPage(groupId: groupId),
                      ),
                    );
                  },
                ),
                item(
                  label: 'Keuangan',
                  icon: Icons.payments_outlined,
                  keyName: 'keuangan',
                  onTap: () {
                    Navigator.pop(context);
                    if (current == 'keuangan') return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupFinancePage(groupId: groupId),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 6),

                // ====== Shortcut grup lain
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
                      // ✅ UBAH "View all" → "Kelola"
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const RootPage()),
                            (_) => false,
                          );
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const GroupPage()),
                          );
                        },
                        child: const Text('Kelola'),
                      ),
                    ],
                  ),
                ),

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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
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
                              padding:
                                  const EdgeInsets.fromLTRB(12, 0, 12, 0),
                              itemCount: top5.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, i) {
                                final doc = top5[i];
                                final d = doc.data();
                                final name = (d['name'] ?? '-') as String;
                                final photoUrl =
                                    (d['photoUrl'] ?? '') as String;

                                final isCurrent = doc.id == groupId;

                                return _DrawerGroupShortcutTile(
                                  name: name,
                                  photoUrl: photoUrl,
                                  selected: isCurrent,
                                  onTap: () {
                                    Navigator.pop(context);
                                    if (isCurrent) return;
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => GroupDetailPage(
                                          groupId: doc.id,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                ),

                const Divider(height: 1),

                // ====== Home (icon only) + Profil di kanan
                ListTile(
                  leading: const Icon(
                    Icons.home_rounded,
                    color: SiKawanTheme.textSecondary,
                  ),
                  title: const SizedBox.shrink(), // ✅ tidak ada tulisan Home
                  trailing: uid == null
                      ? null
                      : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .snapshots(),
                          builder: (context, uSnap) {
                            final udata = uSnap.data?.data() ?? {};
                            final name = (udata['name'] ?? 'User') as String;
                            final photoUrl =
                                (udata['photoUrl'] ?? '') as String;

                            return InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ProfilePage(),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(999),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: SiKawanTheme.border,
                                  backgroundImage: photoUrl.isNotEmpty
                                      ? NetworkImage(photoUrl)
                                      : null,
                                  child: photoUrl.isEmpty
                                      ? Text(
                                          _initials(name),
                                          style: t.bodySmall?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: SiKawanTheme.textPrimary,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const RootPage()),
                      (_) => false,
                    );
                  },
                ),

                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _initials(String name) {
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
