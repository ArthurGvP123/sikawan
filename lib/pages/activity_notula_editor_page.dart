import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/sikawan_theme.dart';

class ActivityNotulaEditorPage extends StatefulWidget {
  final String groupId;
  final String meetingId;

  const ActivityNotulaEditorPage({
    super.key,
    required this.groupId,
    required this.meetingId,
  });

  @override
  State<ActivityNotulaEditorPage> createState() =>
      _ActivityNotulaEditorPageState();
}

class _ActivityNotulaEditorPageState extends State<ActivityNotulaEditorPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final _contentC = TextEditingController();
  bool _saving = false;
  bool _loaded = false;

  DocumentReference<Map<String, dynamic>> get _draftRef {
    final uid = _auth.currentUser!.uid;
    return _db
        .collection('groups')
        .doc(widget.groupId)
        .collection('meetings')
        .doc(widget.meetingId)
        .collection('notes')
        .doc(uid);
  }

  @override
  void initState() {
    super.initState();
    _loadDraft();
    _contentC.addListener(_autosave);
  }

  @override
  void dispose() {
    _contentC.removeListener(_autosave);
    _contentC.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    final snap = await _draftRef.get();
    final data = snap.data();
    if (data != null && data['published'] != true) {
      _contentC.text = (data['content'] ?? '') as String;
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _autosave() async {
    if (!_loaded) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _draftRef.set({
      'uid': uid,
      'title': 'Notula',
      'content': _contentC.text,
      'published': false,
      'authorName': _auth.currentUser?.displayName ?? 'Pengguna',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _publish() async {
    if (_saving) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);

    try {
      await _draftRef.set({
        'published': true,
        'publishedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notula dipublish.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal publish: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteDraft() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SiKawanTheme.surface,
        title: const Text('Hapus draft?'),
        content: const Text('Draft notula akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SiKawanTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await _draftRef.delete();

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tulis Notula'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _publish,
            child: _saving
                ? const SizedBox(
                    height: 16, width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Publish'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _contentC,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Tulis notula di sini...',
                  border: OutlineInputBorder(),
                ),
                style: t.bodyMedium,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _deleteDraft,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Batalkan / Hapus Draft'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SiKawanTheme.error,
                  side: const BorderSide(color: SiKawanTheme.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
