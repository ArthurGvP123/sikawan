import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/drive_upload_service.dart';
import '../theme/sikawan_theme.dart';

class ActivityDokumentasiPage extends StatefulWidget {
  final String groupId;
  final String meetingId;

  const ActivityDokumentasiPage({
    super.key,
    required this.groupId,
    required this.meetingId,
  });

  @override
  State<ActivityDokumentasiPage> createState() =>
      _ActivityDokumentasiPageState();
}

class _ActivityDokumentasiPageState extends State<ActivityDokumentasiPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _picker = ImagePicker();

  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final img = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (img == null) return;

    setState(() => _uploading = true);

    try {
      final Uint8List bytes = await img.readAsBytes();
      final filename = img.name.isNotEmpty
          ? img.name
          : 'doc_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final res = await DriveUploadService.uploadBytes(
        bytes: bytes,
        filename: filename,
        mimeType: 'image/jpeg',
        category: 'documentation',
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
          .collection('docs_media')
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
        .collection('docs_media')
        .orderBy('createdAt', descending: true);

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
          heroTag: 'addDocFab',
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
              : const Icon(Icons.add_a_photo_rounded,
                  color: Colors.white, size: 26),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: coll.snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          final t = Theme.of(context).textTheme;

          if (docs.isEmpty) {
            return Center(
              child: Text(
                'Belum ada dokumentasi.',
                style: t.bodyMedium?.copyWith(
                  color: SiKawanTheme.textSecondary,
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final url = (d['url'] ?? '') as String;

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: InteractiveViewer(
                          child: Image.network(url, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(url, fit: BoxFit.cover),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
