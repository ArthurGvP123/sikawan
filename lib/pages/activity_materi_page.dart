import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/drive_upload_service.dart';
import '../theme/sikawan_theme.dart';

class ActivityMateriPage extends StatefulWidget {
  final String groupId;
  final String meetingId;

  const ActivityMateriPage({
    super.key,
    required this.groupId,
    required this.meetingId,
  });

  @override
  State<ActivityMateriPage> createState() => _ActivityMateriPageState();
}

class _ActivityMateriPageState extends State<ActivityMateriPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _uploading = false;

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'application/octet-stream';
  }

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _uploading = true);

    try {
      final filename = file.name;

      final res = await DriveUploadService.uploadBytes(
        bytes: bytes,
        filename: filename,
        mimeType: _mimeFromName(filename),
        category: 'materials',
      );

      final directUrl = res['directUrl'] as String?;
      final fileId = res['fileId'] as String?;
      if (directUrl == null || fileId == null) {
        throw Exception('Upload gagal.');
      }

      await _db
          .collection('groups')
          .doc(widget.groupId)
          .collection('meetings')
          .doc(widget.meetingId)
          .collection('materials')
          .add({
        'url': directUrl,
        'fileId': fileId,
        'filename': filename,
        'uploadedBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal upload: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coll = _db
        .collection('groups')
        .doc(widget.groupId)
        .collection('meetings')
        .doc(widget.meetingId)
        .collection('materials')
        .orderBy('createdAt', descending: true);

    final t = Theme.of(context).textTheme;

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
          heroTag: 'addMateriFab',
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: _pickAndUpload,
          child: _uploading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Icon(Icons.add_rounded,
                  color: Colors.white, size: 28),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: coll.snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Text(
                'Belum ada materi dibagikan.',
                style: t.bodyMedium?.copyWith(
                  color: SiKawanTheme.textSecondary,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final name = (d['filename'] ?? 'Materi') as String;
              final url = (d['url'] ?? '') as String;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SiKawanTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SiKawanTheme.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_outlined,
                        color: SiKawanTheme.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style:
                            t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Buka link',
                      onPressed: () {
                        // untuk sekarang tampilkan link aja
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: SiKawanTheme.surface,
                            title: Text(name),
                            content: SelectableText(url),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Tutup'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.open_in_new_rounded),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
