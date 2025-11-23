import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/sikawan_theme.dart';
import 'activity_selfdev_editor_page.dart';

class ActivitySelfDevPage extends StatefulWidget {
  final String groupId;
  final String meetingId;

  const ActivitySelfDevPage({
    super.key,
    required this.groupId,
    required this.meetingId,
  });

  @override
  State<ActivitySelfDevPage> createState() => _ActivitySelfDevPageState();
}

class _ActivitySelfDevPageState extends State<ActivitySelfDevPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _isAdmin(Map<String, dynamic> gdata, String uid) {
    final admins = List<String>.from(gdata['admins'] ?? []);
    return admins.contains(uid);
  }

  Future<void> _deleteItem({
    required DocumentReference ref,
    required bool allowed,
  }) async {
    if (!allowed) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SiKawanTheme.surface,
        title: const Text('Hapus catatan?'),
        content: const Text('Data akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SiKawanTheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await ref.delete();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Tidak ada user'));

    final coll = _db
        .collection('groups')
        .doc(widget.groupId)
        .collection('meetings')
        .doc(widget.meetingId)
        .collection('selfdev');

    final groupRef = _db.collection('groups').doc(widget.groupId);

    return Scaffold(
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
          heroTag: 'addSelfDevFab',
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ActivitySelfDevEditorPage(
                groupId: widget.groupId,
                meetingId: widget.meetingId,
              ),
            ),
          ),
          child: const Icon(Icons.edit_rounded,
              color: Colors.white, size: 26),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: groupRef.snapshots(),
        builder: (context, gSnap) {
          final gdata = gSnap.data?.data() ?? {};
          final isAdmin = _isAdmin(gdata, uid);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: coll.orderBy('updatedAt', descending: true).snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              final t = Theme.of(context).textTheme;

              final myDraft = docs.where((d) =>
                  d.id == uid && (d.data()['published'] != true)).toList();
              final published = docs.where((d) =>
                  d.data()['published'] == true).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  if (myDraft.isNotEmpty) ...[
                    Text('Draft saya',
                        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    ...myDraft.map((d) {
                      final data = d.data();
                      return _Card(
                        title: 'Draft Pengembangan Diri',
                        subtitle: 'Belum dipublish',
                        content: (data['content'] ?? '') as String,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ActivitySelfDevEditorPage(
                              groupId: widget.groupId,
                              meetingId: widget.meetingId,
                            ),
                          ),
                        ),
                        onDelete: () =>
                            _deleteItem(ref: d.reference, allowed: true),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],

                  Text('Catatan dipublish',
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),

                  if (published.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          'Belum ada catatan.',
                          style: t.bodyMedium?.copyWith(
                            color: SiKawanTheme.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    ...published.map((d) {
                      final data = d.data();
                      final authorName = (data['authorName'] ?? '-') as String;
                      final publishedAt = (data['publishedAt'] as Timestamp?)?.toDate();
                      final subtitle =
                          '$authorName • ${publishedAt == null ? '-' : _fmtDateTime(publishedAt)}';

                      final mine = d.id == uid;
                      final canDelete = mine || isAdmin;

                      return _Card(
                        title: 'Pengembangan Diri',
                        subtitle: subtitle,
                        content: (data['content'] ?? '') as String,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: SiKawanTheme.surface,
                              title: const Text('Pengembangan Diri'),
                              content: SingleChildScrollView(
                                child: Text((data['content'] ?? '') as String),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Tutup'),
                                ),
                              ],
                            ),
                          );
                        },
                        onDelete:
                            canDelete ? () => _deleteItem(ref: d.reference, allowed: true) : null,
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _fmtDateTime(DateTime d) {
    final dd = '${d.day}/${d.month}/${d.year}';
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$dd $hh:$mm';
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String subtitle;
  final String content;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _Card({
    required this.title,
    required this.subtitle,
    required this.content,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final preview = content.trim().isEmpty
        ? '(kosong)'
        : (content.length > 120 ? '${content.substring(0, 120)}...' : content);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SiKawanTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SiKawanTheme.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_stories_outlined,
                color: SiKawanTheme.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w800)),
                  Text(subtitle,
                      style: t.bodySmall?.copyWith(
                        color: SiKawanTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 8),
                  Text(preview,
                      style: t.bodySmall?.copyWith(
                        color: SiKawanTheme.textSecondary,
                      )),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: SiKawanTheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
